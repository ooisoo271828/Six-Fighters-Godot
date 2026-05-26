# Six Fighter GD

## ⚠️ Critical Rules (每次会话最先阅读)

以下规则来自项目累积的血泪教训。违反其中任何一条都会导致严重问题。

### 规则 1：写文件前先确认文件是否存在
用 `cat >` 或 Write 工具覆盖文件前，先执行：
```bash
git log --oneline -- <file>   # 检查 git 历史
ls -l <file>                  # 检查文件大小
```
Write 工具报 "File has not been read yet" **不等于文件不存在**。绝对不用 `cat >` 覆盖可能已有内容的文件。

### 规则 2：GPUParticles2D 必须设置 texture
GPUParticles2D 的 `texture` 默认值为 `null`，粒子**不可见且不报错**。创建后立即赋值纹理。

### 规则 3：新技能必须同步更新 skill_demo
新增自定义对象池（如 `LaserBeamPool`）时，同步修改 `skill_demo.gd`：
- `_count_active_projectiles()` → 加入新池的统计
- `_clear_all_projectiles()` → 加入新池的清理
- 漏了会导致 UI 播放按钮卡死

### 规则 4：运行时创建节点用 Script.new() 而非 set_script()
`Node2D.new()` + `set_script(script)` 在运行时不可靠。用：
```gdscript
var script = load("res://script.gd")
return script.new() as Node2D
# 或
return load("res://node.tscn").instantiate()
```

### 规则 5：reset_for_pool() 必须覆盖 initialize() 的全部修改
池复用时 `reset_for_pool()` 中每一条赋值，都应能在 `initialize()` 中找到对应的一条。两个函数是互逆操作。**任何遗漏都会导致第二次使用该对象时表现异常。**

完整陷阱参考：[`../../docs/godot-ai-pitfall-guide.md`](../../docs/godot-ai-pitfall-guide.md)

---

## Behavioral Guidelines

Tradeoff: these bias toward caution over speed. For trivial tasks, use judgment.

- **Engine**: Godot 4.x (config_version=5)
- **Resolution**: Portrait 540x960
- **Core loop**: 6-hero auto-battler with skill-based combat
- **Language**: GDScript (Tab indentation mandatory)
- **AI integration**: HasturOperationGD plugin for remote GDScript execution

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

## HasturOperationGD v0.6.0 — Your Bridge to the Running Godot Editor

**This is your PRIMARY tool for interacting with the Godot editor. Use it FIRST before any manual workaround.**
Architecture: `AI Agent :5302 (HTTP) → broker-server (Node.js) :5301 (TCP) → Godot Editor + HasturPlugin`

```
TOKEN=995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7
# Start broker: cd broker/hastur-operation-plugin-main/broker-server && HASTUR_TOKEN=$TOKEN npm run dev
```

### ⚡ Decision Tree — First 3 Things to Try

```
遇到需求 → 先问"Hastur 能不能做？"
  │
  ├─ 查属性/状态 → inspect 或 scene/properties
  ├─ 查场景结构 → inspect (深度 3+) 或 scene/tree
  ├─ 查编译错误 → errors (不用等用户截图)
  ├─ 查信号连接 → signal /root/NodePath
  ├─ 改代码后验证 → reload (先) → errors (后)
  ├─ 执行测试代码 → execute (snippet 模式)
  ├─ 操作场景节点 → execute (场景上下文)
  └─ 调试游戏运行时 → console/stream
```

### 1. REST API 端点总览

**诊断层（v0.6.0）** — 先查再猜：

| 端点 | 用途 | 典型场景 |
|------|------|---------|
| `GET /api/scene/inspect?path=/root&depth=3` | 场景树快照 + 属性 + 信号 | 看节点挂了没有、池状态 |
| `GET /api/scene/signals?path=/root/Node` | 信号连接诊断 | 验证信号是否连上 |
| `GET /api/project/compile-errors` | 查询编译报错 | 重启后自动查错误 |
| `GET /api/executors/:id/console/stream?since=0` | 游戏实时输出 | 看 print 输出（代替"用户截图"） |

**执行层：**

| 端点 | 用途 | 执行模式 |
|------|------|---------|
| `POST /api/script/check` | 编译检查（不执行） | 纯编译 |
| `POST /api/execute` | 执行 GDScript | `snippet`(默认) / `in_scene`(v0.6.0) |
| `POST /api/script/reload` | 软重载脚本（含黑名单保护） | 游戏脚本可热更 |

**编辑器操作：**

| 端点 | 用途 |
|------|------|
| `POST /api/project/rescan` | 写文件后强制编辑器刷新 |
| `POST /api/scene/save` | 保存当前场景 |
| `GET /api/executors/:id/scene/properties` | 读节点属性（支持 filter） |
| `GET /api/scene/tree` | 旧版场景树 |
| `POST /api/scene/nodes` / `DELETE /api/scene/nodes` | 创建/删除场景节点 |

### 2. 三种执行模式详解

```bash
# Snippet 模式（默认）— 轻量，无场景上下文
curl -s -X POST http://localhost:5302/api/execute \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"code":"var t=Engine.get_main_loop() as SceneTree; print(t.root.name)","project_name":"Six Fighter"}'
# 注意：get_node() / get_tree() 不可用，用 Engine.get_main_loop() 替代

# In-Scene 模式（v0.6.0）— get_node() 可直接用
curl -s -X POST http://localhost:5302/api/execute \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"code":"print(get_node(\"CameraAnchor/Camera2D\").zoom)","project_name":"Six Fighter","execution_mode":"in_scene","context_path":"/root/SkillDemo"}'
```

### 3. GDScript 编码规则（致命）

| 规则 | 说明 |
|------|------|
| **Tab 缩进** | 绝对不能用空格！在 Python 字符串中用 `\t` |
| **print() 自动捕获** | 独立 `print(...)` 语句自动被捕获到输出中 |
| **自引用** | `executeContext.output("key", "val")` 手动输出 |
| **私有成员** | 可访问 `_do_cast()`、`_is_casting` 等私有方法/变量 |
| **`@tool`** | Snippet 模式自动添加；Full Class 模式需手动加 |

### 4. CLI 命令速查

```bash
python game/tools/hastur.py status          # 全状态概览（推荐最先用）
python game/tools/hastur.py exec '<code>'   # 执行 GDScript
python game/tools/hastur.py check '<code>'  # 编译检查    [v0.5.0]
python game/tools/hastur.py inspect <path>  # 场景快照    [v0.6.0] ← 最常用的诊断命令
python game/tools/hastur.py errors          # 编译报错    [v0.6.0] ← 重启后立即执行
python game/tools/hastur.py signal <path>   # 信号诊断    [v0.6.0]
python game/tools/hastur.py reload <path>   # 软重载      [v0.6.0]
python game/tools/hastur.py rescan          # 强制刷新文件系统
python game/tools/hastur.py props <path>    # 获取节点属性
python game/tools/hastur.py scene-tree      # 获取场景树
python game/tools/hastur.py logs 20         # 最近日志
python game/tools/hastur.py save            # 保存场景
```

### 5. 工作流实战模板

**场景 1：用户反馈 Bug，第一步做什么？**
```bash
python game/tools/hastur.py status          # broker + executor 都在吗？
python game/tools/hastur.py errors          # 有编译报错吗？（不用等用户截图）
python game/tools/hastur.py exec 'print("alive")'  # 编辑器能响应吗？
```

**场景 2：修改代码后如何验证？**
```bash
python game/tools/hastur.py reload res://scripts/combat/combat_mediator.gd  # 先编译验证
python game/tools/hastur.py errors         # 检查是否引入新错误
```

**场景 3：排查"为什么跳字不显示"**
```bash
python game/tools/hastur.py inspect /root/SkillDemo/DamageTextLayer --depth 3  # 节点在不在？
python game/tools/hastur.py signal /root/SkillDemo/SkillSystem/SkillSignalBus    # 信号连上了吗？
# 然后用 execute in_scene 模式写测试代码
```

**场景 4：排查"技能没有伤害"**
```bash
python game/tools/hastur.py inspect /root/SkillDemo/SkillSystem/LaserBeamPool  # 池状态
# 然后用 execute in_scene 检查碰撞、属性等
```

### 6. 已知限制

- **Snippet 模式**：`get_tree()` / `get_node()` 不可用，用 `Engine.get_main_loop()` 替代
- **In-Scene 模式**：需重启编辑器后才能应用 gdscript_executor.gd 修改
- **核心脚本不可热更**（黑名单保护）：`broker_client.gd`, `gdscript_executor.gd`, `editor_log_catcher.gd` 等 9 个
- **`err=22`**：`Cannot reload script while instances exist` — 有活跃实例时无法热更，必须重启编辑器
- **编辑器场景 vs 游戏场景**：`Engine.get_main_loop().root` 返回编辑器界面根，不是编辑中的场景

Full reference: [`../docs/HasturOperationGD-Technical-Whitepaper.md`](../docs/HasturOperationGD-Technical-Whitepaper.md)

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
- HasturOperationGD technical whitepaper: `../docs/HasturOperationGD-Technical-Whitepaper.md` (project root, single source of truth)
- Camera system: `docs/claude-ref-camera.md` (in-game docs)
- SkillDemo scene: `docs/claude-ref-skill-demo.md` (in-game docs)
