# Six-Unit Squad Assembly Contract

Status: Draft  
Version: v0.2  
Owner: Design  
Last Updated: 2026-03-21  
Scope: Squad assembly rules for the **maximum-six** active hero roster (1–6 distinct identities), including preset semantics, uniqueness/locking constraints, and loaner squad semantics for special stages.  
Related: docs/design/other/game-foundation-baseline.md; docs/design/feature-systems/hero-squad-baseline.md; docs/design/feature-systems/squad-selection-and-entry-rules.md; docs/design/combat-rules/combat-core-baseline.md; docs/design/combat-rules/combat-core-l3-squad-autonomy.md; docs/design/feature-systems/values/loaner-squad-values.csv; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

Notes:

- Historical filename retains **six-unit** for link stability; **maximum** roster size is six heroes, **minimum** is one for a valid run (unless a mode doc specifies a higher minimum).
- Semantic change is recorded in `docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md`.

## 1. Squad Contract (Roster Size 1..6)

- The active committed roster is a `six_unit_squad` in the sense **maximum six slots**, not “always six”.
- Let `N` be the number of selected hero identities. Valid player rosters satisfy:
  - `1 <= N <= 6`
  - all `N` entries are **distinct** hero identities (no duplicate `heroId`).
- Slot ordering is a **dense list** `heroId[0..N-1]` for combat and UI; there are **no** “empty hero” placeholders.

## 1.1 Uniqueness Constraint (No Duplicates)

- The no-duplicate identity constraint applies to:
  - player-selected squads (manual pick)
  - player-loaded `preset` squads
  - system-provided `loaner squad` rosters

## 2. Role Tags are Identity-Driven

- A hero carries role tags derived from its identity.
- Presets do not override role tags in v1; they only select which owned heroes occupy the roster list.

## 3. Preset Semantics (Quick Re-entry)

Preset is required for fast session re-entry into stages:

- The player can save up to `preset_slot_count` presets (numeric cap in `hero-squad-values.csv`).
- Each preset stores an ordered list of **1..6** hero identities.
- A valid preset must satisfy:
  - length between 1 and 6 inclusive
  - all identities distinct
  - every listed hero is available to the player when loading (v1: locked/missing heroes block load or require substitution per `squad-selection-and-entry-rules.md`)

## 4. Squad Integration into Combat

When a run starts:

1. Preset or manual selection yields the final ordered list of `N` heroes.
2. The selected roster becomes **locked** for the entire run/stage.
3. Combat core instantiates **exactly `N` hero entities** on the field.
4. Combat core reads each hero's role tags and applies `fixed_role_ai` (see `role-tags-fixed-role-ai-contract` and `combat-core-l3-squad-autonomy.md`).

### 4.1 Entry-only Lock (No Mid-run Swap)

- Under `move_only` + `fixed_role_ai` v1, the player does not change roster composition mid-run.
- Loaner stages also lock at confirm.

## 5. Implementation-Facing Interfaces (Semantic)

- `saveSquadPreset(playerId, presetIndex, heroIdList: HeroId[])` where `1 <= length(heroIdList) <= 6` and all distinct
- `loadSquadPreset(playerId, presetIndex) -> heroIdList`
- `validateSquadEligibility(heroIdList: HeroId[]) -> ok|reason`

## 6. Loaner Squad Semantics (Special Stages)

Some special stages may use a system-provided `loaner squad`:

- Loaner definition supplies:
  - `K` distinct hero identities where `1 <= K <= 6` (unless a specific stage doc freezes a different bound)
  - role/identity metadata required by `fixed_role_ai`
  - optional `loaner_profile` determining effective progression state for the run
- Player ownership: loaner heroes do not need to be owned.
- `loaner_profile` parameters are defined in `docs/design/feature-systems/values/loaner-squad-values.csv`.
