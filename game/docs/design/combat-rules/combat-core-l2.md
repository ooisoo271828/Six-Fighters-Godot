# Combat Core L2

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L2 combat rules approved for v1.
Related: docs/design/combat-rules/combat-core-decision-freeze-v1.md

## 1. Core Interaction
- Player direct control is `move_only` via one transparent joystick.
- Squad behavior is autonomous and follows `fixed_role_ai`.
- No in-combat micro control for individual hero actions.

## 2. Combat Tempo
- Tempo target is `mid_balanced`.
- Encounters must include breathing windows between pressure spikes.
- Peak moments occur in elite/boss windows.

## 3. Boss Rule
- Boss structure is `phase_3_to_4_flexible`.
- Transition mode is `hp_plus_time`.
- Boss phases must preserve readability and avoid long invulnerability chains.

## 4. Readability Rule
- Policy is `mixed_cap_soft_normal_hard_critical`.
- Critical hazards always override cosmetic effects in visual priority.
- Hazard signal grammar is `strict_global_standard`.

## 5. Fail and Reward
- Fail policy is `partial_reward`.
- Player should receive progression-relevant partial rewards on failure.

## 6. Run Duration Target
- Normal stage target: 3 to 5 minutes.
- Boss stage target: 5 to 7 minutes.

## 7. In-Run Choice Intensity
- Roguelite in-run intensity is `medium`.
- Each run should offer limited but meaningful temporary decisions.

## 8. Change Control
Any change to this L2 rule set requires ADR per freeze policy.

