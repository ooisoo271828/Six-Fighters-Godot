# Squad Selection and Entry Rules

Status: Active  
Version: v1.0  
Owner: Design  
Last Updated: 2026-05-23  
Scope: Player/system rules for selecting a roster of **1..6** hero identities for a stage/run, including formation layout, preset-based entry, and system `loaner squad` entry for special stages.  
Related: docs/design/feature-systems/six-unit-squad-assembly-contract.md; docs/design/play-rules/gameplay-cross-mode-rules.md; docs/design/combat-rules/combat-core-l3-squad-autonomy.md; docs/design/feature-systems/role-tags-fixed-role-ai-contract.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

---

## 1. Design Goals

- Ensure squad selection is predictable and implementation-friendly.
- Support quick re-entry via `preset`.
- Allow special stages to use `loaner squad` without forcing player ownership.
- Preserve combat autonomy readability:
  - player control is `move_only`
  - squad actions are driven by `fixed_role_ai`
- Formation layout is **fixed-position**: each hero occupies a named slot, and the slot determines its position on the battlefield.

---

## 2. Roster Model: Fixed 6-Slot, 1..6 Active

### 2.1 Core Rules

- The squad uses a **fixed 6-slot array** (`SQUAD_SIZE = 6`).
- Each slot can hold one hero identity or be **empty** (`""`).
- **Minimum 1 hero, maximum 6 heroes**. Any count in 1..6 is a valid, playable squad.
- Empty slots are preserved in storage — they are **not** compressed out. This is critical because slot index determines formation position.

### 2.2 Slot Layout (Cone Formation)

The 6 slots form a **cone/arrow pattern** pointing toward the enemy (negative Y = forward):

```
        [0] 前中         ← Front center (vanguard)
     [1]     [2]         ← Mid left / Mid right
  [3]    [4]    [5]      ← Back left / Back center / Back right
```

| Slot Index | Position Name | Offset (px) | Description |
|---|---|---|---|
| 0 | 前中 | (0, -60) | Front center — typically the tank/vanguard |
| 1 | 中左 | (-45, 0) | Mid left |
| 2 | 中右 | (+45, 0) | Mid right |
| 3 | 后左 | (-70, +60) | Back left |
| 4 | 后中 | (0, +60) | Back center |
| 5 | 后右 | (+70, +60) | Back right |

These offsets are relative to the squad's center point. The formation applies identically in Hub (peaceful) and Arena (combat) scenes.

### 2.3 Why Fixed Slots, Not Variable-Length List

- **Positional data must be index-stable**: If hero C is in slot 2 (中右), it must always be in slot 2 regardless of how many other heroes are in the squad. A variable-length list that compresses empty slots would break this.
- **Formation is positional**: Each slot maps to a specific battlefield position. A 3-hero squad using slots 0, 2, 4 has a different spread than one using slots 0, 1, 2.
- **Storage format**: `["ironwall", "", "ember", "", "moss", ""]` — 6 elements, empty strings for unused slots.

---

## 3. Entry-Time Only Selection

- Roster composition is chosen at entry time and becomes locked for the entire run/stage.
- When entry is initiated from Hub portal browse/confirm, roster editing is allowed during the browse phase; the final committed snapshot is locked at confirm.
- No mid-run roster swap is allowed in v1, including loaner stages.

---

## 4. Two Entry Branches

### 4.1 Player Entry (Preset / Manual Picks)

Normal stages/modes use player entry:

1. Player chooses entry method:
   - load an existing `preset`
   - or manually pick **1..6** hero identities from owned heroes
2. Validate roster:
   - must satisfy the no-duplicate identity constraint (same hero cannot occupy two slots)
   - every selected identity must be available (owned/unlocked per mode rules)
   - active count must be within **1..6**
3. Confirm and lock roster for the run.

Validation / preset loading failure handling:

- If a preset references locked/missing heroes: v1 implementation must block load or guide substitution so the final committed list remains valid (distinct ids, count 1..6).

### 4.2 System Entry (Special Stage Loaner Squad)

For special stages, the system may override player entry:

1. System provides a `loaner squad` definition:
   - `K` distinct hero identities, `1 <= K <= 6` unless the stage doc specifies otherwise
   - role/identity metadata required for `fixed_role_ai`
   - optional `loaner_profile` describing the effective progression state for this stage
2. UI presents the loaner roster; player does not need to own those heroes.
3. Player confirms (or auto-confirms) and the roster locks.

---

## 5. Loaner Profile Semantics (Progression State Source)

For a `loaner squad` run, combat uses `loaner_profile` as the effective progression state when provided:

- overrides effective `hero_level`, rank tier, and skill enhancement state for the run
- role tags remain identity-driven and map to `fixed_role_ai`

### 5.1 Profile Parameters

See:

- `docs/design/feature-systems/values/loaner-squad-values.csv`

At minimum, a profile may define:

- `loaner_profile_level`
- `loaner_profile_rank_tier`
- `loaner_profile_skill_enhancement_level`

---

## 6. Data Flow: Single Source of Truth

### 6.1 Architectural Principle

All squad/formation data has a **single source of truth** in `GameManager`. No scene duplicates formation offsets, roster state, or spawn logic.

```
GameManager (single source of truth)
  ├── FORMATION_OFFSETS (only definition)
  ├── SQUAD_SIZE = 6
  ├── selected_roster: Array[String] (6-element, empty = unused slot)
  ├── set_roster() / get_roster() (only write/read interface)
  ├── get_formation_offset(slot_index)
  └── spawn_squad() (only spawn interface)
```

### 6.2 Data Flow

```
SquadEditor (UI popup in Hub)
    │  _on_apply / _on_close
    ▼
GameManager.set_roster(Array[String])   ← stores 6-element array, emits EventBus
    │
    │  (scene change — GameManager singleton persists)
    ▼
GameManager.spawn_squad(parent, center, config)
    │  reads get_roster(), iterates 6 slots
    │  looks up HeroRegistry for each non-empty hero_id
    │  positions at center + FORMATION_OFFSETS[slot_index]
    ▼
{ "heroes": Array[Hero], "slot_indices": Array[int] }
    │
    ▼
Hub Scene / Arena Scene
    │  stores heroes[] and hero_slot_indices[]
    │  every frame: lerp heroes toward formation targets
    ▼
Hero positioned at slot_index's formation offset
```

### 6.3 Rules for New Scenes

Any new gameplay scene (boss rush, dungeon, PvP, etc.) **must** use `GameManager.spawn_squad()` for hero generation. Do not duplicate formation offsets or spawn logic.

```gdscript
# Standard scene entry pattern
var result := GameManager.spawn_squad(parent, center_pos, {
    "hero_registry": hero_registry,
    "skill_registry": skill_registry,
    "add_shadow": true,
})
heroes = result["heroes"]
hero_slot_indices = result["slot_indices"]
```

---

## 7. Squad Editor Interaction Model

### 7.1 Overview

The squad editor is an in-scene popup overlay (not a separate scene). It appears centered on screen when the player presses the "Squad Edit" button in the Hub toolbar.

### 7.2 Interaction Flow

1. Hero cards are displayed in a scrollable grid. Only owned heroes are clickable; unowned heroes appear grayed out with a lock indicator.
2. Player taps a hero card to select it (highlighted with gold border).
3. Player taps one of the 6 formation slot buttons to place the hero.
   - If the hero was already in another slot, it is **removed from the old slot** first (no duplicate placement).
   - If no hero is selected and the player taps an occupied slot, that slot is **cleared**.
4. A counter shows `N / 6` active heroes.

### 7.3 Save Behavior

- **Confirm**: Saves current roster to GameManager, closes editor, respawns heroes in Hub.
- **Close/Back**: Also saves current roster (no discard path). Both actions persist the player's work.
- **Reset**: Clears all 6 slots to empty.

### 7.4 Constraints

- Minimum 1 hero should be in the squad before entering combat (validated at portal confirm time).
- Same hero identity cannot occupy multiple slots (enforced by the UI removing from old slot).

---

## 8. Portal Entry Rules

### 8.1 Flow

1. Player walks the lead hero near the portal in Hub.
2. Confirmation dialog appears: "进入竞技场？"
3. On confirm:
   - Roster is locked (`GameManager.set_roster(GameManager.get_roster())`)
   - Scene changes to Arena (`res://scenes/arena/battle.tscn`)
4. On cancel: dialog closes, player can continue editing.

### 8.2 Entry Validation (Design Target)

Before locking the roster at portal confirm, validate:

- At least 1 active hero in the roster
- No duplicate hero identities
- All selected heroes are owned/unlocked

If validation fails, show an error message and prevent entry.

---

## 9. Persistence (Planned)

### 9.1 Current State

The roster is stored in-memory in `GameManager.selected_roster`. It persists across scene changes (GameManager is a singleton) but is lost on game restart.

### 9.2 Target: Multi-Save-Slot System

The project targets a **single-player game with multiple save slots**. Squad roster will be persisted as part of the save data:

- Save file includes the full 6-element roster array
- On load, roster is restored to `GameManager.selected_roster`
- Multiple independent save slots allow the player to maintain different progress/rosters

This is a planned feature for a future implementation phase.

---

## 10. Implementation-Facing Interfaces

### 10.1 Current (Implemented)

| Interface | Location | Description |
|---|---|---|
| `GameManager.set_roster(roster)` | `scripts/core/game_manager.gd` | Stores 6-element roster, emits `roster_changed` |
| `GameManager.get_roster()` | `scripts/core/game_manager.gd` | Returns full 6-element roster |
| `GameManager.get_active_roster()` | `scripts/core/game_manager.gd` | Returns non-empty heroes only (UI display) |
| `GameManager.get_formation_offset(slot)` | `scripts/core/game_manager.gd` | Returns Vector2 offset for slot index |
| `GameManager.spawn_squad(parent, center, config)` | `scripts/core/game_manager.gd` | Spawns hero nodes, returns `{ heroes, slot_indices }` |
| `SquadEditor` | `scripts/hub/squad_editor.gd` | In-scene popup for roster editing |
| `EventBus.roster_changed` | `scripts/core/event_bus.gd` | Signal emitted on roster change |

### 10.2 Planned (Not Yet Implemented)

| Interface | Description |
|---|---|
| `saveSquadPreset(index, roster)` | Save current roster to a preset slot |
| `loadSquadPreset(index) -> roster` | Load roster from a preset slot |
| `validateSquadEligibility(roster) -> ok\|reason` | Check ownership, duplicates, count |
| `systemProvideLoanerSquad(stageId)` | Get system-defined roster for special stages |
| `resolveLoanerProfile(stageId)` | Get progression overrides for loaner runs |
| Save file persistence | Multi-save-slot system for roster + game progress |

---

## 11. V1 Scope Summary

| Feature | Status |
|---|---|
| Fixed 6-slot roster with empty placeholders | Implemented |
| Cone formation layout (6 named positions) | Implemented |
| Single source of truth (GameManager) | Implemented |
| Squad editor popup in Hub | Implemented |
| Portal confirm → Arena entry | Implemented |
| Roster persists across scene changes | Implemented |
| Entry-time lock, no mid-run swap | Implemented |
| Preset save/load (up to 5 slots) | Design target |
| Validation (ownership, duplicates, count) | Design target |
| Loaner squad system | Design target |
| Multi-save-slot persistence | Design target |
