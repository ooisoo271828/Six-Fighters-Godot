# Game Foundation Baseline

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Project-wide design foundation and global vocabulary for all design documents.
Related: docs/PROJECT-RULES.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md; docs/design/visual-rules/pixel-art-visual-bible.md; docs/design/other/product-combat-positioning.md

## 1. Global Product Targets (Phase 1)
- Mobile portrait-first experience.
- First delivery as a browser-openable quick app, but visual experience remains portrait.
- 2D pixel art with fine-grain pixel detail (8-like granularity, slightly higher where possible).

## 2. Combat & Control Global Vocabulary
These tokens are treated as stable vocabulary across design levels.
- `move_only`: player direct control is movement only via one transparent virtual joystick.
- `fixed_role_ai`: squad actions are autonomous and driven by hero role logic; no per-hero manual targeting.
- `strict_global_standard`: hazard/warning semantics use a globally consistent signal language for readability.
- `partial_reward`: failure still yields progression-relevant partial rewards to avoid growth dead-ends.

## 3. Squad & Build Global Vocabulary
- `six-unit squad` (roster): the active committed team contains **between 1 and 6** distinct hero identities (**maximum** six); **no duplicate** identities in the same roster snapshot.
- Build expression comes from roster composition and growth systems, not from manual micro-control.

## 4. Design Logic vs Numeric Plan Separation
- `.md` documents rules and logic (what happens and why).
- `values/*.csv` documents numeric parameters and tunable thresholds (rates, intervals, ranges, multipliers).

When a decision becomes “frozen”, the related `.md`/CSV should switch to `Approved` and reference a freeze record.

## 5. Mode Family Boundaries
- Mainline Chapter 1-5: linear story + stage pacing.
- Independent modes (L2+): Deep Dungeon, Ruins Escape, Castle Defense.
- All modes must be compatible with the combat global tokens in section 2.

