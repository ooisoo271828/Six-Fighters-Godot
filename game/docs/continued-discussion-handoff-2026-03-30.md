# 续聊交接：方案讨论进度存档（2026-03-30）

Status: Working snapshot  
Purpose: 新 Cursor 会话续聊时先读本文件或 `@docs/continued-discussion-handoff-2026-03-30.md` 恢复上下文。  
Related: [`plans/mvp-phase-design-meeting-track.md`](plans/mvp-phase-design-meeting-track.md)（**MVP 分场方案备份 v0.1.0**）；[`design/visual-rules/discussion-handoff-2026-03-29-projectiles-hit-juice-b7.md`](design/visual-rules/discussion-handoff-2026-03-29-projectiles-hit-juice-b7.md); [`design/combat-rules/skill-warning-zone-spec.md`](design/combat-rules/skill-warning-zone-spec.md); [`design/visual-rules/combat-presentation-spec.md`](design/visual-rules/combat-presentation-spec.md); [`design/combat-rules/projectile-v1-taxonomy.md`](design/combat-rules/projectile-v1-taxonomy.md); [`design/combat-rules/combat-data-table-families-v1.md`](design/combat-rules/combat-data-table-families-v1.md); [`design/combat-rules/b-series-skill-schema-v0.md`](design/combat-rules/b-series-skill-schema-v0.md); [`design/combat-rules/combat-design-discussion-registry.md`](design/combat-rules/combat-design-discussion-registry.md)

---

## 1. 已完成的讨论轮次（摘要）

### 第一场（横向：可读性 × windup × B7）

- **策划四档（口头）与呈现**（已确认）：  
  - **1 档**：不用 windup（无地面警戒片）。  
  - **2、3 档**：**同一套常规 windup**（对应工程侧可映射为同一类 `skill_warn_basic` 素材，两档差异在策划配置其他维度，**不**要求两套常规底图）。  
  - **4 档**：**致命 windup**（对应 `skill_warn_extreme` 那套更红、更华丽的底图 + 片内 sweep）。  
- **B7（警戒 × hit juice 叠画）**：**方案阶段不做避让**；各通道按各自规则播；有可玩版后再看是否微调（判断需要调的概率低）。  
- **待后续落档**：将「策划 1–4 档」与 **`none` / `basic` / `extreme`** 的**正式对照句**写进 `skill-warning-zone-spec` 或单独对照表。

### 第二场（横向：投射物 × 分层 × 管线）

- **windup 片 vs Mid VFX**（已确认并**已落文档**）：常态策划趋同；叠画时 **Mid VFX 在 telegraph 之上**；**技能特效优先于 windup 片**。  
- **V1 九类投射物**：排期以当期共识为准（taxonomy §4）。

### 第三场（数据契约横向）— 已落档

- **`docs/`** 相对 **`six-fighter-web/`** 的 **更高序列**；冲突以 docs 为准并修订 web 镜像。  
- 历史「怪物技能 **combat / presentation 双表 + `skill_id`**」并入 **第四场扩展后的 B 系框架**（见 §2）。

### 第四场（战斗数据表系 A/B/C/D）— 2026-03-30 已落档

- **表系 D**：全局底层机制常量（命中圆桌、元素形状等），**与 A/B/C 分列**；细节可后续专题完善。  
- **表系 A**：单位属性；**多源表 + 运行时合成**（不强制单张总视图）。  
- **表系 B**：技能与打击实例；**与单位解耦**、无专属技能；**时间轴顺序与间隔可充分配置**；**命中与 windup 几何** 在 v0.1 曾写「同一份」— **第五场已修订为分列**（见 `b-series-skill-schema-v0`）。**目标选取**：`max_targets` + 规则（随机/近/远/血线/战力等，战力分后补）。  
- **表系 C**：**全部** `hit_juice` 定义；**B 在技能根传档位枚举**；花活 = **C 系扩档**，**废除** 技能表上的 `hit_juice_override` 思路（与旧讨论快照不一致处以 **`hit-feedback-juice-spec` v0.3** 为准）。  
- **排除**：关卡波次/刷怪归 **玩法/关卡** 议题；**装饰地面判定 vs 真实命中** 另开专题。

### 第五场（B 系技能对象模型与 schema）— 2026-03-30 已落档

- **技能根（L1）**：`hit_juice_*` **唯一**、**技能 CD**、**能量消耗**；**整技能统一 juice 档**，每次命中表现读技能根。  
- **时间轴片段（L2）**：**windup 几何仅段表**；段级 windup 是否显示、`skill_warn_tier`、片内 sweep 等（与 `skill-warning-zone-spec` 衔接）。  
- **打击实例（L3）**：**命中几何仅每条 Strike**；一段可多次打击（如流星雨）。  
- **windup 与命中**：数据上 **分列**（可同 `geometry_id`、可不一致）；废除「命中与 windup 必为同一份定义」的旧表述。  
- **废除** `hit-feedback-juice-spec` 中 **英雄槽位默认 `hit_juice_*` 表**；战斗模块为底层权威。  
- **权威文件**：[`design/combat-rules/b-series-skill-schema-v0.md`](design/combat-rules/b-series-skill-schema-v0.md) **v0.1**；[`design/combat-rules/combat-data-table-families-v1.md`](design/combat-rules/combat-data-table-families-v1.md) **v0.2**；[`design/combat-rules/skill-warning-zone-spec.md`](design/combat-rules/skill-warning-zone-spec.md) **v0.6**；[`design/visual-rules/hit-feedback-juice-spec.md`](design/visual-rules/hit-feedback-juice-spec.md) **v0.3**；[`PROJECT-RULES.md`](PROJECT-RULES.md) **v0.6**（索引链至 B 系 schema + 讨论注册表 + handoff 流程）。

---

## 2. 权威落档文件（本轮）

| 文件 | 版本/要点 |
|------|-----------|
| [`design/combat-rules/b-series-skill-schema-v0.md`](design/combat-rules/b-series-skill-schema-v0.md) | **v0.1**：L1/L2/L3、windup 仅段/命中仅 Strike、juice 仅技能根 |
| [`design/combat-rules/combat-data-table-families-v1.md`](design/combat-rules/combat-data-table-families-v1.md) | **v0.2**：§3 windup/命中分列；§4 juice 在技能根唯一；链 B 系 schema |
| [`design/visual-rules/hit-feedback-juice-spec.md`](design/visual-rules/hit-feedback-juice-spec.md) | **v0.3**：技能根唯一档、整技能统一档；废除英雄槽位默认表 |
| [`design/combat-rules/skill-warning-zone-spec.md`](design/combat-rules/skill-warning-zone-spec.md) | **v0.6**：§5 与 B 系分列模型对齐（windup 片段 / 命中 Strike） |
| [`tech/architecture/web-client-architecture.md`](tech/architecture/web-client-architecture.md) | **v0.4**：指向 `combat-data-table-families-v1`，双表叙述降为 B 系可能切分 |
| [`PROJECT-RULES.md`](PROJECT-RULES.md) | **v0.6**：索引、**跨会话 handoff 流程**、B 系 schema + **讨论注册表** |
| [`design/combat-rules/combat-design-discussion-registry.md`](design/combat-rules/combat-design-discussion-registry.md) | **v0.1**：§2 实现前需开会项；§3 优先方案讨论方向 |

**已废止表述**：`hit_juice_override`（技能表侧覆盖 C）；**英雄技能槽位默认 `hit_juice_*`**（代之以 **技能根唯一声明**）。代之以 **C 系扩档 + B 技能根引用枚举**。

---

## 3. 下一场建议议程

**MVP 阶段（Hub→单关→成长）** 的 **设计决策基线、待敲定总表、含美术在内的 11 场分场顺序** 已备份至 [`plans/mvp-phase-design-meeting-track.md`](plans/mvp-phase-design-meeting-track.md) **v0.1.0**；进入开发前按该顺序开会落档后再开工。

**原子级工程项（CSV、targeting、几何锚点等）** 已 **汇总到** [`design/combat-rules/combat-design-discussion-registry.md`](design/combat-rules/combat-design-discussion-registry.md) **§2**，**刻意不在此逐条推进**；待合适时机 **专门开会** 勾选并回写 spec。

**拉高视角**（更值得优先讨论的方向）见 **同一文件 §3**（验证路径、内容管线、战斗×成长接口、关卡与敌人、可读性预算、首版裁剪、`docs`/client 同步等）。

若续聊 **仍从 B 系工程细节切入**，可提示先读 **registry**：`@docs/design/combat-rules/combat-design-discussion-registry.md`。

---

## 4. 新会话建议提示词（简版，可复制）

```text
请先阅读 @docs/design/combat-rules/combat-design-discussion-registry.md ，从「§3 拉高视角议题」或「§2 暂缓工程项」中用户指定的一块继续讨论。
```

---

## 5. 会话收束快照（上下文备份 · 2026-03-30）

**冻结结论（今日已落档，不必在新会话重辩）**

- **B 系**三层：**技能根**（`hit_juice_*` 唯一、CD、能量）→ **时间轴片段**（仅 **windup 几何**、`skill_warn_tier`、段级是否显示 windup 等）→ **Strike**（仅 **命中几何**，一段可多点）。  
- **windup 与命中** 数据 **分列**，可同 `geometry_id`、可不一致；**废除**「必同一份定义」旧说法。  
- **命中反馈**：`hit_juice_*` **仅技能根**；**整技能统一档**；**废除** 英雄槽位默认 juice 表。  
- **暂缓**：CSV 最小列、`targeting` 枚举、几何锚点、策划档对照、投射物对接等 **不** 在本周原子定稿，已进 [`design/combat-rules/combat-design-discussion-registry.md`](design/combat-rules/combat-design-discussion-registry.md) **§2**。  
- **拉高视角** 优先话题在 **registry §3**（里程碑、管线、战斗×成长、关卡敌人、可读性预算、首版裁剪、docs/client 同步）。

**新会话冷启动（推荐顺序）**

1. 读本文件 **§5**（本段）→ **§3**。  
2. 打开 [`design/combat-rules/combat-design-discussion-registry.md`](design/combat-rules/combat-design-discussion-registry.md)，按用户意图选 **§3** 或 **§2**。  
3. 索引总览：[`PROJECT-RULES.md`](PROJECT-RULES.md)「Combat presentation」与 **Cross-session continuity**。

**新会话完整提示词（可复制）**

```text
请先阅读 @docs/continued-discussion-handoff-2026-03-30.md 的「§5 会话收束快照」，再读 @docs/design/combat-rules/combat-design-discussion-registry.md 。若用户未指定议题，请先简要复述 registry §3 七条与 §2 暂缓项清单，供用户选优先级；若用户已指定，从该块深入。
```

---

## 6. MVP 阶段方案讨论备份（设计分场）

- **规范位置**：[`plans/mvp-phase-design-meeting-track.md`](plans/mvp-phase-design-meeting-track.md) **v0.1.0**（仓库内 **规范备份**；含决策基线、议题总表 §A–J、**11 场**会议顺序、开发准入条件）。
- **用途**：升级/重启 Cursor 或换会话时，先读本段或 `@` 上述文件，再继续 **MVP 前置方案会** 或迭代该文档版本号。

---

## 7. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-03-30 | 第一场/第二场存档 + 第三场入口 |
| 2026-03-30 | 第三场结论落档：docs 优先、双表+skill_id |
| 2026-03-30 | 第四场 A/B/C/D 落档；`hit-feedback-juice` v0.2；`skill-warning-zone` v0.5；交接本文整体重写 |
| 2026-03-30 | 第五场 B 系 schema v0.1 与关联文档 v0.2–v0.6；交接 §1/§2/§3 更新 |
| 2026-03-30 | 新增 `combat-design-discussion-registry`：暂缓工程项 + 拉高视角议题；交接 §3 改为指向 registry |
| 2026-03-30 | 收束：修正第五场 PROJECT-RULES 版本号；**§5 会话收束快照**（上下文备份）；原 §5 修订记录改为 **§6** |
| 2026-03-30 | **迁移**：本文件移至 **`docs/` 根目录**（项目管理入口）；正文内相对链接与 `@` 路径已按新位置更新 |
| 2026-03-30 | 新增 **§6 MVP 分场备份**；[`plans/mvp-phase-design-meeting-track.md`](plans/mvp-phase-design-meeting-track.md) **v0.1.0**；Related 与 §3 指向该文件；原 **§6 修订记录** 顺延为 **§7**；[`PROJECT-RULES.md`](PROJECT-RULES.md) **v0.7** |
