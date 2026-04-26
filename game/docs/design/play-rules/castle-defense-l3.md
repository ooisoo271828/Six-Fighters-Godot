# Castle Defense L3

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: L3 entry rules for castle defense mode: tower function tree dependencies, mixed wave generation schedule, and drop/upgrade encoding.
Related: docs/design/play-rules/castle-defense-decision-freeze-l3-v1.md

## 1. Mode Contract (L3)
- Inherits L2: `multi_structures`, `waves_mixed`, `yes_short_breaks`, `direct_from_kill`, and `generic_materials`.
- L3 specifies how to make the system implementable: dependency graph, wave generation schedule, and drop encoding.

## 2. Tower Function Tree (L3)
### 2.1 Unlock Prerequisite Style
- Tower nodes follow `hard_prereq_graph`.
- A node requires its prerequisites to be satisfied to unlock/upgrade.

### 2.2 Branchful-tree Execution
- Each tower node can branch into multiple successor nodes.
- The hard prerequisite graph prevents invalid jumps and keeps progression readable.

## 3. Mixed Waves Generation (L3)
### 3.1 Schedule Model
- Mixed waves are generated using `weighted_random_per_run`.
- Each run samples wave archetypes using weights rather than a fixed rotation.

### 3.2 Wave Readability
- Even with weighted randomness, wave templates must preserve readability:
  - maintain recognizable pressure alternation patterns
  - avoid stacking too many new archetypes back-to-back

## 4. Drops & Materials (direct_from_kill) (L3)
### 4.1 Encoding Style
- Drop encoding uses `tiered_drop_table`.
- Enemy archetypes map to material tiers by wave depth/pressure band.

### 4.2 Mapping Constraint (loose_binding)
- Binding is loose: not every enemy strictly requires a specific tower type.
- Materials influence upgrade choices, but do not hard-couple every combat archetype to a single tower.

## 5. Upgrade Operations (L3)
- Upgrade time policy: `no_time_restriction`.
- Players can upgrade at any time if they have enough materials.

## 6. Interfaces / Contracts
- Tower upgrade nodes output: structure capability changes and behavior modifications in the next combat interval.
- Enemy pressure nodes input: wave template selection influences enemy composition pools and drop tier band.

## 7. L4 Entry Focus
- Concrete node graph schema (prereq edges, branch successors).
- Wave archetype weight table and sampling algorithm.
- Drop tier table and mapping to generic material categories.

