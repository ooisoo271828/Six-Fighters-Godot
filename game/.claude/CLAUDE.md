# Six Fighter GD

## Project Overview

- **Engine**: Godot 4.x (config_version=5)
- **Resolution**: Portrait 540x960
- **Core loop**: 6-hero auto-battler with skill-based combat
- **Language**: GDScript (Tab indentation mandatory)
- **AI integration**: HasturOperationGD plugin for remote GDScript execution

## Behavioral Guidelines

Tradeoff: these bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- If 200 lines could be 50, rewrite it.

### 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

### 4. Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write a minimal repro script, then implement"
- "Fix the bug" → "Reproduce in SkillDemo, fix, verify the fix holds"
- "Refactor X" → "Verify behavior unchanged before and after"

### 5. Systematic Debugging

No fixes without root cause investigation first. When encountering any bug or error:

1. **Read error messages completely** — stack traces, line numbers, error codes.
2. **Reproduce consistently** — exact steps, every time. Not reproducible? Gather data, don't guess.
3. **Check recent changes** — git diff, recent commits, new dependencies.
4. **Trace data flow** — where does the bad value originate? Trace backward to the source, fix there.
5. **Form ONE hypothesis** — smallest change to test it. Didn't work? New hypothesis. Don't stack fixes.

Red flags — STOP and restart from step 1:
- "Just try changing X and see if it works"
- "I don't fully understand but this might work"
- "One more fix attempt" (after 2+ failures)
- If 3+ fixes all failed: **question the architecture**, discuss with user before continuing.

### 6. Design Before Coding

When requirements are unclear, clarify before implementing.

- **Ask 2-3 key questions upfront** when the task is ambiguous — understand purpose, constraints, and success criteria in one pass.
- **Propose 2-3 approaches with tradeoffs** for complex features — present options with your recommendation.
- **Cut what wasn't asked for** — don't add "nice to have" features or speculative flexibility. YAGNI.

Only triggers on ambiguous or complex tasks. Clear requests go straight to implementation.

---

## HasturOperationGD Quick Reference

AI agent executes GDScript in Godot Editor via REST API.

```
AI Agent ──HTTP──> broker-server (Node.js) ──TCP──> Godot Editor + HasturPlugin
  :5302                    :5301
```

**Start broker**: `cd broker/hastur-operation-plugin-main/broker-server && npm run dev`

**Verify connection**:
```bash
python tools/hastur.py status        # all-in-one check
# or individually:
python tools/editor_call.py --health
python tools/editor_call.py --executors
```

**Execute GDScript** (Tab indentation only, never spaces):
```bash
python tools/editor_call.py 'print("hello")'
python tools/editor_call.py --scene-tree
python tools/editor_call.py --file script.gd
```

**Auth Token**: see `broker/hastur-operation-plugin-main/broker-server/.env` or `HASTUR_TOKEN` env var.

**Critical rules**:
- GDScript indentation must use **Tab** (`\t`), never spaces
- Plugin source: `game/addons/hasturoperationgd/` (modify here, not broker source)
- Full reference: `docs/claude-ref-hastur.md`

---

## Project Structure

```
game/
├── addons/hasturoperationgd/   # Godot plugin (active)
├── assets/                      # Sprites, textures, shaders
├── scenes/
│   ├── arena/                   # Combat arena
│   ├── dev/                     # SkillDemo, test scenes
│   ├── hub/                     # Main hub
│   ├── skill_system/            # Skill system scene
│   └── viewer/                  # Hero/skill viewer
├── scripts/
│   ├── arena/                   # Arena logic
│   ├── combat/                  # Combat system
│   ├── core/                    # Singletons
│   ├── data/                    # Data definitions
│   ├── dev/                     # Dev tools (camera_anchor, skill_demo)
│   ├── hub/                     # Hub logic
│   ├── skill_system/            # Skill registry, effects, modifiers, VFX
│   ├── ui/                      # UI components
│   └── units/                   # Unit definitions
├── resources/                   # Godot resources
├── tools/                       # Python CLI tools (editor_call.py, hastur.py)
└── docs/                        # Design docs, references, handoff notes
```

**Detailed references**:
- HasturOperationGD full guide: `docs/claude-ref-hastur.md`
- Camera system: `docs/claude-ref-camera.md`
- SkillDemo scene: `docs/claude-ref-skill-demo.md`
- GDScript conventions & code examples: `docs/claude-ref-hastur.md#gdscript-code-conventions`
