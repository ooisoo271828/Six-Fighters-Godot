# Ruins Escape Decision Freeze L2 v1

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Freeze of six confirmed L2 decisions for ruins escape mode.
Related: docs/design/play-rules/ruins-escape-framework.md

## 1. Frozen Decisions
1. `loss_severity`: high_loss_80
2. `extraction_model`: multi_hidden_exits
3. `protection_mechanism`: consumable_insurance
4. `chaser_trigger`: hybrid_trigger
5. `run_duration_target`: short_6_to_10
6. `extraction_reward_shape`: stable_plus_rare

## 2. Mandatory Terminology
- Use `high_loss_80` and `death_loss_ratio=0.8` for loss policy.
- Use `multi_hidden_exits` for extraction model.
- Use `consumable_insurance` for protection mechanism.
- Use `hybrid_trigger` for chaser logic.
- Use `short_6_to_10` for run duration target.
- Use `stable_plus_rare` for reward structure.

## 3. Governance Rule
Any change to frozen L2 decisions requires ADR before document or CSV updates.

## 4. L3 Entry Anchors
- Map branch layering and room-weight generation rules.
- Chaser behavior tiers and spawn pool definition.
- Insurance economy and acquisition path.

