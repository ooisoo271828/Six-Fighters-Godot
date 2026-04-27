# 技能资源目录说明

## 目录结构

```
resources/skills/
├── README.md                # 本文件
├── skill_defs/             # 技能定义（.tres）
├── skill_visual_defs/      # 技能视觉定义（.tres）
├── modifiers/              # 技能修饰符（.tres）
└── deprecated/             # 旧架构文件（待迁移）
```

## 新架构规范（v2.0+）

### 数值与视觉分离

**数值配置（CSV 表格）**：
- 文件路径：`docs/design/combat-rules/values/skill-values.csv`
- 包含：base_damage, cooldown, cast_range, timing 等所有战斗数值
- 由数值策划直接编辑

**视觉配置（.tres 文件）**：
- `SkillVisualDef.tres`：包含视觉相关参数（粒子系统、颜色、动画等）
- 不包含数值字段（base_damage, cooldown 等）

**技能定义（.tres 文件）**：
- `SkillDef.tres`：包含技能的基础配置
- **数值字段从 CSV 加载**（运行时覆盖 .tres 中的值）
- 或者，在程序化生成时从 CSV 读取数值并写入 .tres

## 迁移计划

### 步骤 1：确保 CSV 中有正确的数值
- [x] 创建 `docs/design/combat-rules/values/skill-values.csv`
- [ ] 将从旧 .tres 提取的数值填入 CSV
- [ ] 核对设计文档中的数值与 CSV 一致

### 步骤 2：修改 SkillDef.gd（支持从 CSV 加载）
- [x] 添加 `load_values_from_csv()` 方法
- [x] 添加 `load_csv_for_skill()` 静态方法
- [x] 在 SkillRegistry 加载后自动调用

### 步骤 3：迁移旧 .tres 文件
- [ ] 从旧 .tres 提取数值到 CSV
- [ ] 创建新的 .tres 文件（不包含数值字段，或者包含从 CSV 读取的数值）
- [ ] 将旧 .tres 文件移动到 `deprecated/`

### 步骤 4：更新设计文档
- [ ] 确保所有设计文档引用新的 CSV + .tres 架构
- [ ] 移除设计文档中的"战斗参数"表格（已迁移到 CSV）

## 当前状态

| 技能 ID | CSV 中有数值 | .tres 已迁移 | 设计文档已更新 |
|---------|--------------|--------------|----------------|
| fireball_basic | ✅ | ✅ | ✅ |
| missile_storm | ✅ | ❌ | ✅ |
| ghost_fire_skull | ✅ | ❌ | ✅ |
| ice_cyclone | ✅ | ❌ | ✅ |
| chain_lightning | ✅ | ❌ | ✅ |
| burning_hands | ✅ | ❌ | ✅ |
| ice_ring | ✅ | ❌ | ✅ |
| plasma_beam | ✅ | ❌ | ✅ |
| ember_basic | ❌ | ❌ | ❌ |
| ironwall_basic | ❌ | ❌ | ❌ |
| moss_basic | ❌ | ❌ | ❌ |

## 使用示例

### 程序化生成技能

```gdscript
# 1. 读取 CSV 数值
var csv_values = _load_csv_values("fireball_basic")

# 2. 创建/更新 SkillDef.tres
var skill_def = SkillDef.new()
skill_def.skill_id = "fireball_basic"
skill_def.base_damage = csv_values.base_damage  # 从 CSV 读取
# ... 其他数值

# 3. 创建 SkillVisualDef.tres
var visual_def = SkillVisualDef.new()
# ... 视觉参数（不包含数值）

# 4. 保存到 .tres 文件
ResourceSaver.save(skill_def, "res://resources/skills/skill_defs/fireball_basic.tres")
ResourceSaver.save(visual_def, "res://resources/skills/skill_visual_defs/fireball_basic.tres")
```

---

*本文档版本：v1.0*
*最后更新：2026-04-27*
