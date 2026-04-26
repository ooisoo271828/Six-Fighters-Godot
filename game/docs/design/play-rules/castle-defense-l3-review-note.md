# Castle Defense L3 Review Note

Status: Approved
Version: v1.0
Owner: Design
Last Updated: 2026-03-20
Scope: Review summary and governance note for frozen castle defense L3 entry rules.
Related: docs/design/play-rules/castle-defense-l3.md

## 1. L3 Decision Summary
- Tower unlock prerequisites: `hard_prereq_graph`
- Mixed wave schedule: `weighted_random_per_run`
- Drop encoding: `tiered_drop_table`
- Upgrade cost shape: `linear_cost_increase`
- Upgrade time policy: `no_time_restriction`

## 2. Governance
These L3 decisions are frozen for v1 mode development.
Any change requires an ADR before updating design docs or CSV values.

## 3. L4 Ready Checklist
- Define tower node graph schema and prerequisite edges.
- Define wave archetype weights and sampling rules.
- Define drop tier table and mapping rules.
- Define upgrade cost step formula and max levels.

