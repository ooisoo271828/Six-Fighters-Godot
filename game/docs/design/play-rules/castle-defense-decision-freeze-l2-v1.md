# Castle Defense Decision Freeze L2 v1

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Freeze of confirmed L2 decisions for castle defense mode.
Related: docs/design/play-rules/castle-defense-framework.md

## 1. Frozen Decisions
1. `defense_core_position`: multi_structures
2. `enemy_approach_pattern`: waves_mixed
3. `upgrade_resource_shape`: generic_materials
4. `enemy_target_priority`: balanced
5. `wave_break_windows`: yes_short_breaks
6. `tower_upgrade_structure`: branchful_tree
7. `enemy_architecture_binding`: loose_binding
8. `material_drop_link`: direct_from_kill

## 2. Mandatory Terminology
- Use `multi_structures` for defense core implementation.
- Use `waves_mixed` for enemy wave pacing.
- Use `generic_materials` for upgrade resource shape.
- Use `balanced` for enemy target priority.
- Use `yes_short_breaks` for wave upgrade/build windows.
- Use `branchful_tree` for tower upgrade structure.
- Use `loose_binding` for enemy-architecture binding.
- Use `direct_from_kill` for material drop link.

## 3. Governance Rule
Any change to frozen L2 decisions requires ADR before design/values updates.

## 4. L3 Entry Anchors
- Tower function tree nodes and upgrade dependency graph.
- Mixed wave archetypes and their composition schedule.
- Drop tables and resource flow validation.

