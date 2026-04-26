# Deep Dungeon L3

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L3 entry rules for deep dungeon: segment sizing, exit settlement, milestone selection, and prefix-to-reward encoding.
Related: docs/design/play-rules/deep-dungeon-decision-freeze-l3-v1.md

## 1. Mode Contract (L3)
- Inherits L2: `simple_rooms_loop`, `milestone_spike`, `either_combo`, `mechanic_prefix_random`, `segments_and_extract`, and `combo_milestone_linear`.
- L3 specifies implementable algorithms and contracts for segment and milestone behavior.

## 2. Segment Sizing (L3)
- Segment size model: `adaptive_by_build_performance`.
- The system uses a build-performance proxy (e.g., clear speed and damage efficiency) to select a reasonable segment length band.
- Goal: preserve flow without over-stretching or overly shortening segments across different squad builds.

## 3. Segment Exit / Settlement Trigger (L3)
- Segment exit trigger: `after_segment_clear`.
- After meeting the segment clear condition, players receive the segment settlement snapshot and can carry rewards out.

## 4. Milestone Layering & Selection (L3)
- Milestone count policy: `adaptive_to_floor_clear`.
- The number of milestone layers inside a segment adapts based on segment completion quality.

## 5. Prefix to Reward Encoding (L3)
- Prefix encoding: `prefix_bonus_on_base`.
- A mechanic prefix modifies or amplifies the reward outcome while the base reward curve remains on the `combo_milestone_linear` path.
- Prefix reroll policy: `costed_reroll`.
  - Each segment can spend a defined resource to reroll the prefix once (v1 contract; exact currency is configurable).

## 6. L4 Entry Focus
- Implement the adaptive proxy calculation inputs.
- Define milestone selection weighting and room-to-drop mapping.
- Define reroll currency and limits.

