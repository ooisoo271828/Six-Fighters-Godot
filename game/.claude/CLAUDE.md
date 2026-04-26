# Six Fighter GD - Project Guide

## HasturOperationGD Plugin System

This project integrates **HasturOperationGD** — a Godot 4.x plugin + broker-server that allows AI agents to execute GDScript code directly in the Godot Editor remotely via REST API.

### Architecture

```
AI Agent (Claude Code)  ──HTTP──►  broker-server (Node.js)  ──TCP──►  Godot Editor + HasturPlugin
  localhost:5302                        localhost:5301
```

### Quick Start: Connecting to Godot

**Step 1**: Start the broker-server
```bash
cd /e/VibeCoding/hastur-operation-plugin-main/broker-server && npm run dev
```
This starts the broker-server on TCP 5301 (Godot ↔ broker) and HTTP 5302 (AI ↔ broker).

**Step 2**: Open the Godot project
- Open `E:\VibeCoding\six-fighter-gd` in the Godot 4.x Editor
- Project → Project Settings → Plugins → Enable **HasturOperationGD**
- The right-side **Executor** dock should show **Connected** (green)

**Step 3**: Verify the connection
```bash
python tools/editor_call.py --health
python tools/editor_call.py --executors
# or:
python tools/hastur.py status
```

### Executing GDScript Code

**标准方式（推荐）** — 用 `editor_call.py`（Python 3.12）：
```bash
# 执行单行
python tools/editor_call.py 'print("Hello from Godot!")'

# 从文件执行
python tools/editor_call.py --file script.gd

# 获取场景树
python tools/editor_call.py --scene-tree
```

> 备选：如果 Python 不可用，可用 `node tools/editor_call.js` 替代。

**GDScript 缩进——致命规则**：缩进必须用 **Tab** (`\t`)，**绝对不能用空格**。在 Python 字符串中：
```python
# ✅ 正确：用 \\t 表示缩进
code = 'if ei:\n\t executeContext.output("k", "v")'

# ❌ 错误：用空格缩进 → Mixed use of tabs and spaces
code = 'if ei:\n    executeContext.output("k", "v")'
```

### Key API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Health check (no auth) |
| `/api/executors` | GET | List connected Godot instances |
| `/api/execute` | POST | Execute GDScript code |
| `/api/scene/tree` | GET | Get current scene tree |
| `/api/scene/nodes` | POST | Create a node |
| `/api/scene/nodes?path=<path>` | DELETE | Delete a node |
| `/api/executors/:id/logs` | GET | Get editor logs |

**Auth Token**: `995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7`

### GDScript Code Conventions

- **使用 Tab 缩进** — Godot 4.x 拒绝空格缩进（`Mixed use of tabs and spaces`）
- **Snippet 模式**：`print()` 会自动捕获，无需包装
- **返回数据**：用 `executeContext.output("key", value)`，响应格式为 `[["key","value"],...]`
- **解析 output**：用 `out[0]` / `out[1]`，不是 `out.get("key")`
- **EditorInterface**：Snippet 模式用 `executeContext.editor_plugin.get_editor_interface()`，Full Class 模式用 `ctx.editor_plugin.get_editor_interface()`
- **Full class 模式**：需有 `@tool` 注解和 `execute(executeContext)` 方法
- **比较 null**：用 `!= null` / `== null`，不是 `is null`
- **实例化场景**：用 `.instantiate()`，不是 `.instance()`
- **`str(null)`** 返回字符串 `"null"`，不是空字符串
- **`reload_current_scene()`** 返回 void，不能链式调用
- **实例化模板的子节点**：用 `get_node()` / `get_node_or_null()`，不是字典 key

### Debug Checklist

- [ ] broker-server running? → `curl http://localhost:5302/api/health`
- [ ] Executor connected? → `curl -H "Authorization: Bearer <token>" http://localhost:5302/api/executors`
- [ ] Godot plugin enabled? → Right panel should show **Executor** dock with green indicator
- [ ] Code uses Tab indentation? (spaces will cause compile errors)

### Plugin Source Location

The Godot Editor loads plugins from: `res://addons/hasturoperationgd/` (= `E:\VibeCoding\six-fighter-gd\addons\hasturoperationgd\`)
- **Always modify files here** — do not modify `hastur-operation-plugin-main/addons/` directly
- After modifying plugin files, disable/re-enable the plugin in Godot (or restart Godot)

### Broker-Server Location

Source: `/e/VibeCoding/hastur-operation-plugin-main/broker-server/`
- `npm run dev` — start in development mode
- `npm run build && npm start` — production build

### Project Structure

```
six-fighter-gd/
├── addons/hasturoperationgd/   # Godot plugin (active)
├── assets/                      # Game assets
├── scenes/                      # Scene files
│   ├── arena/                   # Combat arena scenes
│   ├── dev/                     # Dev/demo scenes (skill_demo.tscn)
│   ├── hub/                     # Main hub scene
│   ├── skill_system/            # Skill system (skill_system.tscn)
│   └── viewer/                  # Hero/skill viewer scenes
├── scripts/                     # Game code
│   ├── arena/                   # Arena logic
│   ├── combat/                  # Combat system
│   ├── core/                    # Core singletons
│   ├── data/                    # Data definitions
│   ├── dev/                     # Dev tools (camera_anchor, skill_demo)
│   ├── hub/                     # Hub logic
│   ├── skill_system/            # Skill system (registry/effects/modifiers)
│   ├── ui/                      # UI components
│   └── units/                   # Unit definitions
└── resources/                   # Resources
```

## Camera System

See full design doc: `docs/camera_system_design.md`

### Architecture: Anchor-Follow System

```
Player Input → CameraAnchor → Camera2D (child, hard follow)
                    ↓ soft follow (350px radius)
               Heroes (formation offset + AI offset)
```

- **CameraAnchor** (`scripts/dev/camera_anchor.gd`) — Node2D controlled by WASD/joystick, moves at 250 px/s
- **Camera2D** — child of CameraAnchor, smoothing 5.0, `current = true`
- **Soft follow radius**: 350px — heroes can freely move within this circle around the anchor
- **Hard limit**: 480px — hero teleports back to anchor position if exceeded
- **Emergency catch-up**: lerp speed 8.0/s when outside 350px (normal is 3.0/s)

### Direction Systems (Decoupled)

| System | Directions | Detail |
|--------|-----------|--------|
| Character facing | **4 directions** (up/down/left/right) | Quantized from movement vector; 2+2 fallback supported |
| Projectile flight | **360° free** | Not constrained by character facing; full mathematical freedom |

### Scene Layout (Portrait 540×960)

```
Y: 0~350   Enemy zone     ← targets/dummies appear here
Y: 200~750 Combat zone    ← projectile flight space
Y: 600~960 Hero zone      ← caster/heroes positioned here
```

## SkillDemo Scene

**Scene**: `res://scenes/dev/skill_demo.tscn`
**Script**: `scripts/dev/skill_demo.gd`

A skills testing tool that uses the same camera system as the actual game.

### Quick Start

In Godot Editor, open `res://scenes/dev/skill_demo.tscn` and press F5.

### Controls

| Control | Function |
|---------|----------|
| Skill dropdown | Select skill (loaded from SkillRegistry) |
| ▶ Play | Cast selected skill from caster to targets |
| ⏸ Pause | Freeze all projectiles (resume to continue) |
| ⏹ Stop | Clear all projectiles, reset state |
| Speed button | 0.5× / 1× / 2× cycle |
| Target mode button | single / dual / triangle / scatter / line cycle |
| 🔁 Loop checkbox | Auto-replay on completion |
| Space | Play/Stop shortcut |
| R | Toggle loop shortcut |

### Files

| File | Purpose |
|------|---------|
| `scripts/dev/camera_anchor.gd` | CameraAnchor component (reusable) |
| `scripts/dev/skill_demo.gd` | Main controller + UI |
| `scripts/dev/demo_bg.gd` | Grid background drawing |
| `scripts/dev/demo_caster.gd` | Caster unit visual |
| `scripts/dev/demo_target.gd` | Target dummy visual |
| `scenes/dev/skill_demo.tscn` | Scene file |

### Speed/Pause Implementation

Uses `Engine.time_scale`:
- Play: `time_scale = speed_multiplier` (0.5/1.0/2.0)
- Pause: `time_scale = 0.0` (projectiles freeze, UI still responsive)
- Always restored to 1.0 on scene exit (`_exit_tree()`)

## Plugin-First Workflow

**黄金原则：任何 Godot Editor 操作优先使用插件，而非手动编辑 tscn/tres 文件。**

### Before Every Godot Task

```bash
# 方法 A：快速检查（hastur.py status 一次性显示所有状态）
python tools/hastur.py status

# 方法 B：逐项检查
python tools/editor_call.py --health    # broker 是否运行？
python tools/editor_call.py --executors  # Godot 是否连接？

# 3. 如果都不通 → python tools/hastur.py start → 确保 Godot 插件已启用
```

### Capability Decision Tree

| 你想做什么 | 使用方式 |
|-----------|---------|
| 查看场景结构 | `python tools/editor_call.py --scene-tree` |
| 调用 EditorInterface API | Snippet 模式，通过 `executeContext.editor_plugin.get_editor_interface()` |
| 获取/修改节点属性 | Snippet 模式，`get_node(path)` |
| 创建节点 | Snippet 模式，`new NodeType()` → `add_child()` |
| 删除节点 | Snippet 模式，`node.queue_free()` |
| 查看编辑器日志 | `python tools/editor_call.py --executors` → GET `/api/executors/:id/logs` |
| 执行复杂多步操作 | Full Class 模式，用 `executeContext.output()` 通信 |
| 检查项目设置 | Snippet 模式，`ProjectSettings.get_setting()` |
| 获取编辑器选中节点 | Snippet 模式，`ei.get_selection().get_selected_nodes()` |

### GDScript Execution Quick Reference

```python
# Snippet 模式 — 用 \t 缩进！
code = 'print("hello")'  # 自动包装，print 自动捕获

# 操作节点
code = '\n'.join([
    'var n = get_node("/root/Main/SomeNode")',
    '\tif n != null:',
    '\t\tprint(n.name)'
])

# 调用 EditorInterface
code = '\n'.join([
    'var ei = executeContext.editor_plugin.get_editor_interface()',
    'var sel = ei.get_selection().get_selected_nodes()',
    '\tfor n in sel:',
    '\t\texecuteContext.output("sel", n.name)'
])

# Full Class 模式 — EditorInterface via ctx.editor_plugin
code = '\n'.join([
    '@tool',
    'extends RefCounted',
    'func execute(ctx):',
    '\tvar ei = ctx.editor_plugin.get_editor_interface()',
    '\tvar sel = ei.get_selection().get_selected_nodes()',
    '\tctx.output("count", str(sel.size()))',
])
```

### 错误诊断流程

1. **Connection Error**: `--health` → `--executors` → 启动 broker / 检查 Godot 插件
2. **Compile Error**: 检查 Tab 缩进（最常见！） → 检查 `@tool` 注解 → 检查 `extends`
3. **Runtime Error**: 查看日志 GET `/api/executors/:id/logs` → 检查 `@tool` → 检查 `_editor_plugin_ref`
4. **"Placeholder" Error**: `@tool` 缺失 或 脚本不在编辑器模式下工作

### Important Notes

- The broker-server must be **running before Godot connects** (auto-reconnect with exponential backoff)
- TCP 5301 is for Godot↔Broker, HTTP 5302 is for AI↔Broker
- Never expose the broker-server to the public internet
- The auth token is equivalent to a password — treat it as such

### Python Tooling

All CLI tools in `tools/` are Python-native (3.12+):
- **`editor_call.py`** — 轻量级 GDScript 执行器 + 场景树查询
- **`hastur.py`** — 全功能 CLI（健康检查、执行、场景操作、日志、broker 启停）

`hastur.sh` 和 `editor_call.js` 保留为兼容性包装/备选，功能上已被 Python 版本替代。
