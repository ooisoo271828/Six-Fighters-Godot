# Castle Defense L2

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L2 detailed rules for castle defense mode: defense core layout, wave pacing, tower upgrade structure, and drop/resource flow.
Related: docs/design/play-rules/castle-defense-decision-freeze-l2-v1.md

## 1. Mode Contract
- Center defense with allied structures and enemy waves.
- Player controls movement only; squad behavior remains `fixed_role_ai`.

## 2. Defense Core Implementation
- Defense core implementation: `multi_structures`
- Multiple allied buildings exist and cooperate (e.g., towers and utility buildings).
- Enemy pressure must be meaningful against both the player squad and building group.

## 3. Wave Pacing Model
- Wave pacing: `waves_mixed`
- Waves are mixed archetypes with alternating pressure types.
- Between waves, there are short upgrade/build windows: `yes_short_breaks`.

## 4. Target Priority & Enemy Design Mapping
- Enemy target priority: `balanced`
- Binding level: `loose_binding`
- Practical rule: not every enemy requires a specific tower type; only some enemy archetypes react to certain building capabilities.

## 5. Tower Upgrade Structure
- Tower upgrade structure: `branchful_tree`
- Upgrades form a function tree with branching nodes (multiple directions per tower).
- During `yes_short_breaks` windows, players can decide which branches to invest in.

## 6. Resource Drops & Materials
- Upgrade resource shape: `generic_materials`
- Material source: `direct_from_kill`
- Each defeated enemy yields upgrade materials, with rarer material tiers at higher difficulty waves or higher-tier enemies.

## 7. Compatibility with Combat Core Freeze
- Movement control remains `move_only`.
- AI remains `fixed_role_ai`.
- Hazard readability must follow strict global signal policy.

## 8. L3 Entry Focus
- Concrete tower function taxonomy (nodes and dependencies).
- Mixed wave archetype composition table.
- Drop table mapping to generic material tiers and upgrade branch nodes.

