# 战斗HUD设计方案 — 英雄状态面板 + 技能CD显示

## 一、需求概述

在战斗过程中，玩家需要实时了解每个英雄的状态。当前HUD仅有波次文字、倒计时和退出按钮，缺乏关键战斗信息。

**v1 目标**：
1. 显示每个英雄的头像和血条
2. 显示每个英雄的技能CD状态

## 二、现有系统分析

### 2.1 英雄数据
- **3个英雄**：`ember`(DPS/橙色)、`moss`(SUPPORT/绿色)、`ironwall`(FRONTLINER/蓝色)
- 每个英雄有4个技能槽：`basic`(普攻)、`small_a`(小技能A)、`small_b`(小技能B)、`ultimate`(大招)
- CSV中目前定义了`skill_1`和`skill_2`两个技能，对应basic(普攻)和small_a(小技能A)
- small_b(小技能B)和ultimate(大招)目前为空，UI会自动隐藏未配置的技能图标

### 2.2 技能CD系统
- 由 `RoleAI.AutonomyTimers` 管理，包含4个float计时器：`basic`、`small_a`、`small_b`、`rage`
- `tick_timers()` 每帧递减 basic/small_a/small_b
- `rage` 通过伤害积累（伤害的15%），大招消耗怒气
- 技能释放时重置对应计时器为 `SkillDef.cooldown` 值

### 2.3 现有HUD
- CanvasLayer layer=20，纯代码构建
- `_create_hud()` 创建所有UI元素
- `_update_ui()` 当前为空（`pass`）
- 英雄的血量数据在 `Unit.current_hp` / `Unit.max_hp`

## 三、设计方案

### 3.1 整体布局

```
┌─────────────────────────────────────────────────────┐
│ [ironwall] [ember  ] [moss  ]          [退出副本] │
│  ❤ ████░░   ❤ ████░░  ❤ ████░░                   │
│  [A][B][Q]   [A][B][Q]  [A][B][Q]                  │
│                                                     │
│                                                     │
│                  (战斗区域)                           │
│                                                     │
│                                                     │
│                                                     │
│                   [摇杆]                             │
└─────────────────────────────────────────────────────┘
```

左上角横向排列3个英雄卡片（可扩展到6个），每个卡片包含：
- 头像（40x40）
- 名字标签
- 血条（60x8）
- 3个技能小图标（20x20）+ 扇形CD遮罩（小技能A、小技能B、大招）

### 3.2 头像资源系统

**现状**：项目没有英雄头像资源，需要建立管理规则。

**方案**：
1. 创建目录 `game/resources/heroes/portraits/`
2. 每个英雄一个 PNG 文件：`ironwall.png`、`ember.png`、`moss.png`
3. 头像尺寸：80x80像素（UI中显示为40x40，保留2x清晰度）
4. 暂用程序生成的占位头像（角色色块 + 首字），后续替换为正式立绘

**占位头像设计**：
- `ironwall`：蓝色底(#7070E0) + "铁"字
- `ember`：橙色底(#FFA050) + "烬"字
- `moss`：绿色底(#50C060) + "苔"字

### 3.3 技能图标系统

**现状**：项目没有技能图标资源。

**方案**：
1. 创建目录 `game/resources/skills/icons/`
2. 每个技能一个 PNG 文件，如 `fireball_basic.png`
3. 图标尺寸：40x40像素（UI中显示为20x20）
4. 暂用程序生成的占位图标（根据伤害类型着色的几何图形）

**占位图标规则**：
- 火焰技能：橙红圆形
- 冰霜技能：蓝色菱形
- 物理技能：灰色方块
- 大招技能：金色星形

### 3.4 代码架构

#### 新增文件

| 文件路径 | 说明 |
|---------|------|
| `game/scripts/ui/battle_hud.gd` | 战斗HUD主控制器 |
| `game/scripts/ui/hero_status_card.gd` | 单个英雄状态卡片 |
| `game/scripts/ui/skill_icon.gd` | 技能图标 + CD遮罩 |
| `game/scripts/ui/portrait_generator.gd` | 占位头像生成器 |
| `game/scripts/ui/skill_icon_generator.gd` | 占位技能图标生成器 |

#### 修改文件

| 文件路径 | 修改内容 |
|---------|---------|
| `arena_scene.gd` | 在`_create_hud()`中实例化BattleHUD，在`_update_ui()`中调用更新 |

### 3.5 数据流

```
Arena._process()
  └─> BattleHUD.update(heroes)
        └─> HeroStatusCard.update(hero)
              ├─> 更新血条: hero.current_hp / hero.max_hp
              └─> 更新技能CD: hero.timers.get_value(key) / skill_def.cooldown
```

**关键数据源**：
- `hero.is_alive` — 英雄存活状态
- `hero.current_hp` / `hero.max_hp` — 血量
- `hero.timers.small_a` — 小技能A的CD计时器
- `hero.timers.small_b` — 小技能B的CD计时器
- `hero.timers.rage` — 怒气值（大招充能，满100可释放）
- `hero.hero_def.skill_ids` — 技能ID列表
- `skill_registry.get_skill(id)` — 获取SkillDef（含cooldown值）

**技能CD显示规则**：

- 小技能(A/B)：`timer / skill_def.cooldown` 的比值，timer<=0表示可用
- 大招(Q)：`rage / 100.0` 的比值，rage>=100表示可释放

### 3.6 扇形CD遮罩实现

使用Godot的 `_draw()` 方法绘制扇形遮罩：

```gdscript
func _draw() -> void:
    if cd_ratio <= 0.0:
        return
    # 绘制半透明黑色扇形，从顶部顺时针覆盖
    var points := PackedVector2Array()
    points.append(center)
    var end_angle := -PI/2 + cd_ratio * TAU  # 从12点钟方向开始
    for i in range(33):
        var angle := -PI/2 + float(i) / 32.0 * cd_ratio * TAU
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
    draw_colored_polygon(points, Color(0, 0, 0, 0.6))
```

### 3.7 英雄状态卡片布局

```
┌──────────────────────────┐
│ [头像] 名字              │  40px高
│         [====血条====]   │  12px高
│    [A]  [B]  [Q]         │  24px高
└──────────────────────────┘
  80px宽
```

- A = 小技能A (small_a)
- B = 小技能B (small_b)  
- Q = 大招 (ultimate)，怒气满时可释放

单个卡片：80px宽 × 76px高
3个卡片横向排列，间距8px，总宽度约 80*3 + 8*2 = 256px

### 3.8 英雄死亡处理

- 英雄死亡时：卡片整体变灰（modulate = Color(0.4, 0.4, 0.4)）
- 头像上叠加 "X" 标记
- 血条显示为空
- 技能图标锁定当前状态

## 四、实现步骤

### Phase 1：基础框架
1. 创建 `battle_hud.gd` — HUD主容器
2. 创建 `hero_status_card.gd` — 英雄卡片组件
3. 修改 `arena_scene.gd` — 集成BattleHUD

### Phase 2：血条显示
4. 实现血条UI（ColorRect或ProgressBar）
5. 连接数据源：hero.current_hp / hero.max_hp
6. 实现血条颜色变化（绿→黄→红）

### Phase 3：技能CD显示
7. 创建 `skill_icon.gd` — 技能图标组件
8. 实现扇形CD遮罩绘制
9. 连接数据源：hero.timers / skill_def.cooldown

### Phase 4：占位资源
10. 创建 `portrait_generator.gd` — 程序生成占位头像
11. 创建 `skill_icon_generator.gd` — 程序生成占位技能图标

### Phase 5：打磨
12. 英雄死亡视觉反馈
13. 布局微调、响应式适配
14. 性能优化（避免每帧重建UI）

## 五、技术要点

### 5.1 性能考虑
- UI节点在_ready()中一次性创建，_process()中只更新数据
- 使用 `queue_redraw()` 触发CD遮罩重绘，而非每帧_draw()
- 血条使用 ColorRect.size 调整宽度，避免重建节点

### 5.2 扩展性
- BattleHUD 接收 heroes 数组，自动适应 1-6 个英雄
- 卡片布局支持横向排列，可配置间距和边距
- 头像/技能图标通过 Generator 类解耦，方便后续替换正式资源

### 5.3 与现有系统兼容
- 不修改 Unit/Hero/RoleAI 等核心类
- 仅在 arena_scene.gd 中添加初始化和更新调用
- HUD 作为 HUDLayer 的子节点，与现有 UI 元素共存

## 六、后续迭代方向（v2+）

- 怒气条显示
- 状态效果图标（灼烧/冰冻/中毒/眩晕）
- Boss血条
- 英雄选中/点击交互
- 正式立绘替换占位头像
- 正式技能图标替换占位图标
