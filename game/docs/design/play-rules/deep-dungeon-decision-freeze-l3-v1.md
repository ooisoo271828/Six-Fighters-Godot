# Deep Dungeon Decision Freeze L3 v1

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Freeze of key L3 entry decisions for deep dungeon mode.
Related: docs/design/play-rules/deep-dungeon-l3.md

## 1. Frozen Decisions (L3)
1. `segment_size_model`: adaptive_by_build_performance
2. `segment_exit_trigger`: after_segment_clear
3. `milestone_count_policy`: adaptive_to_floor_clear
4. `prefix_to_reward_encoding`: prefix_bonus_on_base
5. `prefix_reroll_policy`: costed_reroll

## 2. Mandatory Terminology
- Use `adaptive_by_build_performance` for L3 segment size model.
- Use `after_segment_clear` for segment exit trigger.
- Use `adaptive_to_floor_clear` for milestone count policy.
- Use `prefix_bonus_on_base` for prefix reward encoding.
- Use `costed_reroll` for prefix reroll policy.

## 3. Governance Rule
Any change to these L3 decisions requires ADR before updating docs/values.

