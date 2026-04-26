# 战斗方案讨论注册表：暂缓工程项 + 拉高视角议题

Status: Active registry  
Version: v0.1.2  
Owner: Design + Engineering  
Last Updated: 2026-03-30  
Scope: **不**替代正式 spec；用于 **冻结**「尚未原子级定稿、但实现前必须掰扯清」的工程问题清单，并 **索引**「更值得在更高一层先对齐」的方案话题。适合在 **专门会议** 中逐条消化，**不必** 在日常短周期内全部定死。

Related: [`b-series-skill-schema-v0.md`](b-series-skill-schema-v0.md); [`combat-data-table-families-v1.md`](combat-data-table-families-v1.md); [`continued-discussion-handoff-2026-03-30.md`](../../continued-discussion-handoff-2026-03-30.md)

---

## 1. 使用说明（冻结与提醒）

- **本表 §2** 所列，为 **工程落地前必须收敛** 的细节；**当前阶段** 刻意 **不** 在文档里原子级定稿，避免挤占「架构与产品方向」的讨论带宽。  
- **回到本表时**：建议 **单独开会**，按条目勾选；定案后 **更新对应 spec / values / ADR**，并在本表或修订记录中 **打勾或归档**。  
- **权威 spec** 仍以 `docs/` 各独立文档为准；本文件是 **索引 + 备忘**，不是数据源。

---

## 2. 暂缓工程项（实现前需开会定案）

| ID | 主题 | 为何重要 | 权威入口 / 待落点 |
|----|------|----------|-------------------|
| E1 | **B 系 CSV 最小列集与文件名** | 管线与工具依赖稳定列名 | [`b-series-skill-schema-v0.md`](b-series-skill-schema-v0.md)；[`values/`](values/) 下待建；[`web-client-architecture.md`](../../tech/architecture/web-client-architecture.md) §4 镜像 |
| E2 | **`targeting` 规则枚举与缺省** | AI、结算、表现共用同一词汇 | [`combat-data-table-families-v1.md`](combat-data-table-families-v1.md) §3；与 `max_targets` 同表或邻表 |
| E3 | **几何库：`geometry_id`、形状参数、坐标系 / 锚点** | 程序、美术、警戒片一致 | [`skill-warning-zone-spec.md`](skill-warning-zone-spec.md) §2.3；独立 `b-geometry-*` 或等价 |
| E4 | **策划 1–4 档 ↔ `none` / `basic` / `extreme` 正式对照** | 口头档与工程枚举对齐 | [`skill-warning-zone-spec.md`](skill-warning-zone-spec.md) 或单独对照表 |
| E5 | **`delivery_kind` 与投射物 taxonomy 在 B 表的对接** | 近战 / 投射物 / beam 共表 | [`projectile-v1-taxonomy.md`](projectile-v1-taxonomy.md) |
| E6 | **段首条 Strike → 段 windup 的缺省工具规则** | 减少手填、允许分叉 | [`b-series-skill-schema-v0.md`](b-series-skill-schema-v0.md) §3 |
| E7 | **节点验证样例技能行**（可选） | 与 `six-fighter-web` 节奏同步 | [`play-rules/values/`](../play-rules/values/)、`node-validation` 相关 |

---

## 3. 拉高两层（优先方案讨论方向，非原子工程）

以下 **不** 依赖 §2 已闭合；适合在 **产品 / 里程碑** 高度先对齐，再决定 §2 的投入顺序。

1. **验证路径与里程碑**：当前阶段优先证明什么——**节点可玩**、**竖切战斗闭环**，还是 **技能管线工具先行**？它决定 §2 里哪些项「必须下个月」、哪些可延后。  
2. **内容生产链路**：谁对 **表 → 客户端** 负责；何时需要 **工具**（校验、缺省填充、首条 Strike→windup） vs 手工；与 **美术/策划 headcount** 的匹配。  
3. **战斗与成长 / 商业化交接**：[`combat-attributes-resolution.md`](combat-attributes-resolution.md) 与 **装备、养成、数值投放** 的 **接口面** 是否已满足「产品想测的付费/留存假设」；**不必** 一次展开，但要 **有意识** 选 **接口** 与 **刻意延后** 的部分。  
4. **敌人、关卡、AI 与 B 系边界**：表系已 **排除** 波次与刷怪；**玩法层** 何时需要 **怪物技能库 + 关卡** 的联合方案，避免战斗 spec **写满** 却 **无内容喂入**。  
5. **可读性与视觉预算**（[`product-combat-positioning.md`](../other/product-combat-positioning.md)、[`node-validation` 计划](../visual-rules/node-validation-visual-upgrade-follow-up-work-plan.md)）：**全局** 上「同屏信息量」与 **技能复杂度** 的上限——避免 B 系能力无限扩张导致 **读不过来**。  
6. **第一期可玩内容的裁剪原则**：投射物九类、多段技能、多 Strike——**哪些** 必须进 **首版** 验证，**哪些** 明确 **二期**，减少并行未定工程面。  
7. **`docs/` 与 client 同步策略**：大重构前如何保证 **不双轨失控**（已有 `docs` 优先原则；若需 **阶段性冻结分支**，可 ADR 级说明）。

---

## 4. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-03-30 | 初稿：§2 工程暂缓项、§3 拉高视角议题；与 handoff 交叉索引 |
| v0.1.1 | 2026-03-30 | handoff 增加 **§5 会话收束快照**（新会话冷启动）；registry 与此同步为上下文备份锚点 |
| v0.1.2 | 2026-03-30 | Related：handoff 迁至 **`docs/` 根目录** |
