# 冰霜旋风 — 技能设计文档

---

## 元数据

```
Status: Draft
Version: v1.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: ice_cyclone
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `ice_cyclone` |
| 显示名称 | 冰霜旋风 |
| 技能类型 | `aoe` 范围类（持续移动） |
| 伤害类型 | *见 CSV 数值表* |
| 设计优先级 | `P1` |
| 设计状态 | `草稿` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "ice_cyclone"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.26 秒
- **视觉效果**：
  - 施法者脚下出现冰霜聚集效果
  - 地面出现矩形警示区域（rect telegraph）
- **镜头效果**：无震屏

---

### 2.2 旋风移动阶段

- **描述**：多层椭圆叠加的冰霜旋风，从施法者位置移动到目标位置，持续旋转，带有旋转碎片和漩涡粒子拖尾
- **移动速度**：基于 travelMs (6000ms) 和施法者-目标距离计算
- **移动轨迹**：直线（从施法者位置到目标位置）
- **视觉效果**：
  - **多层椭圆**（4 层）：
    - 每层是椭圆形，沿着移动路径旋转
    - 层数：0（底层）~ 3（顶层）
    - 垂直偏移：每层向上偏移 0 ~ 80 px（baseHeight）
    - 宽度插值：底部宽度 40px → 顶部宽度 80px（有不规则波动）
    - 高度插值：底部高度 24px → 顶部高度 64px（有旋转偏移）
    - 旋转速度：0.8 + layerRatio * 0.6（随层数增加）
    - 颜色：`#3a8cff`（冰蓝），透明度 0.9 → 0.5（随层数递减，加脉冲波动）
  - **不规则波动**：
    - 使用 sin 函数产生宽度/高度的不规则变化（幅度 0.2~0.4）
  - **漩涡粒子**（SwirlParticles）：
    - 发射间隔：每 120ms
    - 每层发射：3 个粒子
    - 粒子从椭圆层边缘向外旋转扩散
    - 粒子大小：2 ~ 4.5 px
    - 颜色：`#e0f0ff`（极浅蓝）
    - 透明度：0.7，然后淡出
    - 寿命：300 ~ 700 ms
  - **碎片粒子**（Debris）：
    - 发射间隔：每 100ms
    - 每层发射：3 个碎片
    - 碎片从椭圆顶部区域向外随机方向飞散
    - 碎片大小：1.2 ~ 3.0 px
    - 颜色：`#f0f8ff`（白蓝）
    - 透明度：0.6，然后淡出
    - 寿命：200 ~ 500 ms
  - **漩涡拖尾**（CycloneTrail）：
    - 使用 Phaser.Graphics 实时绘制
    - 采样路径点（最多 25 个）
    - 两层绘制：
      - 外层：线宽 5px，颜色 `#d9f6ff`（极浅蓝），透明度 0.2
      - 内层：线宽 2.2px，颜色 `#f3fdff`（白蓝），透明度 0.66
    - 拖尾路径有轻微垂直摆动（sway）
- **持续时间**：6 秒（travelMs）
- **尺寸**：旋风高度 80px，底部宽度 40px，顶部宽度 80px

---

### 2.3 命中 / 爆发阶段

- **描述**：旋风到达目标位置后，产生冰霜爆发效果（待定，旧项目未明确实现）
- **爆发半径**：中等范围
- **视觉效果**：待补充
- **持续时间**：待定

---

### 2.4 持续效果阶段

- **描述**：旋风持续移动过程中，对路径上的敌人造成持续伤害（DOT）
- **持续时间**：6 秒（travelMs）
- **视觉效果**：
  - 同「旋风移动阶段」视觉效果
  - 漩涡粒子和碎片粒子持续发射

---

### 2.5 收尾 / 淡出

- **描述**：旋风到达目标位置后，椭圆层逐渐淡出，粒子停止发射
- **淡出时间**：待定（建议 0.5 秒）

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] 旋风透明度上限：≤ 0.9（底层）
- [ ] 漩涡拖尾透明度上限：≤ 0.66（内层）
- [ ] 色相与敌对/友方语义锚点不冲突（使用蓝/白色系）

---

## 4. 参数配置

### 4.1 粒子系统参数

#### 多层椭圆（Cyclone Layers）

| 参数 | 值 | 说明 |
|------|-----|------|
| layer_count | 4 | 层 |
| base_height | 80 | px |
| base_width_bottom | 40 | px |
| base_width_top | 80 | px |
| layer_color | `#3a8cff` | Color |
| layer_alpha_base | 0.9 | 底层 |
| layer_alpha_decay | 0.4 | 顶层透明度 = 0.9 - 0.4 |
| spin_speed_base | 0.8 | rad/s（底层） |
| spin_speed_increment | 0.6 | rad/s（每层增加） |
| irregularity_freq_1 | 1.8 | Hz |
| irregularity_amplitude_1 | 0.2 | |
| irregularity_freq_2 | 0.7 | Hz |
| irregularity_amplitude_2 | 0.15 | |

#### 漩涡粒子（SwirlParticles）

| 参数 | 值 | 说明 |
|------|-----|------|
| spawn_interval | 120 | ms |
| spawn_count_per_layer | 3 | |
| radius_min | 2.0 | px |
| radius_max | 4.5 | px |
| colors | `#e0f0ff` | |
| alpha_initial | 0.7 | |
| life_min | 300 | ms |
| life_max | 700 | ms |
| spread_speed_min | 40 | px/s（估计值） |
| spread_speed_max | 70 | px/s（估计值） |

#### 碎片粒子（Debris）

| 参数 | 值 | 说明 |
|------|-----|------|
| spawn_interval | 100 | ms |
| spawn_count_per_layer | 3 | |
| radius_min | 1.2 | px |
| radius_max | 3.0 | px |
| colors | `#f0f8ff` | |
| alpha_initial | 0.6 | |
| life_min | 200 | ms |
| life_max | 500 | ms |
| spread_speed_min | 20 | px/s（估计值） |
| spread_speed_max | 50 | px/s（估计值） |

#### 漩涡拖尾（CycloneTrail）

| 参数 | 值 | 说明 |
|------|-----|------|
| max_sample_points | 25 | |
| trail_outer_width | 5 | px |
| trail_outer_color | `#d9f6ff` | |
| trail_outer_alpha | 0.2 | |
| trail_inner_width | 2.2 | px |
| trail_inner_color | `#f3fdff` | |
| trail_inner_alpha | 0.66 | |
| sway_frequency | 0.55 | Hz |
| sway_amplitude | 5.2 | px |

---

### 4.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | 0.26 | s |
| 持续移动时长 | 6.0 | s |
| 椭圆旋转速度 | 0.8~1.4 | rad/s |
| 漩涡粒子发射间隔 | 0.12 | s |
| 碎片粒子发射间隔 | 0.10 | s |
| 震屏强度 | 0 | （无震屏） |
| 震屏时长 | 0 | s |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 椭圆核心色 | `#3a8cff` | 冰蓝 |
| 漩涡粒子色 | `#e0f0ff` | 极浅蓝 |
| 碎片粒子色 | `#f0f8ff` | 白蓝 |
| 拖尾外层色 | `#d9f6ff` | 极浅蓝 |
| 拖尾内层色 | `#f3fdff` | 白蓝 |

---

## 5. 实现映射

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/ice_cyclone.tres` | 技能定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/ice_cyclone.tres` | 视觉定义 |
| VFX 场景 | `res://scenes/skills/vfx/ice_cyclone_vfx.tscn` | VFX 场景文件 |
| 脚本 | `res://scripts/skills/ice_cyclone.gd` | 特殊逻辑脚本（多层椭圆+持续移动） |

---

## 6. 验证记录

### 验证 Checklist

- [ ] 技能可正常从 SkillRegistry 加载
- [ ] 4 层椭圆正确生成，从施法者位置移动到目标位置
- [ ] 椭圆层正确旋转，有不规则波动
- [ ] 漩涡粒子正常发射
- [ ] 碎片粒子正常发射
- [ ] 漩涡拖尾效果正常（Graphics 绘制）
- [ ] 颜色方案符合调色板约束
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 待验证 |

---

*本文档从旧项目 `six-fighter-web` 的 `CycloneBehavior.ts` 和 `ice_cyclone.ts` 翻译而来。*
*翻译人：AI 助手*
