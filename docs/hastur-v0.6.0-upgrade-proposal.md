# HasturOperationGD v0.6.0 Upgrade Proposal

> **Status**: Draft | Created: 2026-05-26 | Based-on: v0.5.0 (Implemented)
>
> **前置文档**:
> - `HasturOperationGD-Technical-Whitepaper.md` — 架构总览
> - `hastur-v0.5.0-upgrade-proposal.md` — v0.5.0 实现方案
> - `godot-ai-pitfall-guide.md` — 工程实践教训

---

## 1. Motivation

v0.5.0 完成了基础设施重构（注册式路由、代码重复消除）和四个基础端点（rescan / check / properties / save）。但经过**小激光术全流程开发**（从方案设计到多轮调试到交付）的实战检验，暴露出更深的系统性缺口：

### 1.1 实战数据

今天的开发会话中，AI 与 Godot 编辑器的交互情况：

| 交互类型 | 次数 | 耗时占比 | 实际完成方式 |
|---------|------|---------|------------|
| 确认脚本是否编译通过 | ~12 次 | 25% | 写 GDSnippet → execute → 看错误信息 |
| 检查场景中节点状态 | ~8 次 | 15% | 写 GDSnippet → Engine.get_main_loop() → 遍历场景树 |
| 查看编辑器的报错 | ~6 次 | 20% | **无法完成** — 依赖用户手动截图 |
| 验证信号是否连接 | ~4 次 | 10% | 写 GDSnippet → get_signal_connection_list() |
| 查看对象池状态 | ~5 次 | 10% | 写 GDSnippet → pool._active.size() |
| 调试碰撞检测 | ~3 次 | 10% | 写 GDSnippet + Area2D 自检 |
| 实际改代码 | ~15 次 | 10% | Edit/Write 工具 |

**结论**: 约 **90% 的时间花在了"信息获取"上**，而非实际的代码修改。核心问题不是"做不到"，而是"做到需要写太多胶水代码"。

### 1.2 三个核心缺口

```
缺口 1: AI 看不到编辑器里发生了什么
  ┌─────────────┐      ┌──────────────┐
  │ AI Agent    │      │ Godot Editor │
  │ (Claude)     │      │              │
  │             │      │  Output Panel│ ← 编译报错在这里
  │ 不知道有报错 │      │  场景树       │
  │ 猜节点状态   │      │  运行时状态   │
  └─────────────┘      └──────────────┘
  AI 在"盲飞"，用户在"传话"

缺口 2: GDSnippet 执行引擎太 "纯净"
  执行代码在隔离的 RefCounted 中运行：
    - 没有 get_tree()（不是节点）
    - 不能直接操作场景（需要 EditorInterface）
    - 即使 game executor 也只是"同一进程"，无法方便地遍历场景
  结果：简单的"查个属性"需要写 10 行胶水代码

缺口 3: 改代码 → 验证 循环太慢
  当前: 改文件 → 告知用户→ 用户重启编辑器 → 用户截图报错 → AI 看到报错 → 再改
  期望: 改文件 → 编辑器自动重载 → AI 收到编译结果 → AI 决定下一步
```

### 1.3 设计原则

1. **诊断优先于操作** — 先让 AI 能"看见"编辑器状态，再考虑"操作"编辑器
2. **零胶水代码** — 任何"查个属性"的操作不应该需要写 GDScript
3. **异步通知** — 编辑器状态变化（编译报错、游戏启动/停止）应主动推送给 AI
4. **向后兼容** — v0.5.0 的所有端点不变
5. **渐进增强** — 不搞大版本重构，每个功能独立交付

---

## 2. Architecture: Diagnostics Layer

v0.6.0 的核心新增一个**诊断层（Diagnostics Layer）**，位于 broker-server 之上，为 AI Agent 提供"编辑器感知能力"：

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AI Agent / Claude Code                        │
│                                                                     │
│  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────────┐   │
│  │   REST API      │  │  WebSocket       │  │  CLI Tools        │   │
│  │  (查询/操作)     │  │  (实时推送)       │  │  (快捷命令)        │   │
│  └────────┬────────┘  └────────┬─────────┘  └────────┬──────────┘   │
│           │                    │                      │              │
└───────────┼────────────────────┼──────────────────────┼──────────────┘
            │                    │                      │
            ▼                    ▼                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       broker-server v0.6.0                          │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Diagnostics Layer (NEW)                          │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌────────────────┐  ┌────────────────┐    │   │
│  │  │ Scene Inspector│  │ Compile Monitor│  │ Live Console   │    │   │
│  │  │ - 场景树快照   │  │ - 编译报错推送  │  │ - print 实时流  │    │   │
│  │  │ - 节点属性读   │  │ - 错误缓存查询  │  │ - push_error    │    │   │
│  │  │ - 信号连接     │  │ - 历史记录      │  │  实时捕获       │    │   │
│  │  └──────────────┘  └────────────────┘  └────────────────┘    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Execution Layer (v0.5.0 基础)                    │   │
│  │  execute | check | rescan | properties | save | scene-tree   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Transport Layer (TCP :5301 / HTTP :5302)         │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
            │                    │
            ▼                    ▼
┌──────────────────────┐  ┌────────────────────────────┐
│  Godot Editor        │  │  Game Runtime              │
│  + HasturPlugin      │  │  + GameExecutor            │
│                      │  │                            │
│  EditorLogCatcher    │  │  SceneTree                 │
│  EditorInterface     │  │  get_node()                │
│  FileSystem          │  │  Engine                    │
└──────────────────────┘  └────────────────────────────┘
```

---

## 3. Phase 1 — Scene Diagnostics (P0)

### 3.1 `GET /api/scene/inspect` — 场景快照

**目的**：一次调用获取场景中任意节点的完整诊断信息，替代多次 GDSnippet。

**痛点**：今天排查 DamageTextLayer → DamageFloater → MonsterPool 的完整链路，需要写 3 段 GDSnippet 拼接信息。

**API**：

```bash
GET /api/scene/inspect?path=/root/SkillDemo&depth=3&include=children,properties,signals
Authorization: Bearer <token>

# Response:
{
    "success": true,
    "data": {
        "node": {
            "name": "SkillDemo",
            "type": "Node2D",
            "script": "res://scripts/dev/skill_demo.gd",
            "children": [
                {
                    "name": "CameraAnchor",
                    "type": "Node2D",
                    "children": [
                        {
                            "name": "Camera2D",
                            "type": "Camera2D",
                            "properties": {
                                "current": true,
                                "zoom": {"x": 1.0, "y": 1.0},
                                "position_smoothing_enabled": true
                            }
                        }
                    ]
                },
                {
                    "name": "DamageTextLayer",
                    "type": "CanvasLayer",
                    "properties": {
                        "layer": 10,
                        "visible": true
                    },
                    "children": [
                        {
                            "name": "DamageFloater",
                            "type": "Node",
                            "script": "res://scripts/skill_system/damage_text/damage_floater.gd",
                            "children": [
                                {
                                    "name": "MonsterDamageTextPool",
                                    "type": "Node2D",
                                    "properties": {
                                        "pool_size": 20,
                                        "_active_size": 0,
                                        "_available_size": 20
                                    }
                                }
                            ]
                        }
                    ]
                }
            ]
        },
        "signals": {
            "/root/SkillDemo/SkillSystem/SkillSignalBus": {
                "skill_hit": [
                    {"connected_to": "_on_demo_skill_hit", "method": "_on_demo_skill_hit", "flags": 0}
                ]
            }
        }
    }
}
```

**关键设计**：

```typescript
// 查询参数:
interface SceneInspectQuery {
    path: string               // 目标节点路径 (required)
    depth?: number             // 递归深度 (default: 1, max: 5)
    include?: string           // 逗号分隔: children,properties,signals,scripts
    property_filter?: string   // 逗号分隔的属性白名单 (可选)
}
```

**序列化合约** — 所有属性值必须可 JSON 序列化：

| Godot 类型 | JSON 表示 |
|-----------|----------|
| `Vector2` | `{"x": float, "y": float}` |
| `Color` | `{"r": float, "g": float, "b": float, "a": float}` |
| `Rect2` | `{"position": {...}, "size": {...}}` |
| `Transform2D` | `{"x": {...}, "y": {...}, "origin": {...}}` |
| `NodePath` | `"string"` |
| `Resource` | `"[Resource: type=Script path=res://...]"` |
| `Callable` | `"[Callable: method_name]"` |
| `null` | `null` |

**Godot 端实现** — 核心是一个递归的 `_inspect_node()` 函数：

```gdscript
func _inspect_node(node: Node, depth: int, include: Dictionary, filter: Array) -> Dictionary:
    if node == null:
        return {}

    var result := {
        "name": node.name,
        "type": node.get_class(),
    }

    if include.get("properties", false):
        result["properties"] = _get_filtered_properties(node, filter)

    if include.get("scripts", false):
        var script = node.get_script()
        if script:
            result["script"] = script.resource_path

    if include.get("signals", false) and depth >= 1:
        var sigs := _get_node_signals(node)
        if not sigs.is_empty():
            result["signals"] = sigs

    if include.get("children", false) and depth > 0:
        var children: Array = []
        for child in node.get_children():
            if child != node:  # 防止自引用
                children.append(_inspect_node(child, depth - 1, include, filter))
        if not children.is_empty():
            result["children"] = children

    return result
```

**tcp-server.ts** 新增消息类型：`get_scene_inspect` / `scene_inspect_result`

**涉及文件**：
| 文件 | 改动 |
|------|------|
| `broker_client.gd` | 新增 `_handle_scene_inspect_request` + `_inspect_node` + `_get_filtered_properties` + `_get_node_signals` |
| `tcp-server.ts` | 消息类型注册 `get_scene_inspect` / `scene_inspect_result` |
| `http-server.ts` | 新增路由 `GET /api/scene/inspect` |
| `types.ts` | 新增接口 `SceneInspectQuery`, `SceneInspectResult`, `NodeSnapshot` |

**为什么不是递归 GET /api/scene/properties**：
- `GET /api/scene/properties` 一次只能查一个节点，查整棵树需要 N 次往返
- SceneInspect 在一次 TCP 往返内完成整树遍历，对深处嵌套的对象池（DamageTextLayer → DamageFloater → MonsterPool）特别高效
- 信号连接信息必须随节点一起返回才有意义（查某个节点时自动显示该节点及其子节点的信号状态）

---

### 3.2 `POST /api/execute` — 上下文执行模式

**目的**：让执行的 GDScript 代码能访问场景树（`get_tree()`、`get_node()`），无需通过 EditorInterface 绕路。

**痛点**：今天想在 game executor 里检查 SkillDemo 场景，但 `get_tree()` 不可用，必须用 `Engine.get_main_loop()` + 各种绕路写法。而且 game executor 和 editor executor 的场景树不同，执行上下文混乱。

**API 增强**：

```json
POST /api/execute
{
    "code": "var demo = get_tree().root.get_node(\"SkillDemo\")\nprint(demo.name)",
    "project_name": "Six Fighter",
    "executor_type": "game",
    "execution_mode": "in_scene",      // NEW: "snippet"(默认) | "in_scene"
    "context_path": "/root/SkillDemo"  // NEW: 在指定节点下执行
}
```

**Godot 端实现**（`gdscript_executor.gd`）：

```gdscript
func execute_code(params: Dictionary) -> Dictionary:
    var code: String = params.get("code", "")
    var mode: String = params.get("execution_mode", "snippet")

    if mode == "in_scene":
        return _execute_in_scene(code, params.get("context_path", ""))

    # 原有 snippet/full_class 路径保持不变
    return _execute_snippet(code, context)

func _execute_in_scene(code: String, context_path: String) -> Dictionary:
    # 1. 在目标节点下创建一个临时节点来执行代码
    var target = _find_node_by_path(context_path)
    if not target:
        return {"run_success": false, "run_error": "Context path not found: " + context_path}

    # 2. 创建一个临时 Node 并挂载 GDScript
    var holder := Node.new()
    holder.name = "_HasturTempExecutor"
    target.add_child(holder)

    var wrapped_code = _wrap_as_node_script(code)
    var script := GDScript.new()
    script.source_code = wrapped_code
    var err := script.reload()
    if err != OK:
        holder.queue_free()
        return _compile_error_result(err, script)

    holder.set_script(script)
    # 脚本的 _run() 将在 holder 的上下文中执行，self = holder，get_tree() 可用

    # 3. 执行并收集输出
    var result = _collect_outputs(holder)
    holder.queue_free()
    return result
```

**包装示例**：

```gdscript
# 用户输入
var camera = get_node("../CameraAnchor/Camera2D")
print(camera.position_smoothing_enabled)

# 自动包装
extends Node

func _ready():
    var camera = get_node("../CameraAnchor/Camera2D")
    # print() 已被替换为 executeContext.output(...)
    executeContext.output("print", str(camera.position_smoothing_enabled))
```

**涉及文件**：
| 文件 | 改动 |
|------|------|
| `gdscript_executor.gd` | 新增 `_execute_in_scene()` + `_wrap_as_node_script()` |
| `broker_client.gd` | 透传 `execution_mode` / `context_path` 参数 |
| `http-server.ts` | 无改动（参数透传） |
| `types.ts` | ExecuteRequest 新增 `execution_mode` / `context_path` |

**安全约束**：
- `context_path` 不能指向临时节点（防止递归）
- 执行完毕后**立即销毁**临时节点（`queue_free()`）
- 单次执行超时 **5000ms**（in_scene 模式默认比 snippet 短，防止 `_process` 循环卡死编辑器）

---

### 3.3 `GET /api/scene/signals` — 信号连接诊断

**目的**：查询指定节点的信号连接情况，快速定位"信号发出去了但没人收到"的问题。

**痛点**：今天排查大激光术跳字时，最重要的证据是"skill_hit 信号到底有没有连上"，但 AI 无法直接查看。

**API**：

```bash
GET /api/scene/signals?path=/root/SkillDemo/SkillSystem/SkillSignalBus
Authorization: Bearer <token>

# Response:
{
    "success": true,
    "data": {
        "node_path": "/root/SkillDemo/SkillSystem/SkillSignalBus",
        "signal_count": 8,
        "signals": {
            "skill_hit": [
                {
                    "connected_to": "/root/SkillDemo",
                    "method": "_on_demo_skill_hit",
                    "flags": 0,
                    "binds": ["[Object: DamageFloater]"]
                }
            ],
            "skill_cast_requested": [...],
            "skill_cast_started": [...],
            "skill_cast_finished": [...]
        }
    }
}
```

**Godot 端实现**：直通 `Node.get_signal_connection_list()`。

**涉及文件**：`broker_client.gd`（1 handler）、`http-server.ts`（1 路由）、`types.ts`（`SignalConnectionResult`）

---

## 4. Phase 2 — Compile Error Push (P0)

### 4.1 `GET /api/project/compile-errors` — 查询当前编译错误

**目的**：获取编辑器当前的全部编译报错（和 Godot Output 面板看到的一致）。

**痛点**：今天 90% 的调试阻塞是因为 AI 看不到编辑器报错。用户重启编辑器后报错在 Output 面板，AI 完全看不见。

**API**：

```bash
GET /api/project/compile-errors
Authorization: Bearer <token>

# Response (有错误):
{
    "success": true,
    "data": {
        "error_count": 3,
        "errors": [
            {
                "file": "res://scripts/combat/target_selector.gd",
                "line": 68,
                "column": 1,
                "message": "Parse Error: Not all code paths return a value.",
                "code": "PARSE_ERROR",
                "type": "error"
            },
            {
                "file": "res://scripts/skill_system/skill_root.gd",
                "line": 35,
                "message": "Parse Error: Expected statement, found \"Indent\" instead.",
                "code": "PARSE_ERROR",
                "type": "error"
            }
        ]
    }
}

# Response (无错误):
{"success": true, "data": {"error_count": 0, "errors": []}}
```

**Godot 端实现**：拦截 `EditorLogCatcher` 中的 `type == "compile_error"` 的日志条目，缓存到独立缓冲区：

```gdscript
# editor_log_catcher.gd 新增
var _compile_errors: Array = []
var _compile_error_mutex: Mutex

func log_compile_error(message: String, file: String, line: int, details: Dictionary) -> void:
    _compile_error_mutex.lock()
    _compile_errors.append({
        "message": message,
        "file": file,
        "line": line,
        "details": details,
        "timestamp": Time.get_unix_time_from_system()
    })
    _compile_error_mutex.unlock()

func get_compile_errors() -> Array:
    _compile_error_mutex.lock()
    var copy = _compile_errors.duplicate()
    _compile_error_mutex.unlock()
    return copy

func clear_compile_errors() -> void:
    _compile_error_mutex.lock()
    _compile_errors.clear()
    _compile_error_mutex.unlock()
```

**缓存策略**：
- 编辑器启动时清空
- 每次文件系统扫描（`scan()`）后清空（因为 Godot 会重新编译所有脚本）
- 新的编译错误实时追加
- 最多缓存 **200 条**（FIFO 淘汰）

**涉及文件**：
| 文件 | 改动 |
|------|------|
| `editor_log_catcher.gd` | 新增编译错误缓存 + 线程安全访问 |
| `broker_client.gd` | 新增 `_handle_get_compile_errors_request` handler |
| `http-server.ts` | 新增路由 `GET /api/project/compile-errors` |
| `types.ts` | 新增接口 `CompileError`, `CompileErrorListResult` |

### 4.2 WebSocket — 编译错误实时推送 (可选 Enhancement)

**目的**：当编辑器产生新的编译错误时，主动通知连接的客户端，无需轮询。

**协议**：

```
客户端 → broker-server:
  GET /api/ws?token=<token>

broker-server → 客户端:
  {"type": "compile_error", "data": {"file": "...", "line": 68, "message": "..."}}
  {"type": "compile_cleared", "data": {}}
  {"type": "scene_changed", "data": {"path": "res://scenes/dev/skill_demo.tscn"}}
  {"type": "game_started", "data": {}}
  {"type": "game_stopped", "data": {}}
```

**实现思路**：
- Godot 端：`EditorLogCatcher` 捕获编译错误后，通过 TCP 发送 `compile_error` 消息到 broker
- Broker 端：维护 WebSocket 客户端列表，收到 Godot 的消息后广播给所有 WebSocket 客户端
- 不需要 Godot 端做任何新的事情——编译错误已经通过 `EditorLogCatcher` 捕获并通过日志通道发送

**HTTP 轮询的替代性**：
- WebSocket 是**未来方向**，但 PMF（Product-Market Fit）验证需要先确认 AI Agent 能消费推送消息
- v0.6.0 先提供 REST API（轮询），**状态标记为 "Alpha"**。根据 AI Agent 集成反馈决定是否正式发布

---

## 5. Phase 3 — Live Console Stream

### 5.1 `GET /api/executors/:id/console/stream` — 实时日志流

**目的**：让 AI 能看到游戏运行时的 `print()` 输出，无需用户截图。

**痛点**：今天 `hastur.py logs` 只能看到编辑器日志，游戏运行时的 `print()` 输出对 AI 完全不可见。排查命中/伤害/碰撞等问题时，这是最大的信息黑洞。

**API**：

```bash
GET /api/executors/:id/console/stream?since=<timestamp_ms>&limit=50
Authorization: Bearer <token>

# Response:
{
    "success": true,
    "data": {
        "entries": [
            {"timestamp_ms": 1234567, "type": "print", "message": "Damaged target for 28"},
            {"timestamp_ms": 1234590, "type": "print", "message": "skill_hit emitted"},
            {"timestamp_ms": 1234620, "type": "error",  "message": "Cannot read property 'x' of null"},
            {"timestamp_ms": 1234650, "type": "warning","message": "Unused variable 'foo'"}
        ],
        "next_timestamp_ms": 1234651
    }
}
```

**实现方式**（Godot 端）：

```gdscript
# editor_log_catcher.gd 新增 — 控制台流缓冲区
var _console_buffer: Array = []
var _console_buffer_mutex: Mutex
const _CONSOLE_BUFFER_MAX: int = 500

# 所有 log_* 方法除了发送到日志队列外，也缓存到控制台流
func _add_to_console_stream(entry: Dictionary) -> void:
    _console_buffer_mutex.lock()
    _console_buffer.append(entry)
    if _console_buffer.size() > _CONSOLE_BUFFER_MAX:
        _console_buffer.pop_front()
    var timestamp = _console_buffer.back().timestamp_ms
    _console_buffer_mutex.unlock()
    # 通知 broker 有新数据
    _notify_console_update(timestamp)

func get_console_entries(since_timestamp: float, limit: int) -> Array:
    _console_buffer_mutex.lock()
    var result: Array = []
    for entry in _console_buffer:
        if entry.timestamp_ms > since_timestamp:
            result.append(entry)
            if result.size() >= limit:
                break
    _console_buffer_mutex.unlock()
    return result
```

**涉及文件**：
| 文件 | 改动 |
|------|------|
| `editor_log_catcher.gd` | 新增控制台流缓冲区 + 时间戳索引 |
| `broker_client.gd` | 新增 `_handle_get_console_stream_request` handler |
| `http-server.ts` | 新增路由 `GET /api/executors/:id/console/stream` |
| `types.ts` | 新增接口 `ConsoleStreamResult`, `ConsoleEntry` |

---

## 6. Phase 4 — Developer Quality of Life

### 6.1 `hastur.py` CLI 增强

```bash
# 场景诊断（一条命令等效 N 行 GDScript）
python tools/hastur.py inspect /root/SkillDemo --depth 3 --include children,properties

# 信号诊断
python tools/hastur.py signal /root/SkillDemo/SkillSystem/SkillSignalBus

# 编译报错
python tools/hastur.py errors

# 控制台跟踪（实时流，Ctrl+C 停止）
python tools/hastur.py console

# 场景下执行代码
python tools/hastur.py exec-in "var n = get_node('CameraAnchor/Camera2D'); print(n.zoom)" /root/SkillDemo
```

### 6.2 行尾自动检测工具 (hastur.py 新增)

今天大量时间浪费在 CRLF/LF 行尾问题上。新增辅助工具：

```bash
# 检测文件行尾
python tools/hastur.py eol script.gd
# → "CRLF"

# 统一行尾
python tools/hastur.py eol --to lf script.gd
# → "Converted: CRLF → LF"

# 批量检查
python tools/hastur.py eol --check scripts/
# → "CRLF: 15 files, LF: 3 files"
```

### 6.3 热重载增强（基于 v0.5.0 "不做"的决策重新评估）

v0.5.0 决定不做热重载，理由是"Godot 没有官方脚本热重载 API"。但今天的实战证明：

**场景：改 `.gd` 后验证编译**
- 无热重载：改文件 → 告知用户 → 用户手动重启编辑器 → 看报错（30s+）
- 有热重载：改文件 → API 调用 reload → 立即知道是否编译通过（2s）

**v0.6.0 的折衷方案 — "软重载"（Soft Reload）**：

```bash
POST /api/script/reload
Authorization: Bearer <token>
Content-Type: application/json

{"path": "res://scripts/combat/target_selector.gd"}

# Response 200:
{
    "success": true,
    "data": {
        "reloaded": true,
        "compile_success": true,
        "method_count": 8,
        "errors": []
    }
}
```

**实现**：
```gdscript
func _handle_script_reload_request(data: Dictionary) -> void:
    var path: String = str(data.get("path", ""))
    var request_id: String = str(data.get("request_id", ""))

    if path.is_empty():
        _send_result("script_reload_result", request_id, {
            "success": false, "error": "No path provided"})
        return

    # 从磁盘读最新源码
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        _send_result("script_reload_result", request_id, {
            "success": false, "error": "File not found: " + path})
        return

    var disk_source := file.get_as_text()
    file.close()

    # 强制加载并编译
    var script := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
    if not script:
        _send_result("script_reload_result", request_id, {
            "success": false, "error": "Failed to load script"})
        return

    script.source_code = disk_source
    var err := script.reload()

    _send_result("script_reload_result", request_id, {
        "success": err == OK,
        "reloaded": true,
        "compile_success": err == OK,
        "method_count": script.get_script_method_list().size() if err == OK else 0,
        "error": _error_code_to_string(err) if err != OK else "",
    })
```

**注意**：这**不会**替换场景树中已实例化的旧脚本对象。它的价值在于：**在改完代码后立即确认新代码能否编译通过**，而不是"改代码 → 重启编辑器 → 等待 → 报错"。

---

## 7. Implementation Order

| Step | Phase | Description | Files | Est. |
|------|-------|-------------|-------|------|
| 1 | **P0** | `broker_client.gd`: `_inspect_node` + 信号连接 API | 1 | 90 min |
| 2 | **P0** | `http-server.ts`: `GET /api/scene/inspect` + signals 路由 | 2 | 30 min |
| 3 | **P0** | `gdscript_executor.gd`: `_execute_in_scene()` + Node 包装 | 1 | 60 min |
| 4 | **P0** | `editor_log_catcher.gd`: 编译错误缓存 | 1 | 45 min |
| 5 | **P0** | `http-server.ts`: `GET /api/project/compile-errors` | 2 | 20 min |
| 6 | **P1** | `editor_log_catcher.gd`: 控制台流缓冲区 | 1 | 30 min |
| 7 | **P1** | `http-server.ts`: `GET /api/executors/:id/console/stream` | 2 | 20 min |
| 8 | **P2** | `broker_client.gd`: `_handle_script_reload_request` | 1 | 30 min |
| 9 | **P2** | `hastur.py`: inspect/signal/errors/console/eol 命令 | 1 | 45 min |
| 10 | **P3** | WebSocket 推送（Alpha） | 2 | 60 min |
| 11 | — | 蓝皮书更新 | 1 | 60 min |

**Total: ~8.5 hours**

---

## 8. File Modification Matrix

### Broker Server (TypeScript)

| File | Modification |
|------|-------------|
| `src/types.ts` | 新增 8 个接口：`SceneInspectQuery`, `NodeSnapshot`, `PropertyValue`, `SignalConnectionResult`, `CompileError`, `ConsoleEntry`, `ScriptReloadRequest`, `SceneInspectResult` |
| `src/tcp-server.ts` | 新增消息类型注册（5 个新消息对） |
| `src/http-server.ts` | 新增 5 条路由；execute 路由增加 `execution_mode` / `context_path` 透传 |

### Godot Plugin (GDScript)

| File | Modification |
|------|-------------|
| `broker_client.gd` | 新增 handler: `scene_inspect`, `get_signals`, `get_compile_errors`, `get_console_stream`, `script_reload`；`_execute` handler 透传 execution_mode |
| `gdscript_executor.gd` | 新增 `_execute_in_scene()` + `_wrap_as_node_script()`；`execute_code()` 新增 mode 分支 |
| `editor_log_catcher.gd` | 新增编译错误缓存 + 控制台流缓冲区（线程安全） |

### CLI (Python)

| File | Modification |
|------|-------------|
| `game/tools/hastur.py` | 新增 `inspect`、`signal`、`errors`、`console`、`exec-in`、`eol` 命令 |

---

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| `_execute_in_scene()` 创建的临时节点可能被游戏逻辑误处理 | 中 — 碰撞检测、信号等可能触发副作用 | 命名加 `_HasturTemp` 前缀；设置 `collision_layer = 0`；执行完立即 `queue_free()` |
| 编译错误缓存与 Godot 文件系统扫描不同步 | 低 — 缓存清理时机不精确，可能显示过时错误 | 缓存条目带 `timestamp`；客户端可根据时间戳过滤；`scan()` 后清空缓存 |
| 大场景的 SceneInspect 序列化过慢 | 中 — `depth=5` 时可能遍历数千节点 | 限制 `depth <= 5`；限制 `include` 默认只返回 children+name；大场景下返回 `truncated: true` 标记 |
| 控制台流缓冲区内存占用 | 低 — 500 条上限，每条几十字节 | `_CONSOLE_BUFFER_MAX = 500`；FIFO 淘汰；`since_timestamp` 参数减少传输量 |
| WebSocket 增加 broker-server 复杂度 | 中 — 需要维护连接状态 + 心跳 | v0.6.0 中标记为 Alpha；仅核心事件推送（编译报错 + 游戏启停）；不加双向 RPC |

---

## 10. Version Bump Checklist

- [ ] `game/addons/hasturoperationgd/plugin.cfg` → `version="0.6.0"`
- [ ] `broker/hastur-operation-plugin-main/broker-server/package.json` → `"version": "0.6.0"`
- [ ] `broker_client.gd` → `_plugin_version = "0.6.0"`
- [ ] `http-server.ts` → health endpoint `version: '0.6.0'`
- [ ] `docs/HasturOperationGD-Technical-Whitepaper.md` → 更新 API 表和功能演进
- [ ] `docs/hastur-v0.6.0-upgrade-proposal.md` → 定稿后标记为 "Proposed"

---

## 11. 与 v0.5.0 的对比

| 维度 | v0.5.0 | v0.6.0 |
|------|--------|--------|
| 核心设计理念 | 让 AI 能**操作**编辑器 | 让 AI 能**看见**编辑器 |
| 关键交付 | rescan / check / properties / save | scene-inspect / compile-errors / console-stream / in-scene-exec |
| 信息获取方式 | 写 GDSnippet → execute → 读输出 | 专用 API → JSON → 直接可读 |
| 故障排查效率 | AI 盲猜 →用户传话 →反复试错 | AI 直接检查场景树 →精确诊断 |
| 新增代码量 | ~900 行 | ~1200 行 |
| 依赖重构 | 注册式路由（~170 行重复代码消除） | 诊断层架构（新增组件，不修改 v0.5.0 已有功能） |

---

*本方案基于 2026-05-26 小激光术全流程开发的实战经验编写，反映了当前工作流中最紧迫的信息缺口。*
