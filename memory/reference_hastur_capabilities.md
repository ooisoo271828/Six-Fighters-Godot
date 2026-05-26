---
name: reference-hastur-capabilities
description: "HasturOperationGD v0.6.0 — Godot editor remote execution tool. Full REST API reference, CLI commands, execution modes, decision trees."
metadata: 
  node_type: memory
  type: reference
  priority: high
  related: 
    - feedback-use-hastur-proactively
  originSessionId: 51e26f72-2277-4669-8f99-37f9a6e31705
---

# HasturOperationGD v0.6.0 — 能力参考

## 架构

```
AI Agent :5302 (HTTP) → broker-server (Node.js) :5301 (TCP) → Godot Editor + HasturPlugin
```

**启动**：`cd broker/hastur-operation-plugin-main/broker-server && HASTUR_TOKEN=<token> npm run dev`
**Token**：`995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7`
**CLI**：`python game/tools/hastur.py <command>`

## 诊断 API（v0.6.0 — 先查再猜）

| API | 何时用 |
|-----|--------|
| `GET /api/scene/inspect?path=/root&depth=N` | 查场景树、节点属性、信号连接（一次调用全拿到） |
| `GET /api/scene/signals?path=/root/NodePath` | 查信号是否连接、连接到了哪个方法 |
| `GET /api/project/compile-errors` | 重启后自动检查编译报错（不用等用户截图） |
| `GET /api/executors/:id/console/stream?since=0` | 读游戏运行时的 print 输出 |

## 执行 API

| API | 用途 |
|-----|------|
| `POST /api/script/check` | 编译检查（不执行） |
| `POST /api/execute { code, execution_mode, context_path }` | 执行 GDScript |
| `POST /api/script/reload { path }` | 软重载脚本（有活跃实例时报 err=22） |

**execution_mode**：`"snippet"`（默认，无场景上下文）或 `"in_scene"`（v0.6.0，get_node/get_tree 可用）。

## CLI 速查

```
status    — 全状态概览（最先用）
exec      — 执行 GDScript
check     — 编译检查
inspect   — 场景快照（最常用诊断）
errors    — 编译报错（重启后立即执行）
signal    — 信号诊断
reload    — 软重载
rescan    — 刷新文件系统
props     — 节点属性
```

## 关键 GDScript 规则

1. **Tab 缩进** — 绝对不能用空格。Python 字符串中用 `\t`
2. **Snippet 模式**：`get_tree()` / `get_node()` 不可用 → 用 `Engine.get_main_loop() as SceneTree`
3. **In-Scene 模式**：`get_node("path")` 可直接用
4. **黑名单**（不可热更）：broker_client.gd、gdscript_executor.gd、editor_log_catcher.gd 等 9 个
5. `print()` 在 snippet 中自动捕获，printerr/push_warning/push_error 全局捕获
