# Six-Fighter-GD 技能系统蓝皮书

**文档类型**：技术蓝皮书 / 团队知识库
**版本**：v1.0
**日期**：2026-04-23
**状态**：已验证通过
**目标读者**：人类开发者 · AI 助理

---

## 📌 执行摘要

2026-04-23，团队对 six-fighter-gd 项目的技能系统进行了深度维护与故障排除，解决了导致技能系统完全无法运行的致命 Bug，并完成了一次完整的知识整理归档。

**核心成果**：

- 修复了 16 个 `.tres` 资源文件的 Tab 缩进问题
- 验证了技能系统的完整执行链路（Registry → ModifierProcessor → Executor → Pool）
- 建立了`.tres` 文件编写的规范与防错检查机制
- 输出了本蓝皮书，确保知识传承

**关键教训**：Godot `.tres` 资源文件的 `[resource]` 块下，**所有属性行必须有 Tab 缩进**，否则 Godot 的 ConfigFile 解析器会忽略这些属性，导致所有字段回退为脚本类的默认值。这是一个极易踩坑、极难诊断的隐蔽陷阱。

---

## 📐 一、技能系统架构总览

### 1.1 设计哲学：引用 vs 所有权

技能系统的核心架构原则是 **引用关系，而非所有权关系**：

```
Unit (Hero / Monster)
  └─ skill_id: String   ← 只引用 skill_id，不持有 SkillDef 实例

SkillRegistry (全局唯一)
  └─ skill_id → SkillDef   ← 全局管理，任意单位可引用
```

**优势**：
- 任意单位（英雄或怪物/Boss）可通过引用 skill_id 使用任意技能
- Boss 可以组合使用英雄技能（如 Boss 使用 `ember_ultimate`）
- 技能平衡性改动全局生效，无需逐单位修改
- 新技能只需添加到 Registry，现有单位立即获得使用权限

### 1.2 四大分离原则

| 分离维度 | 内容 | Godot 实现 |
|---------|------|-----------|
| 技能定义 vs 技能视觉 | 战斗参数与美术参数分离 | `SkillDef` vs `SkillVisualDef` |
| 逻辑执行 vs 美术表现 | 行为与视觉数据分离 | `SkillEffect` + `ModifierProcessor` vs `SkillVFXManager` |
| 战斗结算 vs 视觉播放 | 伤害计算与粒子动画分离 | `DamageResolver` vs `SkillVFXManager` |
| 施法者 vs 技能引用 | Unit 只引用 skillId | 全局 `SkillRegistry` |

**核心原则**：所有变化通过**数据配置**解决，不通过**代码分支**解决。

### 1.3 节点树结构

```
res://scenes/skill_system/skill_system.tscn
├── SkillSystem (Node)                    ← 根节点
│   ├── SkillRegistry (Node)              ← 技能数据注册中心
│   ├── ModifierRegistry (Node)           ← Modifier 注册中心
│   ├── ModifierProcessor (Node)          ← 执行引擎
│   ├── SkillSignalBus (Node)             ← 信号总线
│   ├── ProjectilePool (Node2D)           ← 投射物对象池（预创建100个）
│   ├── ExecutorPool (Node)               ← 执行器对象池
│   └── SkillVFXManager (Node)            ← VFX 总控
│
└── scenes/skill_system/nodes/
    ├── projectile.tscn                    ← 投射物节点模板
    └── executor.tscn                      ← 执行器节点模板
```

### 1.4 资源文件结构

```
res://resources/skills/
├── skill_defs/                       ← 技能战斗数据 (.tres)
│   ├── ember_basic.tres
│   ├── ember_small_a.tres
│   ├── ironwall_basic.tres
│   ├── ironwall_small_a.tres
│   ├── moss_basic.tres
│   └── moss_small_a.tres
│
├── skill_visual_defs/                ← 技能视觉参数 (.tres)
│   ├── ember_basic.tres
│   ├── ember_small_a.tres
│   ├── ironwall_basic.tres
│   ├── ironwall_small_a.tres
│   ├── moss_basic.tres
│   └── moss_small_a.tres
│
└── modifiers/                        ← Modifier 数据配置 (.tres)
    ├── bounce.tres
    ├── expansion.tres
    ├── fission.tres
    └── scatter.tres
```

---

## 🔄 二、技能执行流程

### 2.1 完整执行链路

```
cast_skill(caster, skill_id, target)
    │
    ├─ SkillRegistry.get_skill(skill_id)       ← 获取 SkillDef
    ├─ SkillRegistry.get_skill_visual()         ← 获取 SkillVisualDef
    ├─ ModifierRegistry.get_entity_modifiers()   ← 获取 Modifier 列表
    │
    ├─ 创建 SkillExecutionContext                ← 执行上下文
    ├─ SkillRegistry.create_effect_instance()    ← 创建 Effect 实例
    │
    └─ ModifierProcessor.resolve()               ← 解析执行链
          │
          ├─ 构建根链 ExecutionChain
          ├─ 按 priority 排序 Modifier
          ├─ 依次调用 Modifier.apply()
          │    ├─ Scatter: 产生 N 条扇形分支
          │    ├─ Fission: 注册距离触发器
          │    ├─ Bounce: 注册命中触发器
          │    └─ ...
          │
          └─ 返回 Array[ExecutionChain] (叶子链列表)
               │
               └─ ExecutorPool.acquire()
                    │
                    └─ ProjectilePool.spawn()
                         │
                         └─ ProjectileNode._process()
                              ├─ check_triggers()
                              ├─ update_position()
                              └─ 伤害结算/视觉效果
```

### 2.2 核心数据结构

#### SkillExecutionContext — 执行上下文

```gdscript
class SkillExecutionContext:
    extends RefCounted
    var caster: Node2D           # 施法者
    var target: Node2D           # 目标
    var target_pos: Vector2      # 目标位置
    var direction: Vector2        # 方向向量
    var damage: float            # 伤害值
    var damage_type: String      # 伤害类型
    var skill_id: String          # 技能ID
    var visual_def: Resource      # 视觉定义
```

#### ExecutionChain — 执行链（状态载体）

每条叶子链代表一个抛射物路径，承载该路径的所有运行时状态：

```gdscript
class_name ExecutionChain
extends RefCounted

# 基础信息
var chain_id: int
var effect: SkillEffect
var caster: Node2D
var target: Node2D

# 运动参数
var position: Vector2
var direction: Vector2
var speed: float = 300.0
var distance_traveled: float = 0.0

# 伤害参数
var damage: float
var damage_type: String
var base_damage: float   # 用于计算分裂后的伤害比例

# 外观参数
var scale: float = 1.0
var current_radius: float = 4.0

# 抛射物生命值（0 = 不可破坏）
var projectile_hp: float = 0.0
var can_be_targeted: bool = false

# 触发器
var _time_triggers: Array[Dictionary]
var _distance_triggers: Array[Dictionary]
var _hit_triggers: Array[Dictionary]

# 行为状态
var behavior_state: String = "Flying"  # Flying / Hit / Exploded / Fading / Destroyed
```

### 2.3 SkillDef — 技能战斗数据定义

```gdscript
class_name SkillDef
extends Resource

# 基础信息
@export var skill_id: String = ""
@export var display_name: String = ""

# 技能类别
@export_enum("BASIC:0", "SMALL_A:1", "SMALL_B:2", "ULTIMATE:3")
var category: int = 0

# 战斗属性
@export var base_damage: float = 25.0
@export_enum("PHYSICAL:0", "ELEMENTAL_FIRE:1", "ELEMENTAL_ICE:2", "ELEMENTAL_LIGHTNING:3", "ELEMENTAL_POISON:4")
var damage_type: int = 0
@export var cooldown: float = 2.0
@export var stun_chance: float = 0.0

# Effect 类型
@export var effect_type: String = "emit_projectile"

# 内置 Modifier
@export var base_modifier_ids: Array[String] = []

func is_valid() -> bool:
    return skill_id != "" and base_damage >= 0
```

---

## 🎯 三、Modifier 系统详解

### 3.1 Modifier 类型分类

| 类型 | ID | 触发时机 | 作用 |
|------|-----|---------|------|
| **TRAJECTORY** | 0 | ON_CAST | 修改运动轨迹 |
| **LIFETIME** | 1 | 多种 | 修改存活/消失逻辑 |
| **APPEARANCE** | 2 | 多种 | 修改外观 |
| **BEHAVIOR** | 3 | ON_HIT | 添加命中行为 |
| **CONDITIONAL** | 4 | ON_CAST | 条件生效/压制 |

### 3.2 Modifier 完整列表

| Modifier | ID | 类型 | 触发 | 核心参数 |
|---------|-----|------|------|---------|
| Scatter（散射） | `scatter` | TRAJECTORY | ON_CAST | `num_projectiles`, `fan_angle_deg` |
| CurvedPath（曲线路径） | `curved_path` | TRAJECTORY | ON_CAST | `curve_type`, `control_point_offset` |
| Bounce（弹射） | `bounce` | LIFETIME | ON_HIT | `max_bounces` |
| Fission（分裂） | `fission` | LIFETIME | DISTANCE_TRAVELED | `half_life_distance`, `split_count` |
| Expansion（膨胀） | `expansion` | APPEARANCE | DISTANCE_TRAVELED | `size_growth_per_distance`, `max_scale` |
| ProjectileHP（抛射物HP） | `projectile_hp` | LIFETIME | ON_CAST | `hp`, `destroy_on_hp_zero` |
| ConditionalSuppress（条件压制） | `conditional_suppress` | CONDITIONAL | ON_CAST | `suppressed_modifier_ids` |
| ColorShift（色彩偏移） | `color_shift` | APPEARANCE | ON_CAST | `color_override` |

### 3.3 Modifier 执行优先级

```
priority = 0    → ConditionalSuppress（最先执行，决定压制关系）
priority = 10    → Scatter（产生分支，后续 Modifier 作用于每条分支）
priority = 20    → CurvedPath（修改轨迹算法）
priority = 50    → Fission（注册距离触发）
priority = 60    → Bounce（注册命中触发）
priority = 80    → Expansion（注册距离触发）
priority = 100   → ProjectileHP（最后注册基础属性）
```

### 3.4 Modifier 冲突处理规则

| 场景 | 处理规则 |
|------|---------|
| 同一 `modifier_id` 出现多次 | 后者覆盖前者 |
| 不同来源的同类型 Modifier | 各自独立，都生效 |
| ConditionalSuppress 压制了某 Modifier | 被压制者 `is_active()` 返回 false |
| Modifier 顺序不同导致效果不同 | `Scatter → Bounce` ≠ `Bounce → Scatter` |
| 分裂后的子链继承 Modifier | 继承 `modifier_stack` 副本，通常移除当前 Modifier |

### 3.5 Modifier 叠加示例：从基础火球到超级火球

```
阶段 0：基础火球
SkillDef: ironwall_basic
Effect: EmitProjectile
Modifier: []

阶段 1：+ 散射（来自装备）
Modifier: [Scatter(num=5, fan=60°)]
结果：发射 5 枚火球

阶段 2：+ 弹射（来自天赋）
Modifier: [Scatter, Bounce(max=2)]
结果：5 枚火球各弹射 2 次

阶段 3：+ 分裂（来自强化宝石）
Modifier: [Scatter, Fission(half_life=150, count=2), Bounce]
结果：5 枚火球各在飞行150距离后分裂成2枚（共10枚），每枚再弹射2次

阶段 4：+ 贝塞尔曲线（来自被动技能）
Modifier: [Scatter, Fission, Bounce, CurvedPath(bezier_quad)]
结果：所有火球走贝塞尔曲线飞行

阶段 5：+ 膨胀替换分裂（Boss 光环抑制）
Modifier: [ConditionalSuppress(suppressed=fission), Expansion(rate=0.05)]
结果：分裂被压制，替换为膨胀效果
```

---

## 🐛 四、今天的问题诊断与解决

### 4.1 问题现象

Godot 编辑器启动时，大量 `.tres` 资源文件报出以下警告：

```
[SkillRegistry] Skill at ... has empty skill_id, skipping
[SkillRegistry] Skill at ... has empty modifier_id, skipping
```

**影响**：所有技能使用脚本类的默认值（`skill_id=""`, `base_damage=25.0`），技能系统完全无法工作。

### 4.2 排查历程

**第一阶段：误判缓存问题**

用户报告错误后，首先尝试删除 `.godot` 文件夹（导入缓存）。重启后错误依旧，排除缓存问题。

**第二阶段：分析 `.tres` 文件结构**

检查 `ember_basic.tres` 和 `fission.tres` 的原始内容，发现属性行在 `[resource]` 块下没有缩进。怀疑是缩进问题导致 Godot 解析器忽略这些属性行。

**第三阶段：添加调试输出**

在 `skill_registry.gd` 中添加调试代码：

```gdscript
print("[DEBUG] skill_id value: '", skill_def.skill_id, "'")
print("[DEBUG] base_damage=", skill_def.base_damage)
```

**关键发现**：`base_damage=25.0` 是脚本默认值，而非 `.tres` 中的 `18.0`。这证明属性**完全未被解析**，资源加载时使用了基类默认值。

**第四阶段：Python 脚本修复 Tab 缩进**

尝试用 Python 脚本为每个属性行添加 Tab（`\t`）缩进。经历多次失败：

| 尝试 | 问题 | 原因 |
|------|------|------|
| `"\t"` 字符串拼接 | Tab 字节丢失 | Python 字符串字面量丢失 `\t` 字节 |
| `newline='\r\n'` | `\r\r\n` 双回车 | `newline` 参数对已有的 `\r\n` 又转换一遍 |

**最终解决方案**（`regen_tres_crlf.py`）：

```python
# 关键：使用 newline='\n' 手动拼接 '\r\n'，避免双重转换
for fname, content in files.items():
    fpath = os.path.join(base, fname)
    with open(fpath, 'w', encoding='utf-8', newline='\n') as f:
        lines = content.strip().split('\n')
        f.write(lines[0] + '\r\n')  # 写入表头
        for line in lines[1:]:
            if line.strip():
                f.write('\r\n\t' + line)  # CRLF + Tab + 内容
```

### 4.3 根本原因

**Godot `.tres` 文件格式规范**：`[resource]` 块下的每个属性行**必须以 Tab 字符缩进**。未缩进的行被 Godot 的 ConfigFile 解析器视为脱离该节的普通文本，从而被忽略。

### 4.4 修复清单

| 目录 | 文件数 | 修复内容 |
|------|--------|---------|
| `resources/skills/skill_defs/` | 6 | Tab 缩进 + CRLF |
| `resources/skills/skill_visual_defs/` | 6 | Tab 缩进 + CRLF |
| `resources/skills/modifiers/` | 4 | Tab 缩进 + CRLF |
| **合计** | **16** | |

---

## ⚠️ 五、关键教训与规范

### 5.1 `.tres` 文件编写规范（必读）

> **⚠️ 最重要的一条规范，违反即导致技能系统完全失效。**

Godot `.tres` 资源文件采用 **INI 风格的 ConfigFile 格式**，具有以下关键特性：

```
[gd_resource type="Resource" ...]
[ext_resource type="Script" ...]
[resource]
	script = ExtResource("1")          ← ✅ 有 Tab 缩进，被解析
	skill_id = "ironwall_basic"        ← ✅ 有 Tab 缩进，被解析

script = ExtResource("1")              ← ❌ 无缩进，被忽略
skill_id = "ironwall_basic"           ← ❌ 无缩进，被忽略
```

**规则**：

1. **`[resource]` 块下的每个属性行必须有 Tab 缩进**（1个 Tab 字符）
2. 行尾换行符建议使用 **CRLF（`\r\n`）**，Godot 编辑器默认生成此格式
3. 不要手动用文本编辑器编辑 `.tres` 文件，除非确保 Tab 缩进正确
4. 通过 **Godot Inspector** 编辑是最安全的方式

### 5.2 诊断技能注册失败

当 `SkillRegistry` 报告注册失败时，按以下顺序排查：

```
Step 1: 检查 .tres 文件的 Tab 缩进
    └─ 十六进制查看：每个属性行前应有 0x09 (Tab) 字节

Step 2: 验证 SkillDef.is_valid() 返回 true
    └─ skill_id 不能为空
    └─ base_damage >= 0

Step 3: 检查脚本路径是否正确
    └─ [ext_resource type="Script" path="..."]
    └─ 路径是否存在

Step 4: 添加调试输出
    └─ 在 skill_registry.gd 的 _load_all_skills() 中添加
    └─ print("[DEBUG] Loaded: ", full_path, " | skill_def=", skill_def)
```

### 5.3 CRLF vs LF：Windows 开发陷阱

Windows PowerShell/cmd 默认使用 CRLF（`\r\n`），Git 可能自动转换。涉及 `.tres` 文件的操作时：

- **始终使用** `newline='\n'` 打开文件（Python）
- **手动拼接** `'\r\n'` 而非依赖 `newline` 参数
- **验证字节**：十六进制检查 `0x0d 0x0a`（CRLF）vs `0x0a`（LF）

### 5.4 Python 处理特殊字符的最佳实践

```python
# ✅ 正确：显式字节串
TAB = b'\t'
CRLF = b'\r\n'

# ✅ 正确：newline='\n' 手动拼接
with open(fpath, 'w', encoding='utf-8', newline='\n') as f:
    f.write(header + '\r\n')
    for line in lines[1:]:
        f.write('\r\n\t' + line)

# ❌ 错误：Python 字符串 "\t" 在某些场景下丢失 Tab 字节
# ❌ 错误：newline='\r\n' 对已有的 \r\n 双重转换
```

---

## 📂 六、文件清单

### 6.1 技能系统脚本

| 文件路径 | 职责 |
|---------|------|
| `scripts/skill_system/skill_root.gd` | 技能系统根节点，初始化子系统，提供 `cast_skill()` API |
| `scripts/skill_system/core/skill_effect.gd` | Effect 基类，定义 `SkillExecutionContext` |
| `scripts/skill_system/core/execution_chain.gd` | 执行链（状态载体），管理触发器和链操作 |
| `scripts/skill_system/core/skill_executor.gd` | 单次施法的执行器，持有运行时状态 |
| `scripts/skill_system/core/damage_resolver.gd` | 伤害结算（纯数值计算，无节点代码） |
| `scripts/skill_system/core/modifier_processor.gd` | Modifier 执行引擎，按优先级排序并调用 `apply()` |
| `scripts/skill_system/core/skill_modifier.gd` | Modifier 基类，所有 Modifier 继承此类 |
| `scripts/skill_system/registry/skill_registry.gd` | 技能数据注册中心 |
| `scripts/skill_system/registry/skill_def.gd` | 技能战斗数据定义（Resource 类） |
| `scripts/skill_system/registry/skill_visual_def.gd` | 技能视觉数据定义（Resource 类） |
| `scripts/skill_system/registry/modifier_registry.gd` | Modifier 数据注册中心 |
| `scripts/skill_system/registry/modifier_def.gd` | Modifier 数据定义（Resource 类） |
| `scripts/skill_system/pools/projectile_pool.gd` | 投射物对象池（预创建100个） |
| `scripts/skill_system/pools/projectile_node.gd` | 投射物节点，含 `_process` 运动逻辑 |
| `scripts/skill_system/pools/executor_pool.gd` | 执行器对象池 |
| `scripts/skill_system/vfx/skill_vfx_manager.gd` | VFX 总控，监听信号驱动粒子/动画 |
| `scripts/skill_system/signal_bus/skill_signal_bus.gd` | 所有技能事件信号的集中定义 |
| `scripts/skill_system/types/skill_system_types.gd` | 技能类别枚举常量 |

### 6.2 Effect 叶子节点

| 文件路径 | 语义 |
|---------|------|
| `core/effects/emit_projectile.gd` | 发射抛射物（最常用） |
| `core/effects/area_damage.gd` | 区域伤害（瞬发） |
| `core/effects/apply_status.gd` | 施加状态 |
| `core/effects/emit_burst.gd` | 爆发效果（视觉） |

### 6.3 Modifier 实现

| 文件路径 | 语义 |
|---------|------|
| `core/modifiers/scatter.gd` | 散射（扇形分支） |
| `core/modifiers/bounce.gd` | 弹射（命中后转向） |
| `core/modifiers/fission.gd` | 分裂（距离触发） |
| `core/modifiers/curved_path.gd` | 曲线路径（贝塞尔曲线等） |
| `core/modifiers/expansion.gd` | 膨胀（尺寸随距离增长） |
| `core/modifiers/projectile_hp.gd` | 抛射物生命值（可被破坏） |
| `core/modifiers/conditional_suppress.gd` | 条件压制 |
| `core/modifiers/color_shift.gd` | 色彩偏移 |

### 6.4 资源文件（已修复）

| 目录 | 文件 |
|------|------|
| `resources/skills/skill_defs/` | ember_basic.tres, ember_small_a.tres, ironwall_basic.tres, ironwall_small_a.tres, moss_basic.tres, moss_small_a.tres |
| `resources/skills/skill_visual_defs/` | ember_basic.tres, ember_small_a.tres, ironwall_basic.tres, ironwall_small_a.tres, moss_basic.tres, moss_small_a.tres |
| `resources/skills/modifiers/` | bounce.tres, expansion.tres, fission.tres, scatter.tres |

### 6.5 场景文件

| 文件路径 | 用途 |
|---------|------|
| `scenes/skill_system/skill_system.tscn` | 技能系统根场景 |
| `scenes/skill_system/skill_test.tscn` | 技能系统独立测试场景（含调试 UI） |
| `scenes/skill_system/nodes/projectile.tscn` | 投射物节点模板 |
| `scenes/skill_system/nodes/executor.tscn` | 执行器节点模板 |

---

## 📖 七、快速参考（面向 AI 助理）

### 7.1 如何施放一个技能

```gdscript
# 获取 SkillSystem 实例
var skill_system: Node = get_node("/root/SkillSystem")

# 施放技能
skill_system.cast_skill(caster_unit, "ember_basic", target_unit)
```

### 7.2 如何注册新技能

1. 创建 `resources/skills/skill_defs/xxx.tres` 文件
2. 在 Godot Inspector 中配置属性（**使用 Inspector，不要手动编辑**）
3. 确保 `[resource]` 块下每个属性都有 Tab 缩进
4. 创建对应的 `resources/skills/skill_visual_defs/xxx.tres` 视觉定义

### 7.3 如何添加新 Modifier

1. 创建 `scripts/skill_system/core/modifiers/xxx.gd`，继承 `SkillModifier`
2. 实现 `apply(chain: ExecutionChain) -> Array[ExecutionChain]` 方法
3. 在 `ModifierRegistry` 的 `create_modifier_instance()` 中添加类型分支
4. 可选：创建 `resources/skills/modifiers/xxx.tres` 数据配置

### 7.4 如何调试技能注册问题

```gdscript
# 在 skill_registry.gd 的 _load_all_skills() 中添加：
print("[DEBUG] Loading: ", full_path)
print("[DEBUG] skill_def type: ", typeof(skill_def))
print("[DEBUG] skill_def.skill_id: '", skill_def.skill_id, "'")
print("[DEBUG] is_valid(): ", skill_def.is_valid())
```

### 7.5 如何使用调试测试场景

1. 在 Godot 中打开 `scenes/skill_system/skill_test.tscn`
2. 运行场景
3. 从下拉框选择技能
4. 点击场景任意位置施放技能
5. 右下角调试面板显示活跃投射物数量

### 7.6 常见错误排查表

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `has empty skill_id, skipping` | `.tres` 属性无 Tab 缩进 | 使用 `regen_tres_crlf.py` 重新生成文件 |
| `Failed to load modifier: xxx` | `.tres` 文件损坏或脚本路径错误 | 验证文件存在且脚本路径正确 |
| `Unknown effect type: xxx` | `effect_type` 字符串不在 `_effect_factory` 中 | 在 `skill_registry.gd` 的 `_setup_effect_factory()` 中添加 |
| `No available executor` | ExecutorPool 耗尽 | 检查是否有链未正确归还到池 |

---

## 🔗 八、相关文档索引

| 文档 | 说明 |
|------|------|
| `docs/tech/architecture/godot-skill-system-node-architecture.md` | 节点架构详解 |
| `docs/tech/architecture/skill-system-architecture-2026-04-15.md` | 架构设计 v1（Web → Godot 映射） |
| `docs/design/feature-systems/skill-modifier-system-v1.md` | Modifier 系统设计详解 |
| `docs/tech/incident-bluebook-return-button-2026-04-14.md` | 事故复盘文档模板（参考格式） |

---

## 📝 九、修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-23 | 初版：整合今日工作成果，包含架构总览、Bug诊断、修复过程、规范文档和快速参考 |

---

*本文档由 AI 助理在人类开发者指导下生成，确保知识传承与团队协作效率。*
