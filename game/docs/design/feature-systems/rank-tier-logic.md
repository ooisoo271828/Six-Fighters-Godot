# Rank Tier Logic

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Hero rank/tier progression rules (unlock eligibility, costs, and what gets improved when a rank tier is reached).
Related: docs/design/feature-systems/progression-systems-baseline.md; docs/design/feature-systems/level-xp-logic.md; docs/design/feature-systems/skill-enhancement-logic.md; docs/design/feature-systems/duplicate-hero-shard-conversion-logic.md

Notes:

## 1. Vocabulary
- `rank_tier`: an integer tier index for long-term hero power scaling.
- `rank_tier_count`: the maximum number of rank tiers.
- `rank_up`: the action that consumes resources to advance a hero from tier `i` to `i+1`.

## 2. Rank Unlock Eligibility
A hero can attempt `rank_up` to tier `t_next` when all conditions are met:
1. `rank_tier < rank_tier_count`
2. `hero_level` reaches the configured minimum level for the next tier:
   - `hero_level >= min_level_for_rank_(t_next)`
3. The hero has sufficient resources to pay the rank-up costs:
   - universal `upgrade_material` costs
   - and hero-specific shards (from duplicate conversions)

## 3. Rank-Up Cost Model
### 3.1 Upgrade Material Cost
Universal cost for moving into `t_next` is computed with a base and growth curve:
- `rank_upgrade_material_cost(t_next) = rank_upgrade_material_cost_base * (rank_upgrade_material_cost_growth ^ (t_next - 1)) * upgrade_cost_scale`

### 3.2 Hero Shard Cost
Since duplicates are intended to convert into meaningful progression for the same hero:
- `rank_upgrade_hero_shard_cost(t_next) = rank_upgrade_hero_shard_cost_base * (rank_upgrade_hero_shard_cost_growth ^ (t_next - 1))`

## 4. Rank-Up Effects (What changes)
On successful `rank_up` to `t_next`:
1. Apply rank stat multiplier channel(s) via the configured rank curve:
   - `rank_stat_multiplier_growth` (tier stacking)
2. Update eligibility gates for deeper skill enhancement:
   - skill enhancement eligibility (see `skill-enhancement-logic.md`)
3. Ensure the behavior is compatible with combat readability:
   - rank progression must not invalidate the readability model that `combat-core` has frozen for v1 (see combat-core decision freeze policy).

## 5. Implementation-Facing Interfaces (Semantic)
Design intent for an implementation:
- `tryRankUp(heroId)`: checks eligibility, computes costs, consumes resources, applies rank effects.
- `computeRankUpgradeCost(heroId, t_next)`: deterministic cost computation based on CSV parameters.

