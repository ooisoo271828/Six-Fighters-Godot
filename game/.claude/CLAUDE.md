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

1. **Read error messages completely** — check `run_error_details` / `compile_error_details` for `file`, `line`, `function`, and `frames`. The old flat `run_error` string alone is insufficient — the structured `_details` fields contain the exact location and call stack.
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

**Structured error details (v0.3.1+)**:
When executing GDScript via Hastur, runtime errors now include full location info:

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

**Always check `run_error_details` / `compile_error_details` first** when debugging — they contain the exact file, line number, and call stack. The old flat `run_error` string alone is no longer the primary error signal.

---

## VFX System v4.0 Architecture

### Data Layer

```
SkillVisualDef (纯容器)
├── body: ProjectileVisual      ← 弹体核心（core/inner/hotspot/nose/glow/jitter/纹理）
├── trail: TrailDef             ← 拖尾系统容器
│   ├── particles: ParticleTrailConfig  ← 向后散射粒子（可选）
│   ├── flame: FlameTrailConfig         ← 向前前缘火焰（可选）
│   ├── comet: CometTrailConfig         ← Line2D 实线拖尾（可选）
│   └── path_dots: PathDotConfig        ← 路径光点（可选）
└── impact: ImpactVisual        ← 命中视觉（火花/震屏/VFX层级池）
```

**子 Resource 文件**：`scripts/skill_system/registry/` 下的 `projectile_visual.gd`, `trail_def.gd`, `particle_trail_config.gd`, `flame_trail_config.gd`, `comet_trail_config.gd`, `path_dot_config.gd`, `impact_visual.gd`

### Rendering Layer (Component Pattern)

```
ProjectileNode (壳 — 运动 + 命中检测)
├── CompCoreSprite     ← core/inner/hotspot/nose 四层 Sprite
├── CompGlow           ← glow/glow2/ray 光晕 + ShaderMaterial
├── CompTrailParticles ← GPUParticles2D 向后散射
├── CompFlameTrail     ← GPUParticles2D 向前火焰
├── CompCometTrail     ← Line2D × 3 实线拖尾
├── CompPathDots       ← 路径光点
└── CompExplosion      ← 命中爆炸
```

**Component 文件**：`scripts/skill_system/pools/components/` 下

### Texture & Color Rules

```
[规则] 粒子纹理优先级：
  1. 子 Config 的 texture_path → 加载并使用
  2. 未指定 → VFXTextureManager 程序化纹理（SOFT_CIRCLE / CIRCLE）

[规则] 颜色渐变仅在无自定义纹理时应用（有纹理 → 纹理原色即最终色）

[规则] 每个拖尾子系统独立着色（particles.color_1/2/3, flame.color_1/2, comet 各层颜色）

[规则] 程序化纹理由 VFXTextureManager 统一管理，带缓存
```

### Shader Preset System

```
[规则] 着色器参数通过 ShaderPreset Resource 传递（类型安全），不传裸 Dictionary
[规则] 内置预设：glow_default, glow_intense, glow_subtle, glow_pulsing
[规则] 预设文件：resources/vfx/shader_presets/*.tres
[规则] VFXTextureManager.get_shared_material() 返回共享实例，禁止运行时修改 uniform
[规则] 需要运行时动画 → duplicate_material() 创建独立副本
```

### Object Pool Rules

```
[规则] 每个 Component 的 reset() 在池复用时调用，清理纹理引用和状态
[规则] Component.configure() 必须为每个视觉元素明确设值（启用/禁用）
[规则] 禁止"不设值就保留上一技能状态"的隐式行为
```

---

## Project Structure

```
game/
├── addons/hasturoperationgd/   # Godot plugin (active)
├── assets/textures/vfx/        # VFX 纹理（particles/, cores/, glows/）
├── scenes/
│   ├── arena/                   # Combat arena
│   ├── dev/                     # SkillDemo, test scenes
│   ├── hub/                     # Main hub
│   ├── skill_system/            # Skill system scene
│   └── viewer/                  # Hero/skill viewer
├── scripts/
│   ├── skill_system/
│   │   ├── registry/            # SkillDef, SkillVisualDef, 子 Resource 类
│   │   ├── core/                # SkillEffect, ExecutionChain, Modifier
│   │   ├── pools/               # ProjectileNode, ProjectilePool
│   │   │   └── components/      # CompCoreSprite, CompGlow, CompTrail...
│   │   ├── vfx/                 # SkillVFXManager, executors, shaders
│   │   │   ├── executors/       # ExecRing, ExecParticleBurst...
│   │   │   └── shaders/         # glow, dissolve, ring_wave, telegraph
│   │   └── signal_bus/          # SkillSignalBus
│   ├── combat/                  # Combat system, TargetSelector
│   ├── arena/                   # Arena logic
│   ├── core/                    # Singletons (GameManager)
│   └── ...
├── resources/
│   ├── skills/
│   │   ├── skill_defs/          # SkillDef .tres（战斗数据）
│   │   ├── skill_visual_defs/   # SkillVisualDef .tres（视觉数据）
│   │   └── modifiers/           # ModifierDef .tres
│   └── vfx/
│       ├── tiers/               # VFX 层级池定义
│       ├── layers/              # VFXLayerDef .tres
│       └── shader_presets/      # ShaderPreset .tres
└── docs/                        # Design docs, references
```

**Detailed references**:
- HasturOperationGD full guide: `docs/claude-ref-hastur.md`
- Camera system: `docs/claude-ref-camera.md`
- SkillDemo scene: `docs/claude-ref-skill-demo.md`
- GDScript conventions & code examples: `docs/claude-ref-hastur.md#gdscript-code-conventions`
