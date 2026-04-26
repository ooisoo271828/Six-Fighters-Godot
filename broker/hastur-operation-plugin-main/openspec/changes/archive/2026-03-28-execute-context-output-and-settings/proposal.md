## Why

当前执行器仅支持编译/运行的成功/失败状态反馈，无法获取 GDScript 代码的执行结果数据。AI 编码代理在通过执行器验证逻辑时，无法读取变量值或中间结果，严重限制了代理与 Godot 编辑器的交互能力。添加 `output` 机制后，代理可通过代码主动输出结构化的 key-value 结果，使执行器从单纯的"能否运行"工具升级为"运行并观察结果"的交互通道。

## What Changes

- 为 `executeContext` 添加 `output(key: String, value: String)` 方法，允许执行中的 GDScript 代码输出结构化的 key-value 对
- 执行结果 Dictionary 新增 `outputs` 字段（Array of `[key, value]`），Dock UI 在结果区域渲染 `Output:` 段落
- output 的 value 添加字符数限制，默认单个 value 最大 800 字符，超出时截断并在 value 开头添加 AI 可读的英文截断警告
- 新增插件设置机制，基于 Godot Project Settings 持久化存储配置项，首个配置项为 output 字符限制值，可在 Godot 编辑器 Project Settings 中修改

## Capabilities

### New Capabilities
- `plugin-settings`: 插件配置管理能力，通过 Godot Project Settings (`ProjectSettings`) 注册和持久化插件相关设置项，提供在编辑器中可修改的配置接口

### Modified Capabilities
- `gdscript-executor`: 新增 `output` 函数支持，修改执行结果结构以包含 outputs 数据，添加 value 字符数限制和截断逻辑
- `executor-dock-ui`: 修改结果展示区域以渲染 output key-value 对

## Impact

- `addons/hasturoperationgd/gdscript_executor.gd`: 核心变更 - 注入 output 方法到 executeContext，处理 outputs 收集和截断逻辑，修改返回结果结构
- `addons/hasturoperationgd/executor_dock.gd`: 渲染 output 段落到结果展示区域
- `addons/hasturoperationgd/hasturoperationgd.gd`: 可能需要在 plugin 初始化时注册 Project Settings 默认值
- `addons/hasturoperationgd/` 目录下可能新增 settings 相关的工具类文件
- API 变更：`execute_code()` 返回的 Dictionary 新增 `outputs` key（向后兼容，不破坏现有调用方）
