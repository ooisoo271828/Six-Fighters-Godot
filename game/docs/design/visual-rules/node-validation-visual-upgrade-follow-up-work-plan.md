# 节点演示版 → 美术效果全面落实：后续工作计划

Status: Draft  
Version: v0.1  
Owner: Design + Art + Engineering  
Last Updated: 2026-03-21  
Scope: 在现有 **节点验证（node validation）** Web 客户端（逻辑、CSV、占位矩形）基础上，将 **像素角色 / 特效 / 场景可读性** 按已发布规范落地为可玩、可验收的连续阶段；列出方案讨论、资源生产、程序改造与联调验收的分工与顺序。  
Related: `docs/design/play-rules/node-validation-arena.md`; `docs/design/visual-rules/hero-asset-pipeline-spec.md`; `docs/design/visual-rules/pixel-art-visual-bible.md`; `docs/design/visual-rules/combat-presentation-spec.md`; `docs/tech/architecture/client-rendering-and-assets.md`; `six-fighter-web/README.md`; `six-fighter-web/src/visual/unitVisual.ts`

---

## 1. 背景与目标

| 现状 | 目标 |
|------|------|
| 节点构建已验证：战斗解析、`fixed_role_ai`、Hub→Arena、波次与 Boss、`visual-presentation-values.csv` 驱动的闪屏/震屏等 | **替换占位几何体**，按管线导入 **角色图集 + 动画**、**技能 VFX**、必要时 **Hub/Arena 背景与地面**，并在 **360×640 竖屏** 下保持可读性与性能预算 |

**“全面落实”建议拆成可交付阶段**：先完成 **V1 单英雄竖切**（与 `hero-asset-pipeline-spec.md` §5 一致），再扩展到多英雄、敌兵与 Boss，最后做抛光与音频钩子。MVP 阶段采用“2D 像素混合”：像素资源优先产出，但以调色板/可读性/层级优先级符合为准，而非强制“全部纯像素”。

---

## 2. 阶段 A：方案对齐、细化与确认

**目的**：冻结本阶段范围，避免资源与代码命名不一致导致返工。

1. **范围确认**
   - 节点演示是否仍以 **当前 Hub 可选英雄数量** 为内容上限，还是竖切完成后立刻扩 roster。
   - **敌兵 / Boss**：本阶段仅换皮占位（色块尺寸一致）还是提供第一套敌人图集（对应管线 V2–V3 规划）。

2. **规范审阅与定稿**
   - 冻结或小幅修订：`pixel-art-visual-bible.md`（调色板、安全区、特效层级）。
   - 冻结：`hero-asset-pipeline-spec.md` 中的 **目录结构、`heroId`、动画 key、`vfx/<skillTag>/` 命名**。
   - 对照 `combat-presentation-spec.md`：镜头、层级、动画时长预算是否与首版资源一致。

3. **技能 ↔ 特效映射表（设计产出）**
   - 为验证用英雄列出技能与 **`skillTag` 文件夹** 对应关系（参见 `hero-asset-pipeline-spec.md` §4 表示例）。
   - 与 `hero-skill-template-v1.md` / 实际代码中的技能事件对齐，便于程序在 **同一 hook** 上播动画与 VFX。

4. **验收标准书面化**
   - V1 竖切：动画条、VFX 条数、是否允许部分技能暂用通用 `fx_impact_*` 等（见 `hero-asset-pipeline-spec.md` §5）。
   - **可读性**：对照 `combat-core-l3-readability-guardrails.md`，确认 telegraph 不被盟友特效长期遮挡等。

5. **工程与流程约定**
   - 资源 **唯一落点**：`six-fighter-web/public/assets/`（运行时 `/assets/...`），大文件不进 `docs/`（见管线 spec §1）。
   - 若导出格式或图集工具链变更，按需补 **ADR** 或更新 `client-rendering-and-assets.md`。

---

## 3. 阶段 B：美术资源生产与交付

**目的**：按冻结规范分批交付可加载文件，优先支撑 V1 竖切。

1. **工具与导出**
   - Aseprite（或等价）→ PNG；图集走 **Texture Packer / Phaser atlas JSON** 或文档约定的 sheet+JSON；**非预乘 alpha**、**最近邻**缩放。
   - MVP 资源生产允许“AI/工具化辅助”：你提供自然语言的美术需求（动作/技能/VFX 视觉要点），AI/工具链先生成可编辑的素材草案或关键帧，再由管线导出/打包进 atlas/strip，最终以本计划的验收口径确保可在游戏中有效呈现。

2. **角色包（按 `characters/<heroId>/`）**
   - 首包建议遵循 **V1 竖切**（文档推荐从覆盖火+电读法的英雄开始）：idle / run / attack_basic / skill_a / skill_b / ultimate / hit / death。
   - **统一身高基线、脚底枢轴**（管线 spec §3）。
   - 单包图集 **≤ 2048×2048**（必要时拆分并约定加载顺序）。

3. **特效包（按 `vfx/<skillTag>/`）**
   - `strip.png` + 可选 `meta.json`（fps、loop、混合模式意图）；高亮类特效注意与 `visual-presentation-values.csv` 中的透明度/强度调谐一致。

4. **场景/UI 美术（按优先级）**
   - Arena：**地面/背景**（与 `combat-presentation-spec.md` 层级一致）、可选 parallax。
   - Hub：背景与入口 portal 区（若节点演示需要第一印象）。
   - **字体**：v0 可用系统字；若换像素字体，需约定字号与授权，并在工程中集中加载。

5. **交付与评审**
   - 每批：**PR 或目录拷贝 + 清单**（文件名、帧数、是否循环）。
   - **评审清单**：命名是否符合规范、透明边、轮廓在 portrait 安全区内是否可读。

6. **后续波次（提醒）**
   - V2：多英雄剪影区分；V3：敌人与 Boss 图集（见 `hero-asset-pipeline-spec.md` §6）。

---

## 4. 阶段 C：程序工程调整

**目的**：把静态文件接进 Phaser，驱动动画与特效，并保留 CSV 驱动表现参数。

1. **加载架构**
   - 按 `client-rendering-and-assets.md`：在 **ArenaScene（及 Hub）`preload`** 中加载当前 roster 所需 **hero pack + VFX**，避免仅在 `create` 里异步补载（文档已标明待重构点）。

2. **图集与动画**
   - 注册纹理与 `this.anims.create`，**动画 key** 与 `hero-asset-pipeline-spec.md` §2 一致。
   - 若使用 `animations.json` 自定义 manifest，需单一解析路径，避免硬编码散落。

3. **单位表现层**
   - 扩展 `unitVisual.ts`：由 `Rectangle` 占位改为 **`Sprite`（或容器）+ `UnitVisualAdapter`**，在 `playAttackWindup` / `playHitReact` 等中驱动动画，并与现有 hit-stop、闪屏逻辑对齐。

4. **技能与受击 VFX**
   - 在战斗事件或现有反馈层挂载：**条带动画**、必要时 **ParticleEmitter**；混合模式与粒子数量遵守 `client-rendering-and-assets.md` §4 与性能预算 §6。

5. **层级与相机**
   - 按 `combat-presentation-spec.md` §3 实现或校验 **display list / depth**，确保 telegraph > 单位剪影 > 装饰性 VFX 的约定。

6. **数值与配置**
   - 持续以 `docs/design/visual-rules/values/visual-presentation-values.csv` 为权威设计源，同步到 `six-fighter-web/public/design-values/`；避免在场景代码里写死与表现相关的时长（与现有架构一致）。

7. **质量与工程**
   - `npm run build` / `npm test` 通过；低端集显下 **60 FPS** 目标抽样（见 `client-rendering-and-assets.md` §6）。
   - 更新 `six-fighter-web/public/assets/README.md` 若落地目录与占位说明有变。

---

## 5. 阶段 D：联调、验收与文档收尾

1. **联调**
   - 设计 / 美术 / 程序共同跑通：**Hub → 选将 → 节点 Arena 全流程**，关注技能与特效 **不同步、缺帧、层级错误**。

2. **验收**
   - V1 竖切 checklist（管线 spec §5）+ 节点关卡胜利/失败仍符合 `node-validation-arena.md`。
   - **可读性抽检**：与 `pixel-art-visual-bible.md` §6 及 guardrails 对照。

3. **文档状态**
   - 将本计划与相关规范中已冻结条目更新为 **Approved**（含日期/版本），或在 `game-design-docs-discussion-workflow-rule` 流程下归档变更说明。

---

## 6. 依赖、风险与缓解

| 风险 | 缓解 |
|------|------|
| 动画 key / `heroId` 与代码不一致 | 阶段 A 产出映射表；代码侧常量单点定义（如 `HERO_ANIM_KEYS`） |
| 图集过大或帧数过多导致卡顿 | 分 atlas；限制同屏粒子；按场景懒加载 |
| 技能事件与特效 tag 未对齐 | 阶段 A 技能↔tag 表 + 程序统一从一个事件总线触发 |
| 文档与 `public/design-values` 不同步 | 改 CSV 时走现有同步约定（见 `six-fighter-web/README.md` Design CSVs） |

---

## 7. 建议顺序（摘要）

1. **阶段 A** 冻结范围与命名 → **阶段 B** 交付 V1 英雄包 + 最少 VFX 集 → **阶段 C** 加载与 `UnitVisualAdapter` 实装 → **阶段 D** 联调整收与文档定稿。  
2. 敌兵/Boss/全量 Hub 美术可在 V1 竖切验收通过后按管线 **V2–V3** 排期。

---

## 8. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-03-21 | 初稿：节点演示美术升级后续工作分解 |
