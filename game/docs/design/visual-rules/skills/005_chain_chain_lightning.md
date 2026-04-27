# 闪电链 — 技能设计文档

---

## 元数据

```
Status: Draft
Version: v1.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: chain_lightning
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `chain_lightning` |
| 显示名称 | 闪电链 |
| 技能类型 | `proj` 发射类（链式跳跃） |
| 伤害类型 | *见 CSV 数值表* |
| 设计优先级 | `P1` |
| 设计状态 | `草稿` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "chain_lightning"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.30 秒
- **视觉效果**：
  - 施法者身上出现闪电预兆光效
  - 地面出现圆形警示区域（circle telegraph）
- **镜头效果**：无震屏

---

### 2.2 发射 / 链式跳跃阶段

- **描述**：闪电链在多个目标之间跳跃，使用 4 状态机（FLYING → INCOMING → DWELL → OUTGOING），带有抖动线段和闪烁光效
- **跳跃次数**：最多 10 次（MAX_BOUNCES）
- **跳跃搜索半径**：200 px（SEARCH_RADIUS）
- **飞行速度**：600 px/s（FLYING 状态）
- **视觉效果**：
  - **闪电线段**（Graphics 实时绘制）：
    - 尾部跟随头部，保留 120px 拖尾长度（TRAIN_LENGTH）
    - 线段有随机抖动（jag），幅度 14px
    - 三层绘制：
      - 外层：线宽 7px，颜色 `#ffc88f`（浅橙），透明度 0.30
      - 中层：线宽 4px，颜色 `#4dff91`（绿），透明度 0.55
      - 内层：线宽 2px，颜色 `#ffffff`（白），透明度 0.90
    - 线段节点处有概率绘制白色圆点（50% 概率），半径 1.5px
  - **DVELL 状态**（命中目标后停顿）：
    - 持续 60ms（DWELL_DURATION）
    - 从目标位置向外发射 5 条闪烁电弧（arc）
    - 电弧长度 6~12px，透明度波动（0.4 + sin * 0.4）
    - 目标位置有光晕：
      - 内层：半径 3px，颜色 `#ffffff`，透明度波动
      - 外层：半径 6px，颜色 `#4dff91`，透明度波动
    - 闪烁电弧绘制（drawLightningArc）：
      - 三层绘制：线宽 3/2/1px，颜色 `#ffc88f`/`#4dff91`/`#ffffff`
  - **INCOMING 状态**（尾部回缩）：
    - 持续 200ms（RETRACT_DURATION）
    - 尾部从旧目标位置回缩到当前头部位置
  - **OUTGOING 状态**（头部扩展到下一目标）：
    - 持续 150ms（EXTEND_DURATION）
    - 头部从当前位置扩展到下一目标位置
- **尺寸**：线段宽度 2~7 px

---

### 2.3 命中 / 爆发阶段

- **描述**：每次跳跃命中目标后，产生闪电爆发效果（spawnLightningImpact）
- **爆发半径**：中等范围（闪光 3.6 → 17px）
- **视觉效果**：
  - **闪爆效果**：
    - 圆形，半径 3.6 → 17px（0.07 秒内扩张）
    - 三层光晕：
      - 外层：颜色 `#ffc88f`，透明度 0.35 * alpha
      - 中层：颜色 `#ffffff`，透明度 0.7 * alpha
      - 内层：颜色 `#ffffff`，透明度 0.95 * alpha
    - alpha 从 1 降到 0（0.07 秒内）
  - **电弧扩散**：
    - 6~9 条电弧从目标位置向外扩散
    - 电弧长度 12 → 39px（0.18 秒内扩张）
    - 透明度 0.85 → 0（0.30 秒内）
    - 使用 drawLightningArc 绘制
  - **环形波**：
    - 圆形，半径 2.4 → 31.2px（0.30 秒内扩张）
    - 透明度 0.85 → 0（0.30 秒内）
    - 线宽 2px，颜色 `#4dff91`
  - **余烬粒子**：
    - 数量：10~16 个
    - 从目标位置向外扩散
    - 扩散速度：30~78 px/s
    - 颜色：`#4dff91`（绿）, `#ffc88f`（浅橙）
    - 寿命：100~200 ms
- **持续时间**：约 0.33 秒（闪爆 + 电弧 + 环形波 + 余烬）
- **颜色方案**：绿橙色系 `#4dff91` + `#ffc88f`

---

### 2.4 持续效果阶段

- **描述**：无持续效果（闪电链是一次性跳跃伤害）
- **持续时间**：N/A

---

### 2.5 收尾 / 淡出

- **描述**：余烬粒子自然淡出，闪电线段销毁
- **淡出时间**：200 ms（余烬寿命）

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] 闪电线段透明度上限：≤ 0.90（内层）
- [ ] 余烬粒子透明度上限：≤ 0.95
- [ ] 色相与敌对/友方语义锚点不冲突（使用绿/橙色系）

---

## 4. 参数配置

### 4.1 粒子系统参数

#### 闪电线段（Lightning Segment）

| 参数 | 值 | 说明 |
|------|-----|------|
| max_bounces | 10 | 次 |
| search_radius | 200 | px |
| speed | 600 | px/s |
| train_length | 120 | px |
| retract_duration | 200 | ms |
| dwell_duration | 60 | ms |
| extend_duration | 150 | ms |
| segment_count_min | 4 | |
| segment_jag_amplitude | 14 | px |
| layer_outer_width | 7 | px |
| layer_outer_color | `#ffc88f` | |
| layer_outer_alpha | 0.30 | |
| layer_mid_width | 4 | px |
| layer_mid_color | `#4dff91` | |
| layer_mid_alpha | 0.55 | |
| layer_inner_width | 2 | px |
| layer_inner_color | `#ffffff` | |
| layer_inner_alpha | 0.90 | |
| node_dot_probability | 0.5 | |
| node_dot_radius | 1.5 | px |

#### 闪烁电弧（Flicker Arc）

| 参数 | 值 | 说明 |
|------|-----|------|
| arc_count_min | 4 | |
| arc_count_max | 9 | |
| arc_length_min | 6 | px |
| arc_length_max | 12 | px |
| arc_alpha_base | 0.4 | |
| arc_alpha_mod | 0.4 | sin 波动幅度 |
| draw_layers | 3 | 外层/中层/内层 |
| draw_outer_width | 3 | px |
| draw_mid_width | 2 | px |
| draw_inner_width | 1 | px |

#### 命中爆发效果（Impact Burst）

| 参数 | 值 | 说明 |
|------|-----|------|
| flash_expand_duration | 70 | ms |
| flash_radius_min | 3.6 | px |
| flash_radius_max | 17.0 | px |
| flash_alpha_initial | 0.95 | |
| arc_expand_duration | 180 | ms |
| arc_length_min | 12 | px |
| arc_length_max | 39 | px |
| arc_alpha_initial | 0.85 | |
| ring_expand_duration | 280 | ms |
| ring_radius_min | 2.4 | px |
| ring_radius_max | 31.2 | px |
| ring_alpha_initial | 0.85 | |
| ring_color | `#4dff91` | |
| ember_count_min | 10 | |
| ember_count_max | 16 | |
| ember_speed_min | 30 | px/s |
| ember_speed_max | 78 | px/s |
| ember_life_min | 100 | ms |
| ember_life_max | 200 | ms |
| ember_colors | `#4dff91`, `#ffc88f` | |

---

### 4.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | 0.30 | s |
| 跳跃动画总时长 | 1.2 | s（含所有状态） |
| 每次跳跃时长 | ~0.41 | s（retract+ dwell+ extend） |
| 命中动画时长 | 0.33 | s |
| hit_stop 帧数 | 待定 | |
| 震屏强度 | 120 | |
| 震屏时长 | 0.005 | s |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 线段外层色 | `#ffc88f` | 浅橙 |
| 线段中层色 | `#4dff91` | 绿 |
| 线段内层色 | `#ffffff` | 白 |
| 闪爆外层色 | `#ffc88f` | 浅橙 |
| 闪爆内层色 | `#ffffff` | 白 |
| 环形波色 | `#4dff91` | 绿 |
| 余烬色 | `#4dff91`, `#ffc88f` | 绿+浅橙 |

---

## 5. 实现映射

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/chain_lightning.tres` | 技能定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/chain_lightning.tres` | 视觉定义 |
| VFX 场景 | `res://scenes/skills/vfx/chain_lightning_vfx.tscn` | VFX 场景文件 |
| 投射物场景 | N/A | 闪电链无传统投射物，使用 Graphics 绘制 |
| 脚本 | `res://scripts/skills/chain_lightning.gd` | 特殊逻辑脚本（4状态机） |

---

## 6. 验证记录

### 验证 Checklist

- [ ] 技能可正常从 SkillRegistry 加载
- [ ] 闪电链在多个目标之间正确跳跃（最多10次）
- [ ] 闪电线段有随机抖动效果
- [ ] DWELL 状态闪烁电弧正常
- [ ] 命中爆发效果符合设计
- [ ] 颜色方案符合调色板约束
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 待验证 |

---

*本文档从旧项目 `six-fighter-web` 的 `ChainLightningBehavior.ts` 和 `chain_lightning.ts` 翻译而来。*
*翻译人：AI 助手*