# Project rules (index)

Status: Draft
Version: v0.9
Owner: Project
Last Updated: 2026-04-12  
Scope: Entry point linking repository-wide rules; detailed rules live under `docs/` and `.cursor/`.  
Related: `.cursor/rules/game-design-docs-discussion-workflow-rule.md` §12（跨会话 handoff）；`docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md`

## Cross-session continuity (handoff)

- **Before** substantive design work on a continuing topic: read the relevant **`docs/continued-discussion-handoff-*.md`** (repository `docs/` root) and the authoritative specs it points to.
- **MVP phase** (pre-production design meetings): [`docs/plans/mvp-phase-design-meeting-track.md`](plans/mvp-phase-design-meeting-track.md) **v0.1.0** — decision baseline, topic checklist §A–J, **11-session** schedule (including art), dev gate.
- **After** a slice is decided or documented: update the appropriate **`docs/`** files; update the handoff or **[`combat-design-discussion-registry.md`](design/combat-rules/combat-design-discussion-registry.md)** when used as the session log so the next round can resume without re-deriving history.
- Full procedure: [`.cursor/rules/game-design-docs-discussion-workflow-rule.md`](.cursor/rules/game-design-docs-discussion-workflow-rule.md) §12.

## Design authority vs `six-fighter-web/`

Aligned specifications live under **`docs/`** (higher sequence). The web client may lag or diverge for historical reasons; **on conflict, follow `docs/`** and update the client. Full rules and CSV mirror expectations: [`docs/tech/architecture/web-client-architecture.md`](docs/tech/architecture/web-client-architecture.md) §4.

## Where rules live

1. **Design / doc workflow**: [`.cursor/rules/game-design-docs-discussion-workflow-rule.md`](.cursor/rules/game-design-docs-discussion-workflow-rule.md) — Approved design docs are the implementation gate; logic vs numeric separation; ADR policy; **§12** cross-session handoff (read handoff before work; land docs + update handoff/registry after).
2. **Tech / Web client** (node validation): [`docs/tech/architecture/web-client-architecture.md`](docs/tech/architecture/web-client-architecture.md) — stack, RNG, CSV loading, **docs vs client precedence**; [`docs/tech/architecture/client-rendering-and-assets.md`](docs/tech/architecture/client-rendering-and-assets.md) — pixel rendering, atlases.
3. **Visual rules** (pixel art): [`docs/design/visual-rules/pixel-art-visual-bible.md`](docs/design/visual-rules/pixel-art-visual-bible.md) and [`docs/design/visual-rules/hero-asset-pipeline-spec.md`](docs/design/visual-rules/hero-asset-pipeline-spec.md). **Milestone plan** (node build → full visual rollout): [`docs/design/visual-rules/node-validation-visual-upgrade-follow-up-work-plan.md`](docs/design/visual-rules/node-validation-visual-upgrade-follow-up-work-plan.md). **Cross-session handoff** (方案讨论进度存档、新会话续聊入口，**`docs/` 根目录**): [`docs/continued-discussion-handoff-2026-03-30.md`](continued-discussion-handoff-2026-03-30.md).
4. **Architecture decisions**: [`docs/tech/adr/`](docs/tech/adr/) — ADRs for semantic changes (e.g. flexible squad 1–6, pixel rendering policy).
5. **Asset naming convention** (sprite files): [`docs/project/standards/asset_naming_convention.md`](docs/project/standards/asset_naming_convention.md) — 所有美术资源文件的命名法则，所有新增资源必须遵循。
6. **Sprite pipeline & handoff** (2026-04-13): [`docs/continued-discussion-handoff-2026-04-13-sprite-pipeline.md`](continued-discussion-handoff-2026-04-13-sprite-pipeline.md) — 精灵资产管线、PNG生成、动画查看器、GitHub建库完整记录。

## Product design baseline

- [`docs/design/other/game-foundation-baseline.md`](docs/design/other/game-foundation-baseline.md)
- Combat product positioning (mobile mid-core, big-number RPG, naming convention): [`docs/design/other/product-combat-positioning.md`](docs/design/other/product-combat-positioning.md)

## Combat presentation (frozen discussion → specs)

- **Combat data table families (A/B/C/D)** — authoritative layout: [`docs/design/combat-rules/combat-data-table-families-v1.md`](docs/design/combat-rules/combat-data-table-families-v1.md)
- **B-series skill schema** (skill root / timeline segments / strike instances, windup vs hit geometry, `hit_juice` on skill root): [`docs/design/combat-rules/b-series-skill-schema-v0.md`](docs/design/combat-rules/b-series-skill-schema-v0.md)
- **Combat design discussion registry** (deferred engineering backlog + elevated topics for future sessions): [`docs/design/combat-rules/combat-design-discussion-registry.md`](docs/design/combat-rules/combat-design-discussion-registry.md)
- Monster skill warning zones: [`docs/design/combat-rules/skill-warning-zone-spec.md`](docs/design/combat-rules/skill-warning-zone-spec.md)
- Hit feedback tiers (`hit_juice_*`): [`docs/design/visual-rules/hit-feedback-juice-spec.md`](docs/design/visual-rules/hit-feedback-juice-spec.md)
- Projectile V1 taxonomy: [`docs/design/combat-rules/projectile-v1-taxonomy.md`](docs/design/combat-rules/projectile-v1-taxonomy.md)
- Discussion handoff / snapshot (2026-03-29): [`docs/design/visual-rules/discussion-handoff-2026-03-29-projectiles-hit-juice-b7.md`](docs/design/visual-rules/discussion-handoff-2026-03-29-projectiles-hit-juice-b7.md)
- **Continued cross-session handoff** (progress archive for new sessions): [`docs/continued-discussion-handoff-2026-03-30.md`](continued-discussion-handoff-2026-03-30.md)
- **Continued cross-session handoff** (2026-04-11): MCP调试 + reg05调优 + reg04重构 + 投射物类型澄清: [`docs/continued-discussion-handoff-2026-04-11-mcp-debug-skill-tunning.md`](continued-discussion-handoff-2026-04-11-mcp-debug-skill-tunning.md)
- **Continued cross-session handoff** (2026-04-26): 镜头系统方案 + 技能演示器: [`docs/continued-discussion-handoff-2026-04-26-camera-system-skill-demo.md`](continued-discussion-handoff-2026-04-26-camera-system-skill-demo.md)
- **Camera system design doc**: [`docs/camera_system_design.md`](camera_system_design.md) — 竖屏固定镜头架构、锚点-跟随系统、4 方向角色的 360° 投射物解耦
- **SkillDemo scene**: `scenes/dev/skill_demo.tscn` — 新技能演示器，使用与游戏一致的镜头系统
