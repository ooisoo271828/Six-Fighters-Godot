# Hub World Entry Rules

Status: Draft  
Version: v0.2  
Owner: Design  
Last Updated: 2026-03-21  
Scope: Hub world (town/village scene) and portal interaction rules that lead into gameplay runs, including roster snapshot/locking and loaner squad/profile behavior.  
Related: docs/design/play-rules/gameplay-cross-mode-rules.md; docs/design/feature-systems/squad-selection-and-entry-rules.md; docs/design/feature-systems/six-unit-squad-assembly-contract.md; docs/design/feature-systems/values/loaner-squad-values.csv; docs/design/combat-rules/combat-core-l3-squad-autonomy.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

Notes:

## 1. What the Hub Is

- The Hub world is a non-combat scene shown after game launch.
- The player can freely move within the Hub world and interact with NPCs and facilities.
- Combat is not started in the Hub world; combat control semantics apply only after a gameplay run begins.

## 2. Hub Interactions (NPC + Facilities)

### 2.1 NPC units

- NPCs provide world context, onboarding hints, and navigation guidance.
- NPC interaction does not change combat control model.

### 2.2 Portals (Gameplay Entry Facilities)

- Each portal corresponds to a gameplay entry target (mode node/stage entry).
- When the player approaches or activates a portal, the Hub opens the browse UI for that target.

## 3. Portal Browse -> Confirm

The entry session is split into two phases:

1. Browse (preview/inspection phase)
2. Confirm (entry/commit phase)

### 3.1 Browse Phase

During browse:

- The player can view run/mode entry information (what they will enter).
- The player can decide an entry method, which may include:
  - selecting a `preset` or manually choosing **1..6** hero identities (player entry)
  - accepting a system `loaner squad` for special stages (system entry)

Hub may allow roster editing because commit happens at confirm.

### 3.2 Confirm Phase (Roster Snapshot Commit)

At confirm:

1. The game generates a **locked roster snapshot** containing `N` distinct hero identities (`1 <= N <= 6`).
2. The snapshot is locked for the entire run/stage.
3. The run starts under:
   - `move_only` player control model
   - `fixed_role_ai` squad autonomy driven by role tags

No mid-run roster swap is allowed in v1.

## 4. Roster Editing Semantics in Hub

Your current roster configuration in the Hub is editable until confirm:

- Players can switch `preset` or manually re-select heroes before confirm.
- The committed snapshot must satisfy:
  - **1..6** hero identities
  - **no duplicate** identities

Once confirm is accepted, the committed snapshot cannot be changed.

## 5. Special Stages: System Loaner Squad

For some portals/targets:

- The system provides a `loaner squad` that the player does not need to own/unlock.
- The system may also provide a `loaner_profile` as the effective progression state for this stage/run.

During this run:

- combat uses role tags mapped to `fixed_role_ai`
- progression effectiveness may be overridden by `loaner_profile` (inputs sourced from `values/loaner-squad-values.csv`)

## 6. Relationship to Other Design Modules

- Player preset/manual selection and validation rules: `docs/design/feature-systems/squad-selection-and-entry-rules.md`
- Roster uniqueness and entry-only locking: `docs/design/feature-systems/six-unit-squad-assembly-contract.md`
- Cross-mode session entry structure: `docs/design/play-rules/gameplay-cross-mode-rules.md`
- Squad autonomy: `docs/design/combat-rules/combat-core-l3-squad-autonomy.md`

## 7. Implementation-Facing Interfaces (Semantic)

- `openHubPortal(portalId)`: opens browse UI for the portal target.
- `browseRunTarget(targetId)`: provides run/mode preview and entry-method selection.
- `confirmEnterRun(entryMethod, presetIndex?, heroIdList?: HeroId[], stageId?)`:
  - produces and locks the roster snapshot for the run
  - resolves player entry vs system loaner entry
- `resolveLoanerProfile(stageId) -> loanerProfile`: supplies the effective progression state.
