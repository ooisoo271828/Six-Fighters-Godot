# Six Fighters — Godot

A vertical (9:16 portrait) top-down 2D tactical fighter game built with Godot 4.6.2, developed via VibeCoding (AI-assisted). Features a **POE-style skill modifier system** where skills can be augmented with runtime modifiers (scatter, bounce, fission, expansion, etc.).

> **Current phase**: Core combat loop + skill visual system v2.1. 2 of 8 planned skills implemented.

---

## Current Skills

| Skill | Status | Type | Description |
|-------|--------|------|-------------|
| **Fireball** `fireball_basic` | ✅ v2.1 | Projectile | 225px/s, dual-layer explosion (sparks + flame fragments), 300ms fade-out, scale-ramp trail |
| **Missile Storm** `missile_storm` | ✅ v2.0 | Multi-projectile | 9-12 missiles, BEZIER_QUAD arc, 3-layer Line2D comet trail with sway |
| Chain Lightning | 📋 Designed | Chain-jump | 4-state machine (FLYING→INCOMING→DWELL→OUTGOING) |
| Ice Cyclone | 📋 Designed | AOE moving | Area damage + slow |
| Burning Hands | 📋 Designed | AOE fan | Cone-shaped flame spread |
| Ice Ring | 📋 Designed | AOE ring | Radial ice burst |
| Plasma Beam | 📋 Designed | Beam | 3-layer beam renderer |
| Ghost Fire Skull | 📋 Designed | Homing | Spiral homing projectile |

---

## Architecture

```
┌─────────────┐   HTTP 5302   ┌─────────────────┐   TCP 5301   ┌──────────────────┐
│ AI Agent    │ ◄───────────► │ broker-server   │ ◄──────────► │ Godot Editor     │
│ (Claude Code)│               │ (Node.js/TS)    │              │ + HasturPlugin   │
└─────────────┘               └─────────────────┘              └──────────────────┘
                                           │
                              ┌────────────▼────────────┐
                              │   Python CLI tools       │
                              │   (editor_call.py,       │
                              │    hastur.py)            │
                              └─────────────────────────┘
```

### Game Systems

```
Hub Scene → Hero Selection → Arena Battle (wave-based)
                 │
          EventBus ── GameManager ── CombatResolver
                 │
          SkillSystem ── SkillRegistry (CSV-driven)
                 │
          ProjectilePool ── ProjectileNode (N instances)
                 │                    ├── 5-layer Sprite2D core
                 │                    ├── GPUParticles2D trail
                 │                    ├── GPUParticles2D front flame
                 │                    ├── Line2D comet trail (3-layer)
                 │                    └── Dual-layer explosion
                 │
          Modifier Pipeline: scatter → bounce → fission → expansion → ...
```

---

## Project Structure

```
Six-Fighters-Godot/
├── game/                                # Godot game project
│   ├── project.godot                    # Engine config (540×960, Mobile render)
│   ├── scenes/
│   │   ├── hub/main.tscn               # Hero selection hub
│   │   ├── arena/battle.tscn           # Wave-based combat arena
│   │   ├── dev/skill_demo.tscn         # Skill visual testing scene
│   │   ├── viewer/                     # Hero + skill viewer
│   │   └── skills/vfx/                 # VFX scene files
│   ├── scripts/
│   │   ├── core/                       # EventBus, GameManager
│   │   ├── combat/                     # CombatResolver, CombatParams, EntityStatus
│   │   ├── skill_system/
│   │   │   ├── registry/               # SkillDef, SkillVisualDef, SkillRegistry
│   │   │   ├── core/                   # ExecutionChain, ModifierProcessor, SkillEffect
│   │   │   │   └── effects/            # EmitProjectile, AreaDamage, ApplyStatus
│   │   │   ├── pools/                  # ProjectilePool, ProjectileNode (v2.1)
│   │   │   └── vfx/                    # SkillVFXManager
│   │   ├── units/                      # Hero, Enemy, Unit base class
│   │   ├── data/                       # HeroDef, HeroRegistry, CombatantStats
│   │   ├── hub/                        # Hub scene logic
│   │   ├── arena/                      # Arena battle logic
│   │   └── ui/                         # VirtualJoystick, HeroViewer, SkillViewer
│   ├── resources/skills/
│   │   ├── skill_defs/                 # .tres skill definitions (CSV-driven)
│   │   └── skill_visual_defs/          # .tres visual parameter definitions
│   ├── addons/hasturoperationgd/       # Godot editor plugin (remote execution)
│   ├── assets/textures/vfx/            # Particle textures (fire, spark, smoke, glow)
│   ├── tools/                          # Python dev tools
│   │   ├── editor_call.py              # Inline GDScript executor
│   │   └── hastur.py                   # Full CLI for broker-server management
│   └── docs/                           # Design docs, handoff, architecture
├── broker/hastur-operation-plugin-main/
│   └── broker-server/                  # Node.js broker (TCP 5301 / HTTP 5302)
└── docs/                               # Plugin whitepaper, technical docs
```

## Combat System

- **Hit Resolution**: Hit quality (sigmoid accuracy-vs-evasion) → Round-table (Miss/Glance/Deflect/Hit via softmax) → Crit check
- **Element System**: Physical / Fire / Ice / Lightning / Poison with resistance scaling
- **Status Effects**: Burn (DOT), Frost (slow+DOT), Poison (DOT), Shock (vulnerability), Stun
- **RNG**: Deterministic seeded RNG (LCG) for reproducible combat
- **Controls**: WASD + virtual joystick for squad movement, auto-targeting for attacks

## Skill Visual System

Each projectile is rendered by `ProjectileNode` with up to **11 visual layers**:

| Layer | Type | Configurable Via |
|-------|------|-----------------|
| Glow | Sprite2D | `core_glow_*` params |
| Core | Sprite2D | `core_color/width/height` |
| Inner core | Sprite2D | `core_inner_*` params |
| Hotspot | Sprite2D | `core_hotspot_*` params |
| Nose/tip | Sprite2D | `core_nose_*` params |
| Jitter | Sin offset | `jitter_*` params |
| Trail particles | GPUParticles2D | `trail_*` params (scale_curve) |
| Front flame | GPUParticles2D | `front_flame_*` params |
| Comet trail | Line2D ×3 | `comet_*` params (with sway) |
| Explosion sparks | GPUParticles2D | `impact_*` params (scale_curve) |
| Explosion fragments | GPUParticles2D | Speed-offset layered burst |

---

## Getting Started

### Prerequisites

- Godot 4.6.2 Editor
- Node.js 18+ (for broker server)
- Python 3.12+ (for CLI tools)

### Quick Start

1. Clone the repo
2. Open `game/` in Godot Editor
3. Enable the **HasturOperationGD** plugin (`Project → Project Settings → Plugins`)
4. Start the broker server:
   ```bash
   cd broker/hastur-operation-plugin-main/broker-server
   npm install
   npm run dev
   ```
5. Open `scenes/dev/skill_demo.tscn` in the editor and press **F5** (Run Current Scene)
6. Select a skill from the dropdown and fire at targets

### Verify Connection

```bash
cd game
python tools/editor_call.py --health       # Check broker + editor status
python tools/editor_call.py --executors    # List connected Godot editor
python tools/editor_call.py 'print("Hello from Godot!")'  # Execute GDScript remotely
```

---

## Creating a New Skill

1. **Design doc**: Create `docs/design/visual-rules/skills/XXX_proj_skillname.md`
2. **SkillDef**: Create `.tres` in `resources/skills/skill_defs/`
3. **SkillVisualDef**: Create `.tres` in `resources/skills/skill_visual_defs/`
4. **CSV values**: Add rows to `docs/design/combat-rules/values/skill-values.csv`
5. **Render support**: If new visual behavior is needed, extend `ProjectileNode`

Skills in `skill_defs/` are auto-discovered by `SkillRegistry._load_all_skills()` on startup. CSV values are merged at load time.

---

## Known Gotchas (Godot 4.6)

| Issue | Workaround |
|-------|-----------|
| `Object.get()` has no default parameter | Check `"key" in obj` before calling `obj.get("key")` |
| `@export bool` may not hot-reload correctly | Fall back to numeric property check |
| `CompressedTexture2D` vs `ImageTexture` | Use base class `Texture2D` for local vars |
| `.tres` requires tab indentation | Never use spaces in `.tres` files |
| GPUParticles2D parameters in wrong class | `direction/spread/velocity` are in `ParticleProcessMaterial` |
| Static function cannot reference class members | Rename parameters to avoid shadowing |

---

## License

This project is developed under open-source license. See the [LICENSE](LICENSE) file for details.

---

*Built with [Godot 4.6.2](https://godotengine.org/) · Developed via VibeCoding · Plugin: [HasturOperationGD](docs/HasturOperationGD-Technical-Whitepaper.md)*
