# 技能目标选择规则

Status: Draft
Version: v1.0
Owner: Design
Last Updated: 2026-05-24
Scope: 技能释放时的目标选择流程、射程验证、选择策略的完整规则定义。
Related: `skill-delivery-and-hit-resolution.md`; `skill-values.csv`

---

## 1. 总述

本文定义战斗系统中所有技能从"决定释放"到"确定目标"之间的完整目标选择流程。目标选择是技能释放流程的第一步，发生在投射物生成之前。

### 1.1 设计原则

- **技能自主选择目标**：每个技能内置自己的目标选择逻辑，调用方（CombatMediator、SkillDemo 等）不需要额外指定目标选择规则
- **射程前置过滤**：所有技能都有射程参数，超出射程的单位不具备被选为目标的资格
- **策略可扩展**：目标选择规则以策略模式实现，新增技能可随时定义新的选择逻辑
- **默认兜底**：未指定特殊规则的技能，默认使用"范围内最近目标"策略

---

## 2. 目标选择流程

### 2.1 流程总览

```
施法者决定释放技能
    │
    ▼
① 获取候选目标列表（场上所有存活的合法敌方单位）
    │
    ▼
② 射程过滤：剔除施法者 cast_range 之外的单位
    │
    ▼
③ 调用本技能配置的目标选择策略
    │
    ▼
④ 返回最终目标（单个或多个）
    │
    ▼
⑤ 进入技能投送流程（→ skill-delivery-and-hit-resolution.md）
```

### 2.2 射程（cast_range）

每个技能有一个 `cast_range` 参数，单位为像素（px）。射程以施法者位置为圆心。

**射程过滤规则**：
```
合法目标 = 所有存活敌方单位中，与施法者距离 ≤ cast_range 的单位
```

- `cast_range` 是技能参数，在 SkillDef 中配置，也可在 `skill-values.csv` 中调整
- `cast_range` 可被 Modifier 运行时修正（如射程增减效果）
- 如果射程内无合法目标，技能不释放（不消耗冷却和怒气）

### 2.3 目标选择策略（Target Selection Strategy）

每个技能配置一个目标选择策略。策略决定从射程内的合法目标中如何选出最终目标。

#### 2.3.1 内置策略

| 策略 ID | 名称 | 行为 | 适用场景 |
|---------|------|------|---------|
| `NEAREST` | 最近目标 | 选择距离施法者最近的单个目标 | 单体指向性技能（默认策略） |
| `RANDOM` | 随机目标 | 从合法目标中随机选择一个 | 不需要精确瞄准的技能 |
| `LOWEST_HP` | 最低血量 | 选择当前血量比例（HP/maxHP）最低的目标 | 收割/斩杀类技能 |

#### 2.3.2 默认策略

**未指定目标选择策略的技能，默认使用 `NEAREST`（最近目标）。**

#### 2.3.3 扩展机制

随着新技能的增加，可随时定义新的目标选择策略。策略实现为函数/Callable，注册到目标选择系统中。新策略只需满足：

```
输入：施法者位置 + 合法目标列表（已通过射程过滤）
输出：选中的目标（单个 Node2D，或 Node2D 数组）
```

未来可能的扩展示例：
- `FARTHEST`：最远目标
- `HIGHEST_HP`：最高血量
- `CLUSTER`：选择最密集的目标群中心
- `WEIGHTED`：带权重的复合选择（距离 + 血量 + 仇恨值等）

---

## 3. 各技能目标选择配置

### 3.1 配置表

| skill_id | 技能名称 | cast_range | 目标选择策略 | 特殊规则 | 说明 |
|----------|---------|------------|-------------|---------|------|
| fireball_basic | 火球术 | 400px | `NEAREST` | 无 | 范围内最近目标 |
| missile_storm | 子弹风暴 | 350px | `NEAREST` | 无 | 范围内最近目标 |
| falling_meteor | 落石流星 | 600px | `RANDOM` | 无 | 范围内随机目标 |
| ice_arrow | 冰箭术 | 500px | `NEAREST` | 避弹规则 | 见 §3.2 |

### 3.2 冰箭术特殊规则：避弹目标选择

冰箭术发射 3 支冰箭，每支冰箭**独立执行一次目标选择**，规则如下：

**步骤**：
1. 第 1 支冰箭：从射程内合法目标中，选择最近目标
2. 第 2 支冰箭：从射程内合法目标中，选择最近目标，但**排除第 1 支冰箭已选的目标**
3. 第 3 支冰箭：从射程内合法目标中，选择最近目标，但**排除前 2 支冰箭已选的目标**

**降级规则**：
- 如果排除后无剩余目标（如射程内只有 1 个敌人），则允许选择已排除的目标（回到普通最近目标逻辑）
- 如果射程内无任何合法目标，该支冰箭不发射

**设计意图**：多支冰箭倾向于攻击不同目标，形成分散打击效果；但在目标不足时不会浪费弹药。

**伪代码**：
```
已选目标列表 = []
for 每支冰箭:
    候选 = 射程内合法目标 - 已选目标列表
    if 候选为空:
        候选 = 射程内合法目标   # 降级：允许重复
    目标 = 候选中距离最近的
    已选目标列表.append(目标)
    发射冰箭 → 目标
```

---

## 4. 调用方统一规则

### 4.1 CombatMediator（战斗副本）

英雄/敌人 AI 不再自行选择目标。改为：

```
1. AI 决定释放哪个技能（RoleAI.pick_action）
2. 调用 SkillSystem.cast_skill(caster, skill_id, available_targets)
3. SkillSystem 内部根据 SkillDef 的目标选择策略，从 available_targets 中选出目标
4. 进入技能投送流程
```

**变更点**：
- `cast_skill` 签名变更：去掉 `target` 参数，改为接收 `available_targets` 数组
- 目标选择逻辑从 CombatMediator 移入 SkillSystem
- CombatMediator 只负责提供"场上存活的敌方单位列表"

### 4.2 SkillDemo（技能查看器）

SkillDemo 需要将所有靶标传入 `cast_skill`：

```
skill_system.cast_skill(_caster, _selected_skill, _targets)
```

- 不再手动指定 `_targets[0]` 作为主目标
- SkillSystem 内部根据技能配置自动选择目标
- 靶标需要实现 `is_alive()` 等接口，使其能被目标选择系统识别

### 4.3 统一行为

无论在什么场景下调用技能（战斗副本、查看器、测试场景），目标选择逻辑完全由 SkillSystem 根据 SkillDef 配置决定。调用方只需要提供"可用目标列表"。

---

## 5. 技术实现要点

### 5.1 SkillDef 现有字段

SkillDef 已有以下目标选择相关字段（当前为死数据，未被运行时读取）：

```gdscript
@export var cast_range: float = 300.0
@export_enum("NEAREST:0", "FARTHEST:1", "LOWEST_HP:2", "HIGHEST_HP:3", "RANDOM:4", "ALL:5")
var target_mode: int = 0
@export var max_targets: int = 1
```

### 5.2 TargetSelector 扩展

当前 `TargetSelector` 只有 `find_nearest` 系列方法。需要扩展：

- `find_random(pos, units, max_range)` — 射程内随机选一个
- `find_lowest_hp(pos, units, max_range)` — 射程内血量比例最低的
- `filter_in_range(pos, units, max_range)` — 通用射程过滤

### 5.3 cast_skill 签名变更

当前：
```gdscript
func cast_skill(caster, skill_id, target, extra_modifiers, available_targets)
```

改为：
```gdscript
func cast_skill(caster, skill_id, available_targets, extra_modifiers)
```

内部根据 `skill_def.target_mode` 自动选出目标。

### 5.4 多弹技能的独立目标选择

对于冰箭术等多弹独立选目标的技能，在 `EmitProjectileEffect` 中，每创建一个 ExecutionChain 时独立调用一次目标选择策略，并维护已选目标排除列表。

---

## 6. 术语表

| 术语 | 英文 | 含义 |
|------|------|------|
| 射程 | Cast Range | 技能的有效作用距离，以施法者为圆心 |
| 目标选择策略 | Target Selection Strategy | 技能从合法目标中选出最终目标的逻辑规则 |
| 合法目标 | Valid Target | 通过射程过滤、存活状态检查等条件的目标 |
| 候选目标 | Candidate | 进入选择策略前的合法目标集合 |
| 避弹规则 | Avoidance Rule | 多弹技能中，后续弹药避开前序弹药目标的规则 |

---

## 7. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2026-05-24 | 初稿：射程验证、三种内置策略、冰箭术避弹规则、调用方统一规则 |
