# 伤害跳字系统 — 设计文档

## 1. 概述

伤害跳字系统负责在战斗和技能演示过程中，当单位受到伤害时，在目标位置上方显示数值化的伤害反馈，增强技能打击感和战斗信息透明度。

### 核心原则

- **怪物跳字**：强调跳跃动感，作为打击感的重要组成部分
- **玩家跳字**：轻量化，清晰传达伤害信息即可
- **两个字体池分离**：美术资源、动画参数、后续逻辑各自独立演化

---

## 2. 架构

### 2.1 整体结构

```
CombatMediator          SkillSignalBus
    │                       │
    │   damage_dealt        │   skill_hit
    │   (完整 ResolveResult) │   (基础 DamageInfo)
    └────────┬──────────────┘
             │
    DamageFloater (场景子节点)
         │
    ┌────┴────┐
    │         │
 Monster   Player
   Pool      Pool
    │         │
    ├─ DTN    ├─ DTN       ← DamageTextNode (Label + Tween)
    ├─ DTN    ├─ DTN
    └─ ...    └─ ...

DamageTextLayer (CanvasLayer, layer=10)
```

### 2.2 组件职责

| 组件 | 路径 | 职责 |
|------|------|------|
| `DamageFloater` | `skill_system/damage_text/damage_floater.gd` | 接收伤害事件，路由到对应池，管理两个池的生命周期 |
| `DamageTextPool` | `skill_system/damage_text/damage_text_pool.gd` | 对象池，预分配 DamageTextNode，acquire/release |
| `DamageTextNode` | `skill_system/damage_text/damage_text_node.gd` | 单个跳字节点，包含 Label + Tween 驱动动画 |
| `DamageTextLayer` | 场景中的 CanvasLayer | 已在 Arena 场景存在，在 SkillDemo 中新增 |

### 2.3 集成点

| 集成位置 | 场景 | 数据源 | 数据完整性 |
|---------|------|--------|-----------|
| `CombatMediator._resolve_and_apply_damage()` | Arena | `ResolveResult` | 完整（暴击、命中结果、伤害类型） |
| `CombatMediator._on_projectile_hit()` | Arena | `ResolveResult` | 完整 |
| `CombatMediator._update_enemy_combat()` | Arena | `ResolveResult` | 完整 |
| `CombatMediator._update_dots()` | Arena | `float` | 仅有裸伤害值 |
| `SkillSignalBus.skill_hit` | SkillDemo | `damage_info` | 基础伤害（无 ResolveResult） |

---

## 3. DamageTextNode 详细设计

### 3.1 节点结构

```
DamageTextNode (Node2D)
  └── Label (子节点)
      ├── text           ← 格式化后的数值字符串
      ├── theme overrides ← 颜色、字号、描边
      └── (未来) LabelSettings ← 字体资源替换时使用
```

### 3.2 文本格式

| 情景 | 文本格式 | 示例 |
|------|---------|------|
| 普通伤害 | `{value}` | `42` |
| 暴击 | `{value}!` | `128!` |
| MISS | `MISS` | `MISS` |
| 治疗 | `+{value}` | `+30` |
| DOT | `{value}` (小字号) | `8` |

### 3.3 颜色映射

| 伤害类型 | 颜色 | HEX |
|---------|------|-----|
| 物理 | 白色 | `#FFFFFF` |
| 火焰 | 红色 | `#FF4444` |
| 冰霜 | 蓝色 | `#4488FF` |
| 闪电 | 金色 | `#FFD700` |
| 毒 | 绿色 | `#44FF44` |
| 暴击 | 橙红 | `#FF6600` |
| MISS | 灰色 | `#888888` |
| 治疗 | 翠绿 | `#44DD44` |

### 3.4 动画参数

#### 怪物跳字（跳跃动感）

```
阶段          持续时间    动画
──────────────────────────────────────
Pop in        0~0.10s    scale 0 → 1.3（overshoot），ease_out
                          水平偏移: random(±15px)
Float up      0.10~0.6s  上升 80px，ease_out
                          旋转摆动: ±5° 振荡
Fade out      0.5~0.8s   modulate.a 1.0 → 0.0
                          保持在当前位置

总时长: ~0.8s
```

#### 玩家跳字（轻量）

```
阶段          持续时间    动画
──────────────────────────────────────
Pop in        0~0.08s    scale 0 → 1.0，ease_out
                          无水平偏移
Float up      0.08~0.4s  上升 40px，ease_out
Fade out      0.3~0.5s   modulate.a 1.0 → 0.0

总时长: ~0.5s
```

#### 暴击额外特效

- 文本放大 1.5x（相对于普通跳字）
- 加粗（theme 设置 bold 或使用更大字号）
- 在文字位置生成一个粒子爆炸特效（重用已有点爆 VFX 或独立实现）

#### 治疗跳字

- 使用玩家池的动画参数（轻量级）
- 绿色文本，带 `+` 前缀
- 上升路径略微向上偏右

---

## 4. 对象池设计

遵循现有 `HitVFXPool` 的模式：

```
DamageTextPool (Node2D)
  ├── _available: Array[DamageTextNode]   ← 可用节点栈
  ├── _active: Array[DamageTextNode]      ← 活跃节点列表
  └── pool_size: int                      ← 预分配数量（默认 20）

  acquire(world_pos, text, config) → DamageTextNode
  release(node) → void
  clear_all() → void
  get_stats() → Dictionary
```

---

## 5. 场景适配

### Arena (`battle.tscn`)

- `DamageTextLayer` 已存在（CanvasLayer, layer=10）
- `arena_scene.gd` 已声明 `@onready var damage_text_layer`
- 在 `_initialize()` 或 `_start_combat()` 中创建 `DamageFloater` 作为其子节点
- 连接 `CombatMediator.damage_dealt` 信号

### Skill Demo (`skill_demo.tscn`)

- 在场景根节点下添加 `DamageTextLayer`（CanvasLayer, layer=10）
- 连接 `skill_signal_bus.skill_hit` 信号
- 使用怪物池显示伤害文字（靶标视为敌人）

---

## 6. CombatMediator 信号

新增信号：

```gdscript
signal damage_dealt(
    target: Node2D,
    amount: float,
    is_crit: bool,
    hit_outcome: int,     # MISS, GLANCE, DEFLECT, HIT
    damage_type: int,     # PHYSICAL, ELEMENTAL_FIRE, etc.
    is_player: bool       # true=玩家受击, false=怪物受击
)
```

在每个伤害结算点发射：

| 方法 | 信号数据 |
|------|---------|
| `_resolve_and_apply_damage()` | target=instant_target, is_player=false |
| `_on_projectile_hit()` | target=target, is_player=false（敌人）或 is_player=true（玩家） |
| `_update_enemy_combat()` | target=target, is_player=true |
| `_update_dots()` | target=hero/enemy, is_crit=false, hit_outcome=HIT |

---

## 7. 坐标转换

`DamageTextLayer` 中的子节点使用 Canvas（屏幕）坐标。

```
screen_pos = camera.get_canvas_transform() * target.global_position
text_position = screen_pos - Vector2(0, offset_above_unit)
```

其中 `offset_above_unit` 考虑单位头顶上方位置（大约 -20px 从 global_position 计算）。

---

## 8. 扩展性考虑

- 两个池使用同一个 `DamageTextPool` 类但不同实例，通过构造参数区分配置
- 当逻辑分支需求出现时，可以从 `DamageTextPool` 派生子类（`MonsterDamageTextPool`, `PlayerDamageTextPool`）
- 字体资源替换：`LabelSettings` 或 theme override 集中管理，未来可替换为自定义 `.ttf` 字体文件
- 暴击粒子特效可以作为独立的 VFX 执行器实现，与现有 VFX 系统整合

---

## 9. 文件清单

### 新增文件

| 文件 | 行数估计 | 说明 |
|------|---------|------|
| `game/scripts/skill_system/damage_text/damage_text_node.gd` | ~100 | 跳字节点 |
| `game/scripts/skill_system/damage_text/damage_text_pool.gd` | ~70 | 对象池 |
| `game/scripts/skill_system/damage_text/damage_floater.gd` | ~120 | 协调器 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `game/scripts/combat/combat_mediator.gd` | 新增 `damage_dealt` 信号 + 4 处发射点 |
| `game/scripts/arena/arena_scene.gd` | 创建 DamageFloater，连接信号 |
| `game/scenes/dev/skill_demo.tscn` | 添加 DamageTextLayer CanvasLayer |
| `game/scripts/dev/skill_demo.gd` | 创建 DamageFloater，连接 skill_hit |

---

## 10. 未纳入 v1 范围

- 自定义字体文件（.ttf）导入 — 使用 Godot 默认系统字体
- 暴击粒子爆炸特效 — v1 仅做文本放大加粗
- 伤害数字"连击"合并（多个相同伤害合并显示）
- 伤害数字"吸收"/"免疫"/"格挡"等额外命中结果
