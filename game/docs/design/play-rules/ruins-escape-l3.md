# Ruins Escape L3

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L3 entry rules for ruins escape mode: room/branch generation, chaser tiering, and insurance economy.
Related: docs/design/play-rules/ruins-escape-decision-freeze-l3-v1.md

## 1. Mode Contract (L3)
- Inherits L2: `multi_hidden_exits` + `hybrid_trigger` + `consumable_insurance` + `short_6_to_10` + `stable_plus_rare`.
- Adds L3 entry rules that make L2 mechanics implementable and testable.

## 2. Room / Branch Generation (L3)
### 2.1 Room Generation Rule
- Room generation uses bounded depth-banded weighting: `depth_banded_weights`.
- Same depth band favors similar room archetypes, keeping runs learnable while still varying routes.

### 2.2 Branch Control
- Main path bias exists: the generation prioritizes a reachable exploration backbone.
- Side branches are allowed but must not overrun the run time target.

### 2.3 Depth Bands (L3 Handling)
- Depth bands affect:
  - enemy strength banding
  - chaser spawn pool escalation
  - loot tier exposure

## 3. Chaser Tiering (L3)
### 3.1 Tier Count
- Chaser uses `3_tiers`.

### 3.2 Trigger Logic (L3)
- Chaser tier selection still follows L2: `hybrid_trigger` (run duration + carried loot value).
- Each tier has a distinct threat pool and behavior aggressiveness level.

### 3.3 Readability Requirement
- Tier escalation must be communicated using the global strict hazard signal policy.
- New threat types appear gradually; avoid introducing multiple unknown hazard families in one tier jump.

## 4. Insurance Economy (L3)
### 4.1 Coverage Model
- Insurance protects fixed slots: `protect-slots-fixed`.
- Protected slots count: `2_slots`.

### 4.2 Acquisition Model
- Insurance is pre-equipped by crafting/consuming resources before entering: `pre-equipped-craft`.
- No mid-run insurance crafting is assumed for v1; players plan the risk using pre-run investment.

### 4.3 Protection Mapping
- When death occurs, protected slots preserve the highest-priority loot subset defined by reward tier order.

## 5. Interfaces / Contracts
- Output to extraction: run loot persistence derived from insurance-protected subset and `stable_plus_rare` reward shaping.
- Input from combat readability system: chaser telegraphs must conform to strict global hazard signal policy.

## 6. L4 Entry Focus
- Exact room weight tables by depth band.
- Chaser tier thresholds and threat pool definition.
- Insurance crafting cost table and loot-to-slot mapping rules.

