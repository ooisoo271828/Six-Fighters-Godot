# Combat Core Decision Freeze v1

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Freeze of combat-core decisions from three discussion rounds.
Related: docs/design/combat-rules/combat-core-baseline.md

## 1. Frozen Decisions
1. `control_depth`: move_only
2. `combat_tempo`: mid_balanced
3. `boss_structure`: phase_3_to_4_flexible
4. `readability_policy`: mixed_cap_soft_normal_hard_critical
5. `fail_reward_policy`: partial_reward
6. `boss_transition_mode`: hp_plus_time
7. `ai_control_mode`: fixed_role_ai
8. `inrun_roguelite_intensity`: medium
9. `hazard_signal_policy`: strict_global_standard
10. `combat_duration_target`: normal_3_to_5_min_boss_5_to_7_min

## 2. Mandatory Terminology
- Use `fixed_role_ai`, not free text variants.
- Use `hp_plus_time` for boss transitions.
- Use `strict_global_standard` for hazard signal policy.
- Use `partial_reward` for fail compensation policy.

## 3. Rule on Change
From this point, any change to these 10 decisions requires an ADR before design updates.

## 4. Synced Files
- `docs/design/combat-rules/combat-core-l2.md`
- `docs/design/combat-rules/combat-core-l3-squad-autonomy.md`
- `docs/design/combat-rules/combat-core-l3-boss-phase-grammar.md`
- `docs/design/combat-rules/combat-core-l3-readability-guardrails.md`
- `docs/design/combat-rules/combat-core-l3-review-note.md`
- `docs/design/combat-rules/values/combat-core-l2-values.csv`
- `docs/design/combat-rules/values/combat-core-l3-values.csv`

