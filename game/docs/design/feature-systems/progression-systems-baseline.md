# Progression Systems Baseline

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Project-wide long-term growth systems baseline logic (leveling/rank/skill enhancement). Numeric tuning lives in `values/*.csv`.
Related: docs/design/feature-systems/hero-squad-baseline.md; docs/design/feature-systems/level-xp-logic.md; docs/design/feature-systems/rank-tier-logic.md; docs/design/feature-systems/skill-enhancement-logic.md; docs/design/feature-systems/duplicate-hero-shard-conversion-logic.md

## 1. Progression Goals
- Long-line growth path: from early to high tiers with large overall power multipliers.
- Growth must improve both:
  - combat stats (survivability and output)
  - skill behavior/mechanics (not only raw numbers)

## 2. Growth System Axes (Baseline)
Baseline axes to support long-term scaling:
1. Level / XP progression
2. Rank / tier progression
3. Equipment-like growth axis (generic “gear” substitute if needed)
4. Skill enhancement / modification paths

## 3. Scaling Design Rule (Baseline)
- Provide frequent visible upgrades early.
- Shift to milestone-based upgrades in mid-to-late game.
- Ensure the sum of multipliers can reach large power ranges without breaking combat readability.

## 4. Fail-Safe and Economy Coupling
- Progression must be supported by mode reward output (stage/economy/gacha).
- Fail states using `partial_reward` must still advance meaningful progression lanes.

## 5. Numeric Separation
All numeric tuning (caps, costs, multipliers, curves) belongs to:
- `docs/design/feature-systems/values/progression-systems-values.csv`

## 5.1 Combat Stat Channels (Integration)
Growth systems (level, rank tier, and skill enhancement) output and update *stat channels* that are consumed by the combat resolution layer:
- Accuracy/Evasion channels: influence hit/miss probability.
- Crit channels: include crit rate and crit power; influence critical damage outcome.
- Element channels: include elemental offense power (affects base elemental damage) and elemental resistance per element (reduces final elemental damage).
- Status application channels: influence elemental status strength (DOT/CC potency) such as duration scaling and tick damage scaling.
- Hard CC channels: include `stun_power` and `stun_resistance` to contest and scale stun duration.

In v1, `combat-core` owns encounter flow, while `combat-attributes-resolution` owns the semantics for converting the above stat channels into:
- hit vs miss outcome,
- crit vs non-crit outcome,
- elemental damage after resistance,
- status stack updates and DOT/CC tick scheduling.

## 6. Module Map (Implementation Semantics)
- Level/XP progression: `docs/design/feature-systems/level-xp-logic.md`
- Rank tier progression: `docs/design/feature-systems/rank-tier-logic.md`
- Skill enhancement: `docs/design/feature-systems/skill-enhancement-logic.md`
- Duplicate -> hero shards: `docs/design/feature-systems/duplicate-hero-shard-conversion-logic.md`
