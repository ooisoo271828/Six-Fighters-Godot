# Combat Core Baseline

Status: Draft  
Version: v0.2  
Owner: Design  
Last Updated: 2026-03-21  
Scope: Project-wide high-level combat rules (baseline logic). Numeric thresholds belong to `values/*.csv`.  
Related: docs/design/combat-rules/combat-core-decision-freeze-v1.md; docs/design/feature-systems/six-unit-squad-assembly-contract.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

## 1. Combat Baseline Contract

1. Player input: movement-only control via one transparent virtual joystick (`move_only`).
2. Squad: a committed roster of **1..6** distinct hero identities; combat instantiates **one entity per hero** (see §1.1).
3. Squad actions: autonomous execution driven by hero role logic (`fixed_role_ai`).
4. Encounter pressure: bullets/aoe/timing patterns must be readable in portrait mode.
5. Failure: failure returns progression via `partial_reward` to avoid hard growth dead-ends.

### 1.1 Active roster size (`active_roster_count`)

- Let `N` be the number of heroes in the locked roster snapshot for the run (`1 <= N <= 6`).
- Combat spawns **exactly `N` hero units**; there is **no** “empty slot” unit.
- Enemy targeting, healing, and hazard logic must iterate only over **living** hero units present in the encounter.

### 1.2 Under-strength rosters (minimal rules for v1)

- **AI pipeline**: the same autonomy pipeline order applies per hero (`combat-core-l3-squad-autonomy.md`); there is **no** requirement to invent placeholder heroes for missing roles in v1.
- **Difficulty scaling (optional)**: node validation and early implementations may use **no automatic stat scaling** for low `N`; optional encounter multipliers belong in mode-specific `values/*.csv` and must not change core freeze tokens.
- **Readability**: hazard telegraphs remain `strict_global_standard`; fewer heroes may increase individual exposure—design compensates via encounter tuning rather than by adding invisible allies.

## 2. Encounter Composition (Baseline)

- Waves: repeated pressure patterns that teach and escalate.
- Elite windows: increased pressure density and a clearer dodge solution.
- Boss: phase-based structure with readable telegraphs and opportunity windows.

## 3. Readability Baseline (Baseline Rule)

- Hazard/warning semantics must use a globally consistent signal language (`strict_global_standard`).
- Visual spectacle is allowed, but must not conceal the source of hazards at critical timing.

## 4. Integration Points with Other Systems

- Stage/Dungeon modes supply: map hazard layout, spawn timing, and enemy families.
- Hero systems supply: role tags and skill modifiers affecting output cadence and survivability.
- Progression systems supply: stat channels and unlock states.

## 5. Numeric Separation Note

Any numeric tuning (intervals, thresholds, densities, duration targets, ratios) must be placed in:

- `docs/design/combat-rules/values/combat-core-values.csv`

and later refined into level-specific CSVs.
