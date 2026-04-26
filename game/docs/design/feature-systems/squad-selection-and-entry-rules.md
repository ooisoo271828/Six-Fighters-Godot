# Squad Selection and Entry Rules

Status: Draft  
Version: v0.2  
Owner: Design  
Last Updated: 2026-03-21  
Scope: Player/system rules for selecting a roster of **1..6** distinct hero identities for a stage/run, including preset-based entry and system `loaner squad` entry for special stages.  
Related: docs/design/feature-systems/six-unit-squad-assembly-contract.md; docs/design/play-rules/gameplay-cross-mode-rules.md; docs/design/combat-rules/combat-core-l3-squad-autonomy.md; docs/design/feature-systems/role-tags-fixed-role-ai-contract.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

Notes:

## 1. Design Goals

- Ensure squad selection is predictable and implementation-friendly.
- Support quick re-entry via `preset`.
- Allow special stages to use `loaner squad` without forcing player ownership.
- Preserve combat autonomy readability:
  - player control is `move_only`
  - squad actions are driven by `fixed_role_ai`

## 2. Entry-Time Only Selection

- Roster composition is chosen at entry time and becomes locked for the entire run/stage.
- When entry is initiated from Hub portal browse/confirm, roster editing is allowed during the browse phase; the final committed snapshot is locked at confirm.
- No mid-run roster swap is allowed in v1, including loaner stages.

## 3. Two Entry Branches

### 3.1 Player Entry (Preset / Manual Picks)

Normal stages/modes use player entry:

1. Player chooses entry method:
   - load an existing `preset`
   - or manually pick **1..6** hero identities from owned heroes
2. Validate roster:
   - must satisfy the no-duplicate identity constraint
   - every selected identity must be available (owned/unlocked per mode rules)
   - count must be within **1..6**
3. Confirm and lock roster for the run.

Validation / preset loading failure handling:

- If a preset references locked/missing heroes: v1 implementation must block load or guide substitution so the final committed list remains valid (distinct ids, length 1..6).

### 3.2 System Entry (Special Stage Loaner Squad)

For special stages, the system may override player entry:

1. System provides a `loaner squad` definition:
   - `K` distinct hero identities, `1 <= K <= 6` unless the stage doc specifies otherwise
   - role/identity metadata required for `fixed_role_ai`
   - optional `loaner_profile` describing the effective progression state for this stage
2. UI presents the loaner roster; player does not need to own those heroes.
3. Player confirms (or auto-confirms) and the roster locks.

## 4. Loaner Profile Semantics (Progression State Source)

For a `loaner squad` run, combat uses `loaner_profile` as the effective progression state when provided:

- overrides effective `hero_level`, rank tier, and skill enhancement state for the run
- role tags remain identity-driven and map to `fixed_role_ai`

### 4.1 Profile Parameters

See:

- `docs/design/feature-systems/values/loaner-squad-values.csv`

At minimum, a profile may define:

- `loaner_profile_level`
- `loaner_profile_rank_tier`
- `loaner_profile_skill_enhancement_level`

## 5. Implementation-Facing Interfaces (Semantic)

- `selectEntryMode(modeNodeId)`
- `chooseSquadEntry(method, presetIndex?, heroIdList?: HeroId[])`
- `validateSquadEligibility(heroIdList: HeroId[], method) -> ok|reason`
- `lockSquadForRun(heroIdList: HeroId[])`
- `systemProvideLoanerSquad(stageId) -> loanerDefinition`
