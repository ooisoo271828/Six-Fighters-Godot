# Castle Defense Decision Freeze L3 v1

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Freeze of key L3 entry decisions for castle defense mode.
Related: docs/design/play-rules/castle-defense-l3.md

## 1. Frozen Decisions (L3)
1. `tower_prereq_style`: hard_prereq_graph
2. `mixed_wave_schedule`: weighted_random_per_run
3. `drop_encoding`: tiered_drop_table
4. `upgrade_cost_shape`: linear_cost_increase
5. `upgrade_time_policy`: no_time_restriction

## 2. Mandatory Terminology
- Use `hard_prereq_graph` for tower unlock dependency style.
- Use `weighted_random_per_run` for mixed wave schedule.
- Use `tiered_drop_table` for direct-from-kill tiered material encoding.
- Use `linear_cost_increase` for upgrade cost progression shape.
- Use `no_time_restriction` for upgrade operations timing in v1.

## 3. Governance Rule
Any change to these L3 decisions requires ADR before updating design/values.

