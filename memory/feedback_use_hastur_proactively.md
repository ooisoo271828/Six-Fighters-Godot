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

1. **Debugging code changes** — After editing `.gd` files, use `POST /api/script/check` to verify compilation before moving on. Use `POST /api/execute` to run test snippets.

2. **Inspecting runtime state** — Need to know a node's position, scale, visibility, or any property? Use `GET .../scene/properties` instead of guessing from code.

3. **Understanding scene structure** — Need to find node paths? Use `GET .../scene/tree` instead of reading `.tscn` files manually.

4. **Testing code in-editor** — Any time you need to verify behavior, write a quick snippet and execute it via `POST /api/execute`. Don't just assume code works.

5. **After creating/modifying files externally** — After using Write tool to create `.gd` or `.tres` files, call `POST /api/project/rescan` before executing code that depends on them.

6. **Persisting node changes** — After creating nodes via execute, use `POST /api/scene/save` to persist.

7. **Reading error details** — Always check `run_error_details` and `compile_error_details` (not just the flat error string) for `file`, `line`, `function`, `frames` to get exact error locations.

The complete API reference is in [[reference_hastur_capabilities]].
