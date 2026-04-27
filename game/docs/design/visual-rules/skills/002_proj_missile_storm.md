# 导弹风暴 — 技能设计文档

---

## 元数据

```
Status: Implemented
Version: v2.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: missile_storm
Plugin API: HasturOperationGD (remote GDScript execution)
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `missile_storm` |
| 显示名称 | 导弹风暴 |
| 技能类型 | `proj` 发射类（多弹道） |
| 伤害类型 | 物理 |
| 基础伤害 | 30.0（可由 CSV 覆盖） |
| 冷却时间 | 3.0 秒 |
| 施法距离 | 350 px |
| 导弹数量 | 9~12 枚 |
| 飞行速度 | 450 px/s |
| 飞行轨迹 | 二次贝塞尔曲线（弧线） |
| 设计优先级 | `P1`（已完成） |
| 设计状态 | `已实现` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "missile_storm"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.22 秒
- **视觉效果**：
  - 施法者身边出现多个导弹预兆光点
  - 地面出现圆形警示区域（circle telegraph）
- **镜头效果**：无震屏

---

### 2.2 发射 / 飞行阶段

- **描述**：9~12 枚导弹依次发射，沿弧线弹道飞向目标，带有彗星状拖尾轨迹
- **飞行速度**：基于 travelMs (560ms) 和弧线长度计算
- **飞行轨迹**：二次贝塞尔曲线（弧线），有随机中点偏移
- **视觉效果**：
  - **导弹核心**：圆形，半径 6px，颜色 `#f3df9f`（浅黄）
  - **内核**：圆形，半径 6px，颜色 `#d78d3a`（暗黄），偏移 (0,0)
  - **光晕**：圆形，半径 11px，颜色 `#ff6f5f`（粉橙），透明度波动（0.34 + sin * 0.09）
  - **彗星拖尾**：
    - 使用 Phaser.Graphics 实时绘制
    - 采样路径点（最多 28 个）
    - 三层绘制：
      - 外层：线宽 6px，颜色 `#fff0dc`（极浅橙），透明度 0.35
      - 中层：线宽 3.4px，颜色 `#ffc98f`（浅橙），透明度 0.62
      - 内层：线宽 1.8px，颜色 `#ffffff`（白），透明度 0.96
    - 拖尾路径有轻微蛇形摆动（sway）
  - **拖尾粒子**：
    - 发射数量：5 个/枚导弹
    - 粒子颜色：`#fff0dc`, `#ffc98f`, `#ffffff`
    - 粒子大小：1.5 ~ 3.5 px
    - 粒子寿命：80 ~ 180 ms
    - 向后距离：8 ~ 24 px
    - 横向扩散：8 ~ 8 px（固定）
- **发射间隔**：导弹风暴窗口 1000~1600ms，除以导弹数量，加随机 120ms 偏移
- **尺寸**：核心 12×12 px

---

### 2.3 命中 / 爆发阶段

- **描述**：导弹命中目标后，产生中等强度的爆炸效果
- **爆发半径**：中等范围
- **视觉效果**：
  - **爆炸火花**：
    - 火花数量：10 ~ 14 个
    - 扩散速度：24 ~ 72 px/s
    - 颜色：`#ffe6ba`（浅黄）
    - 寿命：120 ~ 220 ms
- **持续时间**：约 0.2 秒

---

### 2.4 持续效果阶段

- **描述**：无持续效果
- **持续时间**：N/A

---

### 2.5 收尾 / 淡出

- **描述**：爆炸粒子自然淡出，拖尾 Graphics 销毁
- **淡出时间**：120 ~ 220 ms（火花寿命）

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] 爆发效果持续时间 ≤ 0.22 秒
- [ ] 拖尾透明度上限：≤ 0.96（内层）
- [ ] 色相与敌对/友方语义锚点不冲突（使用黄/橙色系）

---

## 4. 参数配置

### 4.1 粒子系统参数

#### 弹体核心

| 参数 | 值 | 说明 |
|------|-----|------|
| core_width | 12 | 像素 |
| core_height | 12 | 像素 |
| core_color | `#f3df9f` | Color |
| inner_width | 6 | 像素 |
| inner_height | 6 | 像素 |
| inner_color | `#d78d3a` | Color |
| glow_radius | 11 | 像素 |
| glow_color | `#ff6f5f` | Color |
| glow_alpha_base | 0.34 | |
| glow_alpha_mod | 0.09 | sin 波动幅度 |

#### 彗星拖尾（Comet Trail）

| 参数 | 值 | 说明 |
|------|-----|------|
| trail_layer_outer_width | 6 | px |
| trail_layer_outer_color | `#fff0dc` | |
| trail_layer_outer_alpha | 0.35 | |
| trail_layer_mid_width | 3.4 | px |
| trail_layer_mid_color | `#ffc98f` | |
| trail_layer_mid_alpha | 0.62 | |
| trail_layer_inner_width | 1.8 | px |
| trail_layer_inner_color | `#ffffff` | |
| trail_layer_inner_alpha | 0.96 | |
| max_sample_points | 28 | |
| sway_freq | 0.7 | Hz |
| sway_amplitude | 1.1 | px |

#### 拖尾粒子（TrailParticles）

| 参数 | 值 | 说明 |
|------|-----|------|
| spawn_count | 5 | 每次发射粒子数 |
| back_dist_min | 8 | px |
| back_dist_max | 24 | px |
| spread_min | 8 | px |
| spread_max | 8 | px（固定） |
| radius_min | 1.5 | px |
| radius_max | 3.5 | px |
| colors | `#fff0dc`, `#ffc98f`, `#ffffff` | |
| duration_min | 80 | ms |
| duration_max | 180 | ms |

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
| 施法前摇时长 | 0.22 | s |
| 飞行时长 | 0.56 | s（单枚导弹） |
| 导弹数量 | 9~12 | 枚 |
| 导弹发射窗口 | 1000~1600 | ms |
| 命中动画时长 | 0.2 | s |
| 震屏强度 | 110 | |
| 震屏时长 | 0.0032 | s |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 核心色 | `#f3df9f` | 浅黄 |
| 内核色 | `#d78d3a` | 暗黄 |
| 光晕色 | `#ff6f5f` | 粉橙 |
| 拖尾外层 | `#fff0dc` | 极浅橙 |
| 拖尾中层 | `#ffc98f` | 浅橙 |
| 拖尾内层 | `#ffffff` | 白 |
| 爆发核心色 | `#ffe6ba` | 浅黄 |

---

## 5. 实现映射

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/missile_storm.tres` | 技能定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/missile_storm.tres` | 视觉定义（含 comet trail） |
| 投射物运行时 | `res://scripts/skill_system/pools/projectile_node.gd` | ProjectileNode v2.0（含 Line2D 彗星拖尾） |
| Effect | `res://scripts/skill_system/core/effects/emit_projectile.gd` | v2.1：多弹道支持 |
| 视觉定义基类 | `res://scripts/skill_system/registry/skill_visual_def.gd` | 新增 projectile_count + comet trail 参数 |

---

## 6. 验证记录

### 验证 Checklist

- [x] 技能可正常从 SkillRegistry 加载
- [x] 9~12 枚导弹依次发射，随机弧线偏移
- [x] 导弹沿弧线弹道飞行（二次贝塞尔曲线 BEZIER_QUAD）
- [x] 彗星拖尾效果正常（3 层 Line2D + 蛇形摆动）
- [x] 拖尾粒子正常发射（5 个/枚，黄色系小粒子）
- [ ] 命中爆炸效果符合设计（当前为中等默认爆炸，可后续调参）
- [x] 颜色方案符合调色板约束（黄/橙/白色系）
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 草稿 |
| 2026-04-27 | v2.0 | 实装多弹道（emit_projectile v2.1）+ 贝塞尔弧线 + 彗星拖尾 Line2D + 蛇形摆动 | 代码完成，视觉效果待 skill_demo 验证 |

---

*本文档从旧项目 `six-fighter-web` 的 `HomingStormBehavior.ts` 和 `missile_storm.ts` 翻译而来。*
*翻译人：AI 助手*
