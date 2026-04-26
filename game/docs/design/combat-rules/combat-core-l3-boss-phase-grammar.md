# Combat Core L3: Boss Phase Grammar

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L3 boss phase grammar approved for v1.
Related: docs/design/combat-rules/combat-core-decision-freeze-v1.md

## 1. Approved Phase Structure
- Bosses use `phase_3_to_4_flexible`.
- Transition mode is `hp_plus_time`.
- Every phase must be learnable and readable in portrait combat.

## 2. Phase Composition
Each phase includes:
- Threat intro signal
- Core pattern loop
- Pressure modifier
- Counter window

## 3. Phase Constraints
- Introduce at most one new mechanic per phase transition.
- Avoid long uninterrupted invulnerability windows.
- Guarantee at least one clear dodge solution for lethal patterns.

## 4. Duration Targets
- Boss total run target is 5 to 7 minutes.
- Phases should maintain pace variation with short breathing pockets.

## 5. v1 Lock
Transition trigger framework remains `hp_plus_time`; alternatives require ADR.

