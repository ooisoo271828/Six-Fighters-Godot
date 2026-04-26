# Node Validation Arena (Milestone Build)

Status: Draft  
Version: v0.2  
Owner: Design  
Last Updated: 2026-03-30  
Scope: Dedicated validation stage reachable from Hub via a portal: wave spawns plus a final boss, used to prove combat + attributes + roster rules before full content production.  
Related: docs/design/play-rules/stage-dungeon-baseline.md; docs/design/combat-rules/combat-core-l3-boss-phase-grammar.md; docs/design/play-rules/values/node-validation-arena-values.csv; docs/tech/architecture/web-client-architecture.md; six-fighter-web/README.md

## 1. Purpose

- Validate **full combat pipeline** (`move_only`, `fixed_role_ai`, `resolveAttackOutcome` semantics) against real encounters.
- Validate **1..6** distinct-identity rosters without requiring a full six heroes for entry (node UI may limit to three picks for content scope; rules remain 1..6 capable).

## 2. Entry

- From Hub: player interacts with **NodeValidationPortal** → browse (optional copy) → confirm roster snapshot → load Arena scene.
- Roster lock follows `hub-world-entry-rules.md`.

## 3. Encounter flow

1. **Warm-up** (optional): short delay or single trivial spawn (implementation choice).
2. **Waves**: ordered wave groups of small enemies; next wave starts when current wave is cleared (or timer if values specify).
3. **Boss**: single boss entity after final wave; uses `hp_plus_time` phase transitions per `combat-core-l3-boss-phase-grammar.md` (minimal pattern set acceptable for node build).

## 4. Win / lose

- **Win**: boss HP reaches 0.
- **Lose**: all player hero entities are defeated (HP <= 0 simultaneously after resolution order).
- **Retry**: node build should allow immediate restart from Hub or in-arena retry (implementation); progression rewards may be **placeholder** (see `partial_reward` in full product).

## 5. Telemetry (recommended for validation)

- DPS per hero id, damage taken, hit outcome distribution sample — implementation-facing, not numeric-tuned in this logic doc.

## 6. Numeric parameters

All timings, counts, HP multipliers, and boss phase thresholds for this arena live in:

- `docs/design/play-rules/values/node-validation-arena-values.csv`

**Authority**: This path is authoritative. The node validation client loads a mirror from `six-fighter-web/public/design-values/node-validation-arena-values.csv`. If the two differ, **follow the `docs/` file** and update the web mirror per [`docs/tech/architecture/web-client-architecture.md`](../../tech/architecture/web-client-architecture.md) §4.
