## ADDED Requirements

### Requirement: ExecutionContext 持有 EditorPlugin 引用
ExecutionContext SHALL 提供一个 `editor_plugin` 属性，类型为 `EditorPlugin` 或 `null`。该属性 SHALL 在构造时通过 `_init(editor_plugin = null)` 参数注入。当提供 EditorPlugin 实例时，该属性 SHALL 持有该引用；未提供时 SHALL 为 `null`。

#### Scenario: 注入 EditorPlugin 实例
- **WHEN** ExecutionContext 使用 `_init(plugin_instance)` 构造，其中 `plugin_instance` 是有效的 EditorPlugin 对象
- **THEN** `editor_plugin` 属性 SHALL 等于传入的 `plugin_instance`

#### Scenario: 未注入 EditorPlugin
- **WHEN** ExecutionContext 使用默认构造 `_init()` 创建
- **THEN** `editor_plugin` 属性 SHALL 为 `null`

### Requirement: agent 代码可通过 executeContext 访问 EditorPlugin
在 snippet 模式和 full class 模式下，agent 代码 SHALL 能通过 `executeContext.editor_plugin` 访问到正确的 EditorPlugin 实例（如果已注入）。

#### Scenario: Snippet 模式访问 editor_plugin
- **WHEN** 一个 snippet 被执行且 ExecutionContext 已注入 EditorPlugin 实例
- **THEN** agent 代码中 `executeContext.editor_plugin` SHALL 返回该 EditorPlugin 实例，且可调用其方法（如 `get_editor_interface()`）

#### Scenario: Full class 模式访问 editor_plugin
- **WHEN** 一个 full class 被执行且 ExecutionContext 已注入 EditorPlugin 实例
- **THEN** 在 `execute(executeContext)` 方法中，`executeContext.editor_plugin` SHALL 返回该 EditorPlugin 实例

#### Scenario: 未注入时访问 editor_plugin
- **WHEN** ExecutionContext 未注入 EditorPlugin（为 null）
- **THEN** `executeContext.editor_plugin` SHALL 为 `null`，执行 SHALL 不报错
