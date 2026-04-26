# 怪物技能警戒区（Windup 片 + 片内时间推进）

Status: Draft  
Version: v0.6  
Owner: Design  
Last Updated: 2026-03-30  
Scope: 怪物技能 **生效前**（windup）的范围与时间可读性；威胁两档 + 不配档；**当前节点验证阶段**不依赖额外「致命叠层」通道。  
Related: `docs/design/visual-rules/combat-presentation-spec.md`; `docs/design/combat-rules/combat-core-l3-readability-guardrails.md`; `docs/design/other/product-combat-positioning.md`; `docs/design/visual-rules/hit-feedback-juice-spec.md`; `docs/design/combat-rules/combat-data-table-families-v1.md`; `docs/design/combat-rules/b-series-skill-schema-v0.md`

## 1. 设计原则

- 重视 **可读性与业务严谨**，体系 **保持简单**；与 **中轻度、大数值** 产品定位一致（见 `product-combat-positioning.md`）。  
- **当前阶段**：警戒与「超高危」语义 **仅通过 windup 警戒片** 表达；**不**单独依赖全屏叠层、额外「第 8 层致命蒙版」等与 windup 片并行的主通道（见 `combat-presentation-spec.md` §3 说明）。  
- **不**引入宫系那类复杂 lethal 语义树；超高危与 **`skill_warn_extreme`** 素材档对齐即可。

## 2. 前摇可读 — 范围与时间（片内推进，非独立进度条）

### 2.1 不是什么

- **不是**在警戒形状 **上方再挂一条** 传统 UI 进度条（血条式条子）。  
- **不是**以「基本 windup 底图 + 再叠一层蒙版/高光」作为 **高危版** 的主实现手段（易糊、易挡读向）；高危与普通为 **两套独立 windup 素材**（见 §3）。

### 2.2 是什么

- **windup 警戒片** 同时承担：**伤害范围** + **剩余前摇时间** 两种信息。  
- 在片 **内部** 播放 **推进类界面特效**（如浪头/扫光）：特效 **走完一遍** 的时长 = 玩家 **可躲避 / 应对窗口** = 与技能 windup 一致的数据（`warn_sweep_duration_s` 或等价字段进技能表 / CSV，本文不写死秒数）。

### 2.3 几何与推进方向（v1）

| 形状 | 片内推进方式 | 备注 |
|------|----------------|------|
| **矩形** | 矩形 **长边与技能主要释放方向一致**；浪头从 **沿释放方向的后侧** 扫向 **前侧** | 与打击方向一致，便于躲闪读向 |
| **圆形** | **匀速径向**：从 **圆心** 推进至 **外缘** | |
| **扇形** | **匀速径向**：从 **扇心（角点）** 推进至 **外弧边** | 与圆形同理，范围为扇形蒙版 |

**v1 范围**：仅支持 **矩形、圆形、扇形** 三类；**其他怪异形状当前阶段不考虑**，后续里程碑另议。

## 3. 威胁分档 — 两套 windup 素材 + 不配档

通过 **`skill_warn_basic` / `skill_warn_extreme`** 选用 **两套不同的 windup 底图素材**（非「同一底 + 叠加层」为主方案）：

| 中文（文档描述） | 英文 ID（表字段 / 代码枚举） | 说明 |
|------------------|------------------------------|------|
| 基本技能提示区 | `skill_warn_basic` | 常规需躲避或需留意的范围技能；底图偏 **黄调** 等较轻配色（具体由美术定稿）。 |
| 超高危技能提示区 | `skill_warn_extreme` | 威胁更高一档；**同一套几何与片内推进逻辑**，**底图** 为独立一套，偏 **血红** 等，**材质/花纹可更华丽**。 |

**片内浪头 / 推进特效（当前阶段）**：**共用一套** 特效逻辑与基础资源，通过 **调色 / 简单色相或强度** 与两档底图协调；若验收不足再排 **浪头独立第二套** 资源。

**不配档**：弱于上述两档的技能 — **`skill_warn_tier: none`**，不配置警戒片区。**并非**所有怪物技能都必须带警戒区。

**与「致命」话术**：产品侧可将 **`skill_warn_extreme`** 与「超高危 / 致命感」对齐；是否即死仍以 **数值与技能表** 为准。

## 4. 与呈现分层的关系

- windup 警戒片落在 `combat-presentation-spec.md` §3 的 **Hazard telegraphs**（及片内推进特效与底图同层或紧邻子层，由实现保证不压过单位剪影可读性）。  
- **与 Mid VFX（投射物、光束、挥砍等）**：见 **`combat-presentation-spec.md` §3.3**。要点：**常态**由策划配置使特效出现时 windup 已结束；**若仍叠画**，分层上 **Mid VFX 在 telegraph 之上**，**技能特效优先于 windup 片**，不因错位把 telegraph 提到 Mid 之上。  
- **命中反馈**（震屏、屏闪、`hit_juice_*`）与警戒叠画的 **轻量裁剪** 见 `hit-feedback-juice-spec.md` §6（可选，玩测定稿）。

## 5. 工程字段（建议）

- `skill_warn_tier`: `none` | `skill_warn_basic` | `skill_warn_extreme`  
- `warn_sweep_duration_s`（或等价字段）：**片内推进**（浪头/扫光）**走完一遍**的时长，等于 windup **可躲窗口**；进技能表 / 怪物表 / CSV，与 §2 机制一致。  
- `warn_shape`: `rect` | `circle` | `fan`（v1 仅三者）。  
- 矩形需可配置 **释放朝向**（或与怪物面向 / 技能锚点绑定），以驱动长边与浪头方向。  
- **显示空间**：windup 警戒片（telegraph）采用 **world-space**（贴在战斗场景里随摄像机/场景变化而保持空间关系），用于保证玩家躲闪读向一致。
- **telegraph 默认锚点**：默认使用 **几何中心 / geometry center** 语义来定位 telegraph 资产；若与 B 系命中/站位几何使用了不同锚点（例如 hero/vfx 采用脚底中心 feet-center），则由实现侧施加**固定 offset** 来对齐视觉位置（而非强行改动几何语义）。
- **与命中几何的关系（B 系）**：**windup 用几何** 在 **时间轴片段** 上配置；**命中判定几何** 在 **每条打击实例** 上配置（见 **`b-series-skill-schema-v0.md`** §3）。二者 **可** 复用同一 `geometry_id`，也 **允许** 不一致；是否绘制本段 windup 由 **`skill_warn_tier`、段级 windup 显示开关** 等控制（如 `none` 表示不配警戒片）。表系划分见 **`combat-data-table-families-v1.md`** §3。

## 6. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-03-30 | 两档 + 不配档初稿（曾误用「充能条」措辞，已废止；时间可读性以片内推进为准，见 v0.2） |
| v0.2 | 2026-03-30 | 片内推进（非独立条）；矩形/圆/扇与匀速径向；两档独立底图 + 共用浪头 v1；当前阶段不启用额外致命叠层主通道 |
| v0.3 | 2026-03-30 | 工程字段 `warn_charge_duration_s` 更名为 `warn_sweep_duration_s`（与「片内扫过」语义一致，避免 charge/充能条误读） |
| v0.4 | 2026-03-30 | §4：与 Mid VFX 叠画 — 策划趋同常态；错位时技能特效高于 windup（对齐 `combat-presentation-spec` §3.3） |
| v0.5 | 2026-03-30 | §5：windup 与命中判定几何同一定义；链 `combat-data-table-families-v1` |
| v0.6 | 2026-03-30 | §5：与 `b-series-skill-schema-v0` 对齐 — windup 几何在片段、命中几何在 Strike，可同可异 |
