## 1. Plugin Settings Infrastructure

- [x] 1.1 Create `addons/hasturoperationgd/plugin_settings.gd` with a static method `register_settings()` that registers `hastur_operation/output_max_char_length` in ProjectSettings with default value 800, initial value, and property info (type int, range hint 100-10000)
- [x] 1.2 Create a static method `get_output_max_char_length()` in `plugin_settings.gd` that reads the setting from ProjectSettings with fallback default 800

## 2. ExecutionContext Object

- [x] 2.1 Create `addons/hasturoperationgd/execution_context.gd` as a RefCounted class with an `_outputs` array property and a `_max_output_length` int property
- [x] 2.2 Implement `output(key: String, value: String)` method that checks value length against `_max_output_length`, truncates with English warning prefix if needed, and appends `[key, value]` to `_outputs`
- [x] 2.3 Implement `get_outputs() -> Array` method that returns the collected outputs array
- [x] 2.4 Implement `_init()` that reads `_max_output_length` from `plugin_settings.gd`

## 3. Executor Integration

- [x] 3.1 Modify `gdscript_executor.gd` to create an `ExecutionContext` instance instead of passing a plain Dictionary
- [x] 3.2 Add `outputs` key to the result Dictionary (initialized as empty Array) in `execute_code()`
- [x] 3.3 After execution (both success and failure paths), read outputs from ExecutionContext and include in result
- [x] 3.4 Update `_execute_snippet()` to pass ExecutionContext as the executeContext property
- [x] 3.5 Update `_execute_full_class()` to pass ExecutionContext as the executeContext argument

## 4. Dock UI Output Display

- [x] 4.1 Modify `_display_result()` in `executor_dock.gd` to render an `Output:` section after run status when `result.outputs` is non-empty
- [x] 4.2 Format each output entry as `key: value` on its own line, with `---` separator before the Output section

## 5. Plugin Entry Point Integration

- [x] 5.1 Call `plugin_settings.gd`'s `register_settings()` in `hasturoperationgd.gd`'s `_enter_tree()` before dock creation

## 6. Verification

- [x] 6.1 Manually verify in Godot editor: plugin loads without errors, Project Settings shows `hastur_operation/output_max_char_length` with default 800
- [x] 6.2 Test snippet execution with `executeContext.output()` calls and verify output display in dock
- [x] 6.3 Test truncation: output a value exceeding 800 chars and verify truncation warning appears
- [x] 6.4 Test full class mode with `execute(executeContext)` and `executeContext.output()` calls
- [x] 6.5 Test runtime error scenario with outputs collected before the error
