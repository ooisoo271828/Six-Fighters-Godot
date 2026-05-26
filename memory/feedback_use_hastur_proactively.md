---
name: feedback-use-hastur-proactively
description: "Always consider Hastur plugin as first option for debugging, inspection, verification, and editor interaction. Don't wait for user to suggest it."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f3ff96ce-ecf9-430b-896c-70d81506fc5a
---

Always consider Hastur capabilities before falling back to manual workarounds.

**Why:** The user repeatedly found that the AI forgot Hastur existed and needed to be reminded. This wastes time and breaks workflow. Hastur is the primary bridge between the AI and the running Godot editor — it should be the default tool, not a last resort.

**How to apply:** When you encounter any of these situations, reach for Hastur FIRST:

1. **Debugging code changes** — After editing `.gd` files, use `POST /api/script/check` (compile check) or `POST /api/script/reload` (v0.6.0, full script reload) before moving on. Use `POST /api/execute` to run test snippets.

2. **Checking compile errors** — After editor restarts, call `GET /api/project/compile-errors` (v0.6.0) **first**. Don't wait for user to report errors. Always check this before starting any work.

3. **Inspecting scene structure** — Use `GET /api/scene/inspect?path=/root&depth=N` (v0.6.0) for a complete node snapshot with properties + signals in one call. This is more efficient than reading .tscn files.

4. **Testing code in-editor** — Use `POST /api/execute` with `execution_mode: "snippet"` (default, no scene context) or `"in_scene"` (v0.6.0, get_node()/get_tree() available, requires `context_path: "/root/NodePath"`).

5. **After creating/modifying files externally** — After using Write tool to create `.gd` or `.tres` files, call `POST /api/project/rescan` before executing code that depends on them.

6. **Persisting node changes** — After creating nodes via execute, use `POST /api/scene/save` to persist.

7. **Reading error details** — Always check `run_error_details` and `compile_error_details` (not just the flat error string) for `file`, `line`, `function`, `frames` to get exact error locations.

8. **Reloading scripts** — After modifying game scripts (not Hastur core scripts), use `POST /api/script/reload` (v0.6.0) to verify compilation. Returns err=22 if instances exist.

9. **Checking signal connections** — Use `GET /api/scene/signals?path=/root/NodePath` (v0.6.0) to verify signals are connected to the right methods.

The complete API reference is in [[reference_hastur_capabilities]].
