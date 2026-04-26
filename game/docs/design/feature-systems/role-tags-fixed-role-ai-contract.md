# Role Tags -> fixed_role_ai Contract

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Defines how hero role tags map into the autonomous behavior model under `fixed_role_ai` (v1 autonomy governance).
Related: docs/design/feature-systems/hero-squad-baseline.md; docs/design/combat-rules/combat-core-l3-squad-autonomy.md; docs/design/feature-systems/skill-enhancement-logic.md; docs/design/feature-systems/hero-skill-template-v1.md

Notes:

## 1. Role Tag Families (Vocabulary)
Baseline hero role families:
- `frontliner`: pressure absorption and disruption
- `dps`: sustained/burst output
- `support`: sustain and utility timing
- `control`: interruption/slow/group pressure reduction

## 2. Mapping Contract (Deterministic Autonomy)
Combat core executes hero behavior deterministically for v1 using the autonomy pipeline:
1. Survival check
2. Role action selection
3. Opportunity action check

This contract defines only what the combat core is allowed to consider as “role input”:
- The hero's role family determines the role action selection behavior.
- If survival check indicates emergency behavior is required, survival actions must take precedence regardless of role.

## 3. Role Action Priority (Tie Resolution)
Within role action selection, when multiple role tags exist:
- Choose the role family by deterministic priority defined in design:
  `frontliner` > `dps` > `support` > `control`

This is required to avoid autopilot oscillation loops and to keep behavior predictable enough for build planning.

## 4. Skill Enhancement Compatibility
Skill enhancement must remain compatible with role-driven autonomy:
- After enhancement, the hero becomes better at the same role family behavior patterns.
- Opportunity checks still follow the pipeline order, and must not break readability assumptions.

## 5. Implementation-Facing Interfaces (Semantic)
- `resolveRoleFamily(heroIdentity) -> roleFamily`
- `selectRoleAction(heroIdentity, roleFamily, tacticalContext) -> action`

