# {技能名称} — 技能设计文档

> **使用前复制本模板，按命名规范重命名文件，再填写内容。**
> **重要**：本模板遵循「数值与视觉分离」架构，数值参数在 CSV 表格中，视觉参数在 .tres 中。

---

## 元数据

```
Status: Draft / Implemented / Verified / Deprecated
Version: v0.1
Owner: Art + Design
Last Updated: YYYY-MM-DD
Skill ID: {skill_id}
Related: docs/design/visual-rules/pixel-art-visual-bible.md
         docs/design/combat-rules/values/skill-values.csv（数值配置）
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `{skill_id}` |
| 显示名称 | `{显示名称}` |
| 技能类型 | `proj` / `aoe` / `dot` / `buff` / `debuff` / `summon` / `dash` |
| 伤害类型 | *见 CSV 数值表* |
| 设计优先级 | `P0`(先做) / `P1`(正常) / `P2`(后做) |
| 设计状态 | `草稿` / `待实现` / `已实现` / `已验证` |
| 目标定位 | 玩家初期技能 / 进阶技能 / Boss技能 / 等 |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "{skill_id}"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

> 玩家按下技能键 → 技能实际释放之间的视觉反馈

- **描述**：
- **持续时间**：`{ }` 秒
- **视觉效果**：
  - 施法者身上效果：
  - 地面提示（Telegraph）：
- **音效**（可选）：
- **镜头效果**：是否震屏 / 速度线 / 等

---

### 2.2 发射 / 飞行阶段（仅发射类技能填写）

- **描述**：
- **飞行速度**：`{ }` px/s
- **飞行轨迹**：直线 / 抛物线 / 曲线路径（CurvedPath）
- **视觉效果**：
  - 弹道主体：
  - 拖尾粒子：
  - 轨迹残留：
- **尺寸**：`{ }` px（基准大小）

---

### 2.3 命中 / 爆发阶段

- **描述**：
- **爆发半径**：`{ }` px（范围技能填写）
- **视觉效果**：
  - 核心爆发：
  - 散射粒子：
  - 光效 / 闪光：
  - 地面残留：
- **持续时间**：`{ }` 秒
- **颜色方案**：

---

### 2.4 持续效果阶段（仅持续伤害/增益类填写）

- **描述**：
- **持续时间**：`{ }` 秒
- **视觉效果**：
  - 区域可视化：
  - 脉冲 / 呼吸效果：
  - 粒子持续生成：

---

### 2.5 收尾 / 淡出

- **描述**：
- **淡出时间**：`{ }` 秒
- **视觉效果**：

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [ ] 不遮挡敌方警戒范围 telegraph
- [ ] 不遮挡玩家单位轮廓
- [ ] 爆发效果持续时间 ≤ `{ }` 秒（避免遮挡战场）
- [ ] _additive_ 粒子透明度上限：`{ }%`
- [ ] 色相与敌对/友方语义锚点不冲突

---

## 4. 参数配置

> 本节区分**数值参数**（在 CSV 中）和**视觉参数**（在 .tres 中）。
> - 数值参数：由程序化生成填充到 CSV 表格
> - 视觉参数：由程序化生成填充到 .tres 文件

### 4.1 数值参数（在 CSV 中）

> 这些参数在 `docs/design/combat-rules/values/skill-values.csv` 中配置

| 参数类别 | 参数名 | 说明 |
|---------|--------|------|
| damage | base_damage | 基础伤害 |
| damage | damage_type | 伤害类型（elemental_fire, physical, etc.） |
| cooldown | cooldown | 冷却时间（秒） |
| range | cast_range | 施法距离（像素） |
| timing | cast_time | 施法时间（秒） |
| timing | telegraph_ms | 预警时长（毫秒） |
| timing | travel_ms | 飞行/持续时长（毫秒） |
| impact | impact_level | 命中等级（weak/medium/strong） |
| telegraph | telegraph_shape | 预警形状（rect/circle） |
| behavior | effect_type | 效果类型（emit_projectile/area_damage/etc.） |
| behavior | * | 其他行为参数（projectile_count, max_bounces 等） |

**生成方式**：
- AI 助手根据设计文档，在 CSV 中创建/更新 `category == "{skill_id}"` 的行
- 数值策划可以直接编辑 CSV

---

### 4.2 视觉参数（在 .tres 中）

> 这些参数在 `SkillVisualDef_{skill_id}.tres` 中配置

#### 4.2.1 粒子系统参数

**发射阶段粒子**（如有）：

| 参数 | 值 | 说明 |
|------|-----|------|
| amount | `{ }` | 最大粒子数 |
| lifetime | `{ }` s | 粒子生命周期 |
| direction | `(Vector3)` | 发射方向 |
| spread | `{ }` ° | 扩散角度 |
| initial_velocity_min | `{ }` | 初速度最小值 |
| initial_velocity_max | `{ }` | 初速度最大值 |
| scale_min | `{ }` | 初始缩放最小值 |
| scale_max | `{ }` | 初始缩放最大值 |
| color_gradient | `{ }` | 颜色渐变描述 |

**爆发阶段粒子**：

| 参数 | 值 | 说明 |
|------|-----|------|
| amount | `{ }` | |
| lifetime | `{ }` s | |
| explosiveness | `{ }` | 0=顺序发射, 1=同时爆发 |
| color_gradient | `{ }` | |
| scale_curve | `{ }` | 大小变化曲线 |

#### 4.2.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | `{ }` s | |
| 命中动画时长 | `{ }` s | |
| hit_stop 帧数 | `{ }` 帧 | 命中时停帧 |
| 震屏强度 | `{ }` | |
| 震屏时长 | `{ }` s | |

#### 4.2.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 主体色 | `#` | |
| 高光色 | `#` | |
| 暗部色 | `#` | |
| 爆发核心色 | `#` | |

---

## 5. 实现映射

> 填写实现过程中生成的资源路径，方便后续查找和修改。

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| 数值配置 | `docs/design/combat-rules/values/skill-values.csv` | 技能数值（CSV 表格） |
| SkillDef | `res://skills/defs/{skill_id}.tres` | 技能定义（可能引用 CSV） |
| SkillVisualDef | `res://skills/visual/{skill_id}_vfx.tres` | 视觉定义 |
| VFX 场景 | `res://scenes/skills/vfx/{skill_id}_vfx.tscn` | VFX 场景文件 |
| 粒子材质 | `res://skills/materials/{skill_id}_particle.tres` | 粒子材质（如有） |
| 脚本 | `res://scripts/skills/{skill_id}.gd` | 特殊逻辑脚本（如有） |

> **注意**：SkillDef 中的数值参数（base_damage, cooldown 等）应该从 CSV 加载，而不是硬编码在 .tres 中。

---

## 6. 验证记录

> 在 `skill_demo` 场景中验证，记录每次迭代的结果。

### 验证 Checklist

- [ ] 技能可正常从 SkillRegistry 加载
- [ ] 施法前摇视觉符合设计
- [ ] 飞行/爆发效果符合设计
- [ ] 颜色方案符合调色板约束
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| | v0.1 | 创建文档 | |
| | | | |

---

*本模板基于项目视觉规范 `pixel-art-visual-bible.md` 制定。*
*在 VibeCoding 工作流中，本文档是 AI 助手生成技能实现的首要输入。*
