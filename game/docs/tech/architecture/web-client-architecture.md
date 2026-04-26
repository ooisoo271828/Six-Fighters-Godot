# Web Client Architecture (Node Validation)

Status: Draft  
Version: v0.4  
Owner: Engineering  
Last Updated: 2026-03-30  
Scope: Browser-first implementation stack for the node validation build: rendering loop, encounter RNG, design CSV ingestion, debug hooks, and links to pixel rendering policy.  
Related: docs/design/combat-rules/combat-attributes-resolution.md; docs/design/combat-rules/combat-data-table-families-v1.md; docs/design/play-rules/node-validation-arena.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md; docs/tech/architecture/client-rendering-and-assets.md; docs/tech/adr/2026-03-22-pixel-art-rendering-policy.md; docs/continued-discussion-handoff-2026-03-30.md

## 1. Stack

- **Language**: TypeScript
- **Bundler / dev server**: Vite
- **2D runtime**: Phaser 3 (scene graph, input, game loop, WebGL/canvas fallback)
- **Portrait layout**: root container styled to a fixed aspect ratio (e.g. 9:16) centered in the browser window to match `game-foundation-baseline.md`.

## 2. Scene flow

1. `BootScene`: load shared assets (CSV text, minimal placeholder sprites).
2. `HubScene`: non-combat hub; portal triggers squad selection UI then starts arena with roster snapshot.
3. `ArenaScene`: combat encounter (waves + boss), virtual joystick, autonomy + resolution pipeline.

Scene transitions are driven by Phaser’s scene manager; roster snapshot is passed via a small `GameRegistry` object.

## 3. RNG and determinism

- Each encounter/run constructs a **deterministic PRNG** from `encounterSeed` (32-bit integer).
- `encounterSeed` is derived from `runId` + optional user-facing seed for debug (`rngSeed` field in debug overlay).
- `resolveAttackOutcome` draws consume this PRNG so hit/crit rolls match design expectations and can be replayed when seed is fixed.

Implementation: `mulberry32` or equivalent; **do not** use `Math.random()` inside resolution for gameplay rolls.

## 4. Design authority and CSV loading

### 4.1 `docs/` vs `six-fighter-web/` (precedence)

- **Higher sequence**: Aligned product and design specifications live under **`docs/`**. That tree is the **source of truth** for what the game should implement once the team has agreed.
- **Historical client**: `six-fighter-web/` was started while design boundaries were still being clarified. It contains implementation choices and mirrored data that may **predate or diverge** from later `docs/` revisions.
- **Rules going forward**:
  1. **Conflict**: If `docs/` and the web client disagree, **follow `docs/`** and **update the web client** (including files under `six-fighter-web/public/design-values/`) until they match.
  2. **No conflict / docs gap**: If the client encodes something **`docs/` does not yet describe**, or the two **do not conflict**, the client may be **provisionally** accepted for engineering progress; **close the gap in `docs/`** when stabilizing so an unlabeled “second truth” does not persist.

### 4.2 Authoring paths and runtime mirrors

- **Authoritative numeric tables** remain in `docs/design/**/values/*.csv`.
- **Runtime loading** uses `six-fighter-web/public/design-values/` (via `fetch`) **or** Vite raw imports — treat those as **mirrors** of authoring tables, maintained under §4.1.

### 4.3 Parser

- Minimal RFC4180-style row parser (comma-separated); ignore `id` column for logic, map by `key` column to numbers/strings.

Changing CSV semantics still requires design process; numeric-only tuning without semantic change is allowed per workflow rule.

**Combat data model (authoritative, 2026-03-30+)**: table families **A/B/C/D** (units, skills, hit-juice, global resolution constants) are defined in **`docs/design/combat-rules/combat-data-table-families-v1.md`**. Historical note: an early split into `monster_skill_combat` + `monster_skill_presentation` is **one possible B-family layout**; final schema names live under that spec. See also `docs/continued-discussion-handoff-2026-03-30.md`.

## 5. Debug tools (node validation)

- Toggle overlay: current phase, wave index, boss HP %, `encounterSeed`, buttons for god mode / skip wave (development only).

## 6. Testing

- Unit tests (Vitest recommended) for `resolveAttackOutcome` and CSV parsing with fixed seeds.
- Smoke: boot hub → pick roster → win/lose path in arena without exceptions.

## 7. Rendering / pixel policy (summary)

- Game canvas uses **nearest-neighbor** pixel scaling; see [`client-rendering-and-assets.md`](client-rendering-and-assets.md) and ADR [`2026-03-22-pixel-art-rendering-policy.md`](../adr/2026-03-22-pixel-art-rendering-policy.md).
- **Visual presentation** tunables (shake, hit-stop, flash alpha caps) load from `visual-presentation-values.csv` (see `docs/design/visual-rules/values/`).
