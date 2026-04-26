# Gameplay Framework Phase 1

Status: Draft  
Version: v0.2  
Owner: Design  
Last Updated: 2026-03-21  
Scope: Level-1 gameplay framework for phase 1 delivery, covering mainline Chapter 1-5 and three independent modes.  
Related: docs/design/combat-rules/combat-core-decision-freeze-v1.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

## 1. Phase 1 Gameplay Scope

- Mainline: Chapter 1 to Chapter 5 (linear progression, combat + story delivery).
- Deep Dungeon: multi-floor push mode with rising difficulty and rewards.
- Ruins Escape: explore-and-extract mode with high death loss.
- Castle Defense: center-defense mode with allied structures and enemy waves.

## 2. Level-1 Theme Tree

1. Mainline chapter framework (unified skeleton for five chapters).
2. Deep dungeon framework.
3. Ruins escape framework.
4. Castle defense framework.
5. Cross-mode unified rules.

## 3. Horizontal-First Discussion Order

1. Complete all Level-1 baseline docs at similar depth.
2. Confirm cross-mode compatibility with combat-core freeze rules.
3. Enter Level-2 vertical detail by risk priority.

## 4. Level-2 Priority Roadmap

1. Ruins Escape (highest risk: death loss and extraction economy).
2. Castle Defense (system coupling: wave pacing + structure upgrades).
3. Deep Dungeon (scaling depth and reward staircase).
4. Mainline Chapter 1-5 detailed expansion.

## 5. Entry Criteria for Level-2

- All Level-1 docs include loop, fail/reward, and progression interfaces.
- Logic docs and CSV placeholders are mapped one-to-one by mode.
- No direct conflict with combat frozen terms (`move_only`, `fixed_role_ai`, `partial_reward` baseline policy references).
- Session entry must support Level-1 Hub world portal flow (browse -> confirm) and commit/lock a **roster snapshot** (`1..6` distinct hero identities) before the run starts.
