## Why

Agent 执行的 GDScript 代码需要调用 EditorPlugin 的 API（如 `get_editor_interface()`、`get_undo_redo()` 等），但目前 `ExecutionContext` 只提供了 `output()` 方法，agent 无法访问 EditorPlugin 实例。这限制了 agent 对编辑器功能的操控能力。

## What Changes

- 在 `ExecutionContext` 中添加 `editor_plugin` 属性，持有 EditorPlugin 实例的引用
- 在 `GDScriptExecutor.execute_code()` 创建 `ExecutionContext` 时，将 EditorPlugin 实例注入
- 需要从插件入口 `hasturoperationgd.gd` 逐层传递 EditorPlugin 引用到 executor

## Capabilities

### New Capabilities

- `editor-plugin-in-context`: 为 ExecutionContext 添加 editor_plugin 属性，使执行中的 GDScript 代码能通过 executeContext 访问 EditorPlugin 实例

### Modified Capabilities

- `gdscript-executor`: ExecutionContext 构造方式变化，需要接收 EditorPlugin 引用

## Impact

- `execution_context.gd`：新增 `editor_plugin` 属性
- `gdscript_executor.gd`：`execute_code()` 需要接收 EditorPlugin 参数并注入到 ExecutionContext
- `executor_backend.gd`：需要持有并传递 EditorPlugin 引用
- `hasturoperationgd.gd`（插件入口）：需要将自身传递给 ExecutorBackend
- `broker_client.gd`：如果远程执行也需要此能力，需同步修改
- API 变更：`execute_code()` 签名可能变化（新增参数）
