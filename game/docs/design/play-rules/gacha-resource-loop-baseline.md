# Gacha & Resource Loop Baseline

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Project-wide gacha acquisition and resource economy loop baseline logic. Numeric tuning lives in `values/*.csv`.
Related: docs/design/other/game-foundation-baseline.md

## 1. Core Goals
- Sustain roster expansion and build experimentation (hero acquisition).
- Provide steady progression fuel for upgrades (resources/materials).
- Support long-term retention through predictable cadence (daily/weekly objectives).

## 2. Baseline Acquisition Contract
Players acquire heroes via pulls:
- Pull outcomes must always provide progression value.
- Duplicates convert into progression utilities rather than pure waste.

## 3. Economy Loop (Baseline)
1. Stage/activities provide resource faucets.
2. Players spend resources to upgrade hero growth.
3. Periodic pulls convert resources into new heroes and/or duplicate utilities.
4. New build choices influence subsequent stage performance.

## 4. Anti-Dead-End Rule
With `partial_reward` failure handling, economy must still allow progression lanes:
- Failure cannot block all upgrade needs.
- High-risk modes (later) may vary loss severity, but baseline campaign must remain survivable.

## 5. Numeric Separation
All tuning belongs in:
- `docs/design/play-rules/values/gacha-resource-loop-values.csv`

## 6. Faucet -> Progression Sink Mapping
This doc defines how gacha/economy outputs connect to the progression system (so `partial_reward` and duplicates always avoid dead ends).

1. New hero acquisition (ownership expansion)
   - Adds a hero identity that can be placed into a `six-unit squad`.
   - Unlocks its role tags, which feed `fixed_role_ai` autonomy and therefore changes combat behavior.
2. Duplicate hero acquisition (build acceleration)
   - Converts into `hero_shards` for the exact duplicated hero identity.
   - Shards are consumed by:
     - Skill enhancement (`docs/design/feature-systems/skill-enhancement-logic.md`)
     - Rank tier upgrades (`docs/design/feature-systems/rank-tier-logic.md`)
3. Universal upgrade materials (level/rank fuel)
   - If configured by economy parameters, pulls also grant some universal `upgrade_material`.
   - `upgrade_material` converts into XP for leveling (`docs/design/feature-systems/level-xp-logic.md`)
   - `upgrade_material` is also part of rank-up cost for tier progression.
