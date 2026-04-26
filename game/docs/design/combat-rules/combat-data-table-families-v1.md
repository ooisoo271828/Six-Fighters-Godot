# 战斗数据表系框架（A / B / C / D）

Status: Draft  
Version: v0.2  
Owner: Design + Engineering  
Last Updated: 2026-03-30  
Scope: 在 **`docs/` 为权威** 的前提下，约定战斗相关数据的 **表系划分** 与 **接口边界**；**不**绑定当前 `six-fighter-web` 历史实现。实现可后续整体重构，以本文与关联 spec 为准。  
Related: [`combat-attributes-resolution.md`](combat-attributes-resolution.md); [`combat-core-decision-freeze-v1.md`](combat-core-decision-freeze-v1.md); [`skill-warning-zone-spec.md`](skill-warning-zone-spec.md); [`hit-feedback-juice-spec.md`](../visual-rules/hit-feedback-juice-spec.md); [`b-series-skill-schema-v0.md`](b-series-skill-schema-v0.md); [`web-client-architecture.md`](../../tech/architecture/web-client-architecture.md) §4

## 1. 总览

| 表系 | 职责（摘要） |
|------|----------------|
| **A** | 单位战斗属性：施法/受击前可用的数值面（基础、成长、装备、Buff 等 **多源表 + 运行时合成**）。技能 **不拥有** 这些数，只 **读取** 当前单位快照。 |
| **B** | 技能定义：与 **播放单位解耦**；任意单位只要挂上技能配置即可释放同一套逻辑。含多段打击、时间轴、windup/命中几何引用等（**可多张表、一组表**，统称 B 系）。对象层级与字段归属见 [`b-series-skill-schema-v0.md`](b-series-skill-schema-v0.md)。 |
| **C** | 命中反馈范式：`hit_juice_*` 各档的通道组合与 **全局** 标量（如 `visual-presentation-values.csv`）。 |
| **D** | 战斗底层机制常量：命中圆桌、暴击/元素形状、DOT 间隔等 **与具体单位、具体技能无关** 的全局参数（如 `combat-attributes-resolution-values.csv` 所服务的一层）。 |

**原则**：A/B/C/D **不混表**；运行时按约定 **彼此调用** 即可。

## 2. 表系 A（单位属性）

- **结构**：**不**强制单张总视图；采用 **多源表 + 运行时合成规则**（加算/乘算桶、上限、冲突处理）为推荐方向。  
- **输出**：进入技能实例与结算管线前，得到 **施法者/受击者属性快照**（攻击、防御、命中相关通道、暴击、元素抗等）。  
- **与 B 的关系**：技能表提供 **系数/标签**；与 A 合成后得到进入 `AttackInstance` / resolution 的 **`baseDamage` 等**，细节在 **`combat-attributes-resolution.md`** 与后续技能 schema 中落档。

## 3. 表系 B（技能与打击实例）

- **解耦**：**不存在专属技能**；技能配置与单位解耦，由关卡/角色/怪物配置 **挂载** `skill_id`。表现错位由 **美术与策划配置** 负责，**不**由本战斗机制表系承担。  
- **层级**：一个技能可含 **多段、多打击实例**（时间轴）；**顺序与间隔必须可配置**，支持反复调参，**不**使用少量写死模板替代。  
- **几何与 windup**：**命中判定几何** 与 **windup 警戒形状** 在数据上 **分列配置**（`hit` 在打击实例、`windup` 在时间轴片段），**可** 指向同一 `geometry_id`，也 **允许** 不一致；是否显示某段的 windup 由该段开关与 `skill_warn_tier` 等控制，见 [`skill-warning-zone-spec.md`](skill-warning-zone-spec.md) 与 [`b-series-skill-schema-v0.md`](b-series-skill-schema-v0.md) §3。  
- **目标选取**（技能片内）：缺省影响范围内 **所有合法单位**；可配置 **`max_targets`**；选取规则可扩展，初版包括：  
  - 范围内 **均匀随机**  
  - 相对释放者 **最近** / **最远**  
  - **最低血量** / **最高血量**  
  - **最高战力** / **最低战力**（战力分为后续增加的 **综合强度估分**）  
- **表拆分**：允许 **技能根 / 时间轴片段 / 打击实例 / 几何库** 等多张表；层级与语义见 [`b-series-skill-schema-v0.md`](b-series-skill-schema-v0.md)；具体 CSV 文件名与最小列集在实现迭代中补全。

## 4. 表系 C（命中反馈 / `hit_juice_*`）

- **全部** 反馈套餐定义在 **C**（各档通道开关 + 关联全局标量）。  
- **B 系** 对命中反馈 **只传递一个档位参数**（`hit_juice_light` … `hit_juice_climax` 等 **枚举引用**），**在技能根上唯一声明**；**不在 B 系表内** 增加 `juice_*` 覆盖字段或双重覆盖。详见 [`b-series-skill-schema-v0.md`](b-series-skill-schema-v0.md) §4 与 [`hit-feedback-juice-spec.md`](../visual-rules/hit-feedback-juice-spec.md)。  
- **例外/花活**：若在少数技能上需要 **违反常规四档** 的表现，在 **C 系中新增扩展档**（如新 ID `hit_juice_special_*`），由该技能在 B 中 **引用该档**；**不**在 B 中堆叠 C 的内容。详见 [`hit-feedback-juice-spec.md`](../visual-rules/hit-feedback-juice-spec.md) §5。

## 5. 表系 D（底层机制常量）

- **内容**：与 **freeze、命中圆桌、暴击曲线、元素/DOT 默认间隔** 等相关的 **全局** 参数；与 A/B/C **分列管理**，细节可 **后续专题会** 与实现迭代逐步完善。  
- **现状锚点**：[`combat-attributes-resolution-values.csv`](values/combat-attributes-resolution-values.csv) 与 [`combat-attributes-resolution.md`](combat-attributes-resolution.md) 描述 resolution 管道形状；[`combat-core-*-values.csv`](values/) 承载部分 freeze 对齐 token 与时长目标。D 系 **不** 被关卡波次、刷怪配置占用。

## 6. 显式排除（本场边界）

- **关卡与遭遇**（波次、刷怪、副本结构）：属 **玩法/关卡** 议题，**不**纳入本战斗数据表系；仅在关卡侧 **引用** 单位与技能 id。  
- **「仅装饰、不参与命中」的地面提示** 与真实伤害判定的区分：若需要，**另开专题** 用具体用例对齐；未定论前不写入本框架的必选项。

## 7. 与历史「怪物技能双表」叙述的关系

早期讨论中的 **`monster_skill_combat` + `monster_skill_presentation`**（`skill_id` 关联）可视为 **B 系在落地初期的一种可能切分**；当前以 **§3 整体 B 系** 为准，具体几张表、是否仍保留上述命名，由后续 schema 定稿。工程索引见 [`web-client-architecture.md`](../../tech/architecture/web-client-architecture.md) §4。

## 8. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-03-30 | 初稿：A/B/C/D 划分、B↔C 接口、目标选取初版、与关卡/装饰专题边界 |
| v0.2 | 2026-03-30 | §3：windup/命中几何分列、链 `b-series-skill-schema-v0`；§4：juice 在技能根唯一声明 |
