## MODIFIED Requirements

### Requirement: ExecuteContext injection
Both execution modes SHALL accept an `ExecutionContext` object (inheriting RefCounted) that provides an `output(key, value)` method and an `editor_plugin` property. In snippet mode, it SHALL be set as a property on the instance before `run()` is called. In full class mode, it SHALL be passed as the argument to `execute(executeContext)`. The ExecutionContext SHALL read its `max_output_char_length` from `ProjectSettings.get_setting("hastur_operation/output_max_char_length", 800)`. The ExecutionContext SHALL accept an optional `editor_plugin` parameter in its constructor to hold a reference to the EditorPlugin instance.

#### Scenario: Snippet receives ExecutionContext
- **WHEN** a snippet is executed
- **THEN** the `executeContext` variable SHALL be an ExecutionContext object with an accessible `output()` method and an `editor_plugin` property

#### Scenario: Full class receives ExecutionContext
- **WHEN** a full class is executed
- **THEN** the `execute(executeContext)` method SHALL receive the ExecutionContext object as its parameter, and `executeContext.editor_plugin` SHALL be accessible

#### Scenario: ExecutionContext with EditorPlugin injected
- **WHEN** the executor is called with a valid EditorPlugin reference
- **THEN** the ExecutionContext SHALL have `editor_plugin` set to that reference, and agent code SHALL be able to call methods on it

#### Scenario: ExecutionContext without EditorPlugin
- **WHEN** the executor is called without providing an EditorPlugin reference
- **THEN** the ExecutionContext SHALL have `editor_plugin` set to `null`, and execution SHALL proceed normally
