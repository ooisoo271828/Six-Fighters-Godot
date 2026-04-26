## Context

项目 `hastur-operation-plugin` 是一个 Godot 4.6 编辑器插件，位于 `addons/hasturoperationgd/`，当前仅有空的插件入口脚本和 `plugin.cfg`。目标是实现一个 GDScript 代码执行器，使得编码代理或用户可以在 Godot 编辑器环境中动态执行任意 GDScript 代码。

核心依赖 API：
- `GDScript.new()` — 创建动态脚本资源（继承自 `Script` → `Resource` → `RefCounted`）
- `Script.source_code` — 设置脚本源码字符串
- `Script.reload()` — 编译源码，返回 `Error` 枚举
- `Script.can_instantiate()` — 检查编译后是否可实例化
- `EditorPlugin` + `EditorDock` — 创建编辑器 Dock 面板

## Goals / Non-Goals

**Goals:**
- 实现 GDScript 代码字符串的动态编译与执行
- 支持两种模式：代码片段（自动包装）和完整类（需 `execute` 方法）
- 返回结构化执行结果（编译状态、编译错误、运行状态、运行错误）
- 执行后正确释放脚本实例和 GDScript 资源，避免内存泄漏
- 提供编辑器 Dock GUI 用于手动测试

**Non-Goals:**
- 不支持获取 GDScript 代码的返回值（MVP 阶段）
- 不支持异步执行
- 不实现代码沙箱或安全限制
- 不支持持久化执行的脚本实例（每次执行后清理）
- `executeContext` 当前仅传入空字典，不包含具体运行时内容

## Decisions

### D1: 使用 `GDScript.new()` + `source_code` + `reload()` 方案

**选择**：在内存中创建 `GDScript` 资源，设置 `source_code`，调用 `reload()` 编译。

**备选方案**：
- 写临时文件 + `load()`：需要文件 I/O，编辑器外可能有权限问题，需管理临时文件清理
- `Expression` 类：仅支持单行表达式，不支持循环/条件/函数定义

**理由**：纯内存操作，无文件 I/O，编译错误通过 `reload()` 返回值检测，`GDScript` 继承 `RefCounted` 可自动内存管理。

### D2: 代码片段自动包装为 `extends RefCounted` 类

**选择**：将用户的代码片段包装为：
```gdscript
@tool
extends RefCounted

var executeContext = {}  # 由调用方传入

func _init():
    executeContext = _exec_ctx
    <用户代码>

var _exec_ctx = {}
```

实际上为了传递 `executeContext`，需要通过属性或 `_init()` 参数传递。由于 `_init()` 不支持自定义参数（`GDScript.new()` 的 vararg 不传递到 `_init`），改为在实例化后设置属性再调用执行方法。

**修正方案**：代码片段包装为：
```gdscript
@tool
extends RefCounted

var executeContext

func run():
    <用户代码>
```
实例化后设置 `executeContext` 属性，然后调用 `run()` 方法。

完整类模式则要求用户代码中定义 `execute(executeContext)` 方法。

**理由**：`RefCounted` 是最轻量的基类，实例化后自动引用计数管理。

### D3: 两种模式通过检测 `extends` 关键字区分

**选择**：检测代码字符串是否以 `extends` 开头（忽略注释和空白）。如果包含 `extends` 则视为完整类模式，否则为代码片段模式。

**理由**：简单可靠，完整类必须声明基类，代码片段通常不包含。

### D4: 编辑器 Dock 面板布局

**选择**：使用 `EditorDock` + 纯代码构建 UI（不用 `.tscn` 场景文件），包含：
- `CodeEdit`（代码输入框，带语法高亮支持）
- `Button`（执行按钮）
- `RichTextLabel`（结果输出框）

**备选方案**：创建 `.tscn` 场景文件

**理由**：MVP 阶段纯代码构建更灵活，减少文件数量，后续可改为场景文件。

### D5: 错误处理策略

**选择**：
- 编译失败：捕获 `reload()` 返回非 `OK` 的错误码，通过 `get_error_text()` 获取详细错误信息（注：`get_error_text` 是 `Expression` 的方法，对于 `Script` 编译错误需要通过 push_error 或 stderr 捕获）
- 运行时错误：通过 `try-catch` 不存在于 GDScript，需要通过连接 `script_changed` 或检查引擎日志。实际上 GDScript 在编辑器中运行时错误会打印到输出面板。

**修正**：GDScript 没有 try-catch 机制。运行时错误会直接打印到编辑器输出。对于 MVP，运行时错误的检测方式有限——如果代码崩溃，实例化或方法调用会失败并产生错误日志。我们可以检查方法是否存在来判断部分问题。

对于完整类模式：检查 `has_method("execute")`，若不存在则返回运行时错误。

### D6: 内存管理

**选择**：`GDScript` 继承 `RefCounted`，当没有引用时自动释放。实例化的对象也继承自 `RefCounted`（代码片段模式）或用户指定基类。每次执行完毕后将引用置 `null` 触发释放。

## Risks / Trade-offs

- **[编译错误信息有限]** `Script.reload()` 只返回 `Error` 枚举值，不提供详细错误文本。→ 对于 MVP 可接受，编译失败的 Error Code 已足够判断问题。实际在编辑器环境中，编译错误会输出到 Godot 的输出面板。
- **[运行时异常无法捕获]** GDScript 没有 try-catch，运行时崩溃无法优雅捕获。→ MVP 可接受，用户可在编辑器输出面板看到错误。
- **[代码注入风险]** 执行任意代码无沙箱。→ 编辑器插件场景下用户本就有完整权限，风险可接受。
- **[编辑器稳定性]** 恶意/错误代码可能导致编辑器崩溃。→ MVP 可接受，后续可考虑在子进程中执行。
