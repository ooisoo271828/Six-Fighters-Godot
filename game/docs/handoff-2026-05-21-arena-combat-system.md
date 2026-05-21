# Arena 战斗系统交接手册 — 2026-05-21

## 概述

本次工作完成了竞技场战斗场景的全面升级：镜头系统、技能系统接入、敌人攻击视觉、投射物生命周期修复。以下按模块交接。

---

## 1. 镜头视窗系统

### 新增文件
- `docs/camera-viewport-rules-v1.md` — 权威镜头/视窗规则文档（10 章 + 附录）
- `scripts/core/camera_with_trauma.gd` — 带屏幕震动的 Camera2D
- `scripts/arena/battle_ground.gd` — 网格地面背景（4000×4000 世界区域）

### 架构：锚点-跟随系统
```
玩家输入 → CameraAnchor (Node2D, 250px/s)
               ↓
           Camera2D (子节点, smoothing=5.0, current=true)
               ↓ 软跟随 (350px 半径, lerp 3.0/s)
           英雄阵型 (斜向三角: 前1后2)
```

### 关键常量 (`arena_scene.gd`)
| 常量 | 值 | 说明 |
|------|-----|------|
| FORMATION_Y_BIAS | 120.0 | 阵型中心向下偏移 |
| SOFT_FOLLOW_RADIUS | 350.0 | 英雄自由活动半径 |
| HARD_FOLLOW_RADIUS | 480.0 | 超出则强制传送 |
| FOLLOW_LERP_NORMAL | 3.0 | 正常跟随速度 |
| FOLLOW_LERP_URGENT | 8.0 | 紧急追赶速度 |

### 阵型偏移 (斜45°三角)
```
FORMATION_OFFSETS = [
    Vector2(-40, -40),   # 英雄B — 前排
    Vector2(-40, +40),   # 英雄A — 后排左
    Vector2(+40, +40),   # 英雄C — 后排右
]
```

### 场景结构 (`battle.tscn`)
```
Arena (Node2D) [arena_scene.gd]
├── Ground (Node2D) [battle_ground.gd] z_index=0
├── CameraAnchor (Node2D) [camera_anchor.gd]
│   └── Camera2D [camera_with_trauma.gd] current=true
├── YSortContainer (Node2D) y_sort_enabled=true
├── Projectiles (Node2D)
├── VFX (Node2D)
├── DamageTextLayer (CanvasLayer) layer=10
├── HUDLayer (CanvasLayer) layer=20
└── FullscreenVFXLayer (CanvasLayer) layer=30
```

---

## 2. 技能系统接入

### 问题
之前 `arena_scene.gd` 有两套断开的系统：
- **CombatResolver** — 纯数学算伤害，不生成投射物
- **SkillSystem** — 生成投射物，但从未被竞技场调用

### 解决方案
在 `_initialize()` 中实例化 `skill_system.tscn`，在 `_update_combat()` 中调用 `skill_system.cast_skill()`。

### 初始化顺序 (`arena_scene.gd._initialize()`)
```
1. SkillSystem 实例化并加入场景树
   → SkillRoot._ready() → SkillRegistry.initialize() → 加载所有技能
2. HeroRegistry 加入场景树
   → HeroRegistry._ready() → 注册英雄（此时技能已可用）
3. GameManager.skill_registry 指向 SkillSystem 的 registry
```

### 战斗流程
```
hero.tick_ai() → RoleAI.pick_action() → 返回 AutonomyPick
    ↓
skill_system.cast_skill(hero, skill_id, target) → 生成视觉投射物
    ↓
CombatResolver.resolve_attack() → 计算伤害
    ↓
target.take_damage() → 施加伤害（即时）
```

**注意**：伤害是即时施加的，投射物是纯视觉效果。投射物命中时只触发 VFX，不重复施加伤害。

---

## 3. 英雄技能配置

### 文件变更
- `scripts/data/hero_registry.gd` — 每个英雄调用 `set_skills()`
- `resources/skills/skill_defs/fireball_basic.tres` — cooldown 2.8→4.0
- `resources/skills/skill_defs/missile_storm.tres` — cooldown 3.0→5.0
- `resources/skills/skill_visual_defs/fireball_basic.tres` — projectile_scale 0.5
- `resources/skills/skill_visual_defs/missile_storm.tres` — projectile_scale 0.8
- `docs/design/combat-rules/values/skill-values.csv` — cooldown 同步

### 英雄技能分配
| 英雄 | 职业 | 技能 | 冷却 | 投射物缩放 |
|------|------|------|------|-----------|
| Ironwall | FRONTLINER | missile_storm (导弹风暴) | 5.0s | 0.8x |
| Ember | DPS | fireball_basic (火球术) | 4.0s | 0.5x |
| Moss | SUPPORT | fireball_basic (火球术) | 4.0s | 0.5x |

### VFX 缩放说明
- 原始火球核心 36×36px，几乎和角色一样大（角色 48-55px）
- 缩放 0.5x 后 18px，约 1/3 角色高度
- 导弹核心 16×16px，缩放 0.8x 后 12.8px，约 1/4 角色高度

---

## 4. 敌人攻击视觉

### 新增文件
- `scripts/arena/enemy_shuriken.gd` — 忍者飞镖（直线旋转投射物）
- `scripts/arena/enemy_slash.gd` — 弧形刀光（近战挥砍特效）

### 机制
- 每个小怪生成时随机分配攻击类型：50% 飞镖 / 50% 刀光（`set_meta("skill_type", ...)`）
- **飞镖敌人**：远程攻击（280px 范围），直线飞行，命中时施加伤害
- **刀光敌人**：近战攻击（80px 范围），即时伤害 + 弧形挥砍视觉

### 关键常量
| 常量 | 值 | 说明 |
|------|-----|------|
| ENEMY_RANGED_RANGE | 280.0 | 飞镖敌人攻击距离 |
| ENEMY_MELEE_RANGE | 80.0 | 刀光敌人攻击距离 |

### 飞镖特性
- 直线飞行（启动时计算方向，不追踪）
- 旋转动画（12 rad/s）
- 命中检测用距离（16px 阈值）

### 刀光特性
- `setup(target)` 时计算 `angle_to_point` 确定朝向
- 弧度 0.6π（约 108°），半径 70px
- 0.25s 渐隐消失

---

## 5. 投射物生命周期修复

### 问题
火球命中后有时不消失，场地累积 7-8 个悬空火球。

### 原因
1. 目标死亡 → `_check_hit()` 返回 early → 投射物无限飞行
2. 弹射无目标 → `_on_chain_hit()` 不调用 destroy → 投射物卡住
3. 无最大生命周期 → 无安全网

### 修复 (`scripts/skill_system/pools/projectile_node.gd`)
| 位置 | 修复 |
|------|------|
| `_check_hit()` | 目标失效时调用 `_chain.destroy()` |
| `_on_chain_hit()` | 弹射无目标时走销毁流程 |
| `_process()` | 5 秒最大生命周期安全网 |
| `_on_chain_destroyed()` | await 后检查 `is_instance_valid(self)` |

---

## 6. 文档整理

### 新增
- `docs/camera-viewport-rules-v1.md` — 镜头/视窗权威规则文档

### 标记废弃 (11 个文件)
以下文件添加了 `[DEPRECATED]` 标记，内容保留但不再作为参考：
- `camera_system_design.md` → 被 `camera-viewport-rules-v1.md` 替代
- `tech/architecture/client-rendering-and-assets.md`
- `design/visual-rules/hero-asset-pipeline-spec.md`
- `tech/architecture/web-client-architecture.md`
- `tech/architecture/skill-system-architecture-2026-04-15.md`
- `tech/architecture/sprite-rendering-bug-analysis-2026-04-16.md`
- `tech/architecture/pixel-art-builder-handoff-2026-04-15.md`
- `tech/scene-ui-management-architecture-2026-04-14.md`
- `tech/incident-bluebook-return-button-2026-04-14.md`
- `tech/adr/2026-03-22-pixel-art-rendering-policy.md`
- `design/visual-rules/node-validation-visual-upgrade-follow-up-work-plan.md`

### 更新引用 (6 个文件)
修正了对旧文档/Phaser 版本的引用：
- `PROJECT-RULES.md` — 镜头引用、Design authority、规则存放位置
- `combat-presentation-spec.md` — 视角锁定 45°、层数更新为 11
- `pixel-art-visual-bible.md` — 分辨率 540×960、Z-Order 更新
- `game-foundation-baseline.md` — 添加 45° 视角说明
- `projectile-v1-taxonomy.md` — 实现映射从 Phaser 更新为 Godot
- `hit-feedback-juice-spec.md` — 移除 six-fighter-web 引用

---

## 7. 已知遗留项

### 未接入
- 敌人（小怪/Boss）没有接入 SkillSystem 的 RoleAI，使用简单的 `tick_ai()` 布尔计时器
- Boss 的 `update_boss_phases()` 有框架但没有具体的 Boss 技能逻辑
- 技能的 modifier 系统（bounce/scatter/fission）在竞技场中未测试

### 待优化
- 敌人飞镖没有飞行距离上限，如果目标死亡且无其他目标会飞出屏幕（靠 5s 安全网回收）
- 刀光视觉是纯 `_draw()` 绘制，后续可替换为精灵图/粒子效果
- `stun_duration_base_sec` 属性名错误（应为 `stun_duration`），已修复但 CombatResolver 的参数映射需复查

### 架构注意
- 伤害是即时施加的（CombatResolver），投射物是纯视觉。如果未来需要"投射物命中时才施加伤害"，需要修改整个流程
- SkillSystem 的 ProjectilePool 在场景树中的渲染顺序在 VFX 层之后（CanvasLayers 仍在最上层）
