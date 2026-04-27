# 旧文件迁移清单

> **本文档列出需要迁移到新架构（数值与视觉分离）的旧文件。**
> 新架构：数值在 CSV (`skill-values.csv`)，视觉在 `.tres` (SkillVisualDef)。

## 迁移原则

1. **不删除旧文件**：避免破坏现有功能
2. **标记状态**：在清单中标记迁移状态
3. **逐步迁移**：在实现技能时同步迁移
4. **CSV 优先**：数值以 CSV 为准

## 待迁移文件清单

### SkillDefs（包含数值字段）

| 文件 | 技能 ID | 数值已提取到 CSV | .tres 已迁移 | 状态 |
|------|---------|------------------|--------------|------|
| `skill_defs/fireball_basic.tres` | fireball_basic | ✅ | ✅ | **已完成** |
| `skill_defs/ember_basic.tres` | ember_basic | ❌ | ❌ | 待迁移 |
| `skill_defs/ironwall_basic.tres` | ironwall_basic | ❌ | ❌ | 待迁移 |
| `skill_defs/moss_basic.tres` | moss_basic | ❌ | ❌ | 待迁移 |
| `skill_defs/ember_small_a.tres` | ember_small_a | ❌ | ❌ | 待迁移 |
| `skill_defs/ironwall_small_a.tres` | ironwall_small_a | ❌ | ❌ | 待迁移 |
| `skill_defs/moss_small_a.tres` | moss_small_a | ❌ | ❌ | 待迁移 |

### SkillVisualDefs（可能包含数值字段）

| 文件 | 技能 ID | 需要迁移 | 状态 |
|------|---------|---------|------|
| `skill_visual_defs/fireball_basic.tres` | fireball_basic | ✅ 已迁移到 v2.0 | **已完成** |
| `skill_visual_defs/ember_basic.tres` | ember_basic | 待检查 | 待迁移 |
| ... | ... | ... | ... |

## 迁移步骤

### 对于 SkillDefs：

1. **提取数值到 CSV**：
   - 读取 `.tres` 文件中的数值字段（`base_damage`, `cooldown` 等）
   - 在 `skill-values.csv` 中创建/更新对应的行
   - 确保 `category` 字段匹配技能 ID

2. **从 .tres 删除数值字段**（或者保留但被 CSV 覆盖）：
   - [x] 修改 `SkillDef.gd`，添加 `load_values_from_csv()` 方法
   - [x] 添加 `load_csv_for_skill()` 静态方法
   - [x] 在 SkillRegistry 加载后自动调用

3. **测试**：
   - 确保技能在游戏中正常工作
   - 数值应该从 CSV 加载

### 对于 SkillVisualDefs：

1. **检查是否包含数值字段**：
   - 读取 `.tres` 文件
   - 检查是否有 `base_damage`, `cooldown` 等数值字段
   - 如果有，移动到 SkillDef 或 CSV

2. **确保只包含视觉参数**：
   - 粒子系统参数
   - 颜色方案
   - 动画参数
   - 速度、大小等视觉参数

## 当前优先级

1. **P0**：迁移 `fireball_basic`（第一个要实现技能）
2. **P1**：迁移其他基础技能（ember, ironwall, moss）
3. **P2**：迁移 small_a 变体

## 注意事项

- 旧的 `.tres` 文件中的数值可能与 CSV 中的数值不一致
- 需要核对并决定哪个数值是正确的（建议以 CSV 为准）
- 迁移时应该保持向后兼容（避免破坏现有功能）

---

*本文档版本：v1.0*
*最后更新：2026-04-27*
