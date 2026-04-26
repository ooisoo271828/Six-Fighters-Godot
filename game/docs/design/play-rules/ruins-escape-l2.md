# Ruins Escape L2

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L2 detailed rules for death settlement, chaser triggers, extraction, and insurance.
Related: docs/design/play-rules/ruins-escape-decision-freeze-l2-v1.md

## 1. Mode Contract
- High-risk exploration mode with extraction-based reward conversion.
- Core loop: explore -> loot -> risk escalation -> extract or die.

## 2. Death Settlement
- Frozen loss severity: `high_loss_80`.
- Numeric contract: `death_loss_ratio=0.8`.
- Protected outcomes come only from `consumable_insurance`.

## 3. Extraction Flow
- Extraction model: `multi_hidden_exits`.
- Players discover exits through room exploration and event reveals.
- Successful extraction converts carried loot using `stable_plus_rare` reward shape.

## 4. Chaser Trigger Logic
- Trigger mode: `hybrid_trigger`.
- Pressure increases with both run duration and carried loot value.
- Chaser encounters are intended to force route and timing decisions.

## 5. Insurance Mechanism
- Protection mechanism: `consumable_insurance`.
- Insurance is consumed per run when active.
- Insurance preserves configured protected value/slots on death.

## 6. Duration Target
- Target run duration: `short_6_to_10`.
- Map event density and exit reveal cadence must support this range.

## 7. Interfaces
- Progression interface: delivers rare materials with extraction success emphasis.
- Economy interface: insurance item demand and acquisition path must stay sustainable.

## 8. L3 Entry Focus
- Branch-room generation weights and reveal logic.
- Chaser tiering and spawn pool escalation model.
- Insurance economy and anti-frustration safeguards.

