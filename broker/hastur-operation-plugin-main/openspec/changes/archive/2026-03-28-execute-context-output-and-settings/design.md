## Context

HasturOperationGD 是一个 Godot 4.6 编辑器插件，允许在编辑器中动态执行 GDScript 代码。当前执行器仅返回编译/运行的成功/失败状态，无法获取代码执行的中间结果或变量值。AI 编码代理通过此插件验证逻辑时，无法观察输出数据，严重限制了交互能力。

当前 `executeContext` 是一个普通 Dictionary，通过属性注入（snippet 模式）或方法参数（full class 模式）传递给用户代码，但没有任何输出机制。

## Goals / Non-Goals

**Goals:**
- 允许执行中的 GDScript 代码通过 `executeContext.output(key, value)` 输出结构化 key-value 数据
- 执行结果包含 outputs 数据，Dock UI 展示 Output 段落
- output value 字符数限制，超出截断并附带 AI 可读的英文截断警告
- 通过 Godot Project Settings 提供插件配置管理，output 字符限制可在编辑器中修改

**Non-Goals:**
- 不支持嵌套/结构化 output value（仅字符串）
- 不支持 output 的排序/分组
- 不实现独立的设置面板 UI（使用 Godot 原生 Project Settings 对话框）

## Decisions

### D1: 使用自定义 ExecutionContext 类替代 Dictionary

**选择**: 创建 `ExecutionContext` 类（继承 RefCounted），包含 `output()` 方法和 outputs 收集数组。

**备选方案**:
- A) 在 Dictionary 中注入 Callable：`executeContext["output"] = func(k, v): ...`，用户需 `executeContext.output.call(k, v)` 调用 — 调用语法不自然
- B) 使用 CallableDictionary hack — 不够清晰

**理由**: 自定义类提供干净的 `executeContext.output("key", "value")` 调用语法，同时内部可封装截断逻辑和 outputs 收集。ExecutionContext 可作为独立文件 `execution_context.gd` 放在插件目录下。

### D2: output 截断在 ExecutionContext 内部处理

**选择**: `ExecutionContext.output()` 方法内部检查 value 长度，超限时截断并添加英文警告前缀。

**截断警告格式**:
```
[TRUNCATED: Output exceeded {n} char limit. Refine output to be more focused. Actual length: {actual}]
```
警告放在截断后的 value 之前，总长度不超过 max_output_length。

**理由**: 截断逻辑封装在 ExecutionContext 中，执行器无需额外处理。警告信息使用英文且面向 AI，明确说明限制和原因。

### D3: 使用 Godot ProjectSettings API 管理插件配置

**选择**: 通过 `ProjectSettings.set_setting()` / `get_setting()` 注册插件设置，使用 `add_property_info()` 添加编辑器 UI 提示。

**设置项命名**: `hastur_operation/output_max_char_length`，类型 int，默认值 800。

**备选方案**:
- A) 自定义 JSON/ConfigFile — 需要自行管理文件路径和 UI
- B) EditorSettings — 仅编辑器级别，不随项目共享

**理由**: ProjectSettings 是 Godot 推荐的插件配置方式，设置随 `project.godot` 持久化，在编辑器 Project Settings 对话框中可见可编辑，且随项目版本控制共享。使用 `hastur_operation/` 前缀在设置中分组显示。

### D4: 插件初始化时注册设置默认值

**选择**: 在 `hasturoperationgd.gd` 的 `_enter_tree()` 中调用设置注册逻辑。

**模式**:
```gdscript
if not ProjectSettings.has_setting("hastur_operation/output_max_char_length"):
    ProjectSettings.set_setting("hastur_operation/output_max_char_length", 800)
ProjectSettings.set_initial_value("hastur_operation/output_max_char_length", 800)
ProjectSettings.add_property_info({"name": "...", "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "100,10000,1"})
```

**理由**: 遵循 Godot EditorPlugin 的标准模式（ProjectSettings 文档示例），确保首次启用插件时设置存在且可在 Project Settings 对话框中编辑。

## Risks / Trade-offs

- **[Breaking Change: executeContext 类型变更]** → 从 Dictionary 变为 ExecutionContext 对象。如果用户代码依赖 Dictionary 特有操作（如 `executeContext.keys()`），会出错。风险较低因为插件刚实现、使用场景有限。
- **[截断信息计入字符限制]** → 截断警告前缀占用的字符数会减少实际可输出的内容量。设计上截断警告前缀长度约 100 字符，800 限制下实际可用约 700 字符，属于合理范围。
- **[ProjectSettings 持久化依赖 project.godot]** → 设置写入 project.godot 文件，多人协作时可能产生冲突。风险低，单个整数值冲突概率极小。
