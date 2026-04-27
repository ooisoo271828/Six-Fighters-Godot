# 等离子光束 — 技能设计文档

---

## 元数据

```
Status: Draft
Version: v1.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: plasma_beam
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `plasma_beam` |
| 显示名称 | 等离子光束 |
| 技能类型 | `beam` 光束类（三层构建） |
| 伤害类型 | *见 CSV 数值表* |
| 设计优先级 | `P1` |
| 设计状态 | `草稿` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "plasma_beam"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.12 秒
- **视觉效果**：
  - 施法者武器位置出现光束预兆光效
  - 地面出现矩形警示区域（rect telegraph）
- **镜头效果**：无震屏（命中时才有）

---

### 2.2 光束构建阶段

- **描述**：三层光束（core/mid/outer）依次构建，从施法者位置射向目标位置，命中目标后产生震屏效果，随后各层依次淡出
- **光束长度**：施法者到目标的距离
- **光束方向**：施法者位置 → 目标位置
- **视觉效果**：
  - **外层光束**（最宽，最后构建，最先淡出）：
    - 构建时长：580 ms（OUTER_BUILD_MS）
    - 构建缓动：ease = 1 - (1-t)^2.5
    - 宽度：0 → 48 px（W_OUTER = 30 * 1.6 / 2）
    - 颜色：`#2266ff`（深蓝）
    - 透明度：0 → 0.25（构建阶段），然后保持，最后淡出（100ms）
    - 绘制方式：双向填充（从中心线向两侧），有抖动（jitter）
    - 抖动强度：7 → 0 px（指数衰减，按 hitElapsed）
  - **中层光束**（中等宽度，其次构建，其次淡出）：
    - 构建时长：400 ms（MID_BUILD_MS，从核心构建完成后开始）
    - 构建缓动：ease = 1 - (1-t)^2.5
    - 宽度：0 → 14 px（W_MID）
    - 颜色：`#88ddff`（冰蓝）
    - 透明度：0 → 0.6（构建阶段），然后保持，最后淡出（200ms）
    - 绘制方式：双向填充，有抖动
  - **核心光束**（最窄，最先构建，最后淡出）：
    - 构建时长：200 ms（CORE_BUILD_MS）
    - 构建缓动：ease = 1 - (1-t)^2.5
    - 宽度：0 → 4 px（W_CORE）
    - 颜色：`#ffffff`（白）
    - 透明度：0 → 0.95（构建阶段），然后保持，最后淡出（300ms）
    - 绘制方式：闭合路径（从中心线向两侧，再返回），有抖动
  - **命中效果**（光束命中目标时）：
    - 触发时机：首次 hitElapsed ≥ 0（即光束到达目标时）
    - 震屏：强度 160，时长 0.006s
    - 目标位置光晕：
      - 三层光晕，大小随命中后时间缩放（1 + (130 - hitElapsed) * 0.0005）
      - 内层：颜色 `#ffffff`，透明度 0.9 * ia
      - 中层：颜色 `#88ddff`，透明度 0.65 * ia
      - 外层：颜色 `#4488ff`，透明度 0.35 * ia
    - ia 从 1 降到 0（130ms 内）
  - **抖动效果**（Jitter）：
    - 光束整体有随机抖动（beamJitterX, beamJitterY）
    - 抖动强度：7 * exp(-hitElapsed * 0.012)
    - 每帧更新：rand(-intensity, intensity)
- **尺寸**：光束宽度 4~48 px（三层之和），长度 = 施法者到目标距离

---

### 2.3 命中 / 爆发阶段

- **描述**：光束命中目标时产生光晕效果（已包含在「光束构建阶段」中）
- **爆发半径**： N/A（光束是持续命中，非爆发）
- **持续时间**：同光束构建和淡出阶段
- **颜色方案**：蓝白色系 `#2266ff` + `#88ddff` + `#ffffff`

---

### 2.4 持续效果阶段

- **描述**：无持续效果（光束是一次性伤害，非DOT）

---

### 2.5 收尾 / 淡出

- **描述**：三层光束依次淡出（外层 → 中层 → 核心），目标光晕淡出
- **淡出时间**：
  - 外层：100 ms（OUTER_FADE_MS）
  - 中层：200 ms（MID_FADE_MS）
  - 核心：300 ms（CORE_FADE_MS）
  - 总时长：200（核心构建） + 1500（光束持续） + 100 + 200 + 300 = 2100 ms

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] 核心光束透明度上限：≤ 0.95
- [ ] 中层光束透明度上限：≤ 0.6
- [ ] 外层光束透明度上限：≤ 0.25
- [ ] 色相与敌对/友方语义锚点不冲突（使用蓝/白色系）

---

## 4. 参数配置

### 4.1 粒子系统参数

#### 光束结构（Beam Structure）

| 参数 | 值 | 说明 |
|------|-----|------|
| core_width | 4 | px（半宽） |
| core_color | `#ffffff` |  |
| core_build_ms | 200 | ms |
| core_alpha | 0.95 |  |
| core_fade_ms | 300 | ms |
| mid_width | 14 | px（半宽） |
| mid_color | `#88ddff` |  |
| mid_build_ms | 400 | ms（从核心构建完成后开始） |
| mid_alpha | 0.6 |  |
| mid_fade_ms | 200 | ms |
| outer_width | 24 | px（半宽 = 30 * 1.6 / 2） |
| outer_color | `#2266ff` |  |
| outer_build_ms | 580 | ms（从核心构建完成后开始） |
| outer_alpha | 0.25 |  |
| outer_fade_ms | 100 | ms |
| beam_duration | 1500 | ms（光束持续时长） |
| total_duration | 2100 | ms |

#### 光束抖动（Beam Jitter）

| 参数 | 值 | 说明 |
|------|-----|------|
| jitter_intensity_initial | 7 | px |
| jitter_decay_rate | 0.012 | 指数衰减系数 |
| jitter_update_interval | 16 | ms（每帧更新） |

#### 命中效果（Impact Effect）

| 参数 | 值 | 说明 |
|------|-----|------|
| hit_trigger_time | 0 | ms（首次到达目标时） |
| shake_intensity | 160 |  |
| shake_duration | 0.006 | s |
| glow_inner_color | `#ffffff` |  |
| glow_inner_alpha | 0.9 |  |
| glow_mid_color | `#88ddff` |  |
| glow_mid_alpha | 0.65 |  |
| glow_outer_color | `#4488ff` |  |
| glow_outer_alpha | 0.35 |  |
| glow_size_scale_factor | 0.0005 | 每秒缩放系数 |
| glow_fade_duration | 130 | ms |

#### 拖尾粒子（Trail Particles）

| 参数 | 值 | 说明 |
|------|-----|------|
| spawn_count | 待定 | 光束可能不需要传统拖尾粒子 |
| back_dist_min | 待定 |  |
| back_dist_max | 待定 |  |
| spread_min | 待定 |  |
| spread_max | 待定 |  |
| radius_min | 待定 |  |
| radius_max | 待定 |  |
| colors | 待定 |  |
| duration_min | 待定 | ms |
| duration_max | 待定 | ms |

> **注意**：光束类技能通常不需要拖尾粒子，因为光束本身是连续的。如果需要粒子效果，可以参考 `plasma_beam.ts` 中的定义。

#### 命中爆发粒子（Impact Burst）

| 参数 | 值 | 说明 |
|------|-----|------|
| spark_count_min | 6 |  |
| spark_count_max | 10 |  |
| speed_min | 10 | px/s |
| speed_max | 30 | px/s |
| life_min | 80 | ms |
| life_max | 150 | ms |
| colors | `#ffffff`, `#88ddff`, `#4488ff` |  |

---

### 4.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | 0.12 | s |
| 核心构建时长 | 0.20 | s |
| 中层构建时长 | 0.40 | s（从核心完成后开始） |
| 外层构建时长 | 0.58 | s（从核心完成后开始） |
| 光束持续时长 | 1.50 | s |
| 外层淡出时长 | 0.10 | s |
| 中层淡出时长 | 0.20 | s |
| 核心淡出时长 | 0.30 | s |
| 总时长 | 2.10 | s |
| hit_stop 帧数 | 待定 |  |
| 震屏强度 | 160 |  |
| 震屏时长 | 0.006 | s |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 核心光束色 | `#ffffff` | 白 |
| 中层光束色 | `#88ddff` | 冰蓝 |
| 外层光束色 | `#2266ff` | 深蓝 |
| 命中光晕内层色 | `#ffffff` | 白 |
| 命中光晕中层色 | `#88ddff` | 冰蓝 |
| 命中光晕外层色 | `#4488ff` | 中蓝 |

---

## 5. 实现映射

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/plasma_beam.tres` | 技能定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/plasma_beam.tres` | 视觉定义 |
| VFX 场景 | `res://scenes/skills/vfx/plasma_beam_vfx.tscn` | VFX 场景文件 |
| 投射物场景 | N/A | 光束无投射物，使用 Graphics 绘制 |
| 脚本 | `res://scripts/skills/plasma_beam.gd` | 特殊逻辑脚本（三层光束构建） |

---

## 6. 验证记录

### 验证 Checklist

- [ ] 技能可正常从 SkillRegistry 加载
- [ ] 三层光束依次构建（核心 → 中层 → 外层）
- [ ] 光束构建有缓动效果（ease = 1 - (1-t)^2.5）
- [ ] 光束有抖动效果（命中后抖动强度指数衰减）
- [ ] 光束命中目标时产生震屏效果
- [ ] 目标位置光晕效果正确（三层，大小缩放）
- [ ] 三层光束依次淡出（外层 → 中层 → 核心）
- [ ] 颜色方案符合调色板约束
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 待验证 |

---

*本文档从旧项目 `six-fighter-web` 的 `PlasmaBeamBehavior.ts` 和 `plasma_beam.ts` 翻译而来。*
*翻译人：AI 助手*