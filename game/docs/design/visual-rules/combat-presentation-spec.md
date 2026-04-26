# Combat Presentation Spec (Camera, Layers, Timing)

Status: Draft  
Version: v0.3  
Owner: Design  
Last Updated: 2026-03-30  
Scope: Framing, draw order, and animation duration budgets for portrait 2D combat; cross-links readability and skill template.  
Related: docs/design/visual-rules/pixel-art-visual-bible.md; docs/design/combat-rules/combat-core-l3-readability-guardrails.md; docs/design/feature-systems/hero-skill-template-v1.md; docs/design/combat-rules/combat-core-l3-boss-phase-grammar.md; docs/design/visual-rules/values/visual-presentation-values.csv; docs/design/combat-rules/skill-warning-zone-spec.md; docs/design/visual-rules/hit-feedback-juice-spec.md; docs/design/combat-rules/combat-data-table-families-v1.md; docs/design/combat-rules/projectile-v1-taxonomy.md; docs/design/other/product-combat-positioning.md

## 1. Camera

- **Single main camera** for combat (no rotating chase cam in v1).
- **Shake** allowed per `combat-core-l3-readability-guardrails.md` §4: shake must not obscure **direction judgment** for movement/dodge — keep intensity/duration from CSV sub-lethal defaults; boss telegraphs may temporarily **disable** shake (implementation flag, future).

## 2. View / Perspective

- **Default**: **three-quarter top-down** or **slightly angled top-down** so squad and enemies share a readable floor plane (final angle locked with first playable art pass).
- **Joystick** remains `move_only`; camera does not reframe per hero — all heroes share one **squad anchor** for presentation (offsets around anchor per hero slot).

## 3. Layer Order (Implementation Contract)

Back to front:

1. Background / parallax (optional)
2. Ground / arena base
3. **Hazard telegraphs** (persistent shapes: circles, cones, lines)
4. Enemy shadows → **Enemy bodies**
5. Ally shadows → **Hero bodies**
6. Mid VFX (projectiles, swings)
7. Front VFX (impacts, sparks)
8. **Critical hazard overlays** — *Node validation / current phase*: **not used** for monster skill windup or “lethal read”; high threat is expressed **only** via `skill_warn_extreme` windup assets (`docs/design/combat-rules/skill-warning-zone-spec.md`). This layer stays **reserved** for future non-windup emphasis (e.g. other modes), to avoid duplicating the windup-only scheme.
9. UI (HP, debug)

This aligns with guardrail **layer priority** semantics: telegraphs and silhouettes beat **decorative** VFX. **Mid VFX** (projectiles, swings, beams per `projectile-v1-taxonomy.md`) is **gameplay presentation**, not decoration — see §3.3 for ordering vs hazard telegraphs.

### 3.1 Monster skill warning zones

Monster **windup** telegraphs: **in-zone sweep / wave** encodes time-to-impact (not a separate UI bar on top); two asset tiers `skill_warn_basic` / `skill_warn_extreme`, optional `none` — see **`docs/design/combat-rules/skill-warning-zone-spec.md`**.

### 3.2 Hit feedback juice tiers

Player-facing hit **juice** packages (`hit_juice_light` … `hit_juice_climax`) and channel matrix — see **`docs/design/visual-rules/hit-feedback-juice-spec.md`**.

### 3.3 Hazard telegraphs vs Mid VFX (projectiles, beams, swings)

**Layer fact:** Hazard telegraphs are **behind** Mid VFX (see list above: items 3 then 6). Mid VFX therefore **draws on top of** ground windup decals when both are visible.

**Authoring norm (not a universal engine hard gate):** For most skills, **design configures** timings and resources so that when projectiles, beams, or similar Mid VFX **appear**, windup **sweep has finished** and the **windup telegraph has ended**. This outcome is achieved by **data and authoring alignment**, not by requiring a global “no Mid VFX until telegraph off” rule in code (unless a future ADR adds one).

**If overlap still occurs** (mistimed config, or one skill’s windup still visible while another skill’s Mid VFX plays): **do not** raise hazard telegraphs above Mid VFX to “fix” it. **Skill presentation effects take precedence over windup telegraph decals** — Mid VFX remains in front per this contract. Cross-skill visual crosstalk is treated as an **authoring bug**, not a reason to invert layers.

Cross-ref: `docs/design/combat-rules/skill-warning-zone-spec.md` §4.

## 4. Animation Duration Budgets (Per Cast)

Upper bounds for **gameplay-relevant** animations (excluding cinematic ultimates):

| Category | Max duration (seconds) | Notes |
|----------|-------------------------|--------|
| Move cycle loop | 0.6–0.9 | loopable |
| Basic attack | 0.35–0.55 | must not block movement input longer than wind-up |
| Small skill A/B | 0.45–0.75 | telegraph + strike |
| Ultimate | 0.9–1.6 | may use screen darkening; split from lethal hazard frames |
| Hit react (light) | 0.12–0.22 | can blend with move |
| Hit react (heavy) | 0.22–0.38 | |
| Death / knockdown | 0.5–0.9 | |

Exact numbers tuned in animation tooling; this table is the **approval gate** for scope creep.

## 5. Skill ↔ VFX Tags (Binding)

Map `hero-skill-template-v1.md` slots to presentation tags:

- `basic_attack` → `fx_melee` or `fx_projectile` per hero config
- `small_skill_a` / `small_skill_b` → element tag `fire|ice|lightning|poison|physical`
- `ultimate_skill` → `fx_ultimate` + optional `screen_vignette` flag

Semantic **hit presentation** (`hit_juice_*` channels: strip, particles, hit-stop, shake, screen flash) — driven by **`hit-feedback-juice-spec.md`** + CSV (`visual-presentation-values.csv`), not this doc.

## 6. Boss Phase Presentation

Per `combat-core-l3-boss-phase-grammar.md`, each phase should introduce **at most one** new readable mechanic.

- Minimum: **phase index HUD** or **boss aura color shift** + **ground pattern change**.
- Phase transition: **avoid** simultaneous full-screen flash + new hazard outline (stagger by design values).

## 7. Numeric Separation

Shake, hit-stop, flash — see `visual-presentation-values.csv`.

## 8. Revision note

| Version | Date | Note |
|---------|------|------|
| v0.3 | 2026-03-30 | §3.3 hazard telegraphs vs Mid VFX; clarify Mid VFX is not “decorative” in §3 list sense |
