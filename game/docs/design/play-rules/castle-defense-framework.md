# Castle Defense Framework

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Level-1 framework for center-defense mode with allied structures.
Related: docs/design/play-rules/castle-defense-decision-freeze-l2-v1.md

## 1. Mode Goal and Player Motivation
- Defend central allied structures against enemy waves.
- Blend squad combat with structure-upgrade decisions.
- Deliver escalating defense pressure and tactical adaptation.

## 2. Entry/Exit and Loop
- Entry: start defense run with selected squad.
- Loop: repel waves, collect drops, upgrade structures between/within waves.
- Exit: survive to target wave count for clear, or fail if defense core collapses.

## 3. Core Rules
1. Enemy units spawn from map edges and advance toward center.
2. Central allied structures provide combat utility (damage/heal/buff).
3. Enemy kills drop upgrade materials.
4. Materials are spent to upgrade structure capability during run.
5. Survive wave milestones to unlock better reward tiers.
6. L2 core policy (frozen): defense core uses `multi_structures`, and wave pacing uses `waves_mixed`.

## 4. Fail and Reward Rule
- Partial rewards granted by reached wave milestone.
- Full clear grants mode-specific bonus and milestone rewards.

## 5. Compatibility with Combat Freeze
- Keeps `move_only` and `fixed_role_ai`.
- Maintains strict hazard signal standards in high density fights.
- Difficulty pressure comes from wave pacing and lane convergence.

## 6. Resource and Progression Interface
- Supplies defense-mode-specific and generic progression materials.
- Creates alternative progression route for players focused on tactical defense play.

## 7. Risks and Open Items
- Upgrade pacing may overpower or underpower structures.
- Wave composition complexity can exceed portrait readability.
- Real-time upgrade UX flow is not finalized.
 - L2-to-L3 decomposition is required for tower function tree and mixed wave composition.

