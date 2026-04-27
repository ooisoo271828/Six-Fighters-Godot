# 火球术 — 技能设计文档

---

## 元数据

```
Status: Draft
Version: v1.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: fireball_basic
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `fireball_basic` |
| 显示名称 | 火球术 |
| 技能类型 | `proj` 发射类 |
| 伤害类型 | *见 CSV 数值表* |
| 设计优先级 | `P0`（先做） |
| 设计状态 | `草稿` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "fireball_basic"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.42 秒
- **视觉效果**：
  - 施法者身上简短的火焰聚集光效（待实现）
  - 地面出现矩形警示区域（rect telegraph）
- **镜头效果**：无震屏

---

### 2.2 发射 / 飞行阶段

- **描述**：火球沿直线飞向目标，带有抖动效果、拖尾粒子和前缘火焰粒子
- **飞行速度**：基于 travelMs (1400ms) 和施法距离计算
- **飞行轨迹**：直线
- **视觉效果**：
  - **弹体核心**：椭圆形，宽36px，高36px，颜色 `#b8231b`（深红）
  - **内核**：椭圆形，偏移 (+2, -2)，宽21px，高17px，颜色 `#e8624e`（亮红）
  - **热点**：椭圆形，偏移 (-4, +3)，宽11px，高9px，颜色 `#ffa487`（橙白）
  - **弹尖**：三角形，长度18px，宽5px，颜色 `#d94435`（暗红）
  - **摩擦光晕**：圆形，半径21px，颜色 `#ff6f5f`（粉橙），透明度 0.48
  - **核心抖动**：振幅 0.9px，频率 X=2.3, Y=2.1
  - **拖尾粒子**：
    - 发射数量：8 个/次
    - 发射间隔：每 0.45 秒发射一次
    - 粒子颜色：`#ffd2c4`, `#ffba9f`, `#ffe9e3`（浅橙白）
    - 粒子大小：1.2 ~ 6.4 px
    - 粒子寿命：180 ~ 450 ms
    - 向后距离：20 ~ 80 px
    - 横向扩散：28 ~ 46 px
  - **前缘火焰粒子**：
    - 弧形采样数：12
    - 内层径向距离：1.2 ~ 5.5 px
    - 外层径向距离：5.5 ~ 14 px
    - 颜色：`#ff7b69`, `#d5362c`
    - 寿命：100 ~ 195 ms
- **尺寸**：核心 36×36 px

---

### 2.3 命中 / 爆发阶段

- **描述**：火球命中目标后，产生中等强度的爆炸效果
- **爆发半径**：待定（参考旧项目为中等范围）
- **视觉效果**：
  - **爆炸火花**：
    - 火花数量：10 ~ 14 个
    - 扩散速度：24 ~ 72 px/s
    - 颜色：`#ffe6ba`（浅黄）
    - 寿命：120 ~ 220 ms
  - **屏幕震动**：强度 110，时长 0.0032（短震）
- **持续时间**：约 0.2 秒
- **颜色方案**：橙红色系 `#ff4400` ~ `#ff6b35`

---

### 2.4 持续效果阶段

- **描述**：无持续效果（非DOT技能）
- **持续时间**：N/A

---

### 2.5 收尾 / 淡出

- **描述**：爆炸粒子自然淡出
- **淡出时间**：120 ~ 220 ms（火花寿命）

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] 爆发效果持续时间 ≤ 0.22 秒
- [ ] 拖尾粒子透明度上限：≤ 0.5
- [ ] 色相与敌对/友方语义锚点不冲突（使用红/橙色系）

---

## 4. 参数配置

> 本节参数从旧项目 TypeScript 代码翻译而来，用于新版 Godot 项目。

### 4.1 粒子系统参数

#### 弹体核心（Scene 中用 Node2D + GPUParticles2D 实现）

| 参数 | 值 | 说明 |
|------|-----|------|
| core_width | 36 | 像素 |
| core_height | 36 | 像素 |
| core_color | `#b8231b` | Color |
| core_jitter_amplitude | 0.9 | 像素 |
| core_jitter_freq_x | 2.3 | Hz |
| core_jitter_freq_y | 2.1 | Hz |
| inner_width | 21 | 像素 |
| inner_height | 17 | 像素 |
| inner_color | `#e8624e` | Color |
| inner_offset_x | 2 | 像素 |
| inner_offset_y | -2 | 像素 |
| hotspot_width | 11 | 像素 |
| hotspot_height | 9 | 像素 |
| hotspot_color | `#ffa487` | Color |
| nose_length | 18 | 像素 |
| nose_width | 5 | 像素 |
| nose_color | `#d94435` | Color |
| glow_radius | 21 | 像素 |
| glow_color | `#ff6f5f` | Color |

#### 拖尾粒子（TrailParticles）

| 参数 | 值 | 说明 |
|------|-----|------|
| spawn_count | 8 | 每次发射粒子数 |
| back_dist_min | 20 | px |
| back_dist_max | 80 | px |
| spread_min | 28 | px |
| spread_max | 46 | px |
| radius_min | 1.2 | px |
| radius_max | 6.4 | px |
| colors | `#ffd2c4`, `#ffba9f`, `#ffe9e3` | |
| duration_min | 180 | ms |
| duration_max | 450 | ms |

#### 前缘火焰粒子（FrontFlameParticles）

| 参数 | 值 | 说明 |
|------|-----|------|
| arc_samples | 12 | 弧形采样数 |
| radial_inner_min | 1.2 | px |
| radial_inner_max | 5.5 | px |
| radial_outer_min | 5.5 | px |
| radial_outer_max | 14.0 | px |
| colors | `#ff7b69`, `#d5362c` | |
| duration_min | 100 | ms |
| duration_max | 195 | ms |

#### 命中爆发粒子（ImpactBurst）

| 参数 | 值 | 说明 |
|------|-----|------|
| spark_count_min | 10 | |
| spark_count_max | 14 | |
| speed_min | 24 | px/s |
| speed_max | 72 | px/s |
| life_min | 120 | ms |
| life_max | 220 | ms |
| colors | `#ffe6ba` | |

---

### 4.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | 0.42 | s |
| 飞行时长 | 1.4 | s |
| 命中动画时长 | 0.2 | s |
| hit_stop 帧数 | 待定 | |
| 震屏强度 | 110 | |
| 震屏时长 | 0.0032 | s |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 核心色 | `#b8231b` | 深红 |
| 内核色 | `#e8624e` | 亮红 |
| 热点色 | `#ffa487` | 橙白 |
| 弹尖色 | `#d94435` | 暗红 |
| 光晕色 | `#ff6f5f` | 粉橙 |
| 拖尾色 | `#ffd2c4` | 浅橙 |
| 爆发核心色 | `#ff4400` | 亮橙红 |

---

## 5. 实现映射

> 填写实现过程中生成的资源路径，方便后续查找和修改。

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/fireball_basic.tres` | 技能定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/fireball_basic.tres` | 视觉定义 |
| VFX 场景 | `res://scenes/skills/vfx/fireball_basic_vfx.tscn` | VFX 场景文件 |
| 投射物场景 | `res://scenes/skills/projectiles/fireball_projectile.tscn` | 投射物场景 |
| 脚本 | `res://scripts/skills/fireball_basic.gd` | 特殊逻辑脚本（如有） |

---

## 6. 验证记录

> 在 `skill_demo` 场景中验证，记录每次迭代的结果。

### 验证 Checklist

- [ ] 技能可正常从 SkillRegistry 加载
- [ ] 施法前摇视觉符合设计（矩形警示区）
- [ ] 飞行弹体有抖动效果
- [ ] 拖尾粒子正常发射
- [ ] 前缘火焰粒子正常发射
- [ ] 命中爆炸效果符合设计
- [ ] 颜色方案符合调色板约束
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 待验证 |

---

*本文档从旧项目 `six-fighter-web` 的 `LinearBehavior.ts` 和 `fireball.ts` 翻译而来。*
*翻译人：AI 助手*
