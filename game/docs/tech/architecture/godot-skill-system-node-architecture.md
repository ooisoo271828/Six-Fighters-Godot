# Godot 技能系统节点架构
**Status:** Approved
**Version:** 1.0
**Date:** 2026-04-22
**Owner:** Engineering + Design
**Related:** `skill-modifier-system-v1.md` · `hero-skill-template-v1.md` · `skill-system-architecture-2026-04-15.md`

---

## 1. 设计原则：四个分离

技能系统是游戏最核心的子系统，必须遵循以下四个分离原则：

| 分离维度 | 内容 | Godot 实现 |
|---------|------|-----------|
| 技能定义 vs 技能视觉 | 战斗参数和美术参数分离 | `SkillDef` vs `SkillVisualDef` |
| 逻辑执行 vs 美术表现 | Behavior 和 ProjectileDef 分离 | `SkillEffect` + `ModifierProcessor` vs `SkillVFX` |
| 战斗结算 vs 视觉播放 | 伤害计算和粒子动画分离 | `DamageResolver` vs `SkillVFXManager` |
| 施法者 vs 技能引用 | Unit 只引用 skillId，不持有技能实例 | 全局 `SkillRegistry` |

**核心原则**：所有变化通过**数据配置**解决，不通过**代码分支**解决。

---

## 2. SkillSystem 场景节点树

`res://scenes/skill_system/skill_system.tscn` 是技能系统的根场景，可独立调试，也可作为子场景嵌入任何父场景。

```
res://scenes/skill_system/
├── skill_system.tscn                      ← 根场景
├── scripts/
│   ├── skill_root.gd                     ← 场景根脚本（初始化）
│   ├── registry/
│   │   ├── skill_registry.gd             ← 技能数据注册中心
│   │   └── modifier_registry.gd          ← Modifier 注册中心
│   ├── core/
│   │   ├── skill_effect.gd               ← Effect 基类
│   │   ├── effects/
│   │   │   ├── emit_projectile.gd        ← 发射抛射物
│   │   │   ├── area_damage.gd            ← 区域伤害
│   │   │   ├── apply_status.gd           ← 施加状态
│   │   │   └── emit_burst.gd             ← 爆发效果
│   │   ├── modifier/
│   │   │   ├── skill_modifier.gd         ← Modifier 基类
│   │   │   ├── modifiers/
│   │   │   │   ├── scatter.gd            ← 散射
│   │   │   │   ├── bounce.gd              ← 弹射
│   │   │   │   ├── fission.gd             ← 分裂
│   │   │   │   ├── curved_path.gd         ← 曲线路径
│   │   │   │   ├── expansion.gd           ← 膨胀
│   │   │   │   ├── projectile_hp.gd       ← 抛射物生命值
│   │   │   │   └── conditional_suppress.gd← 条件压制
│   │   │   └── modifier_processor.gd     ← 执行引擎
│   │   ├── execution_chain.gd            ← 执行链（状态载体）
│   │   ├── skill_executor.gd             ← 施法执行器
│   │   └── damage_resolver.gd            ← 伤害结算
│   ├── vfx/
│   │   ├── skill_vfx_manager.gd          ← VFX 总控
│   │   ├── projectile_vfx.gd             ← 抛射物视觉
│   │   └── effects_vfx.gd                ← 冲击/Buff 视觉
│   ├── pools/
│   │   ├── projectile_pool.gd            ← 投射物对象池
│   │   └── executor_pool.gd              ← 执行器对象池
│   └── signal_bus/
│       └── skill_signal_bus.gd           ← 信号总线
└── nodes/
    ├── projectile.tscn                    ← 投射物节点模板
    └── executor.tscn                      ← 执行器节点模板
```

---

## 3. 数据资源设计

所有技能和 Modifier 参数存储在 `.tres` 资源文件中，可直接在 Godot Inspector 编辑。

```
res://resources/
├── skills/
│   ├── skill_defs/                       ← 技能战斗数据
│   │   ├── ironwall_basic.tres
│   │   ├── ironwall_small_a.tres
│   │   ├── ember_basic.tres
│   │   └── ...
│   ├── skill_visual_defs/                ← 技能视觉参数
│   │   ├── ironwall_basic_vfx.tres
│   │   └── ...
│   └── modifiers/                        ← Modifier 数据配置
│       ├── scatter.tres
│       ├── bounce.tres
│       ├── fission.tres
│       └── ...
└── units/
    ├── heroes/
    │   ├── ironwall.tres
    │   ├── ember.tres
    │   └── moss.tres
    └── enemies/
        └── ...
```

---

## 4. 节点职责明细

### 4.1 SkillRegistry (Node)

- 启动时 `preload` 所有 `resources/skills/skill_defs/*.tres`
- 构建 `skill_id → SkillDef` 的字典映射
- 提供查询 API：
  - `get_skill(skill_id: String) → SkillDef`
  - `get_skill_visual(skill_id: String) → SkillVisualDef`
  - `get_all_skills() → Array[SkillDef]`

### 4.2 ModifierRegistry (Node)

- 启动时 `preload` 所有 `resources/skills/modifiers/*.tres`
- 构建 `modifier_id → SkillModifierData` 的字典映射
- 提供查询 API：
  - `get_modifier(modifier_id: String) → SkillModifierData`
  - `get_entity_modifiers(entity: Node2D, skill_id: String) → Array[SkillModifier]`
    - 内部聚合：基础技能 Modifier + 装备 Modifier + 天赋 Modifier + 环境/光环 Modifier

### 4.3 ModifierProcessor (Node)

**核心执行引擎**。每次施放技能时：
1. 构建基础 `ExecutionChain`
2. 按优先级排序所有 Modifier
3. 依次调用每个 Modifier 的 `apply()` 方法
4. Modifier 可能产生新的子链（Scatter、Fission）
5. 返回完整的叶子链列表

### 4.4 SkillExecutorPool (Node2D)

- 预创建 N 个 `SkillExecutor` 实例
- `acquire() → SkillExecutor`：从池中取空闲执行器
- `release(executor)`：归还执行器（不销毁）
- 每个执行器持有自己的 `ExecutionChain`

### 4.5 ProjectilePool (Node2D)

- 预创建 N 个 `ProjectileNode` 实例
- `spawn(chain: ExecutionChain) → ProjectileNode`：从池中取节点，初始化为指定链
- `despawn(node)`：归还节点
- **这是 Node2D 节点树中最重要的部分**——所有技能视觉表现都挂在这里
- 坐标是世界坐标，与场景中的 Unit 在同一空间

### 4.6 SkillVFXManager (Node)

- 监听 `SkillSignalBus` 的所有信号
- 驱动粒子/动画/光效
- 管理粒子池、光束池、冲击效果池
- 完全独立于战斗逻辑

### 4.7 SkillSignalBus (Node)

所有技能事件的信号集中定义点：

```gdscript
# 施放相关
signal skill_cast_requested(caster: Node2D, skill_id: String, target: Node2D)
signal skill_cast_started(caster: Node2D, skill_id: String, target_pos: Vector2)
signal skill_cast_finished(caster: Node2D, skill_id: String)

# 命中相关
signal skill_hit(caster: Node2D, targets: Array[Node2D], damage_info: Dictionary)
signal skill_missed(caster: Node2D, target: Node2D)

# 投射物行为相关
signal behavior_spawned(projectile: Node2D, behavior_type: String)
signal behavior_update(projectile: Node2D, state: String, position: Vector2)
signal behavior_complete(projectile: Node2D)

# 预警相关
signal telegraph_started(caster: Node2D, target_pos: Vector2, shape: String, duration: float)
signal telegraph_finished(caster: Node2D, target_pos: Vector2)

# VFX 相关
signal vfx_request(effect_id: String, world_pos: Vector2, params: Dictionary)
signal impact_effect(target: Node2D, impact_level: String)
```

---

## 5. Effect 执行树模型

技能不是一条指令，是一个**可以分支的树**。

### 5.1 SkillEffect — 执行树节点基类

```gdscript
class_name SkillEffect
extends RefCounted

# 执行上下文
class ExecutionContext:
    var caster: Node2D
    var target: Node2D
    var target_pos: Vector2
    var direction: Vector2
    var damage: float
    var damage_type: String
    var chain: ExecutionChain  # 持有这条链的引用

# 返回 0 个或多个执行分支
func execute(context: ExecutionContext) -> Array[ExecutionChain]:
    pass

func get_effect_id() -> String:
    return "base_effect"
```

### 5.2 Effect 节点类型

| 节点类型 | 类名 | 语义 |
|---------|------|------|
| 发射抛射物 | `EmitProjectileEffect` | 创建投射物叶子节点 |
| 区域伤害 | `AreaDamageEffect` | 在指定区域结算伤害（瞬发） |
| 施加状态 | `ApplyStatusEffect` | 给目标施加状态效果 |
| 爆发效果 | `EmitBurstEffect` | 在位置产生爆发视觉 |
| 发射子 Effect | `EmitChildEffect` | 在指定时机创建子链 |

### 5.3 叶子节点：EmitProjectileEffect

最重要的 Effect 叶子节点——是 Modifier 最终修改的对象：

```gdscript
class_name EmitProjectileEffect
extends SkillEffect

func execute(context: ExecutionContext) -> Array[ExecutionChain]:
    var chain := ExecutionChain.new()
    chain.effect = self
    chain.position = context.caster.global_position
    chain.direction = context.direction
    chain.damage = context.damage
    chain.damage_type = context.damage_type
    chain.speed = 300.0  # 从 SkillVisualDef 读取
    chain.scale = 1.0
    chain.projectile_hp = 0.0  # 0 = 不可破坏
    chain.modifier_stack = context.chain.modifier_stack.duplicate()
    return [chain]  # 返回一条链，交给 ProjectilePool 处理
```

---

## 6. ExecutionChain — 执行链（状态载体）

每条叶子链承载一个抛射物路径的所有运行时状态：

```gdscript
class_name ExecutionChain
extends RefCounted

# 基础信息
var chain_id: int
var effect: SkillEffect
var caster: Node2D
var target: Node2D
var target_pos: Vector2

# 运动参数
var position: Vector2
var direction: Vector2
var speed: float
var distance_traveled: float = 0.0

# 伤害参数
var damage: float
var damage_type: String
var base_damage: float  # 用于计算分裂后的伤害比例

# 外观参数
var scale: float = 1.0
var current_radius: float = 4.0

# 抛射物生命值（0 = 不可破坏）
var projectile_hp: float = 0.0
var can_be_targeted: bool = false

# Modifier 栈（从父链继承并可能被裁剪）
var modifier_stack: Array[SkillModifier]

# 当前 Modifier 索引（已处理到第几个）
var modifier_index: int = 0

# 子链列表（Modifier 可能在此列表添加新链）
var child_chains: Array[ExecutionChain]

# 当前行为状态（Flying / Hit / Exploded / Fading）
var behavior_state: String = "Flying"

# 注册的触发器
var time_triggers: Array[Dictionary]
var distance_triggers: Array[Dictionary]
var hit_triggers: Array[Dictionary]

# ── 触发器注册 API ──
func add_time_trigger(time_sec: float, callback: Callable) -> void:
    time_triggers.append({"time": time_sec, "callback": callback})

func add_distance_trigger(dist: float, callback: Callable) -> void:
    distance_triggers.append({"dist": dist, "callback": callback})

func add_hit_trigger(callback: Callable) -> void:
    hit_triggers.append({"callback": callback})

# ── 链操作 API ──
func duplicate() -> ExecutionChain:
    var c := ExecutionChain.new()
    c.effect = effect
    c.caster = caster
    c.target = target
    c.target_pos = target_pos
    c.position = position
    c.direction = direction
    c.speed = speed
    c.damage = damage
    c.damage_type = damage_type
    c.base_damage = base_damage
    c.scale = scale
    c.current_radius = current_radius
    c.projectile_hp = projectile_hp
    c.can_be_targeted = can_be_targeted
    c.modifier_stack = modifier_stack
    c.modifier_index = modifier_index
    return c

func add_child(new_chain: ExecutionChain) -> void:
    child_chains.append(new_chain)

func suppress_modifier(modifier_id: String) -> void:
    for mod in modifier_stack:
        if mod.modifier_id == modifier_id:
            mod._suppressed = true

func keep_alive() -> void:
    behavior_state = "Flying"

func destroy() -> void:
    behavior_state = "Destroyed"
```

---

## 7. SkillModifier 系统

### 7.1 Modifier 基类

```gdscript
class_name SkillModifier
extends RefCounted

enum ModifierType:
    TRAJECTORY   # 修改运动轨迹
    LIFETIME     # 修改存活/消失逻辑
    APPEARANCE   # 修改外观
    BEHAVIOR     # 添加命中行为
    CONDITIONAL  # 条件生效/压制

var modifier_id: String = ""
var modifier_type: ModifierType = ModifierType.TRAJECTORY
var priority: int = 100  # 越小越先执行
var trigger_timing: String = "on_cast"  # on_cast / on_hit / time_elapsed / distance_traveled
var _suppressed: bool = false

# 条件（通过 .tres 配置，空 = 无条件）
var condition_tag: String = ""

func is_active(caster: Node2D) -> bool:
    if _suppressed:
        return false
    if condition_tag == "":
        return true
    # 查找 ConditionEvaluator 查询条件结果
    return ConditionEvaluator.evaluate(condition_tag, caster)

# Modifier 的核心接口
# 返回新产生的子链（Scatter/Fission 等会产生新链）
func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
    return []
```

### 7.2 Modifier 完整分类

| 类型 | 类名 | 触发时机 | 作用 |
|------|------|---------|------|
| 散射 | `ScatterModifier` | on_cast | 把单链复制为 N 条扇形分支 |
| 曲线路径 | `CurvedPathModifier` | on_cast | 注册贝塞尔曲线轨迹 |
| 弹射 | `BounceModifier` | on_hit | 命中后转向最近敌人继续飞行 |
| 分裂 | `FissionModifier` | distance_traveled | 飞行距离触发分裂成多个子抛射物 |
| 膨胀 | `ExpansionModifier` | distance_traveled | 尺寸随距离线性增长 |
| 抛射物HP | `ProjectileHPModifier` | on_cast | 抛射物可被敌对伤害打爆 |
| 条件压制 | `ConditionalSuppressModifier` | on_cast | 有条件地压制其他 Modifier |
| 命中减速 | `SlowOnHitModifier` | on_hit | 命中后在目标处留下减速场 |

### 7.3 Modifier 执行优先级

```
priority = 0  → ConditionalSuppress（最先执行，决定压制关系）
priority = 10  → Scatter（产生分支，后续 Modifier 作用于每条分支）
priority = 20  → CurvedPath（修改轨迹算法）
priority = 50  → Fission（注册距离触发）
priority = 60  → Bounce（注册命中触发）
priority = 80  → Expansion（注册距离触发）
priority = 100 → ProjectileHP（最后注册基础属性）
```

### 7.4 Modifier 冲突处理规则

- 同类型 Modifier 后来者覆盖前者（如两个不同来源的 Scatter）
- `ConditionalSuppress` 在最优先执行，发现压制条件满足时设置 `_suppressed = true`
- 被压制的 Modifier 在 `is_active()` 时返回 `false`，不注册任何触发器

---

## 8. ModifierProcessor 执行引擎

```gdscript
class_name ModifierProcessor
extends Node

func resolve(
    base_effect: SkillEffect,
    modifiers: Array[SkillModifier],
    context: SkillEffect.ExecutionContext
) -> Array[ExecutionChain]:
    # 1. 构建根链
    var root_chain := ExecutionChain.new()
    root_chain.effect = base_effect
    root_chain.caster = context.caster
    root_chain.target = context.target
    root_chain.target_pos = context.target_pos
    root_chain.direction = context.direction
    root_chain.position = context.caster.global_position
    root_chain.damage = context.damage
    root_chain.damage_type = context.damage_type
    root_chain.base_damage = context.damage
    root_chain.modifier_stack = modifiers
    
    # 2. 按优先级排序
    var sorted_mods := modifiers.duplicate()
    sorted_mods.sort_custom(_sort_by_priority)
    
    # 3. 依次处理 Modifier
    var all_chains := [root_chain]
    var pending := [root_chain]
    
    while not pending.is_empty():
        var chain: ExecutionChain = pending.pop_front()
        var remaining_mods := chain.modifier_stack
        
        for mod in remaining_mods:
            if not mod.is_active(chain.caster):
                continue
            
            var children := mod.apply(chain)
            for child in children:
                pending.push_back(child)
                all_chains.push_back(child)
    
    return all_chains

func _sort_by_priority(a: SkillModifier, b: SkillModifier) -> bool:
    return a.priority < b.priority
```

---

## 9. 三种使用模式

### 模式 A：独立调试
```
直接打开 skill_system.tscn 作为根场景
↓
SkillRegistry 加载所有 .tres 数据
↓
内置测试 UI 手动触发技能
↓
SkillExecutorPool 执行 → ProjectilePool 显示
↓
在 SkillSystem 自己的场景里观察所有细节
```

### 模式 B：嵌入竞技场
```
HubScene
  ↓
ArenaScene (arena.tscn)
  │
  └── SkillSystem (skill_system.tscn)
        ↓ add_child() 或 preload().instantiate()
        ↓ position = Vector2.ZERO（世界坐标对齐）
```

ArenaScene 通过信号通信：
- `arena → skill_system`：调用 `skill_system.cast_skill(hero, skill_id, target)`
- `skill_system → arena`：监听 `SkillSignalBus.skill_hit`

### 模式 C：关卡编辑器
```
LevelEditorScene
  └── SkillSystem（同一套）
```

---

## 10. ProjectilePool 在节点树中的坐标

`SkillSystem` 作为 `Node2D` 嵌入 Arena 时，其 `position` 即世界坐标原点：

```
ArenaScene (Node2D, 世界坐标系原点)
  │
  ├── Units (Node2D)
  │   ├── Heroes (Node2D)  ← 位置在世界坐标
  │   └── Enemies (Node2D) ← 位置在世界坐标
  │
  └── SkillSystem (Node2D) ← position = (0, 0)，子节点自然在世界坐标
        │
        └── ProjectilePool (Node2D)
              ├── Projectile_001  ← position = 世界坐标
              ├── Projectile_002
              └── ...
```

---

## 11. 扩展性保障

| 扩展场景 | 方案 |
|---------|------|
| 新增一种移动模式 | 新建 `XxxModifier.gd`，继承 `SkillModifier`，在 `ModifierRegistry` 注册 |
| 新增一种 Effect | 新建 `XxxEffect.gd`，继承 `SkillEffect` |
| 新增一种视觉效果 | 新建 `XxxVFX.gd`，在 `SkillVFXManager` 里加分支或用策略模式 |
| 新增一种伤害类型 | 在 `DamageType` 枚举加值 |
| 新增一个技能 | 新建 `.tres` 文件，关联 Effect 类型 |
| 变体/分支技能 | Modifier 叠加实现，或在 `SkillDef` 里加 `variant_modifiers` 字段 |
| 新增触发时机 | 在 `ExecutionChain` 加对应 `_triggers` 数组 |
| 新增光环效果 | `AuraManager`（独立子系统）产出 Modifier 列表 |

---

## 12. Web → Godot 映射表

| Web 版 (2026-04-15) | Godot 版 (v1) |
|---------------------|--------------|
| `SkillDef.visual.behavior` | `SkillEffect` 子类 |
| `SKILL_TABLE` (硬编码数组) | `.tres` 资源文件 |
| 8 种 `ProjectileBehavior` | `SkillModifier` 子类（Trajectory）+ `SkillEffect` 组合 |
| `ProjectileDef` (TS 对象) | `ProjectileVisualData` (Resource) |
| `resolveAttackOutcome` | `DamageResolver` |
| 无 | **核心新增**：`ExecutionChain` 状态载体 |
| 无 | **核心新增**：`ModifierProcessor` 执行引擎 |
| 无 | **核心新增**：`SkillModifier` 体系 |
| 无 | **核心新增**：`SkillSignalBus` 信号总线 |
| `playSkillVisual()` fire-and-forget | `SkillVFXManager` 监听信号驱动 |

---

## 13. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-22 | 初稿：整合 Web 版设计 + Godot 工程化 + Modifier 系统 |
