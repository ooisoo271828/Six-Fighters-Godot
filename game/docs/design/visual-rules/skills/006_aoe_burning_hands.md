# 火焰之手 — 技能设计文档

---

## 元数据

```
Status: Draft
Version: v1.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: burning_hands
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `burning_hands` |
| 显示名称 | 火焰之手 |
| 技能类型 | `aoe` 范围类（扇形扩散） |
| 伤害类型 | *见 CSV 数值表* |
| 设计优先级 | `P1` |
| 设计状态 | `草稿` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "burning_hands"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.28 秒
- **视觉效果**：
  - 施法者双手位置出现火焰聚集效果
  - 地面出现扇形警示区域（rect telegraph，对应施法方向 ±45°）
- **镜头效果**：无震屏

---

### 2.2 扇形扩散阶段

- **描述**：火焰从施法者位置向目标方向扇形扩散，持续产生火焰粒子，带有呼吸波动效果
- **扩散角度**：±45°（SPREAD_ANGLE = π/2）
- **最大半径**：120 px（MAX_RADIUS）
- **扩散时长**：350 ms（SPREAD_DURATION）
- **持续时长**：400 ms（PERSIST_DURATION）
- **总时长**：750 ms（TOTAL_DURATION）
- **视觉效果**：
  - **扇形填充区域**：
    - 使用 Graphics 实时绘制
    - 从施法者位置向目标方向扇形展开
    - 半径随时间从 0 → 120px（350ms 内）
    - 边缘有噪声扰动（noise 0.6~1.6）
    - 颜色：`#ff2200`（亮红），透明度 0.08 * alphaBase
    - alphaBase 有波动（0.65 + sin * 0.15）
  - **火焰粒子**（32 个预计算粒子）：
    - 每个粒子有固定的基础角度、距离、大小、速度、相位
    - 粒子角度在扇形范围内随机偏移（±0.25 rad）
    - 粒子距离有噪声扰动（±0.18）
    - 粒子大小有呼吸波动（size * (0.7 + breathe * 0.5)）
    - 粒子颜色：距离比率 > 0.6 为 `#ff6b35`（橙），否则 `#ff4400`（亮红）
    - 粒子透明度：alphaBase * rand(0.15, 0.35)
    - 三层绘制：
      - 外层：颜色同粒子色，透明度 * 0.4，大小 * 2.2
      - 中层：颜色同粒子色，透明度 * 0.7，大小 * 1.3
      - 内层：颜色 `#ffc88f`（浅橙），透明度 * 1.0，大小 * 0.5
  - **前沿火焰粒子**（12 个/帧）：
    - 从扇形前沿随机位置生成
    - 粒子大小：8~18 px，有呼吸波动
    - 颜色：`#ff4400`（亮红）, `#ff6b35`（橙）
    - 透明度：alphaBase * 0.2 * rand(0.5, 1.0)
    - 三层绘制（同火焰粒子）
  - **震屏效果**：
    - 每 80ms 触发一次（如果在该位置未触发过）
    - 强度 110，时长 0.0032s
- **尺寸**：扇形半径 120px，角度 ±45°

---

### 2.3 命中 / 持续伤害阶段

- **描述**：火焰覆盖区域内的敌人持续受到伤害（DOT），视觉上火焰持续燃烧
- **持续时间**：400 ms（PERSIST_DURATION）
- **视觉效果**：同「扇形扩散阶段」，但半径保持不变（120px），粒子持续发射

---

### 2.4 持续效果阶段

- **描述**：无额外持续效果（DOT 已在「持续伤害阶段」覆盖）

---

### 2.5 收尾 / 淡出

- **描述**：扇形区域和粒子自然淡出
- **淡出时间**：火焰粒子寿命 80~180 ms 后自然销毁

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] 扇形填充透明度上限：≤ 0.08（基础）
- [ ] 火焰粒子透明度上限：≤ 0.35（基础）
- [ ] 色相与敌对/友方语义锚点不冲突（使用红/橙色系）

---

## 4. 参数配置

### 4.1 粒子系统参数

#### 扇形填充区域（Fan Filarea）

| 参数 | 值 | 说明 |
|------|-----|------|
| spread_angle | 90 | °（±45°） |
| max_radius | 120 | px |
| spread_duration | 350 | ms |
| persist_duration | 400 | ms |
| total_duration | 750 | ms |
| fill_color | `#ff2200` | |
| fill_alpha_base | 0.08 | |
| alpha_wave_freq | 0.015 | Hz |
| alpha_wave_amp | 0.15 | |

#### 火焰粒子（Flame Partices — 32 个预计算）

| 参数 | 值 | 说明 |
|------|-----|------|
| particle_count | 32 | |
| base_angle_range | ±1.0 | rad（转换为扇形内角度） |
| base_dist_range | 0.05~0.9 | 比率 |
| size_range | 4~14 | px |
| speed_range | 0.8~1.6 | 速度系数 |
| phase_range | 0~2π | rad |
| breathe_freq | 0.02 | Hz（速度系数调整） |
| breathe_amp | 0.5 | 大小波动幅度 |
| color_threshold | 0.6 | 距离比率阈值 |
| color_near | `#ff6b35` | 远处（> 阈值） |
| color_far | `#ff4400` | 近处（≤ 阈值） |
| alpha_range | 0.15~0.35 | 基础透明度比率 |
| layer_outer_mult | 2.2 | 大小倍数 |
| layer_outer_alpha_mult | 0.4 | 透明度倍数 |
| layer_mid_mult | 1.3 | 大小倍数 |
| layer_mid_alpha_mult | 0.7 | 透明度倍数 |
| layer_inner_color | `#ffc88f` | |
| layer_inner_alpha_mult | 1.0 | 透明度倍数 |
| layer_inner_size_mult | 0.5 | 大小倍数 |

#### 前沿火焰粒子（Front Flame — 12 个/帧）

| 参数 | 值 | 说明 |
|------|-----|------|
| front_count_per_frame | 12 | |
| front_dist_range | 0.7~1.0 | 比率（距施法者） |
| front_size_range | 8~18 | px |
| front_breathe_freq | 0.03 | Hz |
| front_breathe_amp | 0.3 | 大小波动幅度 |
| front_color | `#ff4400`, `#ff6b35` | |
| front_alpha_base | 0.2 | 基础透明度比率 |
| front_alpha_mult_range | 0.5~1.0 |  |
| front_layer_outer_mult | 1.0 | 大小倍数（同粒子） |
| front_layer_outer_alpha_mult | 0.4 | 透明度倍数 |
| front_layer_mid_mult | 0.8 | 大小倍数 |
| front_layer_mid_alpha_mult | 0.7 | 透明度倍数 |
| front_layer_inner_color | `#ffc88f` |  |
| front_layer_inner_alpha_mult | 1.0 | 透明度倍数 |
| front_layer_inner_size_mult | 0.5 | 大小倍数 |

#### 拖尾粒子（Trail Particles）

| 参数 | 值 | 说明 |
|------|-----|------|
| spawn_count | 4 | 每次发射粒子数 |
| back_dist_min | 6 | px |
| back_dist_max | 20 | px |
| spread_min | 12 | px |
| spread_max | 24 | px |
| radius_min | 4 | px |
| radius_max | 14 | px |
| colors | `#ff6b35`, `#ff4400`, `#ffc88f` | |
| duration_min | 80 | ms |
| duration_max | 180 | ms |

#### 命中爆发粒子（Impact Burst）

| 参数 | 值 | 说明 |
|------|-----|------|
| spark_count_min | 6 |  |
| spark_count_max | 10 |  |
| speed_min | 16 | px/s |
| speed_max | 40 | px/s |
| life_min | 80 | ms |
| life_max | 160 | ms |
| colors | `#ff6b35`, `#ff4400` |  |

---

### 4.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | 0.28 | s |
| 扩散时长 | 0.35 | s |
| 持续时长 | 0.40 | s |
| 总时长 | 0.75 | s |
| hit_stop 帧数 | 待定 |  |
| 震屏强度 | 110 |  |
| 震屏时长 | 0.0032 | s |
| 震屏触发间隔 | 80 | ms |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 扇形填充色 | `#ff2200` | 亮红 |
| 火焰粒子近色 | `#ff4400` | 亮红 |
| 火焰粒子远色 | `#ff6b35` | 橙 |
| 火焰粒子高光色 | `#ffc88f` | 浅橙 |
| 前沿火焰色 | `#ff4400`, `#ff6b35` | 亮红+橙 |
| 拖尾粒子色 | `#ff6b35`, `#ff4400`, `#ffc88f` | 橙+亮红+浅橙 |
| 爆发粒子色 | `#ff6b35`, `#ff4400` | 橙+亮红 |

---

## 5. 实现映射

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/burning_hands.tres` | 技能定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/burning_hands.tres` | 视觉定义 |
| VFX 场景 | `res://scenes/skills/vfx/burning_hands_vfx.tscn` | VFX 场景文件 |
| 投射物场景 | N/A | 火焰之手无投射物，使用 Graphics 绘制 |
| 脚本 | `res://scripts/skills/burning_hands.gd` | 特殊逻辑脚本（扇形扩散） |

---

## 6. 验证记录

### 验证 Checklist

- [ ] 技能可正常从 SkillRegistry 加载
- [ ] 火焰从施法者位置向目标方向扇形扩散（±45°）
- [ ] 扩散半径正确扩展到 120px（350ms 内）
- [ ] 火焰粒子有呼吸波动效果
- [ ] 前沿火焰粒子正常生成
- [ ] 震屏效果每 80ms 触发一次
- [ ] 颜色方案符合调色板约束
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 待验证 |

---

*本文档从旧项目 `six-fighter-web` 的 `BurningHandsBehavior.ts` 和 `burning_hands.ts` 翻译而来。*
*翻译人：AI 助手*