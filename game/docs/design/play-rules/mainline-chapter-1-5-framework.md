# Mainline Chapter 1-5 Framework

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Level-1 framework for linear mainline chapters 1 to 5.
Related: docs/design/play-rules/gameplay-framework-phase1.md

## 1. Mode Goal and Player Motivation
- Deliver the core story and world progression.
- Provide stable combat practice and roster growth path.
- Establish chapter-to-chapter escalation in challenge and narrative stakes.

## 2. Entry/Exit and Loop
- Entry: choose unlocked chapter node.
- Loop: chapter run with combat encounters and story beats.
- Exit: chapter clear/fail settlement and progression unlock updates.

## 3. Core Rules
1. Chapters are linear and unlock in strict order.
2. Each chapter contains combat progression and story expression segments.
3. Chapter bosses represent milestone checks for build readiness.
4. Chapter rewards are the baseline progression backbone.
5. Fail states allow retry with clear guidance on power gaps.

## 4. Fail and Reward Rule
- Failing chapter attempts still grants limited progression value.
- Full clear grants chapter milestone rewards and unlock progression.

## 5. Compatibility with Combat Freeze
- Uses `move_only` control and `fixed_role_ai`.
- Boss rhythm should stay within approved run targets.
- Warning semantics cannot break strict global signal rules.

## 6. Resource and Progression Interface
- Produces stable base materials for leveling and upgrades.
- Serves as primary gate for opening independent mode layers.

## 7. Risks and Open Items
- Narrative pacing may conflict with short-session mobile behavior.
- Chapter difficulty cliffs may block progression if not smoothed.
- Story delivery format and skip policy are not finalized.

