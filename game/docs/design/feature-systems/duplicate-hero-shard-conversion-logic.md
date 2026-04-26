# Duplicate -> Hero Shard Conversion Logic

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: How duplicate hero acquisitions convert into hero-specific shards, and how shards are stored/consumed by progression upgrades.
Related: docs/design/feature-systems/hero-squad-baseline.md; docs/design/feature-systems/skill-enhancement-logic.md; docs/design/feature-systems/rank-tier-logic.md; docs/design/play-rules/gacha-resource-loop-baseline.md

Notes:

## 1. Vocabulary
- `duplicate_acquisition`: the player receives a hero they already own.
- `rarity_tier`: the hero rarity tier returned by acquisition (input from gacha).
- `hero_shards`: hero-specific shards credited to the duplicated hero identity.

## 2. Conversion Contract (Core Rule)
For `duplicate_acquisition`, the reward is never pure waste:
- duplicates convert into `hero_shards` for that exact hero identity
- shards are then usable by upgrades that depend on the same hero identity

This conversion is driven by rarity tier:
- shards gained are computed from CSV parameters:
  - `duplicate_shards_per_rarity_tier[tier]`

## 3. Shard Storage Semantics
- Shards are stored per hero identity and persist until spent.
- Shards are not converted into role-tag changes; role tags remain derived from hero identity.

## 4. Shard Spending Semantics
Hero shards are spent only when attempting upgrades:
- Skill enhancement attempts (see `skill-enhancement-logic.md`).
- Rank tier upgrades (see `rank-tier-logic.md`).

The spending amount is computed deterministically by the target upgrade level/tier using the configured ratio(s)/cost functions.

## 5. Interactions With Economy Anti Dead-End
Even if a run fails and the player only receives `partial_reward`, gacha and mode rewards must still keep progression meaningful:
- stage `partial_reward` provides universal upgrade materials (which can become XP)
- gacha pulls provide at least some progression value:
  - new heroes (roster expansion)
  - duplicates -> shards (build acceleration for the same hero identity)
  - universal upgrade materials, if configured by economy parameters

