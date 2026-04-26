# Hero & Squad Baseline

Status: Draft  
Version: v0.2  
Owner: Design  
Last Updated: 2026-03-21  
Scope: Project-wide hero roster and squad assembly baseline logic (1–6 distinct heroes per committed roster). Numeric tuning lives in `values/*.csv`.  
Related: docs/design/other/game-foundation-baseline.md; docs/design/feature-systems/six-unit-squad-assembly-contract.md; docs/design/feature-systems/role-tags-fixed-role-ai-contract.md; docs/design/feature-systems/duplicate-hero-shard-conversion-logic.md; docs/design/feature-systems/hero-skill-template-v1.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

## 1. Core Idea

- Players obtain heroes via gacha-like acquisition.
- Players assemble a roster of **up to six** collected heroes to express their build (`build`) through composition; **minimum one** hero can be taken into a valid run unless a mode specifies otherwise.

## 2. Squad Assembly Contract

1. Roster size is **between 1 and 6** active heroes (distinct identities, no duplicates).
2. Each hero has one or more role tags that drive autonomous combat behavior.
3. Squad presets are required to support quick re-entry into different stages.

## 3. Role Tags (Baseline)

Baseline hero role families:

- `frontliner`: pressure absorption and disruption
- `dps`: sustained/burst output
- `support`: sustain and utility timing
- `control`: interrupt/slow/group pressure reduction

Role tags must map to combat behaviors under `fixed_role_ai`.

## 4. Duplicate & Progression Relationship

- Duplicates are not pure waste; they convert into progression utilities (shards/limits/materials) defined by the progression system.
- This conversion must feed both stat upgrades and skill enhancements.

## 5. Integration Points

- Input from Gacha/Acquisition: hero identity, rarity tier, and duplicate conversion.
- Input from Progression: unlock states and growth channels.
- Output to Combat Core: role tags and skill modifiers affecting autonomous behavior.

## 6. Numeric Separation

All numeric tuning (conversion rates, caps, preset limits) belongs in:

- `docs/design/feature-systems/values/hero-squad-values.csv`

## 7. Module Map (Squad & Progression Interfaces)

- Squad assembly & presets: `docs/design/feature-systems/six-unit-squad-assembly-contract.md`
- Role tags -> autonomous actions: `docs/design/feature-systems/role-tags-fixed-role-ai-contract.md`
- Duplicate -> hero shards: `docs/design/feature-systems/duplicate-hero-shard-conversion-logic.md`
