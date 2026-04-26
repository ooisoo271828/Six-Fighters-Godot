# 讨论交接：投射物类型、命中表现档、B7 话术（2026-03-29）

Status: Draft（会议记录 / 决策快照）  
Owner: Design + Engineering  
Scope: 讨论过程**快照**；**实施引用请以正式 spec 为准**（见下「正式落档」）。  
Related: `product-combat-positioning.md`; `skill-warning-zone-spec.md`; `hit-feedback-juice-spec.md`; `projectile-v1-taxonomy.md`; `combat-presentation-spec.md`; `node-validation-visual-upgrade-follow-up-work-plan.md`

## 0. 正式落档（Canonical）

以下内容已拆入独立文档，便于评审与实现门禁：

| 主题 | 路径 |
|------|------|
| 产品战斗定位 + 文档/工程命名约定 | `docs/design/other/product-combat-positioning.md` |
| 怪物技能警戒区（两档 + windup 片内推进） | `docs/design/combat-rules/skill-warning-zone-spec.md` |
| 命中综合表现档 `hit_juice_*` + 映射 | `docs/design/visual-rules/hit-feedback-juice-spec.md` |
| 投射物 V1 类型 A–L | `docs/design/combat-rules/projectile-v1-taxonomy.md` |
| 战斗数据表系框架 A/B/C/D | `docs/design/combat-rules/combat-data-table-families-v1.md` |
| B 系技能对象模型与 schema | `docs/design/combat-rules/b-series-skill-schema-v0.md` |

索引入口：`docs/PROJECT-RULES.md` →「Combat presentation」节。`combat-presentation-spec.md` 已增加 §3.1 / §3.2 交叉引用。

### 0.1 与后续定案的关系（勘误）

- 本文档中仍出现的 **`hit_juice_override`**、技能表侧 **双重覆盖**、**英雄槽位默认 juice**、**命中与 windup 必同一份几何** 等表述，为 **讨论快照**。**现行规则** 以 **`hit-feedback-juice-spec.md` v0.3**、**`combat-data-table-families-v1.md` v0.2**、**`b-series-skill-schema-v0.md` v0.1** 为准：**`hit_juice_*` 在技能根唯一声明；整技能统一档；windup 几何在片段、命中几何在 Strike；C 系持有全部 juice 标量；特例在 C 系扩档**。

---

## 1. 团队话术约定（当日确认）

- **设计文档**：尽量中文，便于方案沟通与体验描述。  
- **工程侧命名**：表头、参数 key、资源路径、代码标识符等 **缺省英文**（国际化协作）。

---

## 2. 产品定位与战斗呈现（更新：非硬核 ARPG）

**清晰定义（团队口径）**

- **不是**传统意义上的硬核 ARPG；**核心用户**偏 **手机端、中轻度泛游戏用户**，而非以 **毫秒级反射、极限操作反馈** 为核心诉求的 hardcore 动作玩家。  
- **产品形态**：**2D 即时制关卡游戏**，操作轻松，带 **部分动作类技能的视觉表现**（投射物、爆炸感等）。  
- **胜负与成长**：**大数值 RPG** — 角色与怪物 **数值成长幅度大**；能否击杀/被击杀的 **主要决定因素是养成是否达标**，而非宫系作品那样 **高度依赖瞬时操作**。  
- **警戒/致命提示**：**要做**，体现业务严谨与对用户的关注；但 **不作为游戏最核心模块**，**不做过度复杂** 的警戒体系。

**仍保留的呈现讨论（与上并不矛盾）**

- **技能圈 + 若干投射物** 的 **视觉丰富度** 可高于一般轻度即时制；投射物数量 **多于常见 ARPG**、**远不到** 弹幕海。  
- **实现结构（方案 1）**：绝大多数技能 = **运动类型 × 发射模式 × 美术 strip**；少数招牌可单独脚本。  
- **光束（J）**：走 **投射物层**（与飞弹共用调度 / 池化思路）。

---

## 3. V1 投射物类型（已冻结）

**本里程碑须可玩验收的类型**：`A B C D F G H J L`（字母含义见下）。  
**明确延后**：`E`（抛物）、`I`（子母/延迟分裂）、`K`（贴地/沿地）。  
**交付节奏**：用户选择 **一个里程碑内** 上述类型均需可在关卡中点到（工程量大，建议内部分 sprint 排期，对外仍是一个里程碑）。

| 代号 | 含义 |
|------|------|
| A | 直线匀速 |
| B | 变速直线 |
| C | 弱追踪 |
| D | 强追踪 |
| F | 弹跳 |
| G | 扇形散射 |
| H | 环形径向 |
| J | 光束/扫掠（投射物层） |
| L | 轨道/绕体 |

---

## 4. 命中「综合表现感」分档（B1–B4 已拍板）

**含义**：玩家在同一命中事件中接收到的 **视听 + 相机/时间感** 等综合反馈（**不是**伤害数值档，**不是**判定面积档；可与伤害/稀有度映射，但不等价）。

**档数**：四档。  
**英文 ID（工程用）**：

| 顺序（轻→重） | `hit_juice_*` ID |
|---------------|------------------|
| 1 | `hit_juice_light` |
| 2 | `hit_juice_standard` |
| 3 | `hit_juice_heavy` |
| 4 | `hit_juice_climax` |

**通道策略**：`subset_light` — 轻档 **少通道**；standard 起再叠震屏、闪屏等；高档在同一套通道上 **加强度（CSV）**。

**通道矩阵（定稿）**：

| 通道 ID | light | standard | heavy | climax |
|---------|-------|----------|-------|--------|
| `burst_strip` | ● | ● | ● | ● |
| `impact_particles` | ● | ● | ● | ● |
| `hit_stop` | ○ | ● | ● | ● |
| `camera_shake` | ○ | ● | ● | ●（**高幅、短时**） |
| `screen_flash` | ○ | ○ | ● 使用 `screen_flash_profile_heavy` | ● 使用 `screen_flash_profile_climax` |

**climax 专项**：震屏 **振幅大、时间短**；屏闪 **余韵长**，且 **余韵可持续时间 > 震屏持续时间**（参数进 CSV）。

---

## 5. 技能 → 命中档映射（B5 已拍板）

- **主规则**：**混合** — 按 **技能槽位** 给默认档，字段 **`hit_juice_override`** 可覆盖；空则走槽位默认表。  
- **DoT tick**：默认 **`hit_juice_light`**；特殊 DoT 爆段可用 override 提高档。  
- **槽位默认表（建议初值，可再调）**：

| `skill_slot` | 默认档 |
|--------------|--------|
| `attack_basic` | `hit_juice_light` |
| `skill_a` | `hit_juice_standard` |
| `skill_b` | `hit_juice_heavy` |
| `ultimate` | `hit_juice_climax` |

- **例外**：`hit_juice_climax` 用于非 `ultimate` 建议主策划审批（防滥用）。  
- **敌人**：可共用枚举与 override；无 override 时的敌人默认表 **待补**（或暂约定默认 standard）。

---

## 6. 怪物技能警戒区方案（已定产品要求，2026-03-30）

**设计思想**：重视警戒提示的 **框架与可读性**，但体系 **保持简单**；与 **大数值、中轻度操作** 定位一致。

### 6.1 前摇阶段 — 技能范围 + 片内时间推进

- 怪物技能 **生效前** 的提示，类比 ARPG「前摇」，在本产品中 **核心手段** 仍是：**技能范围 windup 警戒片**（矩形 / 圆形 / 扇形，v1）。  
- **不是**在片上再挂独立 UI 条；而是在片 **内部** 播放 **推进特效**（如浪头），**走完一遍** 的时间 = 可躲窗口（与 windup 数据一致）。矩形沿释放方向扫；圆/扇 **匀速径向** 从心到外缘。  
- **正式条文与两档独立底图**：见 `docs/design/combat-rules/skill-warning-zone-spec.md` v0.2+。

### 6.2 威胁档位 — 仅两档警戒区 + 不配档

仅需要 **两种** 警戒区类型（通过 **整体颜色与材质/样式** 区分「超高危」与「普通技能提示」）：

| 中文（文档） | 建议英文 ID（工程 / 表字段） | 说明 |
|--------------|------------------------------|------|
| 基本技能提示区 | `skill_warn_basic` | 常规需躲避或需留意的范围技能。 |
| 超高危技能提示区 | `skill_warn_extreme` | 威胁更高一档；**同一套几何 + 片内推进逻辑**，**独立一套 windup 底图**（偏血红、可更华丽），与 basic **非**「底图+叠层」主方案。 |

**第三情况**：比上述两档 **更弱** 的技能 — **不配置** 警戒片区（无范围提示区）。**并非**所有技能都带警戒区。

### 6.3 与旧话术的关系

- **Telegraph**：仍可用于指「生效前的可读信号」；本产品里 **落地形态** 以 **§6.1–6.2** 为准。  
- **「致命」**：在产品中可与 **`skill_warn_extreme`** 的语义对齐为「超高危一档」，**不必**引入宫系那套复杂 lethal 分层；具体是否即死仍以 **数值与技能表** 为准。

### 6.4 B7（命中表现 vs 警戒）— 倾向简化

因警戒模块 **非核心且两档即可**，**B7** 建议改为 **轻量规则**：例如仅在 **`skill_warn_extreme` 激活且与全屏闪叠画** 时再做裁剪或削强度；**不必**按 hardcore ARPG 预设「大范围压 hit_juice」。**具体 clamp 是否要做、做几条**，可待玩测后 **可选** 定稿。

---

## 7. 建议后续工作顺序

1. ~~并入正式文档~~ → 已完成，见 **§0 正式落档**。  
2. **待办**：在 B 系技能/打击实例 CSV 中落地字段（如 `skill_warn_tier`、`warn_sweep_duration_s`、**`hit_juice_*` 档位引用** 等）；`hit_juice` 通道标量仍在 `visual-presentation-values.csv` / C 系；**不**再使用 `hit_juice_override`（见 `combat-data-table-families-v1.md`）。  
3. **可选**：玩测后定稿 **B7 轻量 clamp**（见 `hit-feedback-juice-spec.md` §6）。

---

## 8. 经验小结（交流用）

- **先统一话术再定 B7**，比先定实现再改文档成本低。  
- **命中档** 管的是 **表现套餐**，与 **伤害/范围** 分表，策划映射规则（B5）才清晰。  
- **四档 + 英文 ID** 已足够支撑 CSV 与国际化工程习惯。  
- **V1 九类投射物** 与 **单里程碑全验收** 并存时，需内部分批实现，避免排期误判。

---

## 9. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-03-29 | 当日讨论交接初稿 |
| v0.2 | 2026-03-30 | 产品定位（非硬核 ARPG、大数值中轻度）；怪物警戒区两档 + windup 片内推进与可躲窗口对齐；B7 倾向简化 |
| v0.3 | 2026-03-30 | 拆出正式 spec 四篇 + `PROJECT-RULES` / `combat-presentation-spec` 索引 |
| v0.4 | 2026-03-30 | §6.1 与正式 `skill-warning-zone-spec` v0.2 对齐：片内推进、圆/扇匀速径向、两档独立底图；节点阶段不启用额外致命叠层主通道 |
| v0.5 | 2026-03-30 | 待办字段名与正式 spec 一致：`warn_charge_duration_s` → `warn_sweep_duration_s` |
| v0.6 | 2026-03-30 | §0：纳入 `combat-data-table-families-v1`；§0.1 勘误 override 方案已由 v0.2 / 表系框架取代 |
