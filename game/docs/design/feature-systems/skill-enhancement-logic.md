# Skill Enhancement Logic

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Hero skill enhancement progression rules (unlock eligibility, enhancement levels, and how hero shards participate).
Related: docs/design/feature-systems/progression-systems-baseline.md; docs/design/feature-systems/level-xp-logic.md; docs/design/feature-systems/rank-tier-logic.md; docs/design/feature-systems/duplicate-hero-shard-conversion-logic.md; docs/design/feature-systems/hero-skill-template-v1.md

Notes:

## 1. Vocabulary
- `skill_enhancement_level`: integer enhancement level for a hero's skill behavior track.
- `skill_upgrade_cap`: absolute maximum enhancement level.
- `hero_shards`: hero-specific shards generated from duplicates.
- `skill_xp`: abstract enhancement points used to compute the upgrade requirement.

## 2. Enhancement Eligibility
A hero can attempt `skill_enhance` for enhancement level `l_next` when:
1. `l_next` is within `[0..skill_upgrade_cap]`.
2. `hero_level` meets the minimum level gate for skill enhancement.
3. `rank_tier` meets the minimum rank gate for skill enhancement.
4. The hero has enough resources:
   - hero-specific shards (`hero_shards`)
   - optional universal upgrade materials (if the player cannot rely solely on duplicates)

## 3. Resource -> Skill Advancement Model
### 3.1 Shard Contribution
Hero shards contribute to the skill advancement via:
- `skill_xp_from_shards = hero_shards_amount * hero_shard_to_skill_xp_ratio`

### 3.2 Required Skill XP
The required skill XP for the next enhancement is computed by:
- `required_skill_xp(l_current) = skill_xp_base * (l_current ^ skill_xp_level_exponent) * (skill_xp_growth_multiplier ^ l_current)`

Where:
- `l_current` is the current `skill_enhancement_level`.

## 4. Optional Universal Material Consumption
If shards alone are insufficient, universal upgrade materials may fill the gap:
- `skill_xp_from_upgrade_materials = upgrade_material_amount * skill_xp_per_upgrade_material`

The implementation may choose:
- shard-only if sufficient shards exist
- shard + materials if player has partial progress

## 5. Skill Enhancement Effects (Design Meaning)
The goal is not only “bigger numbers”; each enhancement level must change skill behavior/mechanics in a readable way.
Design guarantees:
- Behavior changes must be consistent with `fixed_role_ai` autonomy:
  - a hero becomes better at its role family behavior patterns
  - opportunity checks still respect the same pipeline order (survival -> role action -> opportunity)
- Enhancement must remain predictable enough for build planning.

## 6. Implementation-Facing Interfaces (Semantic)
- `trySkillEnhance(heroId)`: attempts to advance `skill_enhancement_level` based on current resources.
- `computeSkillEnhancementCost(heroId, l_next)`: returns the deterministic required shards/materials.

