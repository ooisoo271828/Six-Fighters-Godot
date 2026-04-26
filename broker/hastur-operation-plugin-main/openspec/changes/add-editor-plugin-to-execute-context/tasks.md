## 1. 修改 ExecutionContext

- [x] 1.1 在 `execution_context.gd` 中添加 `var editor_plugin` 属性（类型 EditorPlugin，默认 null）
- [x] 1.2 修改 `_init()` 接受可选参数 `editor_plugin = null`，并将其赋值给 `editor_plugin` 属性

## 2. 修改 GDScriptExecutor

- [x] 2.1 修改 `execute_code()` 签名，添加可选参数 `editor_plugin = null`
- [x] 2.2 在创建 `ExecutionContext` 时将 `editor_plugin` 传入构造函数

## 3. 修改 ExecutorBackend

- [x] 3.1 添加 `var _editor_plugin` 属性
- [x] 3.2 修改 `_ready()` 或添加 `initialize()` 方法接收 EditorPlugin 引用
- [x] 3.3 在调用 `_executor.execute_code()` 时传入 `_editor_plugin`

## 4. 修改插件入口

- [x] 4.1 在 `hasturoperationgd.gd` 的 `_enter_tree()` 中，将自身（`self`）传递给 `ExecutorBackend`

## 5. 验证

- [x] 5.1 验证 snippet 模式下可通过 `executeContext.editor_plugin` 访问 EditorPlugin
- [x] 5.2 验证未注入时 `editor_plugin` 为 null 且不报错
