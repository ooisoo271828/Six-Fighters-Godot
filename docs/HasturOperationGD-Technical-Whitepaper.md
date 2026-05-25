# HasturOperationGD 插件技术蓝皮书

> **版本**: v0.4.0（插件） / v0.1.0（broker-server）
> **最后更新**: 2026-05-25
> **适用对象**: 人类开发团队成员、AI 助理（Claude Code 等）
> **状态**: 正式记录
>
> **核心目标**: 让任意 AI 助理在阅读本蓝皮书后，能在自己的环境下，从零搭建并完整运行这套 Godot 引擎链接插件环境。

---

## 一、项目概述

### 1.1 插件定位

HasturOperationGD 是一个 Godot 编辑器插件，将 Godot 编辑器变身为一个可远程编程操作的"执行器"（Executor）。外部 Agent（如 AI 编码助手）通过 broker-server（中间层服务）向 Godot 编辑器下达指令，Godot 执行代码并返回结果。

### 1.2 整体架构

```
┌─────────────┐   HTTP/TCP    ┌─────────────────┐   TCP    ┌──────────────────┐
│ AI Agent    │ ◄───────────► │ broker-server   │ ◄──────► │ Godot Editor     │
│ (Claude Code)│               │ (Node.js/TS)    │          │ + HasturPlugin   │
│              │  端口 5302    │  端口 5301/5302 │          │                  │
└─────────────┘               └─────────────────┘          └──────────────────┘
```

- **TCP 端口 5301**: Godot 插件与 broker-server 的长连接通道
- **HTTP 端口 5302**: 外部客户端（AI Agent）调用 REST API 的入口
- **默认认证 Token**: `995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7`（v0.4.0 起支持 `HASTUR_TOKEN` 环境变量覆盖）

### 1.3 目录结构

```
项目根目录/                                     # e.g. Six-Fighters-Godot/
├── game/                                       # ⭐ Godot 项目目录
│   ├── addons/hasturoperationgd/               # ⭐ 插件运行位置（v0.4.0）
│   │   ├── broker_client.gd                    # TCP 通信 + 场景树/节点操作
│   │   ├── gdscript_executor.gd                # GDScript 代码编译执行引擎
│   │   ├── execution_context.gd                # 执行上下文（output 方法）
│   │   ├── editor_log_catcher.gd               # 编辑器日志捕获（缓冲+批处理）
│   │   ├── hastur_logger.gd                    # 全局日志捕获器
│   │   ├── runtime_error_capture.gd            # 运行时错误安全包装
│   │   ├── executor_backend.gd                 # 执行后端（连接管理）
│   │   ├── executor_dock.gd                    # 编辑器面板 UI（4 标签页）
│   │   ├── executor_dock.tscn                  # UI 场景文件
│   │   ├── game_executor.gd                    # 游戏运行时代码执行（仅 debug）
│   │   ├── hasturoperationgd.gd                # 插件主入口
│   │   ├── hastur_operation_gd_plugin_settings.gd  # 设置管理（host/port/输出长度）
│   │   └── plugin.cfg                          # 插件清单
│   ├── .claude/CLAUDE.md                       # 项目指南（单一起源）
│   └── <游戏源码>                               # scenes/scripts/resources/...
│
├── broker/hastur-operation-plugin-main/        # broker-server 源码
│   └── broker-server/
│       ├── src/
│       │   ├── index.ts                        # 启动入口（CLI args）
│       │   ├── tcp-server.ts                   # TCP 消息路由（5301）
│       │   ├── http-server.ts                  # HTTP REST API（5302）
│       │   ├── executor-manager.ts             # 执行器状态管理
│       │   ├── auth.ts                         # Bearer Token 认证
│       │   └── types.ts                        # TypeScript 类型定义
│       └── package.json
│
└── docs/
    ├── HasturOperationGD-Technical-Whitepaper.md  # ⬅ 本文档
    └── godot-ai-pitfall-guide.md                  # AI 避坑指南
```

> **⚠️ 关键警告**: Godot 4.x 只会加载 `game/addons/hasturoperationgd/` 下的插件源码，**绝不会**加载 `broker/hastur-operation-plugin-main/addons/` 下的源码。所有开发修改必须在 `game/addons/` 目录下进行。

---

## 二、快速启动

### 2.1 前置条件

- Node.js >= 18.x（运行 broker-server 需要）
- Godot 4.x 编辑器（当前项目使用 4.6.2-stable）
- Git Bash 或类似 Unix 风格终端

### 2.2 最短路径：从零搭建环境

**Step 1: 启动 broker-server**

设置认证 Token（建议通过环境变量，避免硬编码）：

```bash
# 设置认证 Token（默认值可用，也可自定义）
export HASTUR_TOKEN="995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7"

cd broker/hastur-operation-plugin-main/broker-server
npm install
npm run dev
```

> v0.4.0 起 `HASTUR_TOKEN` 环境变量会被 broker-server 自动读取。未设置时自动生成随机 Token 并打印到控制台。

验证 broker-server 是否运行：

```bash
curl http://localhost:5302/api/health
# 应返回 {"success":true, "data": {"status": "ok", "version": "0.3.0", ...}}
```

**Step 2: 在 Godot 编辑器中启用插件**

1. 用 Godot 打开 `game/` 项目
2. 进入 **Project → Project Settings → Plugins**
3. 将 **HasturOperationGD** 设为 **Enabled**
4. 在编辑器右侧面板应看到 **Executor** 面板（显示 Connected）

**Step 3: 验证连接**

```bash
# 检查 broker API 是否返回已连接的 executor
curl -s -H "Authorization: Bearer 995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7" \
  http://localhost:5302/api/executors
# 应返回 executor 列表，包含 id、project_name、status 等
```

**Step 4: 执行第一条代码**

```bash
curl -s -X POST http://localhost:5302/api/execute \
  -H "Authorization: Bearer 995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7" \
  -H "Content-Type: application/json" \
  -d '{"code":"print(\"Hello from Godot!\")","project_name":"Six Fighter"}'
```

---

## 三、系统组件详解

### 3.1 Godot 插件端

#### 3.1.1 `broker_client.gd` — 核心通信引擎

**职责**: 与 broker-server 建立 TCP 长连接，接收并处理来自 broker 的所有指令消息。

**消息类型**:

| 方向 | 消息类型 | 说明 |
|------|----------|------|
| **接收** | `register_result` | 注册结果，获得 executor_id |
| **接收** | `execute` | 远程代码执行请求 |
| **接收** | `get_scene_tree` | 获取场景树 |
| **接收** | `create_node` | 创建场景节点 |
| **接收** | `delete_node` | 删除场景节点 |
| **接收** | `ping` | 心跳请求（broker 发起） |
| **发送** | `execute_result` | 代码执行结果 |
| **发送** | `scene_tree_result` | 场景树数据 |
| **发送** | `create_node_result` | 节点创建结果 |
| **发送** | `delete_node_result` | 节点删除结果 |
| **发送** | `logs` | 日志流数据 |
| **发送** | `heartbeat` + `data.rtt_ms` | 主动心跳（**v0.4.0 新增** — 每 5 秒由 `poll()` 驱动，之前定义但从未被调用） |

**关键设计**:

- 自动重连（指数退避 1s → 30s 上限），断线时 `disconnect_client()` 会清理 `_executor`（v0.4.0 修复）
- RTT 追踪：Godot 端通过 heartbeat → heartbeat_ack 计算 RTT 并附带在下次心跳中发送；Broker 端 ping → pong 时也独立计算（**v0.4.0 修复** — 之前 rtt_ms 始终为 null）
- EditorInterface 通过 BrokerClient 持有 EditorPlugin 引用间接访问
- 日志系统：HasturLogger（全局）→ EditorLogCatcher（缓冲 + 每 100ms 批量发送）
- 缓冲区最大 **500** 条（v0.4.0 从 200 提升），每批发送最大 50 条，Mutex 线程安全

#### 3.1.2 `gdscript_executor.gd` — 代码执行引擎

**职责**: 动态编译并执行 GDScript 代码片段。

**两种执行模式**:

| 模式 | 检测条件 | 包装方式 |
|------|---------|---------|
| **Snippet** | 不含 `extends` | 自动包装为 `@tool extends RefCounted` + `run(executeContext)` 方法 |
| **Full Class** | 含 `extends` | 自动补 `@tool` 注解，调用 `execute(executeContext)` |

**Snippet 包装示例**:

```gdscript
# 用户输入
var x = 10
print(x)

# 自动包装为
@tool
extends RefCounted

var executeContext: RefCounted

func run(_ec: RefCounted):
    executeContext = _ec
    var x = 10
    executeContext.output("print", str(x))  # print() 自动捕获
```

**`print()` 自动捕获算法**: 逐字符扫描代码，匹配独立 `print(...)` 语句（表达式嵌入的 print 不转换），替换为 `executeContext.output("print", str(...))`。

> **v0.4.0**: 移除了 `_notification()` 方法（RefCounted 不应有 `_notification`，会导致空实例崩溃）。`dispose()` 必须显式调用。

#### 3.1.3 `execution_context.gd` — 执行上下文

```gdscript
class_name ExecutionContext
extends RefCounted

var editor_plugin = null        # EditorPlugin 引用（通过此处访问编辑器 API）
var _outputs: Array = []        # 输出键值对缓冲区
var _max_output_length: int = 800  # 单值最大字符数

# 注入方式
func _init(p_editor_plugin = null):
    editor_plugin = p_editor_plugin

# 输出方法（value 必须是 String 类型）
func output(key: String, value: String):
    _outputs.append([key, value])  # 超过 800 字符自动截断 + 警告

func get_outputs() -> Array:
    return _outputs                # 返回 [["key", "value"], ...]
```

**EditorInterface 访问（核心修正）**:

```
✅ 正确:
  Snippet 模式:  executeContext.editor_plugin.get_editor_interface()
  Full Class 模式: ctx.editor_plugin.get_editor_interface()

❌ 错误（不存在此变量）:
  _editor_plugin_ref.get_editor_interface()
```

`_editor_plugin_ref` 是 `BrokerClient` 的内部属性名，**不会**被注入到 GDScript 执行环境中。

#### 3.1.4 日志捕获子系统

**架构**: 双层日志捕获

```
OS.print() / push_error() / push_warning()
        ↓
  HasturLogger（全局 Logger，通过 OS.add_logger() 注册）
        ↓
  EditorLogCatcher（缓冲 + 批处理，500 条上限）
        ↓
  BrokerClient._on_logs_ready() → TCP → broker-server → REST API
```

**output_type 类型**:

| 类型 | 来源 |
|------|------|
| `print` | 普通 `print()` 输出 |
| `debug` | 调试信息 |
| `warning` | `push_warning()` |
| `error` | 引擎错误 |
| `script_error` | 脚本运行时错误 |
| `compile_error` | 编译错误 |
| `runtime_error` | 运行时异常 |

> **Godot 4.6 兼容**: `Logger.ErrorType` 枚举没有 `ERROR_TYPE_RUNTIME`。代码中使用硬编码整数：
> ```gdscript
> const _ERROR_TYPE_ERROR: int = 0
> const _ERROR_TYPE_WARNING: int = 1
> const _ERROR_TYPE_SCRIPT: int = 2
> ```

#### 3.1.5 `executor_dock.gd` — 编辑器面板 UI

**4 标签页设计**:

| 标签 | 功能 |
|------|------|
| Execute | CodeEdit 代码编辑器 + 执行结果展示 |
| Breakpoints | 断点列表管理 |
| History | 执行历史（最多 50 条）+ RTT 折线图（60 数据点）+ 统计 |
| Logs | 日志查看器 |

#### 3.1.6 `game_executor.gd` — 游戏运行时代码执行

用于在游戏运行时（非编辑器）执行代码，仅在 debug build 中启用。

```gdscript
func _ready() -> void:
    if not OS.is_debug_build():
        queue_free()
```

#### 3.1.7 插件配置项

| 设置 | 默认值 | 说明 |
|------|--------|------|
| `hastur_operation/broker_host` | `localhost` | Broker 主机地址 |
| `hastur_operation/broker_port` | `5301` | Broker TCP 端口 |
| `hastur_operation/output_max_char_length` | `800` | Output 单值最大字符数 |

#### 3.1.8 结构化错误捕获（v0.3.1+）

> **新增于 2026-05-22**。解决 AI 在调试过程中"盲猜"的根本问题：错误信息从平字符串升级为带文件名、行号、函数名、完整栈帧的结构化数据。

**问题背景**：

Hastur v0.3.1 之前，`execute_result` 返回的错误只有平字符串：

```json
{"run_error": "索引超出范围"}
```

AI 不知道出错位置，只能盲猜代码、反复试错。根本原因在于 4 个断裂点：

| 断裂点 | 文件 | 问题 |
|--------|------|------|
| `_log_message` 空操作 | `gdscript_executor.gd:294` | 某些运行时错误走 `_log_message` 路径，被静默丢弃 |
| `script_backtraces` 未提取 | `gdscript_executor.gd:289` | `_log_error` 收到完整 `ScriptBacktrace` 对象，但只提取了消息字符串 |
| 原始对象无法序列化 | `hastur_logger.gd:55` | `ScriptBacktrace` 对象持有 GC 引用，传入 context 后无法被 JSON 序列化 |
| `log_script_error` 没传帧 | `editor_log_catcher.gd:83` | 脚本运行时错误调用 `log_script_error`，该函数不接受栈帧参数 |

**修复方案**：

在 `_CompileErrorCapturer` 和 `HasturLogger` 的 `_log_error` 回调中，**立即提取** `ScriptBacktrace` 对象的帧数据为普通字典（`{file, line, function}`），而非存储原始对象。提取后的帧数据天然可 JSON 序列化，通过 `execute_result` 同步返回。

**修复后的返回格式**：

```json
{
  "compile_success": true,
  "run_success": false,
  "run_error": "索引超出范围",
  "run_error_details": [
    {
      "message": "索引超出范围",
      "file": "gdscript://-9223370014612971483.gd",
      "line": 9,
      "function": "run",
      "code": "索引超出范围",
      "error_type": 2,
      "frames": [
        {"function": "run", "file": "gdscript://-9223370014612971483.gd", "line": 9},
        {"function": "_execute_snippet", "file": "res://addons/hasturoperationgd/gdscript_executor.gd", "line": 236},
        {"function": "execute_code", "file": "res://addons/hasturoperationgd/gdscript_executor.gd", "line": 100},
        {"function": "_handle_execute", "file": "res://addons/hasturoperationgd/broker_client.gd", "line": 271},
        {"function": "_handle_message", "file": "res://addons/hasturoperationgd/broker_client.gd", "line": 241},
        {"function": "_read_data", "file": "res://addons/hasturoperationgd/broker_client.gd", "line": 221},
        {"function": "poll", "file": "res://addons/hasturoperationgd/broker_client.gd", "line": 141},
        {"function": "_process", "file": "res://addons/hasturoperationgd/executor_backend.gd", "line": 36}
      ]
    }
  ]
}
```

**关键设计约束**：

- **向后兼容**：新字段 `compile_error_details` / `run_error_details` 是追加而非替换，旧字段 `compile_error` / `run_error` 保持不变。现有解析代码无需修改。
- **立即提取**：`ScriptBacktrace` 对象持有 GC 引用，不能在回调之外存储，必须在 `_log_error` 回调中立即提取为普通字典。
- **类型安全**：帧数据只包含 `String` 和 `int`，天然可 JSON 序列化，适合 TCP NDJSON 传输。
- **零外部依赖**：所有修改都在已有 Godot 插件代码内部，不新增 package / npm 模块。

**涉及文件（修改量 +96/-4 行）**：

| 文件 | 改动 |
|------|------|
| `gdscript_executor.gd` | 修复 `_log_message` 空操作；新增 `_captured_details` + `get_captured_details()`；`_log_error` 中提取帧数据；`execute_code` 在各阶段收集结构化错误 |
| `broker_client.gd` | `execute_result` 增加 `compile_error_details` / `run_error_details`；`_on_logs_ready` 从 context 提取 frames 填入日志条目 |
| `hastur_logger.gd` | `_log_error` 中立即提取 frames 而非传递原始对象（绕过 JSON 序列化限制）；新增 `_extract_frames()` 辅助方法 |
| `editor_log_catcher.gd` | `log_script_error` 接受可选 `frames` 参数，条目包含 `stack` 字段 |

**异步日志通道**：

除了同步的 `execute_result` 路径（`POST /api/execute` 返回值），`GET /api/executors/:id/logs/errors` 异步日志通道也同样包含栈帧信息。游戏进程运行时（GameExecutor）发生的脚本错误，会通过 `HasturLogger` → `EditorLogCatcher` → TCP 日志通道 → broker 的链路，携带完整的 file/line/function 信息。

**验证方法**：

```bash
# 执行一段会报错的代码
curl -s -X POST "http://localhost:5302/api/execute" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"code":"var arr = []\nprint(arr[0])","project_name":"Six Fighter"}'

# 检查返回值中的 run_error_details 是否包含 file/line/frames

# 检查日志通道是否也包含栈帧
curl -s "http://localhost:5302/api/executors/<id>/logs/errors" \
  -H "Authorization: Bearer <token>"
```

---

### 3.2 broker-server 端（TypeScript/Node.js）

#### 3.2.1 HTTP API 端点一览

| 端点 | 方法 | 功能 | 认证 |
|------|------|------|------|
| `/api/health` | GET | 健康检查 + executor 状态 | 否 |
| `/api/executors` | GET | 列出所有 executor | Bearer |
| `/api/executors/:id` | GET | 单个 executor 信息 | Bearer |
| `/api/executors/:id/metrics` | GET | 连接指标 | Bearer |
| **`/api/execute`** | **POST** | **执行 GDScript 代码** | Bearer |
| `/api/scene/tree` | GET | 获取场景树 | Bearer |
| `/api/scene/nodes` | POST | 创建节点 | Bearer |
| `/api/scene/nodes?path=` | DELETE | 删除节点 | Bearer |
| `/api/executors/:id/logs` | GET | 获取日志 | Bearer |

> 注意：实际部署的 broker-server v0.1.0 仅实现了上述端点。断点相关端点和 `/api/executors/:id/logs/clear` 在运行时不可用。

#### 3.2.2 Execute API

---

### 3.3 Python 工具链

`game/tools/` 下提供两个 Python CLI 工具，封装了 broker-server 的 REST API：

#### `editor_call.py` — 轻量级执行器

```bash
python tools/editor_call.py 'print("hello")'           # 执行单行 GDScript
python tools/editor_call.py --file script.gd            # 从文件执行
python tools/editor_call.py --scene-tree                # 获取场景树
python tools/editor_call.py --health                    # 健康检查
python tools/editor_call.py --executors                 # 列出 executor
```

#### `hastur.py` — 完整 CLI 工具

```bash
python tools/hastur.py status          # 全状态概览
python tools/hastur.py health          # 健康检查
python tools/hastur.py exec '<code>'   # 执行 GDScript
python tools/hastur.py scene-tree      # 获取场景树
python tools/hastur.py logs [limit]    # 获取日志
python tools/hastur.py start|stop|restart  # 管理 broker-server
```

> 另提供 `editor_call.js` 和 `hastur.sh` 作为兼容性包装，功能已被 Python 版本取代。

#### 3.2.2 Execute API

**请求**:

```json
POST /api/execute
Authorization: Bearer <token>
Content-Type: application/json

{
    "executor_id": "<uuid>",
    "code": "print(\"Hello\")",
    "timeout_ms": 30000
}
```

**响应**:

```json
{
    "success": true,
    "data": {
        "compile_success": true,
        "compile_error": "",
        "compile_error_details": [],
        "run_success": false,
        "run_error": "Invalid access of index '0' on a base object of type: 'Array'.",
        "run_error_details": [
            {
                "message": "索引超出范围",
                "file": "res://scripts/arena/arena_scene.gd",
                "line": 142,
                "function": "_process_enemy_spawning",
                "frames": [
                    {"function": "_process_enemy_spawning", "file": "res://scripts/arena/arena_scene.gd", "line": 142},
                    {"function": "_process", "file": "res://scripts/arena/arena_scene.gd", "line": 85}
                ]
            }
        ],
        "outputs": [
            ["scene", "SkillTestScene"]
        ],
        "execution_time_ms": 12
    }
}
```

> **v0.3.1 新增**: `compile_error_details` 和 `run_error_details` 字段。当代码执行出错时，这两个字段包含 `file`、`line`、`function`、`frames`（完整栈帧）的结构化数据，取代之前仅有平字符串的 `compile_error` / `run_error`。旧字段保持不变以确保向后兼容。

#### 3.2.3 executor_id 生成机制

executor_id 通过 SHA-256 哈希 `project_name|project_path|editor_pid` 生成，确保同一编辑器实例重连后 ID 不变。每次 broker-server 重启后重新注册。

---

## 四、与编辑器交互方式

### 4.1 方式一：通过 curl 直接调用 HTTP API（推荐）

所有操作通过 broker-server 的 REST API 完成。认证 Token: `995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7`

```bash
# 健康检查
curl -s http://localhost:5302/api/health

# 列出已连接的编辑器
curl -s -H "Authorization: Bearer 995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7" \
  http://localhost:5302/api/executors

# 执行 GDScript
curl -s -X POST http://localhost:5302/api/execute \
  -H "Authorization: Bearer 995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7" \
  -H "Content-Type: application/json" \
  -d '{"code":"print(\"hello\")","project_name":"Six Fighter"}'

# 获取最近错误日志
curl -s -H "Authorization: Bearer 995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7" \
  http://localhost:5302/api/executors/<executor_id>/logs/errors?limit=20
```

### 4.2 GDScript 缩进规则（致命）

**缩进必须使用 Tab 字符**，绝对不能用空格。在 Python 字符串中：

```python
# ✅ 正确：用 \t 表示缩进
code = 'if ei:\n\tctx.output("k", "v")'

# ❌ 错误：用空格缩进 → Mixed use of tabs and spaces
code = 'if ei:\n    ctx.output("k", "v")'

# ❌ 错误：在 shell heredoc 中嵌入 GDScript（PowerShell 自动转 Tab 为空格）
```

### 4.3 方式二：通过 Python CLI 工具调用

Python 工具（详见 [3.3 Python 工具链](#33-python-工具链)）封装了相同的 REST API，适合日常开发快速操作：

```bash
# 健康检查
python tools/hastur.py health

# 执行 GDScript
python tools/hastur.py exec 'print("hello")'

# 轻量级替代 — editor_call.py
python tools/editor_call.py 'print("hello")'
python tools/editor_call.py --scene-tree
```

> 两种方式等价，curl 适合脚本化和精确控制，Python CLI 适合交互式使用。

### 4.4 GDScript 执行快速参考

```python
# Snippet 模式 — print() 自动捕获
code = 'print("hello")'

# 操作节点
code = '\n'.join([
    'var n = get_node("/root/Main/SomeNode")',
    '\tif n != null:',
    '\t\tprint(n.name)'
])

# 调用 EditorInterface（Snippet 模式）
code = '\n'.join([
    'var ei = executeContext.editor_plugin.get_editor_interface()',
    'var sel = ei.get_selection().get_selected_nodes()',
    '\tfor n in sel:',
    '\t\texecuteContext.output("sel", n.name)'
])

# Full Class 模式
code = '\n'.join([
    '@tool',
    'extends RefCounted',
    'func execute(ctx):',
    '\tvar ei = ctx.editor_plugin.get_editor_interface()',
    '\tvar sel = ei.get_selection().get_selected_nodes()',
    '\tctx.output("count", str(sel.size()))',
])
```

---

## 五、Godot 4.x 兼容性说明

### 5.1 Logger.ErrorType 枚举值

Godot 4.6 没有 `ERROR_TYPE_RUNTIME` 常量：

```gdscript
const _ERROR_TYPE_ERROR: int = 0
const _ERROR_TYPE_WARNING: int = 1
const _ERROR_TYPE_SCRIPT: int = 2
```

### 5.2 RefCounted 生命周期

`GDScriptExecutor` 继承 `RefCounted`，必须显式调用 `dispose()` 清理 Logger 资源。

> **v0.4.0 注意**: `RefCounted` 不应有 `_notification()` 方法（会导致空实例崩溃），已在 `gdscript_executor.gd` 中移除。`disconnect_client()` 现在会显式调用 `_executor.dispose()`。

### 5.3 其他迁移注意事项

| 旧语法/方法 | 新语法/方法 | 说明 |
|------------|------------|------|
| `obj.is_valid()` | `is_instance_valid(obj)` | Node 子类不存在 `is_valid()` |
| `obj.instance()` | `obj.instantiate()` | Godot 4.x 改名 |
| `is null` | `== null` | 比较运算符变化 |
| `str(null)` | 返回 `"null"` | 不是空字符串 |
| `reload_current_scene()` | 返回 void | 不能链式调用 |

---

## 六、常见问题排查

| 症状 | 最可能原因 | 解决方案 |
|------|-----------|---------|
| API 返回 401 | Token 错误或缺失 | 确认 `Authorization: Bearer <token>` 头 |
| "Executor not found" | Godot 插件未启用 | 检查 Executor 面板，确认 Connected |
| "Mixed use of tabs and spaces" | 缩进用了空格 | 用 Python `\t` 而非空格 |
| "is_ready on placeholder instance" | 非 `@tool` 脚本的运行时调用 | 只对有 `@tool` 注解的脚本调用方法 |
| "Invalid type in function 'output'" | `ctx.output()` 传了非 String 参数 | 用 `str()` 转换：`str(3.14)` |
| "Identifier not declared" | 使用了不存在的变量（如 `_editor_plugin_ref`） | 改用 `executeContext.editor_plugin` / `ctx.editor_plugin` |
| 连接断开不重连 | 网络短暂中断 | BrokerClient 指数退避自动重连（1s→30s） |
| `print()` 输出为空 | print 未被自动捕获 | 检查代码是否包含合法的独立 `print()` 语句，或用 `executeContext.output()` |
| broker-server 无法启动 | Node.js 版本或依赖问题 | 确认 Node >= 18，`npm install` 已执行 |
| RTT 始终 null（v0.4.0 前） | 心跳定义但从未在 `poll()` 中调用 | v0.4.0 已修复 — `poll()` 每 5s 自动 `send_heartbeat()` |
| Token 不匹配 | 使用了环境变量但 broker 未读取 | v0.4.0 起 `HASTUR_TOKEN` env var 会被 broker-server 自动读取；CLI 也从此变量获取 |

### 诊断流程

```bash
# 1. broker 是否运行？
curl -s http://localhost:5302/api/health

# 2. Godot 是否连接？
curl -s -H "Authorization: Bearer <token>" http://localhost:5302/api/executors

# 3. 查看最近错误日志
curl -s -H "Authorization: Bearer <token>" http://localhost:5302/api/executors/<id>/logs/errors?limit=20

# 4. 如果编译错误 → 检查 Tab 缩进
# 5. 如果运行时错误 → 检查日志中的详细 stack trace
```

### 能力决策树

| 任务 | 方法 |
|------|------|
| 查看场景结构 | Snippet 模式, `get_node(path)` |
| 调用 EditorInterface API | Snippet 模式 via `executeContext.editor_plugin.get_editor_interface()` |
| 获取/设置节点属性 | Snippet 模式, `get_node(path).property = value` |
| 创建节点 | Snippet 模式, `var n = NodeType.new()` → `add_child(n)` |
| 删除节点 | Snippet 模式, `node.queue_free()` |
| 查看编辑器日志 | `GET /api/executors/:id/logs` |
| 复杂多步操作 | Full Class 模式, 用 `executeContext.output()` 通信 |
| 检查项目设置 | Snippet 模式, `ProjectSettings.get_setting()` |
| 获取编辑器选中节点 | Snippet 模式, `ei.get_selection().get_selected_nodes()` |

### 调试检查清单

- [ ] broker-server 是否运行？ → `curl http://localhost:5302/api/health`
- [ ] Executor 是否连接？ → `curl -H "Authorization: Bearer <token>" http://localhost:5302/api/executors`
- [ ] Godot 插件是否启用？ → 右侧面板应显示 **Executor** Dock，绿色指示灯
- [ ] 代码是否使用 Tab 缩进？ （空格会导致编译错误）
- [ ] 编译错误 → 检查 Tab 缩进（最常见原因）→ 检查 `@tool` 注解 → 检查 `extends`
- [ ] 运行时错误 → 检查 `GET /api/executors/:id/logs` → 检查 `@tool` → 检查 `_editor_plugin_ref`

---

## 七、版本对照表

| 组件 | 源码仓库版本 | 生产版本 | 说明 |
|------|------------|---------|------|
| 插件 | v0.1 | **v0.4.0** | `game/addons/hasturoperationgd/` 下为生产版本 |
| broker-server | v0.1.0 | **v0.1.0** | 运行中 API 返回 version 0.3.0 |
| CLI 工具 | 无 | **Python 3.x** | `game/tools/hastur.py` + `game/tools/editor_call.py` |

### 功能演进：v0.1 → v0.4.0

| 特性 | v0.1 | v0.4.0 | 状态 |
|------|------|--------|------|
| TCP 通信 | ✅ | ✅ | 稳定 |
| 远程代码执行 | ✅ | ✅ | 稳定 |
| 编译/运行时错误捕获 | ✅ | ✅ | 稳定 |
| 日志捕获转发 | ✅ | ✅ | 稳定 |
| 场景树 API | ⚠️ 有缺陷 | ✅ | 已修复 |
| 节点创建 | ⚠️ 缺少 HTTP API | ✅ | 已完善 |
| 节点删除 | ⚠️ 路径解析错误 | ✅ | 已修复 |
| `_editor_plugin_ref` 空指针 | ❌ | ✅ | 已修复 |
| RTT 追踪 | ❌ | ✅ | 新增 |
| UI RTT 图表 | ❌ | ✅ | 新增 |
| 执行统计面板 | ❌ | ✅ | 新增 |
| `print()` 自动捕获 | ❌ | ✅ | 新增 |
| `executeContext` 变量注入 | ⚠️ 有缺陷 | ✅ | 已修复 |
| Logger.ErrorType 兼容性 | ❌ | ✅ | 已修复 |
| Timer.is_instance_valid | ❌ | ✅ | 已修复 |
| Logger 内存泄漏 | ❌ | ✅ | 已修复 |
| CLI Python 工具链 | ❌ | ✅ | 新增 |
| 结构化错误捕获（file/line/stack） | ❌ | ✅ | 2026-05-22 新增 |
| `_log_message` 空操作（丢错误） | ❌ | ✅ | 2026-05-22 修复 |
| `ScriptBacktrace` 帧数据未提取 | ❌ | ✅ | 2026-05-22 修复 |
| 日志通道栈帧丢失 | ❌ | ✅ | 2026-05-22 修复 |
| 主动心跳 + RTT 追踪修复 | ❌ | ✅ | 2026-05-25 — 之前 RTT 始终 null，心跳定义但从未调用 |
| `HASTUR_TOKEN` 环境变量 | ❌ | ✅ | 2026-05-25 — 替代硬编码 Token，broker/CLI/插件统一读取 |
| `disconnect_client()` 未清理 Executor | ❌ | ✅ | 2026-05-25 修复 — 断开连接时未 dispose GDScriptExecutor |
| `flush()` 防御性保护 | ❌ | ✅ | 2026-05-25 — 增加二次 is_valid() 检查 |
| 日志缓冲扩容 200→500 | ❌ | ✅ | 2026-05-25 — 降低高频日志丢弃概率 |
| CLI 跨平台 | ❌ | ✅ | 2026-05-25 — Windows tasklist + Unix ps aux 双路径 |
| `_notification` 空实例崩溃 | ❌ | ✅ | 2026-05-25 修复 — RefCounted 不应有 _notification |

---

## 八、安全提醒

> **⚠️ 重要**: 本插件会在编辑器中执行任意代码。Broker Server 通过 Bearer Token 进行访问控制，但仍需注意以下事项：
>
> - **切勿将 broker server 暴露至公网。** 默认绑定 `localhost`，请保持不变。
> - **妥善保管认证 token。** 这是一个 64 位随机十六进制字符串，本质上等同于密码。v0.4.0 起建议用 `HASTUR_TOKEN` 环境变量设置，而非硬编码在 CLI 命令或文档中。
> - **确保 AI Agent 来源可信。** 它能执行 GDScript 所能做的一切操作，能力范围相当于"有编辑器完整权限"。
> - **`.claude/CLAUDE.md` 和 `CLAUDE.md` 应视为敏感文件。** 其中包含 Token、API 地址等连接信息。

---

## 九、参考文档

| 文档 | 位置 | 内容 |
|------|------|------|
| 项目指南（单一起源） | `game/.claude/CLAUDE.md` | 所有操作流程、决策树、快速参考 |
| 插件技术蓝皮书 | `docs/HasturOperationGD-Technical-Whitepaper.md` | 完整架构、API、排错（即本文档） |
| AI 避坑指南 | `docs/godot-ai-pitfall-guide.md` | 常见陷阱与解决方案 |

---

*本蓝皮书于 2026-05-25 更新，反映插件 v0.4.0、Python 工具链、以及 Token/心跳/RTT/跨平台等改进的完整状态。*
