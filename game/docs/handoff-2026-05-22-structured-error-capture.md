# Handoff: Hastur 结构化错误捕获实现

> **日期**: 2026-05-22
> **目的**: 记录 HasturOperationGD 插件运行时错误捕获的 4 项修复，使 AI 在调试时能获取完整的 file/line/stack 信息

---

## 问题和背景

AI 通过 Hastur 执行 GDScript 时，如果代码报错只返回平字符串（如 `"索引超出范围"`），没有文件名、行号、堆栈。AI 只能盲猜位置，反复试错甚至原地打转。

**根因**: Hastur 插件的 `_CompileErrorCapturer` 和 `HasturLogger` 虽然通过 `OS.add_logger()` 收到了完整的 `ScriptBacktrace` 对象（含 file/line/function/栈帧），但在 4 个环节把信息丢掉了。

---

## 修改内容

### 修改 1: `_log_message` 空操作 → 实现捕获

**文件**: `game/addons/hasturoperationgd/gdscript_executor.gd:294-295`

之前 `_log_message` 是 `pass`，走这条路径的运行时错误被静默丢弃。现在实现为在捕获窗口内记录错误消息（仅 `error == true`）。

### 修改 2: `_log_error` 立即提取帧数据

**文件**: `game/addons/hasturoperationgd/gdscript_executor.gd:279-330`

- 新增 `_captured_details: Array` 存储 structed 数据
- `_log_error` 回调中调用 `_extract_frames()` 将 `ScriptBacktrace` 对象转换为普通字典（`{file, line, function}`）
- `execute_code` 在 compile/instantiate/run 三阶段分别调用 `get_captured_details()`，存入 `result.compile_error_details` / `result.run_error_details`

关键约束：`ScriptBacktrace` 对象持有 GC 引用，不能在回调之外存储，必须在 `_log_error` 中立即提取。

### 修改 3: `execute_result` 转发结构化字段

**文件**: `game/addons/hasturoperationgd/broker_client.gd:283-296`

`execute_result` 消息增加 `compile_error_details` 和 `run_error_details` 字段，同步返回给 AI。

### 修改 4: 日志通道帧数据提取

**文件**: 
- `game/addons/hasturoperationgd/hastur_logger.gd`
- `game/addons/hasturoperationgd/editor_log_catcher.gd`
- `game/addons/hasturoperationgd/broker_client.gd`

`HasturLogger._log_error` 中提取帧数据后传递到所有下游路径（`log_error`、`capture_warning`、`log_script_error`、`capture_runtime_error`），确保 `GET .../logs/errors` 异步日志通道也包含栈帧信息。

---

## 返回格式示例

```json
{
  "run_success": false,
  "run_error": "索引超出范围",
  "run_error_details": [{
    "message": "索引超出范围",
    "file": "gdscript://-9223370014612971483.gd",
    "line": 9,
    "function": "run",
    "frames": [
      {"function": "run", "file": "gdscript://...", "line": 9},
      {"function": "_execute_snippet", "file": "res://.../gdscript_executor.gd", "line": 236},
      ...
    ]
  }]
}
```

---

## 相关文档

- 插件技术蓝皮书: `docs/HasturOperationGD-Technical-Whitepaper.md`（第 3.1.8 节）
- 项目 CLAUDE.md: `game/.claude/CLAUDE.md`（Hastur Quick Reference + Systematic Debugging 更新）
- 白皮书深度分析: `docs/HasturOperationGD-Technical-Whitepaper.md`

---

## 涉及文件清单

| 文件 | 修改量 | 内容 |
|------|--------|------|
| `game/addons/hasturoperationgd/gdscript_executor.gd` | +70/-2 | `_log_message` 修复、`_captured_details`、帧提取、`execute_code` 收集详情 |
| `game/addons/hasturoperationgd/broker_client.gd` | +4/-0 | `execute_result` 增加 `_details` 字段、`_on_logs_ready` 提取 frames |
| `game/addons/hasturoperationgd/hastur_logger.gd` | +29/-4 | `_log_error` 提取 frames、新增 `_extract_frames()` |
| `game/addons/hasturoperationgd/editor_log_catcher.gd` | +2/-1 | `log_script_error` 接受可选 `frames` 参数 |
| `game/.claude/CLAUDE.md` | 文档 | Hastur 快速参考 + Debugging 流程更新 |
| `docs/HasturOperationGD-Technical-Whitepaper.md` | 文档 | 新增 3.1.8 结构化错误捕获章节 |

**总计**: 4 个插件源码文件修改（+105/-7 行），2 个文档补充。
