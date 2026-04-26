## 1. GDScript Executor Core

- [x] 1.1 Create `addons/hasturoperationgd/gdscript_executor.gd` — the executor class with a public `execute_code(code: String, execute_context: Dictionary = {}) -> Dictionary` method
- [x] 1.2 Implement mode detection: check if code string contains `extends` keyword to determine snippet vs full class mode
- [x] 1.3 Implement snippet mode wrapping: wrap code into `@tool extends RefCounted` class with `var executeContext` property and `func run():` method containing the user's code
- [x] 1.4 Implement compile step: create `GDScript.new()`, set `source_code`, call `reload()`, check return value for compile errors
- [x] 1.5 Implement snippet execution: instantiate compiled script, set `executeContext` property, call `run()`, capture result
- [x] 1.6 Implement full class execution: instantiate compiled script, check `has_method("execute")`, call `execute(executeContext)` or return method-missing error
- [x] 1.7 Implement structured result: return `{"compile_success": bool, "compile_error": String, "run_success": bool, "run_error": String}`
- [x] 1.8 Implement memory cleanup: set all script instance and GDScript resource references to `null` after execution in all code paths (success and failure)

## 2. Editor Dock UI

- [x] 2.1 Create `addons/hasturoperationgd/executor_dock.gd` — a `@tool extends Control` script that builds UI programmatically with `VBoxContainer`, `CodeEdit`, `Button`, and `RichTextLabel`
- [x] 2.2 Implement the "Execute" button click handler: read code from `CodeEdit`, call executor, format and display result in `RichTextLabel`
- [x] 2.3 Implement result display formatting: show "Compile: SUCCESS/FAILED" and "Run: SUCCESS/FAILED/(skipped)" with error details when applicable
- [x] 2.4 Set minimum sizes: CodeEdit min height 200px, RichTextLabel min height 100px

## 3. Plugin Integration

- [x] 3.1 Update `addons/hasturoperationgd/hasturoperationgd.gd` — in `_enter_tree()`, create `EditorDock`, add the `executor_dock` control as child, set title "Hastur Executor", configure dock slot and layouts, call `add_dock()`
- [x] 3.2 In `_exit_tree()`, call `remove_dock()` and `queue_free()` to clean up the dock
- [x] 3.3 Verify plugin loads in Godot editor without errors, dock appears when enabled and disappears when disabled
