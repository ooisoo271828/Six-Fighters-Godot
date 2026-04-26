# Deep Dungeon Framework

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Level-1 framework for multi-floor deep dungeon progression mode.
Related: docs/design/play-rules/deep-dungeon-decision-freeze-l2-v1.md

## 1. Mode Goal and Player Motivation
- Offer endless-like floor push progression.
- Reward build strength and endurance through rising challenge layers.
- Provide high-value reward milestones at deeper floors.

## 2. Entry/Exit and Loop
- Entry: choose current target floor range.
- Loop: clear floor combat rooms and advance.
- Exit: leave after progress checkpoint or fail out.

## 3. Core Rules
1. Floor structure is simple and fast to parse (`simple_rooms_loop` at L2).
2. Monster strength scales with floor depth.
3. Enemy skill complexity increases with depth bands.
4. Reward quality scales with floor milestones (milestone spikes at L2).
5. Periodic checkpoint floors reduce frustration.

## 4. Fail and Reward Rule
- Failure grants floor-progress based partial rewards.
- Reaching milestone floors grants persistent bonus rewards.

## 5. Compatibility with Combat Freeze
- Keeps `move_only` and `fixed_role_ai`.
- Uses shared hazard signal standards.
- Pressure increase emphasizes sustained endurance, not control complexity.

## 6. Resource and Progression Interface
- Supplies scaling materials for mid-to-late growth systems.
- Acts as repeatable mode for power validation.

## 7. Risks and Open Items
- Power inflation risks if deep rewards outpace other modes.
- Floor scaling formulas need anti-wall smoothing.
- Reset season cadence is not yet decided.
 - L2-to-L3 decomposition required: segment rules, milestone weighting, prefix-to-drop mapping.

