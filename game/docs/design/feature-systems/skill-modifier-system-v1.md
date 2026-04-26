# Skill Modifier 系统设计 (v1)
**Status:** Approved
**Version:** 1.0
**Date:** 2026-04-22
**Owner:** Design + Engineering
**Related:** `godot-skill-system-node-architecture.md` · `hero-skill-template-v1.md` · `skill-system-architecture-2026-04-15.md`

---

## 1. 概述

Modifier 系统是技能效果叠加、变体、延展的核心机制。所有非基础技能的效果变化，都通过**在基础技能上叠加 Modifier** 实现，而不是修改技能代码本身。

**核心设计原则**：Modifier 是**装饰器（Decorator）**，不是技能本身。Modifier 只改变**执行参数**或**插入新的执行分支**，不替代 Effect 执行树的结构。

---

## 2. Modifier 与 Effect 的关系

```
Effect 执行树（技能的结构骨架）
  │
  └─ 叶子节点 = EmitProjectileEffect
                   │
                   ├── 参数（direction, speed, damage, scale...）
                   └── Modifier Stack
                        │
                        ├── [Scatter]          ← 创建 N 个子链
                        ├── [Fission]          ← 注册 distance 触发器
                        ├── [Bounce]           ← 注册 hit 触发器
                        └── [Expansion]        ← 注册 distance 触发器
```

Modifier 的执行结果是**一棵完整的树**：

```
根链（隐式）
  │
  ├── EmitProjectile (chain_1)    ← Scatter 产生
  │     ├── modifier_stack = [Fission, Bounce, Expansion]
  │     │     │
  │     │     └── Fission 触发 → chain_1-1 + chain_1-2
  │     │           │
  │     │           ├── chain_1-1: modifier_stack = [Bounce, Expansion]
  │     │           │     │
  │     │           └── chain_1-2: modifier_stack = [Bounce, Expansion]
  │     │                 │
  │     │                 └── 命中 → Bounce → 转向 → 继续飞
  │     │
  │     └── 命中 → 伤害结算
  │
  ├── EmitProjectile (chain_2)    ← Scatter 产生（5条中的第2条）
  │     └── 同上...
  │
  └── EmitProjectile (chain_3/4/5)...
```

---

## 3. Modifier 完整分类

### 3.1 TRAJECTORY — 修改运动轨迹

| Modifier | ID | 触发时机 | 核心参数 | 行为 |
|---------|-----|---------|---------|------|
| 散射 | `scatter` | on_cast | `num_projectiles`, `fan_angle_deg` | 创建 N 条扇形分支 |
| 曲线路径 | `curved_path` | on_cast | `curve_type`, `control_point_offset`, `travel_time_multiplier` | 注册曲线算法 |

#### ScatterModifier

```gdscript
class_name ScatterModifier
extends SkillModifier

var num_projectiles: int = 5
var fan_angle_deg: float = 60.0

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
    if chain.modifier_index > 0:
        return []  # Scatter 只在最外层生效，不递归
    
    var base_angle := chain.direction
    var step := fan_angle_deg / (num_projectiles - 1) if num_projectiles > 1 else 0.0
    var start_angle := base_angle - fan_angle_deg / 2.0
    
    var children := []
    for i in num_projectiles:
        var angle := start_angle + step * i
        var child := chain.duplicate()
        child.direction = angle
        child.chain_id = ChainIdGenerator.next()
        child.modifier_index = chain.modifier_index  # 子链继承当前索引
        children.append(child)
    
    # 母体消失（Scatter 替代了原始链）
    chain.behavior_state = "Destroyed"
    return children
```

#### CurvedPathModifier

```gdscript
class_name CurvedPathModifier
extends SkillModifier

enum CurveType:
    BEZIER_QUAD   # 二次贝塞尔
    BEZIER_CUBIC  # 三次贝塞尔
    SINE_WAVE     # 正弦波动
    SPIRAL        # 螺旋

var curve_type: CurveType = CurveType.BEZIER_QUAD
var control_point_offset: float = 100.0  # 控制点垂直偏移
var travel_time_multiplier: float = 1.5  # 飞行时间倍率

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
    # 不产生新链，只修改母链的运动算法
    chain.trajectory_type = curve_type
    chain.control_point_offset = control_point_offset
    chain.travel_time_multiplier = travel_time_multiplier
    return []
```

---

### 3.2 LIFETIME — 修改存活/消失逻辑

| Modifier | ID | 触发时机 | 核心参数 | 行为 |
|---------|-----|---------|---------|------|
| 弹射 | `bounce` | on_hit | `max_bounces` | 命中后转向最近敌人 |
| 分裂 | `fission` | distance_traveled | `half_life_distance`, `split_count`, `scale_factor`, `damage_factor` | 距离触发分裂 |
| 抛射物HP | `projectile_hp` | on_cast | `hp`, `destroy_on_hp_zero` | 可被敌对伤害打爆 |

#### BounceModifier

```gdscript
class_name BounceModifier
extends SkillModifier

var max_bounces: int = 2

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
    chain.projectile_hp += max_bounces  # 弹射消耗额外生命
    chain.register_hit_trigger(_on_hit)
    return []

func _on_hit(chain: ExecutionChain, target: Node2D) -> void:
    if chain.bounce_remaining > 0:
        chain.bounce_remaining -= 1
        var next := _find_nearest_enemy_excluding(chain, target)
        if next:
            chain.direction = chain.position.direction_to(next.global_position)
            chain.target = next
            chain.keep_alive()
        else:
            chain.destroy()
    else:
        chain.destroy()  # 无弹射次数，消失
```

#### FissionModifier

```gdscript
class_name FissionModifier
extends SkillModifier

var half_life_distance: float = 150.0
var split_count: int = 2
var scale_factor: float = 0.7
var damage_factor: float = 0.6
var split_angle_spread_deg: float = 30.0

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
    chain.register_distance_trigger(half_life_distance, _on_fission)
    return []

func _on_fission(chain: ExecutionChain) -> void:
    var parent := chain  # 保存父链引用
    var base_angle := chain.direction
    var step := split_angle_spread_deg / (split_count - 1) if split_count > 1 else 0.0
    var start_angle := base_angle - split_angle_spread_deg / 2.0
    
    for i in split_count:
        var child := chain.duplicate()
        child.chain_id = ChainIdGenerator.next()
        child.direction = start_angle + step * i
        child.position = chain.position
        child.scale *= scale_factor
        child.damage *= damage_factor
        child.current_radius *= scale_factor
        child.modifier_index = chain.modifier_index
        # 半衰期分裂的子链，移除自身的 Fission（防止无限分裂）
        child.modifier_stack = _remove_fission_from_stack(chain.modifier_stack)
        # 通知父链加入子链
        parent.add_child(child)
    
    chain.destroy()  # 母体消失
```

#### ProjectileHPModifier

```gdscript
class_name ProjectileHPModifier
extends SkillModifier

var hp: float = 100.0
var destroy_on_hp_zero: bool = true

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
    chain.projectile_hp = hp
    chain.can_be_targeted = true
    chain.connect("projectile_damaged", _on_damaged)
    return []

func _on_damaged(chain: ExecutionChain, damage: float) -> void:
    chain.projectile_hp -= damage
    if chain.projectile_hp <= 0:
        if destroy_on_hp_zero:
            chain.explode()
        else:
            chain.destroy()
```

---

### 3.3 APPEARANCE — 修改外观

| Modifier | ID | 触发时机 | 核心参数 | 行为 |
|---------|-----|---------|---------|------|
| 膨胀 | `expansion` | distance_traveled | `size_growth_per_distance`, `max_scale` | 尺寸随距离增长 |
| 色彩偏移 | `color_shift` | on_cast | `color_override` | 改变抛射物颜色 |

#### ExpansionModifier

```gdscript
class_name ExpansionModifier
extends SkillModifier

var size_growth_per_distance: float = 0.02  # 每单位距离增加 2% 尺寸
var max_scale: float = 3.0  # 最大放大倍数

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
    chain.add_distance_trigger(1.0, _on_expand)  # 每1像素检查一次
    return []

func _on_expand(chain: ExecutionChain) -> void:
    if chain.distance_traveled > 0:
        var new_scale := chain.base_scale + chain.distance_traveled * size_growth_per_distance
        chain.scale = minf(new_scale, max_scale)
        chain.current_radius = chain.base_radius * chain.scale
```

---

### 3.4 BEHAVIOR — 添加命中行为

| Modifier | ID | 触发时机 | 核心参数 | 行为 |
|---------|-----|---------|---------|------|
| 命中减速 | `slow_on_hit` | on_hit | `slow_factor`, `slow_duration` | 在命中处留下减速场 |

---

### 3.5 CONDITIONAL — 条件生效

| Modifier | ID | 触发时机 | 核心参数 | 行为 |
|---------|-----|---------|---------|------|
| 条件压制 | `conditional_suppress` | on_cast | `suppressed_modifier_ids`, `condition_tag` | 满足条件时压制其他 Modifier |
| 光环强化 | `aura_amplify` | on_cast | `amplified_modifier_ids`, `aura_tag`, `amplify_factor` | 满足条件时强化其他 Modifier |

#### ConditionalSuppressModifier

```gdscript
class_name ConditionalSuppressModifier
extends SkillModifier

var suppressed_modifier_ids: Array[String]
var condition_tag: String  # e.g. "in_boss_suppression_aura"

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
    if not ConditionEvaluator.evaluate(condition_tag, chain.caster):
        return []
    
    for mod_id in suppressed_modifier_ids:
        chain.suppress_modifier(mod_id)
    return []
```

---

## 4. 触发时机体系

所有触发时机在 `ExecutionChain` 中统一管理：

```gdscript
# 触发时机类型
enum TriggerTiming:
    ON_CAST         # 施放时（最早）
    ON_HIT          # 命中目标时
    TIME_ELAPSED    # 经过时间触发
    DISTANCE_TRAVELED  # 飞行距离触发
    ON_EXPLODE      # 抛射物爆炸时
    AURA_ENTER      # 进入光环范围时
    AURA_EXIT       # 离开光环范围时

# Chain 上的触发器注册
func register_hit_trigger(callback: Callable) -> void:
    hit_triggers.append({"callback": callback})

func register_distance_trigger(distance: float, callback: Callable) -> void:
    # 插入已排序的距离触发器列表
    var pos := distance_triggers.size()
    for i in distance_triggers.size():
        if distance < distance_triggers[i]["dist"]:
            pos = i
            break
    distance_triggers.insert(pos, {"dist": distance, "callback": callback, "triggered": false})

# 每帧检查触发器（在 ProjectileNode._process 中调用）
func check_triggers(chain: ExecutionChain, dt: float) -> void:
    # 时间触发
    for t in time_triggers:
        if elapsed >= t["time"] and not t["triggered"]:
            t["triggered"] = true
            t["callback"].call(chain)
    
    # 距离触发
    for d in distance_triggers:
        if chain.distance_traveled >= d["dist"] and not d["triggered"]:
            d["triggered"] = true
            d["callback"].call(chain)
```

---

## 5. Modifier 冲突规则

| 场景 | 处理规则 |
|------|---------|
| 同一 `modifier_id` 出现多次 | 后者覆盖前者（Component 模式） |
| 不同来源的同类型 Modifier | 各自独立，都生效（如两个 Scatter 叠加 = 扇形内再扇形） |
| `conditional_suppress` 压制了某 Modifier | 被压制者的 `is_active()` 返回 false，不注册任何触发器 |
| Modifier 顺序不同导致效果不同 | `Scatter → Bounce`（散射后每枚独立弹）≠ `Bounce → Scatter`（先弹再散成多枚）|
| 分裂后的子链继承 Modifier | 继承当前 `modifier_stack` 的副本，且通常移除当前 Modifier 防止无限分裂 |

---

## 6. Modifier 叠加示例：从火球到超级火球

### 阶段 0：基础火球
```
SkillDef: ironwall_basic
Effect: EmitProjectile
Modifier: []
```

### 阶段 1：+ 散射（来自装备）
```
SkillDef: ironwall_basic
Effect: EmitProjectile
Modifier: [Scatter(num=5, fan=60°)]
结果：发射 5 枚火球
```

### 阶段 2：+ 弹射（来自天赋）
```
SkillDef: ironwall_basic
Effect: EmitProjectile
Modifier: [Scatter(num=5, fan=60°), Bounce(max=2)]
结果：5 枚火球各弹射 2 次
```

### 阶段 3：+ 半衰期分裂（来自强化宝石）
```
SkillDef: ironwall_basic
Effect: EmitProjectile
Modifier: [Scatter, Fission(half_life=150, count=2), Bounce]
结果：5 枚火球各在飞行150距离后分裂成2枚更小火球（共10枚），每枚再弹射2次
```

### 阶段 4：+ 贝塞尔曲线（来自被动技能）
```
SkillDef: ironwall_basic
Effect: EmitProjectile
Modifier: [Scatter, Fission, Bounce, CurvedPath(bezier_quad)]
结果：所有火球走贝塞尔曲线飞行，时间×1.5
```

### 阶段 5：+ 生命飞弹（来自升级效果）
```
SkillDef: ironwall_basic
Effect: EmitProjectile
Modifier: [Scatter, Fission, Bounce, CurvedPath, ProjectileHP(hp=50)]
结果：所有火球可被敌对伤害打爆
```

### 阶段 6：Boss 光环抑制分裂，但追加膨胀
```
额外 Modifier（来自 BOSS 光环）:
Modifier: [ConditionalSuppress(suppressed=fission), Expansion(rate=0.05)]
结果：分裂被压制，替换为膨胀效果（每飞行1像素，尺寸+5%）
```

---

## 7. ConditionEvaluator — 条件评估器

所有 Modifier 的激活条件由 `ConditionEvaluator` 统一评估：

```gdscript
class_name ConditionEvaluator
extends Node

static func evaluate(tag: String, caster: Node2D) -> bool:
    match tag:
        "always":        return true
        "never":         return false
        "in_boss_aura":  return AuraManager.is_caster_in_aura(caster, "boss_suppression")
        "hp_below_50%":  return caster.get_hp_ratio() < 0.5
        "has_enhance_x": return caster.has_skill_enhancement("fireball", 3)
        _:               return false
```

条件标签定义在 `.tres` 文件中，或配置在 `conditions.csv` 里。

---

## 8. 数据配置示例

所有 Modifier 参数在 `.tres` 文件中配置：

```
resources/skills/modifiers/
├── scatter.tres
├── bounce.tres
├── fission.tres
├── curved_path.tres
├── expansion.tres
├── projectile_hp.tres
├── conditional_suppress.tres
└── aura_amplify.tres
```

```gdscript
# scatter.tres (Resource)
class_name ScatterModifierData
extends Resource

@export var modifier_id: String = "scatter"
@export var modifier_type: SkillModifier.ModifierType = SkillModifier.ModifierType.TRAJECTORY
@export var priority: int = 10
@export var trigger_timing: String = "on_cast"
@export var num_projectiles: int = 5
@export var fan_angle_deg: float = 60.0
@export var condition_tag: String = ""  # 空=无条件激活

func to_modifier() -> SkillModifier:
    var m := ScatterModifier.new()
    m.modifier_id = modifier_id
    m.modifier_type = modifier_type
    m.priority = priority
    m.trigger_timing = trigger_timing
    m.num_projectiles = num_projectiles
    m.fan_angle_deg = fan_angle_deg
    m.condition_tag = condition_tag
    return m
```

---

## 9. Modifier 体系在 SkillSystem 中的位置

```
SkillSystem
  │
  ├── SkillRegistry
  │     └── skill_id → SkillDef  (含基础 modifier_ids[])
  │
  ├── ModifierRegistry
  │     └── modifier_id → SkillModifierData (.tres)
  │
  └── ModifierProcessor
        │
        ├─ resolve(skill_def, active_modifiers, context)
        │    │
        │    └─ 遍历 chain.modifier_stack
        │         │
        │         └─ for mod in sorted_modifiers:
        │              if mod.is_active(caster):
        │                   children := mod.apply(chain)
        │
        └─ → Array[ExecutionChain] (叶子链列表)
             │
             └─ → ProjectilePool.spawn(chain)
                  │
                  └─ ProjectileNode._process()
                       ├─ check_triggers()  ← 检查所有触发器
                       ├─ update_position()  ← 根据 trajectory_type 移动
                       └─ emit behavior_update
```

---

## 10. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-22 | 初稿：Modifier 分类体系 + 执行流程 + 数据配置 |
