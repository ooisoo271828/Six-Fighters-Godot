# Deep Dungeon Decision Freeze L2 v1

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Freeze of confirmed L2 decisions for deep dungeon mode.
Related: docs/design/play-rules/deep-dungeon-framework.md

## 1. Frozen Decisions
1. `floor_structure`: simple_rooms_loop
2. `scaling_approach`: milestone_spike
3. `milestone_trigger`: either_combo
4. `key_reward_variance`: mixed_variance_everywhere
5. `progression_goal`: room_clear
6. `milestone_boss_pool`: mechanic_prefix_random
7. `max_floor_and_exit`: segments_and_extract
8. `reward_settlement_on_exit`: combo_milestone_linear

## 2. Mandatory Terminology
- Use `simple_rooms_loop` for the per-floor room structure.
- Use `milestone_spike` for the stepwise growth with key-floor spikes.
- Use `either_combo` for milestone selection between elite and boss nodes.
- Use `mixed_variance_everywhere` for overall reward variance style.
- Use `room_clear` as the per-floor completion goal.
- Use `mechanic_prefix_random` for milestone boss/elite mechanism generation.
- Use `segments_and_extract` for per-segment settlement and carrying rewards out.
- Use `combo_milestone_linear` for reward settlement: milestone amplification + linear base.

## 3. Governance Rule
Any change to frozen L2 decisions requires ADR before design docs or CSV values updates.

## 4. L3 Entry Anchors
- Segment size and checkpoint scheduling rules.
- Milestone selection algorithm and room/elite/boss node weighting.
- Reward sampling model linking prefixes to drops.

