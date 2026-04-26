## Context

当前 Hastur Operation Plugin 是一个 Godot EditorPlugin，允许通过 GDScript executor 执行代码。执行时创建 `ExecutionContext` 对象传递给用户代码，但该对象仅提供 `output()` 方法。插件入口 `hasturoperationgd.gd` extends EditorPlugin，而 executor 位于 `GDScriptExecutor`，中间经过 `ExecutorBackend`。调用链为：

```
hasturoperationgd.gd (EditorPlugin)
  → ExecutorBackend
    → GDScriptExecutor
      → ExecutionContext
```

目前 EditorPlugin 引用没有沿这条链传递下去。

## Goals / Non-Goals

**Goals:**
- 让 agent 执行的代码能通过 `executeContext.editor_plugin` 访问 EditorPlugin 实例
- 沿调用链逐层传递 EditorPlugin 引用，保持现有代码结构不变
- 确保向后兼容：不传 EditorPlugin 时功能不受影响

**Non-Goals:**
- 不为 EditorPlugin API 做额外封装或限制访问范围
- 不修改远程执行（broker_client）的协议层
- 不对 agent 可调用的 EditorPlugin 方法做白名单过滤

## Decisions

### Decision 1: 在 ExecutionContext 上添加 `editor_plugin` 属性

**选择**: 直接在 ExecutionContext 上加 `var editor_plugin` 属性（类型为 EditorPlugin 或 null）

**理由**: ExecutionContext 是 agent 代码已能访问的对象，在其上扩展最自然。使用可空类型保持向后兼容。

**备选方案**: 创建独立的 `PluginContext` 对象——增加了不必要的复杂度，且 agent 代码需要额外学习新 API。

### Decision 2: 通过构造函数参数注入 EditorPlugin

**选择**: 修改 `ExecutionContext._init()` 接受可选的 `editor_plugin` 参数

**理由**: 构造时注入是最直接的方式，避免后续需要 setter 方法或可变状态。GDScript 的 `_init` 支持默认参数，向后兼容。

### Decision 3: 沿调用链透传 EditorPlugin

**选择**: `hasturoperationgd.gd` → `ExecutorBackend`（构造或初始化时传入） → `GDScriptExecutor.execute_code()` → `ExecutionContext`

**理由**: 这是依赖注入的标准模式。每层持有引用并向下传递，不引入全局单例或 autoload。

**备选方案**: 使用 Engine.get_singleton 或全局 autoload 获取 EditorPlugin——破坏了现有的依赖注入模式，增加隐式耦合。

## Risks / Trade-offs

- **[Agent 可调用任何 EditorPlugin API]** → 限定为可信 agent 使用，暂不做 API 白名单
- **[EditorPlugin 引用在插件禁用时失效]** → ExecutionContext 是短生命周期对象（单次执行），风险极低
- **[execute_code 签名变更]** → 使用默认参数 `editor_plugin = null` 保持向后兼容
