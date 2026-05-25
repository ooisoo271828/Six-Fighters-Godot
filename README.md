# Six Fighters — Godot

A vertical (9:16 portrait) top-down 2D tactical fighter game built with Godot 4.x, developed via VibeCoding (AI-assisted). Features a **POE-style skill modifier system** where skills can be augmented with runtime modifiers (scatter, bounce, fission, expansion, etc.).

> **Current phase**: Core combat loop + VFX tier pool system (full implementation). 2 of 8 planned skills implemented. Modifier pipeline fixed. Hastur plugin enhanced with structured error capture for AI debugging (file/line/stack in execute responses).

---

## Current Skills

| Skill | Status | Type | Description |
|-------|--------|------|-------------|
| **Fireball** `fireball_basic` | v2.1 | Projectile | 225px/s, dual-layer explosion, 300ms fade-out, scale-ramp trail. VFX tier pool: spark_fire + burst_fire |
| **Missile Storm** `missile_storm` | v2.2 | Multi-projectile | 9-12 missiles, BEZIER_QUAD arc, 3-layer Line2D comet trail, staggered launch (0.05-0.8s window), randomized trajectory per missile, Sprite2D-based impact explosion |
| Chain Lightning | Designed | Chain-jump | 4-state machine (FLYING→INCOMING→DWELL→OUTGOING) |
| Ice Cyclone | Designed | AOE moving | Area damage + slow |
| Burning Hands | Designed | AOE fan | Cone-shaped flame spread |
| Ice Ring | Designed | AOE ring | Radial ice burst |
| Plasma Beam | Designed | Beam | 3-layer beam renderer |
| Ghost Fire Skull | Designed | Homing | Spiral homing projectile |

---

## Architecture

The project uses a **three-layer architecture**: AI Agent ↔ broker-server ↔ Godot Editor (see [HasturOperationGD Technical Whitepaper](docs/HasturOperationGD-Technical-Whitepaper.md) for details), with a POE-style skill modifier system.

```
Hub Scene → Hero Selection → Arena Battle (wave-based)
                 │
          EventBus ── GameManager ── CombatResolver
                 │
          SkillSystem ── SkillRegistry (CSV-driven)
                 │
          ProjectilePool ── ProjectileNode (N instances)
                 │                    ├── Sprite2D core (5-layer: glow/core/inner/hotspot/nose)
                 │                    ├── GPUParticles2D trail
                 │                    ├── Line2D comet trail (3-layer, sway)
                 │                    └── Sprite2D burst explosion (Tween-driven)
                 │
          SkillVFXManager
                 ├── VFXTierRegistry (A/B/C tier pools)
                 ├── VFXExecutorRegistry → ExecParticleBurst / ExecSpriteBurst / ExecFlash / ExecShaderRing
                 ├── HitVFXPool (object pooling)
                 └── VFXTextureManager
                 │
          Modifier Pipeline: ModifierProcessor → effect.execute() → scatter → bounce → fission → expansion
```

### VFX Tier Pool System

Hit effects are organized into composable **tier pools** with a **strategy-pattern executor system**. Each skill picks one effect per tier (or uses global defaults):

```
A Layer (Small)   → spark_tiny, glint
B Layer (Medium)  → spark_phys, spark_magic, spark_fire
C Layer (Large)   → burst_fire, shake_strong
```

**Executor System** — Each layer is dispatched to a specialized executor:
- `ExecParticleBurst` — GPUParticles2D burst effects
- `ExecSpriteBurst` — Sprite2D fragment explosion (Tween-driven)
- `ExecFlash` — Screen flash effects
- `ExecShaderRing` — Shader-based ring/shockwave effects

All executors use `HitVFXNode` + `HitVFXPool` for object pooling (acquire → setup → play → release lifecycle).

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
│   │   │   ├── registry/               # SkillDef, SkillVisualDef, SkillRegistry, ProjectileVisual, TrailVisual, ImpactVisual, VFXOverride
│   │   │   ├── core/                   # ExecutionChain, ModifierProcessor, SkillEffect
│   │   │   │   └── effects/            # EmitProjectile, AreaDamage, ApplyStatus
│   │   │   ├── pools/                  # ProjectilePool, ProjectileNode (v2.2)
│   │   │   └── vfx/                    # SkillVFXManager, VFXTierRegistry, VFXLayerDef
│   │   │       ├── executors/          # VFXExecutorBase, ExecParticleBurst, ExecSpriteBurst, ExecFlash, ExecShaderRing
│   │   │       └── shaders/            # GLSL shaders for ring/flash effects
│   │   ├── units/                      # Hero, Enemy, Unit base class
│   │   ├── data/                       # HeroDef, HeroRegistry, CombatantStats
│   │   ├── hub/                        # Hub scene logic
│   │   ├── arena/                      # Arena battle logic
│   │   └── ui/                         # VirtualJoystick, HeroViewer, SkillViewer
│   ├── resources/
│   │   ├── skills/
│   │   │   ├── skill_defs/             # .tres skill definitions (CSV-driven)
│   │   │   ├── skill_visual_defs/      # .tres visual parameter definitions + sub-resources
│   │   │   └── modifiers/             # .tres modifier definitions (bounce, scatter, fission, expansion)
│   │   └── vfx/                        # VFX tier pools & layer definitions
│   │       ├── tiers/                  # tier_A.tres, tier_B.tres, tier_C.tres
│   │       └── layers/                 # Individual VFXLayerDef .tres files
│   ├── addons/hasturoperationgd/       # Godot editor plugin (remote execution)
│   ├── assets/textures/vfx/            # Particle textures (fire, spark, smoke, glow)
│   ├── tools/                          # Python dev tools
│   │   ├── editor_call.py              # Inline GDScript executor
│   │   └── hastur.py                   # Full CLI for broker-server management
│   └── docs/                           # Design docs, handoff, references
│       ├── claude-ref-camera.md        # Camera system reference
│       ├── claude-ref-skill-demo.md    # SkillDemo scene reference
│       ├── camera_system_design.md     # Camera system design doc
│       ├── PROJECT-RULES.md            # Project rules
│       └── handoff-*.md                # Session handoff documents
├── broker/hastur-operation-plugin-main/
│   └── broker-server/                  # Node.js broker (TCP 5301 / HTTP 5302)
└── docs/                               # Whitepaper, pitfall guide
    ├── HasturOperationGD-Technical-Whitepaper.md  # Hastur main doc
    └── godot-ai-pitfall-guide.md       # AI programming pitfalls
```

---

## VFX System Architecture

### VFX Tier Pool System

The hit VFX system uses a **tier pool architecture**:

- **3 tiers**: A (Small), B (Medium), C (Large) — skills pick one effect per tier
- **Global defaults**: Each tier has a configurable default effect
- **Data-driven**: Effects defined as `VFXLayerDef` resources, registered in `VFXTierDef` pools
- **Runtime**: `SkillVFXManager` receives `skill_hit` signal → resolves tier config via `VFXTierRegistry` → dispatches layers to specialized executors via `VFXExecutorRegistry`
- **Sprite2D+Tween**: Particle effects use programmatic Sprite2D with Tween animation (not GPUParticles2D/CPUParticles2D), avoiding GPU direction normalization bugs

### Modifier Pipeline

The modifier system follows a **Effect → Modifier** two-phase architecture:

1. **Effect phase**: `effect.execute(context)` creates base `ExecutionChain`(s) — e.g., `EmitProjectileEffect` creates 1-12 chains depending on `projectile_count_min/max`
2. **Modifier phase**: Each chain passes through sorted modifiers (scatter, bounce, fission, expansion) which can split, redirect, or augment chains

Skills opt into modifiers via `base_modifier_ids` in their SkillDef. Multi-projectile skills (like missile_storm) get their count from the visual def's `projectile_count_min/max` fields.

### Skill Visual System (Per-Projectile)

Each projectile is rendered by `ProjectileNode` with up to **11 visual layers**:

| Layer | Type | Configurable Via |
|-------|------|-----------------|
| Glow + Glow2 | Sprite2D | `core_glow_*` / `core_glow2_*` params |
| Core | Sprite2D | `core_color/width/height` |
| Inner core | Sprite2D | `core_inner_*` params |
| Hotspot | Sprite2D | `core_hotspot_*` params |
| Nose/tip | Sprite2D | `core_nose_*` params |
| Radial rays | Sprite2D | Procedural texture, auto-rotates |
| Jitter | Sin offset | `jitter_*` params |
| Trail particles | GPUParticles2D | `trail_*` params (scale_curve) |
| Comet trail | Line2D x3 | `comet_*` params (sway, width_curve taper) |
| Impact explosion | Sprite2D + Tween | Custom per-skill (or via VFX tier pools) |

---

## Combat System

- **Hit Resolution**: Hit quality (sigmoid accuracy-vs-evasion) → Round-table (Miss/Glance/Deflect/Hit via softmax) → Crit check
- **Element System**: Physical / Fire / Ice / Lightning / Poison with resistance scaling
- **Status Effects**: Burn (DOT), Frost (slow+DOT), Poison (DOT), Shock (vulnerability), Stun
- **RNG**: Deterministic seeded RNG (LCG) for reproducible combat
- **Controls**: WASD + virtual joystick for squad movement, auto-targeting for attacks

---

## Getting Started

### Prerequisites

- Godot 4.x Editor
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
curl -s http://localhost:5302/api/health
curl -s -H "Authorization: Bearer <token>" http://localhost:5302/api/executors
```
See the [HasturOperationGD Technical Whitepaper](docs/HasturOperationGD-Technical-Whitepaper.md) for the full API reference.

### Structured Error Capture (v0.3.1+)

When executing GDScript via Hastur, runtime errors now return structured location details alongside the error message:

```json
{
  "run_error": "索引超出范围",
  "run_error_details": [{
    "file": "res://scripts/arena/arena_scene.gd",
    "line": 142,
    "function": "_process_enemy_spawning",
    "frames": [{"file": "...", "function": "...", "line": N}, ...]
  }]
}
```

This applies to both the synchronous `POST /api/execute` response (`compile_error_details` / `run_error_details`) and the asynchronous `GET /api/executors/:id/logs/errors` log channel. See [the whitepaper](docs/HasturOperationGD-Technical-Whitepaper.md#318-%E7%BB%93%E6%9E%84%E5%8C%96%E9%94%99%E8%AF%AF%E6%8D%95%E8%8E%B7v031) for details.

---

## Creating a New Skill

1. **Design doc**: Create `docs/design/visual-rules/skills/XXX_proj_skillname.md`
2. **SkillDef**: Create `.tres` in `resources/skills/skill_defs/`
3. **SkillVisualDef**: Create `.tres` in `resources/skills/skill_visual_defs/` — include VFX tier config
4. **CSV values**: Add rows to `docs/design/combat-rules/values/skill-values.csv`
5. **Render support**: If new visual behavior is needed, extend `ProjectileNode`
6. **VFX tier config**: Set `hit_vfx_tier_A/B/C` in SkillVisualDef to opt into shared hit effects

Skills in `skill_defs/` are auto-discovered by `SkillRegistry._load_all_skills()` on startup. CSV values are merged at load time.

---

## Known Gotchas (Godot 4.x)

See full [Godot AI Programming Pitfall Guide](docs/godot-ai-pitfall-guide.md) for detailed analysis and prevention.

| Issue | Root Cause | Workaround |
|-------|-----------|------------|
| Particles spray right | GPUParticles2D `direction=Vector3(0,0,0)` → GPU defaults to (1,0,0) | Use non-zero direction + spread=360, or Sprite2D+Tween |
| CPUParticles2D bias | Default direction=(1,0), gravity=(0,10) | Always set direction/spread/gravity explicitly |
| `.tres` values not loading | Resource cache stale | Delete `.godot/*.cfg` or restart editor |
| Error: "Could not find type" | Missing `class_name` declaration | Add `class_name` + trigger filesystem scan |
| Error: "Unexpected Indent" | Mixed 0-tab / 1-tab indentation | All class members must use same indentation |
| `sed` inserts literal "t" | Git Bash doesn't recognize `\t` | Use Python instead of sed for file modifications |
| Two VFX systems overlapping | VFXManager + `_spawn_explosion` independent | Use skill_id skip list to prevent conflicts |

---

## License

This project is developed under open-source license. See the [LICENSE](LICENSE) file for details.

---

*Built with [Godot 4.x](https://godotengine.org/) · Developed via VibeCoding · Plugin: [HasturOperationGD](docs/HasturOperationGD-Technical-Whitepaper.md)*
