# HasturOperationGD Full Reference

## Architecture

```
AI Agent (Claude Code)  ──HTTP──>  broker-server (Node.js)  ──TCP──>  Godot Editor + HasturPlugin
  localhost:5302                        localhost:5301
```

## Quick Start: Connecting to Godot

**Step 1**: Start the broker-server
```bash
cd broker/hastur-operation-plugin-main/broker-server && npm run dev
```

**Step 2**: Open the Godot project
- Open `game/` in the Godot 4.x Editor
- Project → Project Settings → Plugins → Enable **HasturOperationGD**
- The right-side **Executor** dock should show **Connected** (green)

**Step 3**: Verify the connection
```bash
python tools/editor_call.py --health
python tools/editor_call.py --executors
# or:
python tools/hastur.py status
```

## Key API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Health check (no auth) |
| `/api/executors` | GET | List connected Godot instances |
| `/api/execute` | POST | Execute GDScript code |
| `/api/scene/tree` | GET | Get current scene tree |
| `/api/scene/nodes` | POST | Create a node |
| `/api/scene/nodes?path=<path>` | DELETE | Delete a node |
| `/api/executors/:id/logs` | GET | Get editor logs |

**Auth Token**: see `broker/hastur-operation-plugin-main/broker-server/.env` or `HASTUR_TOKEN` env var.

## Executing GDScript Code

Standard way (recommended) — `editor_call.py` (Python 3.12):
```bash
# Execute single line
python tools/editor_call.py 'print("Hello from Godot!")'

# Execute from file
python tools/editor_call.py --file script.gd

# Get scene tree
python tools/editor_call.py --scene-tree
```

Alternative: `node tools/editor_call.js` if Python is unavailable.

## GDScript Code Conventions

- **Use Tab indentation** — Godot 4.x rejects spaces (`Mixed use of tabs and spaces`)
- **Snippet mode**: `print()` is auto-captured, no wrapping needed
- **Return data**: `executeContext.output("key", value)`, response format: `[["key","value"],...]`
- **Parse output**: `out[0]` / `out[1]`, not `out.get("key")`
- **EditorInterface**: Snippet: `executeContext.editor_plugin.get_editor_interface()`, Full Class: `ctx.editor_plugin.get_editor_interface()`
- **Full class mode**: requires `@tool` annotation and `execute(executeContext)` method
- **Compare null**: `!= null` / `== null`, not `is null`
- **Instantiate scene**: `.instantiate()`, not `.instance()`
- **`str(null)`** returns string `"null"`, not empty string
- **`reload_current_scene()`** returns void, cannot chain
- **Get child nodes**: `get_node()` / `get_node_or_null()`, not dict key

### GDScript Tab Indentation — Critical Rule

Indentation must use **Tab** (`\t`), **never spaces**. In Python strings:
```python
# Correct: use \t for indentation
code = 'if ei:\n\t executeContext.output("k", "v")'

# Wrong: spaces → Mixed use of tabs and spaces
code = 'if ei:\n    executeContext.output("k", "v")'
```

### GDScript Execution Quick Reference

```python
# Snippet mode — use \t indentation!
code = 'print("hello")'  # Auto-wrapped, print auto-captured

# Manipulate nodes
code = '\n'.join([
    'var n = get_node("/root/Main/SomeNode")',
    '\tif n != null:',
    '\t\tprint(n.name)'
])

# Call EditorInterface
code = '\n'.join([
    'var ei = executeContext.editor_plugin.get_editor_interface()',
    'var sel = ei.get_selection().get_selected_nodes()',
    '\tfor n in sel:',
    '\t\texecuteContext.output("sel", n.name)'
])

# Full Class mode — EditorInterface via ctx.editor_plugin
code = '\n'.join([
    '@tool',
    'extends RefCounted',
    'func execute(ctx):',
    '\tvar ei = ctx.editor_plugin.get_editor_interface()',
    '\tvar sel = ei.get_selection().get_selected_nodes()',
    '\tctx.output("count", str(sel.size()))',
])
```

## Capability Decision Tree

| Task | Method |
|------|--------|
| View scene structure | `python tools/editor_call.py --scene-tree` |
| Call EditorInterface API | Snippet mode via `executeContext.editor_plugin.get_editor_interface()` |
| Get/set node properties | Snippet mode, `get_node(path)` |
| Create node | Snippet mode, `new NodeType()` → `add_child()` |
| Delete node | Snippet mode, `node.queue_free()` |
| View editor logs | `python tools/editor_call.py --executors` → GET `/api/executors/:id/logs` |
| Complex multi-step ops | Full Class mode, use `executeContext.output()` for communication |
| Check project settings | Snippet mode, `ProjectSettings.get_setting()` |
| Get editor selected nodes | Snippet mode, `ei.get_selection().get_selected_nodes()` |

## Debug Checklist

- [ ] broker-server running? → `curl http://localhost:5302/api/health`
- [ ] Executor connected? → `curl -H "Authorization: Bearer <token>" http://localhost:5302/api/executors`
- [ ] Godot plugin enabled? → Right panel should show **Executor** dock with green indicator
- [ ] Code uses Tab indentation? (spaces will cause compile errors)

## Error Diagnosis Flow

1. **Connection Error**: `--health` → `--executors` → start broker / check Godot plugin
2. **Compile Error**: check Tab indentation (most common!) → check `@tool` annotation → check `extends`
3. **Runtime Error**: check logs GET `/api/executors/:id/logs` → check `@tool` → check `_editor_plugin_ref`
4. **"Placeholder" Error**: `@tool` missing or script not in editor mode

## Important Notes

- The broker-server must be **running before Godot connects** (auto-reconnect with exponential backoff)
- TCP 5301 is for Godot↔Broker, HTTP 5302 is for AI↔Broker
- Never expose the broker-server to the public internet
- The auth token is equivalent to a password — treat it as such

## Plugin Source Location

The Godot Editor loads plugins from: `game/addons/hasturoperationgd/`
- **Always modify files here** — do not modify `broker/hastur-operation-plugin-main/addons/` directly
- After modifying plugin files, disable/re-enable the plugin in Godot (or restart Godot)

## Broker-Server Location

Source: `broker/hastur-operation-plugin-main/broker-server/`
- `npm run dev` — start in development mode
- `npm run build && npm start` — production build

## Python Tooling

All CLI tools in `tools/` are Python-native (3.12+):
- **`editor_call.py`** — lightweight GDScript executor + scene tree query
- **`hastur.py`** — full CLI (health check, execute, scene ops, logs, broker start/stop)

`hastur.sh` and `editor_call.js` are kept as compatibility wrappers, functionally replaced by Python versions.
