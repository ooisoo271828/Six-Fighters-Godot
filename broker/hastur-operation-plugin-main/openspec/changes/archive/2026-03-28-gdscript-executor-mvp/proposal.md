## Why

需要一个类似 JS `eval()` 的能力，在 Godot 编辑器环境中动态编译并执行任意 GDScript 代码。这使得编码代理（coding agent）可以通过程序化方式操控 Godot 编辑器，执行任何运行时和编辑器 API 操作，无需预先编写固定逻辑或重启编辑器。

## What Changes

- 新增 GDScript 执行器核心模块，基于 `GDScript.new()` + `source_code` + `reload()` 方案，支持动态编译和执行 GDScript 代码字符串
- 支持两种执行模式：**代码片段模式**（自动包装为 `extends RefCounted` 类，在 `_init()` 中执行）和**完整类模式**（要求提供 `execute(executeContext)` 方法）
- 两种模式均向执行代码注入 `executeContext` 变量（当前为空字典，后续扩展）
- 执行结果返回结构化信息：编译是否成功、编译错误信息、运行是否成功、运行时错误信息
- 新增编辑器 Dock 面板，提供代码输入框、执行按钮、结果输出框的 GUI 测试界面

## Capabilities

### New Capabilities
- `gdscript-executor`: 核心执行器模块，负责接收代码字符串、动态编译、执行、返回结果、清理内存
- `executor-dock-ui`: 编辑器 Dock 面板，提供代码输入、执行触发、结果展示的 GUI 界面

### Modified Capabilities
<!-- 无现有 capability 需要修改 -->

## Impact

- 新增文件：`addons/hasturoperationgd/` 目录下新增执行器脚本和 Dock 场景文件
- 修改文件：`addons/hasturoperationgd/hasturoperationgd.gd`（插件入口，注册 Dock）
- 修改文件：`addons/hasturoperationgd/plugin.cfg`（如有必要更新插件描述）
- 依赖：Godot 4.x 的 `GDScript`、`EditorPlugin`、`EditorDock`、`Control` 等 API
