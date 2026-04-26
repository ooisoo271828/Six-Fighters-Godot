# B 系技能对象模型与 Schema（v0）

Status: Draft  
Version: v0.1  
Owner: Design + Engineering  
Last Updated: 2026-03-30  
Scope: 表系 **B**（技能与打击实例）的 **对象层级、外键语义与字段归属**；与 [`combat-data-table-families-v1.md`](combat-data-table-families-v1.md) 一致，**不**绑定 `six-fighter-web` 当前实现细节。具体 CSV 文件名与最小列集可在后续迭代补行。  
Related: [`combat-data-table-families-v1.md`](combat-data-table-families-v1.md); [`skill-warning-zone-spec.md`](skill-warning-zone-spec.md); [`hit-feedback-juice-spec.md`](../visual-rules/hit-feedback-juice-spec.md); [`combat-attributes-resolution.md`](combat-attributes-resolution.md); **暂缓工程项与拉高视角议题** — [`combat-design-discussion-registry.md`](combat-design-discussion-registry.md)

## 1. 模块权威关系

- **战斗数据表系**（本文与 `combat-data-table-families-v1`）为 **底层权威**。  
- 英雄、成长、单位挂载 **`skill_id`** 时 **服从** 已定义的 B 系字段与枚举；**不**用角色/成长侧规则反向覆盖战斗模块中的技能语义（如 `hit_juice_*`、CD、能量、几何引用）。

## 2. 三层对象

| 层级 | 对象（工作名） | 职责摘要 |
|------|----------------|----------|
| L1 | **技能根** `SkillDef` | 全局 `skill_id`；**整技能唯一** 的 `hit_juice_*` 档位引用；**技能 CD**；**能量消耗**；展示名/标签等。与 **施法单位解耦**。 |
| L2 | **时间轴片段** `SkillTimelineSegment` | **顺序与间隔**；本段 **windup / telegraph** 用几何（**仅在本层出现**）；**段级 windup 是否显示**（策划可改为关闭，开发期建议缺省非空）；**警戒** `skill_warn_tier`、片内 sweep 时长等（见 `skill-warning-zone-spec`）。**一段对应一个 windup**（语义上）。 |
| L3 | **打击实例** `StrikeInstance` | 一次结算单元；**命中判定用几何**（**仅在每条 Strike 上出现**）；**目标选取**（`max_targets` + 规则）；伤害/状态等与 resolution 对齐的系数或标签。一段内可有 **多次打击**（如流星雨多落点）。 |

## 3. 几何：`windup` 与 `hit` 分列

- **工程上**，**windup（警戒/读条提示）** 与 **命中/结算判定** 为 **两套独立配置**。  
- **列挂载（已定）**：  
  - **`windup_geometry_id`（名称可最终统一）**：只在 **片段表（L2）** 上出现。  
  - **`hit_geometry_id`（名称可最终统一）**：在 **每条 `StrikeInstance`（L3）** 上出现。  
- 二者可 **复用同一** `geometry_id` 指向几何库；也 **允许** 段 windup 与各 Strike 命中 **不一致**。  
- **工作流**：缺省可用 **本段首条 Strike 的命中几何** 去 **凑** 段 windup，便于跑通；后续策划可把段 windup **单独改数**。  
- **几何库**（形状类型、参数、坐标系）单独表或独立 CSV；细节可与 `skill-warning-zone-spec` §2.3 形状枚举对齐。

## 4. `hit_juice_*`（与 C 系接口）

- **C 系** 持有各档 **通道与标量**（如 `visual-presentation-values.csv`）。  
- **B 系** 仅在 **技能根** 上 **引用一个** `hit_juice_*` 枚举；**不在** 片段或 Strike 上重复声明。  
- **现阶段规则**：**整技能统一档**；同技能内 **任意多次命中**（含多段、多 Strike），**每次命中表现** 均使用该技能根上的档位。  
- **废除**：按 **英雄技能槽位** 给默认 `hit_juice_*` 的规则（旧见 `hit-feedback-juice-spec` 历史 §5.1）；以 **技能根唯一数据源** 为准。

## 5. 与警戒 spec 的衔接

- 地面警戒片、片内 sweep 使用 **段表上的 windup 几何** + `skill_warn_tier` 等（见 [`skill-warning-zone-spec.md`](skill-warning-zone-spec.md)）。  
- **命中几何** 与 **windup 几何** **不**再要求强制同一参数行；呈现上仍可通过配置使二者 **看起来一致**。

## 6. 表拆分与 CSV（方向性）

- 允许 **`skill_id` 根表 / 片段表 / Strike 表 / 几何库** 等多张表；文件名与最小列集在实现落地时与 [`combat-data-table-families-v1.md`](combat-data-table-families-v1.md) §3 一并填入 `docs/design/combat-rules/values/`（及 web 镜像目录）。  
- 历史 **`monster_skill_combat` + `monster_skill_presentation`** 可视为工程上的 **早期切分**；逻辑上仍属 B 系子集。

## 7. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-03-30 | 初稿：L1/L2/L3、windup 仅段/命中仅 Strike、juice 仅技能根、与 A/B/C 边界 |
