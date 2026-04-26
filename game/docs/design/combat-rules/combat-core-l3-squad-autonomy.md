# Combat Core L3: Squad Autonomy

Status: Approved
Version: v1.1
Owner: Design
Last Updated: 2026-03-21
Scope: L3 autonomous behavior details approved for v1, including variable active roster size (1..6 heroes).
Related: docs/design/combat-rules/combat-core-decision-freeze-v1.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

## 1. Approved Autonomy Model
- Control mode is fixed: `move_only` + `fixed_role_ai`.
- No tactical profile switching in v1.
- Behavior logic is deterministic by role priority.
- **Active roster size**: autonomy runs independently for **each spawned hero entity** (`1..6` per run). There is no special-case “fill empty slots” behavior in v1; missing role coverage is a player build choice, not an AI substitute for extra heroes.

## 2. Behavior Pipeline
Each hero resolves behavior in this order:
1. Survival check
2. Role action selection
3. Opportunity action check

## 3. Role Priority
- Frontliner: zone control and pressure absorption.
- DPS: uptime-first damage with threat-aware repositioning.
- Support: emergency sustain and utility timing.
- Control: interruption and crowd pressure reduction.

## 4. Fairness Constraints
- Avoid decision oscillation loops in autopilot movement.
- Ensure responses come from readable threats.
- Keep autonomy predictable enough for build planning.

## 5. v1 Lock
Per-hero behavior customization is out of scope for v1.

