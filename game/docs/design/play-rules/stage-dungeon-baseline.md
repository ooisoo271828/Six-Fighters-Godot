# Stage Dungeon Baseline

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Linear stage dungeon baseline logic (used by mainline Chapter pacing). Numeric tuning lives in `values/*.csv`.
Related: docs/design/combat-rules/combat-core-decision-freeze-v1.md

## 1. Role of Stage Dungeons
- Provide the core “short-to-mid session” combat experience.
- Support story progression and stable reward distribution.
- Feed progression and economy loops with predictable materials.

## 2. Baseline Run Structure
Each stage run should follow:
1. Entry and combat warm-up encounters.
2. Wave groups (small enemies) with pressure escalation.
3. Elite pressure windows.
4. Boss encounter and settlement.

## 3. Baseline Fail/Reward Rule
- Failure grants `partial_reward` to keep progression lanes active.
- Full clear grants stage milestone rewards and stronger unlock progress.

## 4. Compatibility Requirements
- Combat control remains `move_only`.
- Squad behavior remains `fixed_role_ai`.
- Hazard readability uses `strict_global_standard`.

## 5. Numeric Separation
All thresholds and tuning (timings, counts, multipliers) belong to:
- `docs/design/play-rules/values/stage-dungeon-values.csv`

## 6. Faucet -> Progression Sink Mapping
Stage rewards exist to feed the progression system in a readable and anti-dead-end way.

1. Full clear milestone rewards (upgrade fuel)
   - Provide universal `upgrade_material` that feeds:
     - Leveling XP (`docs/design/feature-systems/level-xp-logic.md`)
     - Rank upgrade costs (`docs/design/feature-systems/rank-tier-logic.md`)
2. Failure rewards with `partial_reward` (anti dead-end guarantee)
   - Even on failure, the stage must still yield some `upgrade_material`.
   - Since `upgrade_material` always converts into XP, players still move toward meaningful level ups instead of hitting growth dead-ends.
