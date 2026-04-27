# 幽灵火焰骷髅 — 技能设计文档

---

## 元数据

```
Status: Draft
Version: v1.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: ghost_fire_skull
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `ghost_fire_skull` |
| 显示名称 | 幽灵火焰骷髅 |
| 技能类型 | `proj` 发射类（追踪弹） |
| 伤害类型 | *见 CSV 数值表* |
| 设计优先级 | `P1` |
| 设计状态 | `草稿` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "ghost_fire_skull"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.38 秒
- **视觉效果**：
  - 施法者身边出现幽灵火焰预兆
  - 地面出现圆形警示区域（circle telegraph）
- **镜头效果**：无震屏

---

### 2.2 发射 / 飞行阶段

- **描述**：9~12 个火焰骷髅弹头依次发射，追踪目标，带有螺旋运动和抖动轨迹，拖尾粒子
- **飞行速度**：基础 240 px/s，有速度波动（±30%）
- **飞行轨迹**：追踪目标，带随机转向抖动、正弦摆动、间歇性螺旋运动
- **视觉效果**：
  - **骷髅头部**：椭圆形，宽10px，高9px，颜色 `#1a0f2e`（深蓝黑）
  - **左眼**：椭圆形，宽3px，高3px，颜色 `#000000`（黑），位置偏移 (-3, -1)
  - **右眼**：椭圆形，宽3px，高3px，颜色 `#000000`（黑），位置偏移 (+3, -1)
  - **下颌**：椭圆形，宽6px，高4px，颜色 `#1a0f2e`（深蓝黑），位置偏移 (0, +4)
  - **外层火焰光晕**：圆形，半径 14px，颜色 `#ff6b35`（橙），透明度波动（0.65 * flicker）
  - **内层火焰光晕**：圆形，半径 9px，颜色 `#4dff91`（绿），透明度波动（0.50 * flicker）
  - **幽灵光晕**：圆形，半径 20px，颜色 `#4dff91`（绿），透明度 0.15 波动
  - **追踪行为**：
    - 转向速率：2.5 rad/s
    - 摆动频率：2.0~3.0 Hz
    - 摆动幅度：初始 15~28 px，指数衰减
    - 随机转向：40% 概率，转向量 -0.9~+0.9 rad
    - 螺旋运动：0.4% 概率/帧触发，持续 0.25~0.50 秒，半径 12~22 px，速度 4~7 rad/s
  - **拖尾粒子**：
    - 发射间隔：0.030 秒
    - 每次发射：3~5 个粒子
    - 粒子大小：2.5 ~ 7.0 px
    - 粒子颜色：`#ff6b35`（橙）, `#4dff91`（绿）
    - 透明度：0.15 ~ 0.50
    - 寿命：约 80ms 后淡出销毁
    - 粒子池上限：28 个
- **发射间隔**：导弹风暴窗口 1000~1600ms，除以弹头数量，加随机 120ms 偏移
- **尺寸**：骷髅头 10×9 px

---

### 2.3 命中 / AOE 爆发阶段

- **描述**：骷髅弹头命中目标后，产生 AOE（Area of Effect）环形爆发效果
- **爆发半径**：20 px（RING_MAX）
- **视觉效果**：
  - **闪爆效果**：
    - 圆形，半径 4 → 24 px（0.07 秒内扩张）
    - 颜色：`#4dff91`（绿），透明度 0.9 → 0
  - **填充光晕**：
    - 圆形，半径 0 → 20 px（0.20 秒内扩张）
    - 然后保持 0.30 秒
    - 然后淡出 0.30 秒
    - 颜色：`#4dff91`（绿），透明度 0.12
  - **环形波**：
    - 圆形，半径 4 → 20 px（0.30 秒内扩张）
    - 然后保持 0.35 秒
    - 然后淡出 0.30 秒
    - 颜色：`#4dff91`（绿），透明度 0.85 → 0
  - **余烬粒子**：
    - 数量：12 个
    - 从环形波半径中点向外扩散
    - 扩散速度：40~70 px/s
    - 颜色：`#4dff91`（绿）, `#ff6b35`（橙）
    - 寿命：0.40~0.55 秒
- **持续时间**：约 0.95 秒（AOE 动画总时长）
- **颜色方案**：橙绿色系 `#ff6b35` + `#4dff91`

---

### 2.4 持续效果阶段

- **描述**：无持续效果（AOE 爆发是一次性的）
- **持续时间**：N/A

---

### 2.5 收尾 / 淡出

- **描述**：AOE 环形波和余烬粒子自然淡出
- **淡出时间**：0.30 秒（环形波淡出） + 0.55 秒（余烬粒子寿命）

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] AOE 爆发效果持续时间 ≤ 0.95 秒
- [ ] 拖尾粒子透明度上限：≤ 0.50
- [ ] 色相与敌对/友方语义锚点不冲突（使用橙/绿色系）

---

## 4. 参数配置

### 4.1 粒子系统参数

#### 弹体核心（骷髅头）

| 参数 | 值 | 说明 |
|------|-----|------|
| core_width | 10 | 像素 |
| core_height | 9 | 像素 |
| core_color | `#1a0f2e` | Color |
| eye_width | 3 | 像素 |
| eye_height | 3 | 像素 |
| eye_color | `#000000` | Color |
| jaw_width | 6 | 像素 |
| jaw_height | 4 | 像素 |
| jaw_offset_y | +4 | 像素 |
| outer_flame_radius | 14 | 像素 |
| outer_flame_color | `#ff6b35` | Color |
| inner_flame_radius | 9 | 像素 |
| inner_flame_color | `#4dff91` | Color |
| glow_radius | 20 | 像素 |
| glow_color | `#4dff91` | Color |

#### 追踪行为参数

| 参数 | 值 | 说明 |
|------|-----|------|
| base_speed | 240 | px/s |
| turn_rate | 2.5 | rad/s |
| osc_freq_min | 2.0 | Hz |
| osc_freq_max | 3.0 | Hz |
| osc_amp_initial_min | 15 | px |
| osc_amp_initial_max | 28 | px |
| osc_amp_decay_rate | 2.0 | 指数衰减系数 |
| jolt_probability | 0.40 | 随机转向概率 |
| jolt_magnitude | 0.9 | rad |
| spiral_trigger_prob | 0.004 | 螺旋触发概率/帧 |
| spiral_duration_min | 0.25 | s |
| spiral_duration_max | 0.50 | s |
| spiral_radius_min | 12 | px |
| spiral_radius_max | 22 | px |
| spiral_speed_min | 4 | rad/s |
| spiral_speed_max | 7 | rad/s |

#### 拖尾粒子（TrailParticles）

| 参数 | 值 | 说明 |
|------|-----|------|
| spawn_interval | 0.030 | s |
| spawn_count_min | 3 | |
| spawn_count_max | 5 | |
| radius_min | 2.5 | px |
| radius_max | 7.0 | px |
| colors | `#ff6b35`, `#4dff91` | |
| alpha_min | 0.15 | |
| alpha_max | 0.50 | |
| life_duration | 80 | ms（固定淡出） |
| max_pool_size | 28 | |

#### AOE 爆发效果

| 参数 | 值 | 说明 |
|------|-----|------|
| ring_max_radius | 20 | px |
| flash_expand_duration | 0.07 | s |
| flash_alpha_initial | 0.9 | |
| fill_expand_duration | 0.20 | s |
| fill_hold_duration | 0.30 | s |
| fill_fade_duration | 0.30 | s |
| fill_alpha | 0.12 | |
| ring_expand_duration | 0.30 | s |
| ring_hold_duration | 0.35 | s |
| ring_fade_duration | 0.30 | s |
| ring_alpha_initial | 0.85 | |
| ember_count | 12 | |
| ember_speed_min | 40 | px/s |
| ember_speed_max | 70 | px/s |
| ember_life_min | 0.40 | s |
| ember_life_max | 0.55 | s |
| ember_colors | `#4dff91`, `#ff6b35` | |

---

### 4.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | 0.38 | s |
| 飞行时长 | 0.8 | s（单枚弹头） |
| 弹头数量 | 9~12 | 枚 |
| 弹头发射窗口 | 1000~1600 | ms |
| AOE 动画总时长 | 0.95 | s |
| 震屏强度 | 120 | |
| 震屏时长 | 0.005 | s |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 骷髅核心色 | `#1a0f2e` | 深蓝黑 |
| 火焰外层色 | `#ff6b35` | 橙 |
| 火焰内层色 | `#4dff91` | 绿 |
| 幽灵光晕色 | `#4dff91` | 绿 |
| AOE 爆发色 | `#4dff91` | 绿 |

---

## 5. 实现映射

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/ghost_fire_skull.tres` | 技能定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/ghost_fire_skull.tres` | 视觉定义 |
| VFX 场景 | `res://scenes/skills/vfx/ghost_fire_skull_vfx.tscn` | VFX 场景文件 |
| 投射物场景 | `res://scenes/skills/projectiles/skull_projectile.tscn` | 投射物场景（多实例） |
| 脚本 | `res://scripts/skills/ghost_fire_skull.gd` | 特殊逻辑脚本（追踪+螺旋） |

---

## 6. 验证记录

### 验证 Checklist

- [ ] 技能可正常从 SkillRegistry 加载
- [ ] 9~12 个骷髅弹头依次发射，有随机延迟
- [ ] 弹头追踪目标，有随机转向抖动
- [ ] 间歇性螺旋运动正常触发
- [ ] 拖尾粒子正常发射
- [ ] 命中后 AOE 环形爆发效果符合设计
- [ ] 颜色方案符合调色板约束
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 待验证 |

---

*本文档从旧项目 `six-fighter-web` 的 `GhostFireSkullBehavior.ts` 和 `ghost_fire_skull.ts` 翻译而来。*
*翻译人：AI 助手*
