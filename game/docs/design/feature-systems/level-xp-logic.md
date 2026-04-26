# Level & XP Logic

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Hero level and XP progression logic (where XP comes from, how it turns into level ups, and what eligibility rules apply).
Related: docs/design/feature-systems/progression-systems-baseline.md; docs/design/play-rules/stage-dungeon-baseline.md; docs/design/play-rules/gacha-resource-loop-baseline.md

Notes:

## 1. Vocabulary
- `hero_level`: the current progression level of a hero.
- `xp`: the accumulated experience points used to advance `hero_level`.
- `upgrade_material`: universal upgrade items granted by stage/mode rewards that can be converted into `xp` for leveling.
- `max_level_cap`: the absolute ceiling for `hero_level`.

## 2. Level Progression Contract
### 2.1 Eligibility
- A hero can only level up when `hero_level` is below `max_level_cap`.
- XP accumulation never reduces progress; failed conversions are not allowed (materials should always yield XP).

### 2.2 XP Sources (Faucets -> XP)
`upgrade_material` is treated as the canonical input token for XP gain.
- When a player obtains/claims `upgrade_material`, it is converted to XP using:
  - `xp_gain = upgrade_material_amount * xp_per_upgrade_material`

`upgrade_material_amount` comes from multiple mode faucets:
- Stage/dungeon rewards (including `partial_reward` on failure).
- Gacha/resource economy rewards (if the economy grants upgrade materials).

## 3. XP to Level Conversion
### 3.1 Required XP for Next Level
The required XP for the next level is computed via the configured curve:
- `required_xp_for_next_level(level) = xp_base * (level ^ xp_level_exponent) * (xp_growth_multiplier ^ (level - 1))`

Where:
- `level` is the hero's current `hero_level` (starting from level 1).

### 3.2 Level-Up Effects
On each level-up:
1. Apply the level stat multiplier channel(s) defined by:
   - `level_stat_multiplier_base`
   - `level_stat_multiplier_growth`
2. Update any eligibility gates that depend on `hero_level`:
   - Skill enhancement eligibility (see `docs/design/feature-systems/skill-enhancement-logic.md`)
   - Rank-tier unlock eligibility (see `docs/design/feature-systems/rank-tier-logic.md`)

## 4. Anti Dead-End Coupling (partial_reward)
To ensure progression does not get stuck:
- Stage failure yields `partial_reward` that still grants some `upgrade_material`.
- Since `upgrade_material` always converts to XP, the player always makes forward progress toward meaningful level-up.

## 5. Implementation-Facing Interfaces (Semantic)
Design intent for an implementation:
- `grantUpgradeMaterial(heroId, upgradeMaterialAmount)`: credits `upgrade_material`.
- `convertUpgradeMaterialToXp(heroId)`: converts all (or claimed) upgrade materials into XP using `xp_per_upgrade_material`.
- `tryLevelUp(heroId)`: while XP >= required XP, increment `hero_level` and apply level effects.

