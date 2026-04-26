# ADR: Flexible squad roster (1–6 heroes, no duplicate identities)

Status: Accepted
Version: v1.0
Owner: Tech + Design
Last Updated: 2026-03-21
Scope: Record the semantic change from “exactly six active heroes” to “maximum six active heroes, minimum one, under-strength rosters allowed”, and list impacted design documents.
Related: docs/design/feature-systems/six-unit-squad-assembly-contract.md; docs/design/other/game-foundation-baseline.md; docs/design/combat-rules/combat-core-baseline.md; docs/tech/architecture/web-client-architecture.md

## Context

Earlier squad docs described a **fixed-size six-hero** active roster (`six-unit squad` as “always 6”). Product direction for the node validation milestone and forward requires:

- **Maximum** roster size of **6** distinct hero identities (the “full” build expression).
- **Minimum** roster size of **1** hero for a valid run.
- **No duplicate** hero identities within the same committed roster snapshot.
- Gameplay must remain coherent when the roster has **fewer than six** active heroes (under-strength).

This is a **design semantic change** relative to older Draft docs; it does not invalidate combat-core freeze tokens (`move_only`, `fixed_role_ai`, etc.) but updates how many player-controlled hero entities participate in a run.

## Decision

1. Replace “exactly 6 heroes required” with **“1..6 distinct hero identities”** for player entry and for presets, subject to mode-specific minimums (defaults: minimum 1 unless a mode doc specifies higher).
2. **Loaner / system squads** remain “up to 6” identities: a stage may define a loaner roster of size `K` where `1 <= K <= 6`, all distinct, unless a future mode doc freezes otherwise.
3. **Combat-facing model**: at run start, combat receives an ordered list `activeHeroes[]` with `length N`, `1 <= N <= 6`, with **no duplicate** `heroId`. There are **no empty placeholder heroes**; absent slots simply do not exist as entities.
4. **Node validation / difficulty**: under-strength rosters do **not** require automatic enemy stat scaling in v1 of the node validation build; optional coefficients may be added later via CSV without changing this ADR’s roster rules.

## Consequences

- UI and save/load for presets must store **variable-length** distinct hero id lists (max 6), not a fixed 6-tuple with sentinels.
- Tutorials and copy must stop implying “you must bring six heroes”.
- Any automated test or tool that assumed `heroIdList.length === 6` must be updated.

## Conflicting or outdated statements (fix in design docs)

The following previously implied **exactly six** heroes everywhere:

- `docs/design/other/game-foundation-baseline.md` — §3 `six-unit squad` wording.
- `docs/design/feature-systems/hero-squad-baseline.md` — §2 fixed size.
- `docs/design/feature-systems/six-unit-squad-assembly-contract.md` — §1 fixed six slots; preset APIs with `[6]`.
- `docs/design/feature-systems/squad-selection-and-entry-rules.md` — §3.1 manual six picks; interfaces `heroIdList[6]`.
- `docs/design/play-rules/hub-world-entry-rules.md` — §3.1, §4 snapshot wording.
- `docs/design/play-rules/gameplay-framework-phase1.md` — §5 entry criteria “six-unit squad snapshot”.
- `docs/design/combat-rules/combat-core-baseline.md` — §1.2 fixed six-unit squad.

**Note:** Filename `six-unit-squad-assembly-contract.md` is retained for link stability; the term **six-unit** is interpreted as **maximum six slots**, not “must always be six”.

## Compliance with combat freeze

- Does **not** change `move_only`, `fixed_role_ai`, `strict_global_standard`, `partial_reward` policy, boss phase grammar tokens, or `hp_plus_time` unless separately proposed via ADR.
