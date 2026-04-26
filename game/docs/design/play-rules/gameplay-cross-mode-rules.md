# Gameplay Cross-Mode Rules

Status: Draft
Version: v0.2
Owner: Design
Last Updated: 2026-03-21
Scope: Shared gameplay rules across mainline and independent modes at Level-1.
Related: docs/design/play-rules/gameplay-framework-phase1.md; docs/tech/adr/2026-03-21-flexible-squad-1-to-6.md

## 1. Shared Player Motivation
- Short-term: finish a run and gain visible rewards.
- Mid-term: strengthen roster builds (up to six distinct heroes).
- Long-term: unlock harder content and richer mode identity.

## 2. Shared Session Structure
- Entry:
  - enter target from Hub world via portal browse (mode node/stage entry preview)
  - confirm squad via one of two entry branches:
    - Player entry: load a `preset` or manually pick **1..6** heroes (validated: distinct identities, max six)
    - System entry: for special stages, system provides a `loaner squad` (player does not need ownership/unlock)
- Run: follow mode-specific loop under same combat control constraints.
- Settlement: grant rewards and progression updates.

## 3. Shared Compatibility with Combat Freeze
- Control remains `move_only`.
- Squad action model remains `fixed_role_ai`.
- Squad composition is locked for the entire run/stage after entry to keep `fixed_role_ai` predictable.
- Danger signal language follows strict global standard.
- Failure handling can vary per mode, but must preserve fairness and readability.

## 4. Shared Reward and Cost Rules
- Each mode must define at least one stable resource faucet.
- Each mode must map to at least one progression sink target.
- Extreme high-risk mode can grant higher upside but must communicate loss risk clearly.

## 5. Shared Access and Unlock Rule
- Mainline progression is the primary unlock backbone.
- Independent modes unlock progressively to avoid cognitive overload.
- Early mode onboarding must include one simplified tutorial pass.

## 6. Shared Risks
- Cross-mode reward inflation can break progression pacing.
- Mode identity overlap can reduce content differentiation.
- Overly punishing high-risk mode can damage retention if onboarding is weak.

