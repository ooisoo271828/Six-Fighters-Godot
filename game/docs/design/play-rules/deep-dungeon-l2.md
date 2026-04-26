# Deep Dungeon L2

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L2 detailed rules for deep dungeon: room loop structure, milestone spikes, segment settlement, and reward model.
Related: docs/design/play-rules/deep-dungeon-decision-freeze-l2-v1.md

## 1. Mode Contract
- Endless-like multi-floor push progression.
- Each floor follows a simple and readable room loop.
- Difficulty and reward quality rise with depth, with stepwise milestone spikes.
- Session settlement happens per segment, with carried rewards.

## 2. Per-Floor Structure
- Floor structure: `simple_rooms_loop`.
- Core loop: clear room chain -> reach floor checkpoint -> prepare next floor.
- Room types repeat with depth-banded variations (enemy skill complexity increases by depth band).

## 3. Growth Model (Milestone Spikes)
- Scaling approach: `milestone_spike`.
- Most floors provide steady progression.
- Key floors introduce a spike to create memorable difficulty and reward peaks.
- Milestone trigger selection: `either_combo` (milestone can be elite and/or boss nodes).

## 4. Completion Goal
- Progression goal per floor: `room_clear`.
- Players must achieve a required room completion threshold to advance.

## 5. Milestone Boss/Elite Generation
- Milestone mechanism generation: `mechanic_prefix_random`.
- Boss/elite identity comes from a prefix/mechanic pool.
- The mechanism prefix guarantees consistency within a threat family while still allowing variety.

## 6. Reward Variance and Settlement
- Reward variance style: `mixed_variance_everywhere`.
- Reward settlement rule on exit: `combo_milestone_linear`.
  - Base value grows linearly by depth.
  - Milestone floors amplify reward outputs.

## 7. Segment Settlement and Carry Out
- Maximum floor and exit model: `segments_and_extract`.
- Each segment provides a settlement snapshot that can be carried out as progression rewards.
- Exiting between segments preserves the segment settlement while preventing runaway advantage.

## 8. Compatibility with Combat Core Freeze
- Control remains `move_only`.
- Squad action remains `fixed_role_ai`.
- Hazard semantics must follow `strict_global_standard`.

## 9. L3 Entry Focus
- Segment size, checkpoint scheduling, and exit timing UX.
- Milestone weighting by depth bands.
- Prefix-to-drop mapping and reward sampling rules.

