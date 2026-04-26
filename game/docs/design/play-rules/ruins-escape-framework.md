# Ruins Escape Framework

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Level-1 framework synchronized with frozen L2 decisions for explore-and-extract high-risk mode.
Related: docs/design/play-rules/ruins-escape-decision-freeze-l2-v1.md

## 1. Mode Goal and Player Motivation
- Deliver high-tension exploration with meaningful risk-reward choices.
- Encourage route planning under pressure from threats and uncertainty.
- Reward successful extraction with high-value loot outcomes.

## 2. Entry/Exit and Loop
- Entry: choose ruins run and enter branching map.
- Loop: explore rooms, loot, evade/fight threats, locate extraction.
- Exit: extract with carried loot or die and lose most loot.

## 3. Core Rules
1. Map includes branches and optional side rooms.
2. Loot sources include random chests and encounter drops.
3. Death loss severity is frozen as `high_loss_80`.
4. Chaser pressure trigger is frozen as `hybrid_trigger` (time + loot value).
5. Extraction model is frozen as `multi_hidden_exits`.
6. Protection mechanism is frozen as `consumable_insurance`.

## 4. Fail and Reward Rule
- On death, run settlement uses `death_loss_ratio=0.8`.
- On successful extraction, reward shape is frozen as `stable_plus_rare`.
- Run duration target is frozen as `short_6_to_10`.

## 5. Compatibility with Combat Freeze
- Uses `move_only` + `fixed_role_ai`.
- Threat readability must follow strict global signal policy.
- High tension comes from routing and risk decisions, not extra control inputs.

## 6. Resource and Progression Interface
- Produces high variance, high upside rewards.
- Supports rare-material acquisition paths for advanced upgrades.

## 7. Risks and Open Items
- High-loss pressure can still harm retention if insurance access is too narrow.
- Hidden exit distribution may create large run variance without map-weight safeguards.
- Chaser escalation pacing requires L3 decomposition and validation.

