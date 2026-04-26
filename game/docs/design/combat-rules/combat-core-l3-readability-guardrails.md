# Combat Core L3: Readability Guardrails

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L3 readability constraints approved for v1.
Related: docs/design/combat-rules/combat-core-decision-freeze-v1.md

## 1. Approved Policy
- Readability policy: `mixed_cap_soft_normal_hard_critical`.
- Hazard signal policy: `strict_global_standard`.

## 2. Signal Language
- Same hazard family must use the same warning grammar globally.
- Critical warnings must remain stable across chapters.
- Visual style can vary, but signal semantics cannot vary.

## 3. Layer Priority
Visual priority from high to low:
1. Lethal and near-lethal hazards
2. Player-relevant warning telegraphs
3. Player and hero silhouettes
4. Ally skill effects
5. Decorative effects

## 4. Camera/Flash Constraints
- Camera shake cannot hide direction judgment.
- Screen flash cannot mask hazard boundaries at critical timing.

## 5. v1 Lock
Any request to break global signal standard requires ADR.

