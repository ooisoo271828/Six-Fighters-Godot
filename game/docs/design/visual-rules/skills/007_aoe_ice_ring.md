# 冰环 — 技能设计文档

---

## 元数据

```
Status: Draft
Version: v1.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: ice_ring
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `ice_ring` |
| 显示名称 | 冰环 |
| 技能类型 | `aoe` 范围类（环形扩散） |
| 伤害类型 | *见 CSV 数值表* |
| 设计优先级 | `P1` |
| 设计状态 | `草稿` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "ice_ring"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.26 秒
- **视觉效果**：
  - 施法者脚下出现冰霜聚集效果
  - 地面出现圆形警示区域（circle telegraph）
- **镜头效果**：无震屏

---

### 2.2 环形扩散阶段

- **描述**：冰环从施法者位置向外扩散，带有冰晶粒子和光晕效果，持续旋转和波动
- **最大半径**：160 px（MAX_RADIUS）
- **扩散时长**：300 ms（SPREAD_DURATION）
- **持续时长**：500 ms（PERSIST_DURATION）
- **淡出时长**：150 ms（FADE_DURATION）
- **总时长**：950 ms（TOTAL_DURATION）
- **视觉效果**：
  - **环形填充区域**：
    - 使用 Graphics 实时绘制
    - 从施法者位置向外环形展开
    - 半径随时间从 0 → 160px（300ms 内，缓动 ease = 1 - (1-t)^2.5）
    - 边缘有噪声扰动（noise 0.88~1.15）
    - 颜色：`#88ddff`（冰蓝），透明度 0.07 * globalAlpha
    - globalAlpha 有波动（持续阶段：0.6 + sin * 0.2；淡出阶段：线性下降）
  - **环形线**（3 层）：
    - 使用 Graphics 绘制圆形
    - 半径：当前半径 - 0/3/6 px
    - 线宽：6/4.5/3 px（随层数递减）
    - 颜色：`#aaeeff`（极浅蓝）
    - 透明度：0.8 * globalAlpha * (1 - layer * 0.3) * 0.4
  - **冰晶粒子**（24 个预计算粒子）：
    - 每个粒子有固定的基础角度、距离比率、大小、相位、速度
    - 粒子角度随时间缓慢旋转（speed * 0.0008）
    - 粒子距离有呼吸波动（distRatio + sin * 0.08）
    - 粒子大小有呼吸波动（size * (0.7 + breathe * 0.5)）
    - 粒子透明度：ringAlpha * rand(0.3, 0.7)
    - 三层绘制：
      - 外层：颜色 `#88ddff`，透明度 * 0.3，大小 * 2.2
      - 中层：颜色 `#aaeeff`，透明度 * 0.6，大小 * 1.4
      - 内层：颜色 `#ffffff`，透明度 * 0.9，大小 * 0.5
  - **中心光晕粒子**（6 个预计算）：
    - 每个粒子有固定的基础角度、距离比率、相位
    - 粒子角度随时间缓慢旋转（0.001）
    - 粒子距离有呼吸波动（dist * (1 + sin * 0.5)）
    - 粒子大小有呼吸波动（4 + breathe * 5）
    - 粒子透明度：globalAlpha * 0.25 * breathe
    - 颜色：`#aaeeff`（极浅蓝）
  - **填充光晕**：
    - 使用 Graphics 填充圆形
    - 半径：当前半径
    - 颜色：`#66ccff`（中蓝）
    - 透明度：0.12 * globalAlpha
- **尺寸**：环形半径 160px

---

### 2.3 命中 / 持续伤害阶段

- **描述**：冰环覆盖区域内的敌人持续受到伤害（DOT），视觉上冰晶持续旋转和波动
- **持续时间**：500 ms（PERSIST_DURATION）
- **视觉效果**：同「环形扩散阶段」，但半径保持不变（160px），粒子持续发射，有旋转和波动

---

### 2.4 持续效果阶段

- **描述**：无额外持续效果（DOT 已在「持续伤害阶段」覆盖）

---

### 2.5 收尾 / 淡出

- **描述**：环形区域和粒子逐渐淡出
- **淡出时间**：150 ms（FADE_DURATION），透明度线性下降到 0

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] 环形填充透明度上限：≤ 0.07（基础）
- [ ] 冰晶粒子透明度上限：≤ 0.7（基础）
- [ ] 色相与敌对/友方语义锚点不冲突（使用蓝/白色系）

---

## 4. 参数配置

### 4.1 粒子系统参数

#### 环形填充区域（Ring Filarea）

| 参数 | 值 | 说明 |
|------|-----|------|
| max_radius | 160 | px |
| spread_duration | 300 | ms |
| persist_duration | 500 | ms |
| fade_duration | 150 | ms |
| total_duration | 950 | ms |
| spread_ease | 2.5 | 缓动指数 |
| fill_color | `#88ddff` |  |
| fill_alpha_base | 0.07 |  |
| fill_noise_range | 0.88~1.15 |  |
| global_alpha_spread | 0.7~1.0 | （扩散阶段） |
| global_alpha_persist | 0.6~0.8 | （持续阶段，有波动） |
| global_alpha_fade | 1.0~0.0 | （淡出阶段，线性） |

#### 环形线（Ring Lines — 3 层）

| 参数 | 值 | 说明 |
|------|-----|------|
| ring_count | 3 |  |
| ring_width_base | 6 | px（外层） |
| ring_width_decay | 1.5 | px（每层递减） |
| ring_color | `#aaeeff` |  |
| ring_alpha_base | 0.8 |  |
| ring_alpha_decay | 0.3 | （每层乘以 (1 - decay)） |
| ring_alpha_mult | 0.4 | 最终透明度倍数 |

#### 冰晶粒子（Crystal Partices — 24 个预计算）

| 参数 | 值 | 说明 |
|------|-----|------|
| crystal_count | 24 |  |
| angle_range | 0~2π | rad |
| dist_ratio_range | 0.65~1.05 | 比率 |
| size_range | 3~9 | px |
| phase_range | 0~2π | rad |
| speed_range | 1.2~2.5 | 旋转速度系数 |
| rotate_speed | 0.0008 | rad/ms（角度旋转） |
| breathe_freq | 0.004 | Hz（大小波动） |
| breathe_amp | 0.5 | 距离波动幅度 |
| size_breathe_freq | 0.004 | Hz（大小波动） |
| size_breathe_amp | 0.5 | 大小波动幅度 |
| alpha_range | 0.3~0.7 | 基础透明度比率 |
| layer_outer_color | `#88ddff` |  |
| layer_outer_alpha_mult | 0.3 | 透明度倍数 |
| layer_outer_size_mult | 2.2 | 大小倍数 |
| layer_mid_color | `#aaeeff` |  |
| layer_mid_alpha_mult | 0.6 | 透明度倍数 |
| layer_mid_size_mult | 1.4 | 大小倍数 |
| layer_inner_color | `#ffffff` |  |
| layer_inner_alpha_mult | 0.9 | 透明度倍数 |
| layer_inner_size_mult | 0.5 | 大小倍数 |

#### 中心光晕粒子（Center Glow — 6 个预计算）

| 参数 | 值 | 说明 |
|------|-----|------|
| glow_count | 6 |  |
| angle_range | 0~2π | rad |
| dist_ratio_range | 0.1~0.4 | 比率 |
| phase_range | 0~2π | rad |
| rotate_speed | 0.001 | rad/ms（角度旋转） |
| breathe_freq | 0.006 | Hz（大小和透明度波动） |
| breathe_amp | 0.5 | 大小和透明度波动幅度 |
| size_base | 4 | px |
| size_breathe_amp | 5 | px（大小波动幅度） |
| alpha_base | 0.25 | 基础透明度比率 |
| color | `#aaeeff` |  |

#### 填充光晕（Fill Glow）

| 参数 | 值 | 说明 |
|------|-----|------|
| fill_color | `#66ccff` |  |
| fill_alpha_base | 0.12 |  |
| fill_alpha_mult | 1.0 | 乘以 globalAlpha |

#### 拖尾粒子（Trail Particles）

| 参数 | 值 | 说明 |
|------|-----|------|
| spawn_count | 3 | 每次发射粒子数 |
| back_dist_min | 4 | px |
| back_dist_max | 12 | px |
| spread_min | 12 | px |
| spread_max | 20 | px |
| radius_min | 2.0 | px |
| radius_max | 4.0 | px |
| colors | `#e0f0ff`, `#f0f8ff` |  |
| duration_min | 120 | ms |
| duration_max | 240 | ms |

#### 命中爆发粒子（Impact Burst）

| 参数 | 值 | 说明 |
|------|-----|------|
| spark_count_min | 8 |  |
| spark_count_max | 12 |  |
| speed_min | 20 | px/s |
| speed_max | 50 | px/s |
| life_min | 100 | ms |
| life_max | 200 | ms |
| colors | `#88ddff`, `#aaeeff` |  |

---

### 4.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | 0.26 | s |
| 扩散时长 | 0.30 | s |
| 持续时长 | 0.50 | s |
| 淡出时长 | 0.15 | s |
| 总时长 | 0.95 | s |
| hit_stop 帧数 | 待定 |  |
| 震屏强度 | 0 | （无震屏） |
| 震屏时长 | 0 | s |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 环形填充色 | `#88ddff` | 冰蓝 |
| 环形线色 | `#aaeeff` | 极浅蓝 |
| 冰晶粒子外层色 | `#88ddff` | 冰蓝 |
| 冰晶粒子中层色 | `#aaeeff` | 极浅蓝 |
| 冰晶粒子内层色 | `#ffffff` | 白 |
| 中心光晕色 | `#aaeeff` | 极浅蓝 |
| 填充光晕色 | `#66ccff` | 中蓝 |
| 拖尾粒子色 | `#e0f0ff`, `#f0f8ff` | 极浅蓝+白蓝 |
| 爆发粒子色 | `#88ddff`, `#aaeeff` | 冰蓝+极浅蓝 |

---

## 5. 实现映射

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/ice_ring.tres` | 技能定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/ice_ring.tres` | 视觉定义 |
| VFX 场景 | `res://scenes/skills/vfx/ice_ring_vfx.tscn` | VFX 场景文件 |
| 投射物场景 | N/A | 冰环无投射物，使用 Graphics 绘制 |
| 脚本 | `res://scripts/skills/ice_ring.gd` | 特殊逻辑脚本（环形扩散） |

---

## 6. 验证记录

### 验证 Checklist

- [ ] 技能可正常从 SkillRegistry 加载
- [ ] 冰环从施法者位置向外扩散（半径 0 → 160px，300ms 内）
- [ ] 扩散有缓动效果（ease = 1 - (1-t)^2.5）
- [ ] 冰晶粒子正确旋转和波动
- [ ] 中心光晕粒子正常发光
- [ ] 环形线正确绘制（3 层）
- [ ] 颜色方案符合调色板约束
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 待验证 |

---

*本文档从旧项目 `six-fighter-web` 的 `IceRingBehavior.ts` 和 `ice_ring.ts` 翻译而来。*
*翻译人：AI 助手*