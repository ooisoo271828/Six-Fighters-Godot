# 命中综合表现档（Hit Juice）

Status: Draft  
Version: v0.3  
Owner: Design + Engineering  
Last Updated: 2026-03-30  
Scope: 玩家在 **命中事件** 上感知的 **视听 + 相机/时间感** 分档（`hit_juice_*`）；**非**伤害数值档、**非**判定面积档。通道矩阵、与 CSV 关系、技能侧 **仅在技能根传档位枚举**；可选与警戒区叠画策略。  
Related: `docs/design/visual-rules/values/visual-presentation-values.csv`; `docs/design/visual-rules/combat-presentation-spec.md`; `docs/design/combat-rules/skill-warning-zone-spec.md`; `docs/design/combat-rules/combat-data-table-families-v1.md`; `docs/design/combat-rules/b-series-skill-schema-v0.md`

## 1. 语义

- **Hit juice**：一次命中结算时触发的 **表现套餐** 强度与通道组合。  
- 可与 **伤害/技能稀有度** 在数据上映射，但 **不与** 伤害公式或碰撞体积 **等价**。

## 2. 四档英文 ID

| 顺序（轻 → 重） | ID |
|-----------------|-----|
| 1 | `hit_juice_light` |
| 2 | `hit_juice_standard` |
| 3 | `hit_juice_heavy` |
| 4 | `hit_juice_climax` |

## 3. 通道策略：`subset_light`

- **轻档** 少通道；**standard** 起叠加震屏、屏闪等；**更高档** 在 **同一套通道** 上通过 **CSV 调强** 时长与幅度。  
- 具体数值（秒、强度、粒子上限等）进 `visual-presentation-values.csv`（及 `six-fighter-web/public/design-values/` 镜像），代码只认档 + 读表。

## 4. 通道矩阵（逻辑开关）

| `channel_id` | `hit_juice_light` | `hit_juice_standard` | `hit_juice_heavy` | `hit_juice_climax` |
|--------------|-------------------|----------------------|-------------------|---------------------|
| `burst_strip` | on | on | on | on |
| `impact_particles` | on | on | on | on |
| `hit_stop` | **off** | on | on | on |
| `camera_shake` | off | on | on | on（**高幅、短时**，CSV） |
| `screen_flash` | off | **off** | on，`screen_flash_profile_heavy` | on，`screen_flash_profile_climax` |

### 4.1 `hit_juice_climax` 专项

- **震屏**：振幅大、持续时间短（CSV）。  
- **屏闪**：主峰值可较短，**余韵/淡出维持更久**；**余韵结束时间允许晚于震屏结束时间**（CSV 分键控制）。

## 5. 技能 → 档映射（B 系技能根只传档位；C 系持有全部定义）

- **C 系** 持有各 `hit_juice_*` 的 **完整通道与标量**；**B 系** 在 **技能根**（`SkillDef`）上 **唯一引用一个** 档位枚举，**不在** 片段或打击实例表上重复声明；**不在 B 系** 配置 `juice_*` 覆盖字段或 per-skill 覆盖表，避免双重来源。框架见 **`docs/design/combat-rules/combat-data-table-families-v1.md`** §4 与 **`docs/design/combat-rules/b-series-skill-schema-v0.md`** §4。  
- **整技能统一档**：同技能内 **任意多次命中**，**每次** 命中表现均使用 **技能根** 上声明的 `hit_juice_*`。  
- **英雄 / 敌人**：均以 **`skill_id` → 技能根** 上的档位为准；**废除** 原「按英雄技能槽位给默认 `hit_juice_*`」的规则（旧版 §5.1 表已删除）。角色、成长、单位挂载技能时 **服从** 战斗模块技能根数据。  
- **DoT 周期结算**：与某技能绑定的 tick，**默认** 使用该 **技能根** 上的 `hit_juice_*`；若需与直接命中不同强度，在 **C 系** 扩档或专题约定，**不**在 B 系堆叠标量覆盖。

### 5.1 审批

- `hit_juice_climax` 用于非 `ultimate`：**建议主策划审批**。

### 5.2 扩展档（「花活」）

- 若需 **违反常规四档** 的少数特例：在 **C 系** 增加新 ID（如 `hit_juice_special_01` 或团队约定的 **0 档 / 99 档** 命名），在 **技能根** 上像普通档一样 **仅改引用枚举**；**不**把额外通道标量塞进 B 系。

## 6. 可选：与警戒区叠画（原 B7，轻量）

- 本产品 **警戒模块非核心**（见 `skill-warning-zone-spec.md`），**不**预设硬核 ARPG 级「全局压 hit_juice」。  
- **可选**：仅在 **`skill_warn_extreme` 激活** 且与 **全屏类屏闪** 冲突明显时，对 `screen_flash` / `camera_shake` 做裁剪或降强度 — **玩测后** 用少量规则定稿即可。

## 7. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-03-30 | 初稿：四档、通道矩阵、槽位默认 |
| v0.2 | 2026-03-30 | 与 `combat-data-table-families-v1` 对齐：废除 B 系 `hit_juice_override`；B 只传档；花活 = C 系扩档 |
| v0.3 | 2026-03-30 | §5：档位 **唯一** 在技能根；整技能统一档；废除英雄槽位默认表；链 `b-series-skill-schema-v0` |
