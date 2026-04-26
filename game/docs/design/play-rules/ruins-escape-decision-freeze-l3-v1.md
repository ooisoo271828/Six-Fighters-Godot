# Ruins Escape Decision Freeze L3 v1

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Freeze of key L3 entry decisions for ruins escape mode.
Related: docs/design/play-rules/ruins-escape-l3.md

## 1. Frozen Decisions (L3)
1. `room_generation_rule`: depth_banded_weights
2. `chaser_tier_count`: 3_tiers
3. `insurance_acquisition`: pre-equipped-craft
4. `insurance_coverage`: protect-slots-fixed
5. `insurance_protected_slots_count`: 2_slots

## 2. Mandatory Terminology
- Use `depth_banded_weights` for L3 room generation.
- Use `3_tiers` for L3 chaser tier count.
- Use `pre-equipped-craft` for insurance acquisition.
- Use `protect-slots-fixed` with `2_slots` for protection coverage.

## 3. Governance Rule
Any change to these L3 decisions requires ADR before updating docs/values.

## 4. L4 Entry Anchors
- Exact room weight tables and depth band definitions.
- Chaser tier threshold mapping to spawn pools.
- Insurance crafting/consumption cost and slot mapping.

