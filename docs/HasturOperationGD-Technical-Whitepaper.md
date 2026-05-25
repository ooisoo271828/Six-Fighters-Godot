# HasturOperationGD 插件技术蓝皮书

> **版本**: v0.5.0（插件 + broker-server）
> **最后更新**: 2026-05-25（新增第五章 + 编译阶段重构 + 全路由 asyncTcpRoute 迁移 + 激光束计数修复 + 死代码清理）
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

| 端点 | 方法 | 功能 | 认证 | 版本 |
|------|------|------|------|------|
| `/api/health` | GET | 健康检查 + executor 状态 | 否 | v0.1 |
| `/api/executors` | GET | 列出所有 executor | Bearer | v0.1 |
| `/api/executors/:id` | GET | 单个 executor 信息 | Bearer | v0.1 |
| `/api/executors/:id/metrics` | GET | 连接指标 | Bearer | v0.1 |
| **`/api/execute`** | **POST** | **执行 GDScript 代码**（v0.5.0 增加 summary） | Bearer | v0.1 |
| `/api/scene/tree` | GET | 获取场景树 | Bearer | v0.1 |
| `/api/scene/nodes` | POST | 创建节点 | Bearer | v0.1 |
| `/api/scene/nodes?path=` | DELETE | 删除节点 | Bearer | v0.1 |
| `/api/executors/:id/logs` | GET | 获取日志 | Bearer | v0.1 |
| **`/api/project/rescan`** | **POST** | **强制编辑器刷新文件系统** | Bearer | v0.5.0 |
| **`/api/script/check`** | **POST** | **编译检查（不执行）** | Bearer | v0.5.0 |
| **`/api/executors/:id/scene/properties`** | **GET** | **获取节点属性**（支持 filter 参数） | Bearer | v0.5.0 |
| **`/api/scene/save`** | **POST** | **保存当前场景到磁盘** | Bearer | v0.5.0 |

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
python tools/hastur.py check '<code>'  # 编译检查（不执行）  [v0.5.0]
python tools/hastur.py scene-tree      # 获取场景树
python tools/hastur.py props <path> [--filter p1,p2]  # 获取节点属性  [v0.5.0]
python tools/hastur.py rescan          # 强制文件系统刷新  [v0.5.0]
python tools/hastur.py save [--force]  # 保存当前场景  [v0.5.0]
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

## 五、远程技能自动化测试指南

> **v0.5.0 工作流** — 基于 2026-05-25 实测验证
> **适用场景**: AI Agent 通过 Hastur 在游戏运行时中自动打开 SkillDemo 场景、选择技能、施放测试、验证结果的全流程

### 5.1 双 Executor 架构

Hastur 支持两类 executor，远程技能测试需要同时使用两者：

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Claude Code / AI Agent                      │
│                              │                                      │
│                    POST /api/execute                                 │
│                              │                                      │
├──────────────────────────────┼──────────────────────────────────────┤
│                    broker-server (Node.js)                           │
│                              │                                      │
│              ┌───────────────┼───────────────┐                      │
│              │               │               │                      │
│    ┌─────────▼─────────┐   │   ┌─────────▼─────────┐              │
│    │  Editor Executor   │   │   │   Game Executor    │              │
│    │  type: "editor"   │   │   │   type: "game"    │              │
│    │  (TCP :5301)      │   │   │   (TCP :5301)     │              │
│    │                   │   │   │                   │              │
│    │  Godot Editor     │   │   │  Game Runtime     │              │
│    │  + HasturPlugin   │   │   │  + GameExecutor   │              │
│    │                   │   │   │  (autoload)       │              │
│    └─────────┬─────────┘   │   └─────────┬─────────┘              │
│              │             │             │                          │
│  ┌───────────▼────────┐   │   ┌─────────▼───────────┐              │
│  │ play_main_scene()  │   │   │ Engine.get_main_loop │              │
│  │ stop_playing_scene()│  │   │ change_scene_to_file()│              │
│  │ Ignore Error Breaks│   │   │ SkillDemo._do_cast() │              │
│  └────────────────────┘   │   └───────────────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

| Executor 类型 | 用途 | 可用的 API |
|-------------|------|-----------|
| `editor` | 控制编辑器行为：启停游戏、设置调试器、修改项目设置 | `EditorInterface`, `executeContext.editor_plugin`, `EditorFileSystem` |
| `game` | 控制游戏运行时：切换场景、操作场景节点、调用游戏内方法 | `SceneTree`, `Engine`, 游戏内所有类 |

**两者必须配合使用**: editor executor 负责游戏的生命周期管理（启动/停止），game executor 负责游戏内的技能测试操作。

### 5.2 前置条件

#### 5.2.1 GameExecutor Autoload（必需）

`game_executor.gd` 必须注册为项目 Autoload，否则游戏进程不会连接 broker-server。

```
[autoload]  (project.godot)

GameExecutor="*res://addons/hasturoperationgd/game_executor.gd"
```

验证方法：

```bash
grep -n "GameExecutor\|game_executor" game/project.godot
# 应输出: GameExecutor="*res://addons/hasturoperationgd/game_executor.gd"
```

如果缺失，通过 Hastur 添加：

```gdscript
# 在 editor executor 上执行
executeContext.editor_plugin.add_autoload_singleton("GameExecutor", "res://addons/hasturoperationgd/game_executor.gd")
executeContext.output("result", "done")
```

#### 5.2.2 broker-server 运行中

```bash
cd broker/hastur-operation-plugin-main/broker-server
HASTUR_TOKEN=<token> npm run dev
# 或已有 PM2/systemd 守护进程
```

#### 5.2.3 Godot 编辑器运行 + Hastur 插件启用

Godot 4.x 打开项目，**Project → Project Settings → Plugins → HasturOperationGD → Enabled**

验证连接：

```bash
curl -s http://localhost:5302/api/health
# 确认 executors_connected >= 1
```

### 5.3 完整工作流

```
Step 1 ─ 确认 broker + editor executor
Step 2 ─ 启动游戏 (editor executor)
Step 3 ─ 等待 game executor 连接
Step 4 ─ 启用 Ignore Error Breaks (editor executor)
Step 5 ─ 导航到 SkillDemo (game executor)
Step 6 ─ 列出可用技能 (game executor)
Step 7 ─ 选择并施放技能 (game executor)
Step 8 ─ 验证结果 (game executor)
Step 9 ─ 截图验证 (game executor)
Step 10 ─ 停止游戏 (editor executor)
```

#### Step 1: 确认连接

```bash
curl -s http://localhost:5302/api/executors \
  -H "Authorization: Bearer $HASTUR_TOKEN"

# 期望结果: 至少一个 type: "editor" 的 executor
```

#### Step 2: 启动游戏

在 **editor executor** 上执行：

```gdscript
var ei = executeContext.editor_plugin.get_editor_interface()
ei.play_main_scene()
executeContext.output("started", "ok")
```

> **注意**: 不要用 `ei.play_current_scene()` — 它播放编辑器当前打开的脚本场景而非项目主场景。`play_main_scene()` 播放 `project.godot` 中 `run/main_scene` 指定的场景。

#### Step 3: 等待 Game Executor

游戏启动后约 3-5 秒，game executor 通过 GameExecutor autoload 连接 broker。轮询等待：

```bash
# 持续轮询（建议每 2 秒一次，最多等 15 秒）
for i in $(seq 1 8); do
  sleep 2
  COUNT=$(curl -s http://localhost:5302/api/executors \
    -H "Authorization: Bearer $HASTUR_TOKEN" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for e in d.get('data',[]) if e.get('type')=='game'))")
  echo "Game executors: $COUNT"
  [ "$COUNT" -ge 1 ] && break
done
```

#### Step 4: 启用 Ignore Error Breaks（关键）

**每次向 game executor 发指令前必须执行。** 否则如果 GDScript 有运行时错误，Godot 调试器会冻结游戏进程，导致后续所有 API 调用超时。

在 **editor executor** 上执行：

```gdscript
var ei = executeContext.editor_plugin.get_editor_interface()
var base = ei.get_base_control()
var stack = [[base, 0]]
var toolbar = null
while stack.size() > 0:
	var pair = stack.pop_back()
	var node = pair[0]
	var depth = pair[1]
	if toolbar != null:
		break
	if depth > 25:
		continue
	if node.name.find("Stack Trace") != -1 and node.get_class() == "VBoxContainer":
		for child in node.get_children():
			if child is HBoxContainer:
				toolbar = child
				break
	for child in node.get_children():
		stack.append([child, depth + 1])
if toolbar != null:
	for child in toolbar.get_children():
		if child is Button and child.tooltip_text == "Ignore Error Breaks":
			if child.button_pressed:
				executeContext.output("ignore_error_breaks", "already_enabled")
			else:
				child.set_toggle_mode(true)
				child.set_pressed(true)
				child.emit_signal("pressed")
				executeContext.output("ignore_error_breaks", "enabled")
			break
```

> **为什么这么复杂？** Ignore Error Breaks 按钮的 `toggle_mode` 初始为 `false`。直接 `emit_signal("pressed")` 或 `set_pressed(true)` 无效。必须先 `set_toggle_mode(true)` 再 `set_pressed(true)` 再 `emit_signal("pressed")`。

#### Step 5: 导航到 SkillDemo

在 **game executor** 上执行：

```gdscript
var tree = Engine.get_main_loop() as SceneTree
if tree:
	tree.change_scene_to_file("res://scenes/dev/skill_demo.tscn")
	executeContext.output("navigated", "skill_demo")
else:
	executeContext.output("error", "no scene tree")
```

> **重要**: 在 game executor 的 snippet 模式中，`get_tree()` 不可用（因为 `self` 是 `RefCounted` 而非 `Node`）。必须用 `Engine.get_main_loop() as SceneTree` 获取场景树。

等待约 2 秒让 SkillDemo 完成初始化（`_ready()` 中有 `await get_tree().create_timer(0.3).timeout`）：

```bash
sleep 2
```

#### Step 6: 列出可用技能

在 **game executor** 上执行：

```gdscript
var tree = Engine.get_main_loop() as SceneTree
var demo = tree.root.get_node_or_null("SkillDemo")
if demo:
	var skill_sys = demo.get_node_or_null("SkillSystem")
	if skill_sys:
		var registry = skill_sys.get_node_or_null("SkillRegistry")
		if registry and registry.has_method("get_all_skill_ids"):
			var ids = registry.get_all_skill_ids()
			for i in range(ids.size()):
				executeContext.output("skill_" + str(i), ids[i])
			executeContext.output("skill_count", str(ids.size()))
```

#### Step 7: 选择并施放技能

在 **game executor** 上执行：

```gdscript
var tree = Engine.get_main_loop() as SceneTree
var demo = tree.root.get_node_or_null("SkillDemo")
if demo and demo.has_method("_do_cast"):
	# 选择技能（直接设 skill_id）
	demo._selected_skill = "fireball_basic"
	# 设置速度倍率（0=0.5×, 1=1×, 2=2×）
	demo._speed_idx = 1
	Engine.time_scale = 1.0
	# 设置目标模式（0=pentagon, 1=single, 2=dual, 3=triangle, 4=scatter, 5=line）
	demo._current_mode_idx = 0
	demo._update_targets()
	# 施放技能
	demo._do_cast()
	executeContext.output("skill", demo._selected_skill)
	executeContext.output("is_casting", str(demo._is_casting))
```

**可选配置**:

```gdscript
# 启用循环模式（施放完成后自动重放）
demo._looping = true
if demo._loop_check:
	demo._loop_check.button_pressed = true

# 二倍速
demo._speed_idx = 2
Engine.time_scale = 2.0

# 切换为目标模式
demo._current_mode_idx = 1  # single
demo._update_targets()
```

#### Step 8: 验证结果

等待投射物结束（约 2-5 秒，取决于技能时长和速度倍率），然后检查状态：

```gdscript
var tree = Engine.get_main_loop() as SceneTree
var demo = tree.root.get_node_or_null("SkillDemo")
if demo:
	executeContext.output("is_casting", str(demo._is_casting))
	executeContext.output("status", demo._status_label.text if demo._status_label else "?")
	
	# 检查普通投射物
	var pool = demo._skill_system.get_node_or_null("ProjectilePool")
	if pool and pool.has_method("get_active_count"):
		executeContext.output("active_projectiles", str(pool.get_active_count()))
	
	# 检查激光池（激光术专用）
	var lb_pool = demo._skill_system.get_node_or_null("LaserBeamPool")
	if lb_pool and lb_pool.has_method("get_active_count"):
		executeContext.output("active_lasers", str(lb_pool.get_active_count()))
```

**状态标签含义**:

| 状态文本 | 含义 |
|---------|------|
| `施放完成` | 技能执行完毕，所有投射物已结束 |
| `施放: <skill_id>` | 技能正在播放中 |
| `射程<range>内无合法目标` | 目标不在技能射程内，或目标模式不匹配 |
| `已暂停` | 用户或代码设置了 `Engine.time_scale = 0` |
| `就绪 — N 个技能` | SkillDemo 初始化完成，N 个技能可测试 |

#### Step 9: 截图验证

在 **game executor** 上执行：

```gdscript
var tree = Engine.get_main_loop() as SceneTree
var img = tree.root.get_texture().get_image()
var dict = Time.get_datetime_dict_from_system()
var date_str = "%04d-%02d-%02d" % [dict["year"], dict["month"], dict["day"]]
var time_str = "%02d-%02d-%02d" % [dict["hour"], dict["minute"], dict["second"]]
var rel_path = ".temp/" + date_str + "-" + time_str + "-game.png"
var abs_path = ProjectSettings.globalize_path("res://" + rel_path)
var dir_abs = ProjectSettings.globalize_path("res://.temp")
if not DirAccess.dir_exists_absolute(dir_abs):
	DirAccess.make_dir_recursive_absolute(dir_abs)
var err = img.save_png(abs_path)
executeContext.output("path", rel_path)
executeContext.output("result", "OK" if err == 0 else "Error: " + str(err))
```

截图文件保存至 `game/.temp/<date>-<time>-game.png`。

#### Step 10: 停止游戏

在 **editor executor** 上执行：

```gdscript
var ei = executeContext.editor_plugin.get_editor_interface()
ei.stop_playing_scene()
executeContext.output("stopped", "ok")
```

---

### 5.4 SkillDemo 内部结构参考

#### 5.4.1 场景树

```
SkillDemo (Node2D)                     ← res://scripts/dev/skill_demo.gd
├── Background (Node2D)                ← res://scripts/dev/demo_bg.gd
├── Caster (Node2D)                    ← res://scripts/dev/demo_caster.gd
│   └── position = (0, 190)
├── CameraAnchor (Node2D)              ← res://scripts/dev/camera_anchor.gd
│   └── Camera2D
├── SkillSystem (Node)                 ← res://scenes/skill_system/skill_system.tscn
│   ├── SkillRegistry
│   ├── ModifierRegistry
│   ├── ModifierProcessor
│   ├── SkillSignalBus
│   ├── ProjectilePool
│   ├── ExecutorPool
│   ├── SkillVFXManager
│   └── LaserBeamPool
├── VFX (Node2D)                       ← 运行时创建
├── Target_* (Node2D)                  ← 运行时创建（具体数量由目标模式决定）
└── CanvasLayer (CanvasLayer)
    └── ControlPanel (PanelContainer)  ← UI 控制栏（底部）
```

#### 5.4.2 关键方法

| 方法 | 功能 | 参数 |
|------|------|------|
| `_do_cast()` | 执行技能施放（核心入口） | 无参数，使用 `_selected_skill` 和 `_targets` |
| `_on_play_pressed()` | 按钮事件 → 设置 `Engine.time_scale` → 调用 `_do_cast()` | 无 |
| `_on_pause_pressed()` | 切换 0 倍速 / 恢复原速 | 无 |
| `_on_stop_pressed()` | 清理所有投射物，重置状态 | 无 |
| `_on_speed_pressed()` | 循环切换 0.5× / 1× / 2× | 无 |
| `_on_mode_pressed()` | 循环切换目标模式 | 无 |
| `_update_targets()` | 根据 `_current_mode_idx` 重建靶标 | 无 |
| `_count_active_projectiles()` | 返回 `ProjectilePool` 中活跃投射物数 | 返回 `int` |
| `_clear_all_projectiles()` | 清空 `ProjectilePool` 中所有投射物 | 无 |

#### 5.4.3 关键变量

| 变量名 | 类型 | 说明 |
|--------|------|------|
| `_selected_skill` | `String` | 当前选中技能的 ID |
| `_targets` | `Array[Node2D]` | 当前靶标列表（由 `_current_mode_idx` 决定） |
| `_current_mode_idx` | `int` | 目标模式索引 (0-5) |
| `_speed_idx` | `int` | 速度索引 (0-2) |
| `_looping` | `bool` | 是否循环播放 |
| `_is_casting` | `bool` | 是否正在施放中 |
| `_is_frozen` | `bool` | 是否已暂停 |
| `_caster` | `Node2D` | 施法者节点（位置 Vector2(0, 190)） |
| `_skill_system` | `Node` | SkillSystem 根节点引用 |
| `_status_label` | `Label` | 底部状态栏文本 |
| `_skill_option` | `OptionButton` | 技能选择下拉框 |

#### 5.4.4 目标模式

| 索引 | 模式名称 | 靶标数 | 布局说明 |
|------|---------|--------|---------|
| 0 | pentagon（五目标） | 5 | 五边形排列 |
| 1 | single（单受体） | 1 | 单一中心靶标 |
| 2 | dual（双目标） | 2 | 水平并列 |
| 3 | triangle（三角阵） | 3 | 倒三角排列 |
| 4 | scatter（散开群） | 5 | 随机散布 |
| 5 | line（一字排） | 5 | 水平一排 |

施法者位于 `(0, 190)`，所有靶标位于 Y 轴负方向（施法者上方），距离施法者 80-400 像素。

#### 5.4.5 直接控制（不依赖 UI）

通过直接设置变量和方法调用，可绕过 UI 操作，实现完全编程控制：

```gdscript
# 设置技能
demo._selected_skill = "fireball_basic"

# 设置目标模式
demo._current_mode_idx = 0  # pentagon
demo._update_targets()       # 重建靶标

# 设置速度
demo._speed_idx = 1          # 1×
Engine.time_scale = 1.0

# 施放
demo._do_cast()

# 等待后检查结果
var active = demo._count_active_projectiles()
var status_text = demo._status_label.text
```

---

### 5.5 通过 curl 一步到位（完整脚本模板）

以下是一个完整的 bash 脚本，执行全部技能测试流程：

```bash
#!/bin/bash
# skill_test.sh — 通过 Hastur 远程测试指定技能
# 用法: ./skill_test.sh <skill_id> [target_mode_idx] [speed_idx]

TOKEN="${HASTUR_TOKEN:-995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7}"
HOST="${HASTUR_HOST:-localhost}"
PORT="${HASTUR_PORT:-5302}"
BASE="http://${HOST}:${PORT}/api"
SKILL="${1:-fireball_basic}"
MODE="${2:-0}"
SPEED="${3:-1}"
PROJECT="Six Fighter"

# 1. 健康检查
echo "== 1. Health Check =="
curl -s "$BASE/health" | python3 -m json.tool

# 2. 启动游戏（通过 editor executor）
echo "== 2. Starting game =="
curl -s -X POST "$BASE/execute" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"code\":\"var ei = executeContext.editor_plugin.get_editor_interface()\\nei.play_main_scene()\\nexecuteContext.output(\\\"started\\\", \\\"ok\\\")\",\"project_name\":\"$PROJECT\",\"type\":\"editor\"}"

# 3. 等待 game executor 连接
echo "== 3. Waiting for game executor =="
for i in $(seq 1 8); do
  sleep 2
  COUNT=$(curl -s "$BASE/executors" -H "Authorization: Bearer $TOKEN" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for e in d.get('data',[]) if e.get('type')=='game'))")
  echo "  Game executors: $COUNT"
  [ "$COUNT" -ge 1 ] && break
done

# 4. 启用 Ignore Error Breaks
echo "== 4. Enabling Ignore Error Breaks =="
# [此处插入 Step 4 的 GDScript 代码]

# 5. 导航到 SkillDemo
echo "== 5. Navigating to SkillDemo =="
curl -s -X POST "$BASE/execute" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"code\":\"var tree = Engine.get_main_loop() as SceneTree\\ntree.change_scene_to_file(\\\"res://scenes/dev/skill_demo.tscn\\\")\\nexecuteContext.output(\\\"nav\\\", \\\"ok\\\")\",\"type\":\"game\",\"project_name\":\"$PROJECT\"}"
sleep 2

# 6. 施放技能
echo "== 6. Casting skill: $SKILL =="
CODE=$(cat <<'GDS'
var tree = Engine.get_main_loop() as SceneTree
var demo = tree.root.get_node_or_null("SkillDemo")
if demo and demo.has_method("_do_cast"):
	demo._selected_skill = "<SKILL>"
	demo._current_mode_idx = <MODE>
	demo._update_targets()
	demo._speed_idx = <SPEED>
	Engine.time_scale = [1.0, 0.5, 1.0, 2.0][<SPEED>]
	demo._do_cast()
	executeContext.output("skill", demo._selected_skill)
	executeContext.output("is_casting", str(demo._is_casting))
GDS
)
CODE="${CODE//<SKILL>/$SKILL}"
CODE="${CODE//<MODE>/$MODE}"
CODE="${CODE//<SPEED>/$SPEED}"

curl -s -X POST "$BASE/execute" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps({'code': '''$CODE''', 'type': 'game', 'project_name': '$PROJECT'}))")"

# 7. 等待后验证
sleep 4
echo "== 7. Result =="
curl -s -X POST "$BASE/execute" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"code\":\"var tree = Engine.get_main_loop() as SceneTree\\nvar demo = tree.root.get_node_or_null(\\\"SkillDemo\\\")\\nif demo:\\n\\texecuteContext.output(\\\"is_casting\\\", str(demo._is_casting))\\n\\texecuteContext.output(\\\"status\\\", demo._status_label.text if demo._status_label else \\\"?\\\")\",\"type\":\"game\",\"project_name\":\"$PROJECT\"}"

# 8. 停止游戏
echo "== 8. Stopping game =="
curl -s -X POST "$BASE/execute" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"code\":\"var ei = executeContext.editor_plugin.get_editor_interface()\\nei.stop_playing_scene()\\nexecuteContext.output(\\\"stopped\\\", \\\"ok\\\")\",\"project_name\":\"$PROJECT\",\"type\":\"editor\"}"

echo "== Done =="
```

---

### 5.6 测试过的技能列表

截至 v0.5.0，SkillRegistry 中注册了以下技能：

| 技能 ID | 伤害类型 | 目标模式 | 效果类型 | 交付方式 |
|---------|---------|---------|---------|---------|
| `fireball_basic` | 火焰 | 单目标 | 投射物 | projectile |
| `ice_arrow` | 冰霜 | 单目标 | 投射物 | projectile |
| `falling_meteor` | 物理+火焰 | AoE | 投射物 | projectile |
| `laser_beam` | 火焰 | MAX_COVERAGE(6) | emit_laser_beam | instant |
| `missile_storm` | 物理 | 多目标 | 投射物群 | projectile |
| `water_wave` | 物理 | 扇形 | 投射物 | projectile |

#### 目标模式兼容性

| 技能 | 单受体 | 五目标 | 三角阵 | 散开群 | 一字排 | 备注 |
|------|--------|--------|--------|--------|--------|------|
| fireball_basic | ✅ | ✅ | ✅ | ✅ | ✅ | |
| ice_arrow | ✅ | ✅ | ✅ | ✅ | ✅ | 多重发射 |
| falling_meteor | ✅ | ⚠️ | ✅ | ✅ | ✅ | AoE 技能 |
| laser_beam | ✅ | ✅ | ✅ | ✅ | ✅ | MAX_COVERAGE 自动选角度 |
| missile_storm | ✅ | ✅ | ✅ | ✅ | ✅ | 散射型 |
| water_wave | ✅ | ✅ | ✅ | ✅ | ✅ | 扇形技能 |

---

### 5.7 已知问题与注意事项

#### 5.7.1 ~~激光束计数缺陷~~ 已修复（2026-05-25）

> **历史**: `_count_active_projectiles()` 原只检查 `ProjectilePool`，不检查 `LaserBeamPool`。激光术通过 `LaserBeamPool` 发射（走 `skill_root.gd` 的 MAX_COVERAGE 独立分支），导致：
> - 施放激光术后 `_count_active_projectiles()` 始终返回 0
> - `_do_cast()` 误判为"射程内无合法目标"
> - `_process()` 中 `_had_projectiles` 永远 false，`_is_casting` 永远 true

**当前状态**: 已修复。`_count_active_projectiles()` 和 `_clear_all_projectiles()` 同时检查两个池：

```gdscript
func _count_active_projectiles() -> int:
	var count := 0
	var pool = _skill_system.get_node_or_null("ProjectilePool")
	if pool and pool.has_method("get_active_count"):
		count += pool.get_active_count()
	var lb_pool = _skill_system.get_node_or_null("LaserBeamPool")
	if lb_pool and lb_pool.has_method("get_active_count"):
		count += lb_pool.get_active_count()
	return count

func _clear_all_projectiles() -> void:
	var pool = _skill_system.get_node_or_null("ProjectilePool")
	if pool and pool.has_method("clear_all"):
		pool.clear_all()
	var lb_pool = _skill_system.get_node_or_null("LaserBeamPool")
	if lb_pool and lb_pool.has_method("clear_all"):
		lb_pool.clear_all()
```

> **根因**: MAX_COVERAGE 模式（target_mode=6）是激光术特有的目标选择逻辑，走 `skill_root.gd:60-111` 的独立分支，直接调用 `laser_beam_pool.spawn()`。旧的项目池计数逻辑未覆盖此分支。

#### 5.7.2 Snippet 模式的 RefCounted 限制

在 game executor 的 snippet 模式中：

| 不可用 | 替代方案 |
|--------|---------|
| `get_tree()` | `Engine.get_main_loop() as SceneTree` |
| `get_node(path)` | `tree.root.get_node_or_null(path)` |
| `get_viewport()` | `tree.root` |

#### 5.7.3 远程代码环境 vs 本地执行

| 方面 | 远程（Hastur） | 本地（Godot 内） |
|------|---------------|-----------------|
| `self` | RefCounted（snippet） | Node（SkillDemo） |
| 调用私有方法 | ✅ 可调用 `_do_cast()` | ✅ 同 |
| 访问私有变量 | ✅ 可读写 `_is_casting` | ✅ 同 |
| `@tool` | 自动添加（snippet） | 手动标签 |
| 缩进 | Tab 字符 | Tab 字符 |

#### 5.7.4 时间缩放对远程调用的影响

`Engine.time_scale = 0`（暂停）会使 `POST /api/execute` 请求超时（30s），因为游戏主循环不再处理 TCP 消息。如果在暂停状态下发送了指令，需要用 editor executor 恢复：

```gdscript
# 在 editor executor 上执行
var ei = executeContext.editor_plugin.get_editor_interface()
ei.stop_playing_scene()  # 停止游戏进程
# 然后重新启动
```

#### 5.7.5 调试器冻结恢复

如果 game executor 请求超时（HTTP 504），游戏很可能已被调试器冻结：

1. 在 editor executor 上点击"Continue"按钮恢复：

```gdscript
var ei = executeContext.editor_plugin.get_editor_interface()
var base = ei.get_base_control()
# [同上 Step 4 的搜索逻辑，但找 tooltip_text == "Continue" 的按钮]
# 对非 toggle button，直接 emit_signal("pressed") 即可
```

2. 启用 Ignore Error Breaks（见 Step 4）
3. 重新发送 game executor 指令

#### 5.7.6 curl 中 GDScript 转义规则

在 bash 的 curl 命令中嵌入 GDScript 时，陷阱很多：

| 场景 | 方法 | 缩进 |
|------|------|------|
| 单行代码 | `-d '{"code":"print(1)"}'` | 无缩进 |
| 多行代码（内联） | 用 `\n` 分隔，`\t` 缩进 | `\t` |
| 多行代码（heredoc） | 先构造变量再 JSON 编码 | 真实 Tab |
| 复杂代码 | 用 Python 辅助构造 JSON | Tab 或 `\t` |

**推荐做法**: 用 Python 脚本生成 JSON payload，避免 bash 转义问题：

```bash
CODE=$(cat <<'GDS'
var tree = Engine.get_main_loop() as SceneTree
var demo = tree.root.get_node_or_null("SkillDemo")
if demo:
	demo._selected_skill = "fireball_basic"
	demo._do_cast()
GDS
)
curl -s -X POST "$BASE/execute" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json,sys; print(json.dumps({'code': sys.stdin.read(), 'type': 'game', 'project_name': '$PROJECT'}))" <<< "$CODE")"
```

---

## 六、Godot 4.x 兼容性说明

### 6.1 Logger.ErrorType 枚举值

Godot 4.6 没有 `ERROR_TYPE_RUNTIME` 常量：

```gdscript
const _ERROR_TYPE_ERROR: int = 0
const _ERROR_TYPE_WARNING: int = 1
const _ERROR_TYPE_SCRIPT: int = 2
```

### 6.2 RefCounted 生命周期

`GDScriptExecutor` 继承 `RefCounted`，必须显式调用 `dispose()` 清理 Logger 资源。

> **v0.4.0 注意**: `RefCounted` 不应有 `_notification()` 方法（会导致空实例崩溃），已在 `gdscript_executor.gd` 中移除。`disconnect_client()` 现在会显式调用 `_executor.dispose()`。

### 6.3 其他迁移注意事项

| 旧语法/方法 | 新语法/方法 | 说明 |
|------------|------------|------|
| `obj.is_valid()` | `is_instance_valid(obj)` | Node 子类不存在 `is_valid()` |
| `obj.instance()` | `obj.instantiate()` | Godot 4.x 改名 |
| `is null` | `== null` | 比较运算符变化 |
| `str(null)` | 返回 `"null"` | 不是空字符串 |
| `reload_current_scene()` | 返回 void | 不能链式调用 |

### 6.4 GDScript Resource Reload 机制（热重载可行性分析）

> **v0.5.0 新增 — 基于 2026-05-25 实测验证**

AI Agent 工作流中频繁遇到"修改 `.gd` 文件后编辑器使用旧缓存"的问题。本节记录 Godot 4 中 `GDScript.reload()` 的实际行为，以及热重载的可行性结论。

#### 实测环境

- Godot 4.6.2-stable
- 通过 Hastur 插件 `POST /api/execute` 执行 Full Class 模式 GDScript
- 测试脚本：`res://scripts/dev/_hot_reload_test.gd`（运行时创建）

#### 测试矩阵

| 测试场景 | `load()` 获取缓存 | 修改 `source_code` | `reload()` 返回值 | 效果 |
|----------|-------------------|-------------------|-------------------|------|
| 无实例存在 | ✅ 返回 GDScript Resource | ✅ 可写入 | `OK (0)` | ✅ 方法数 1→2，新方法可调用，返回值正确 |
| 有实例存在 | ✅ 同一 Resource 对象 | ✅ 可写入 | `ERR_ALREADY_IN_USE (22)` | ❌ 引擎拒绝，抛出 `"Cannot reload script while instances exist."` |

#### 关键发现

**1. `load()` 返回缓存的 GDScript Resource**

```gdscript
var script_res = load("res://path/to/script.gd")
# script_res 指向引擎内部缓存的同一个 Resource 对象
# 多次 load() 返回同一个 instance_id
```

**2. `source_code` 可直接修改**

```gdscript
script_res.source_code = "extends Node2D\n\nfunc new_code():\n\treturn 42\n"
# 修改立即生效于 Resource 对象，但不会自动触发重编译
```

**3. `reload()` 受实例生命周期约束**

```gdscript
var err = script_res.reload()
# 无实例时: OK (0) — 重新编译，新方法立即可用
# 有实例时: ERR_ALREADY_IN_USE (22) — 引擎拒绝重编译
```

引擎在 `modules/gdscript/gdscript.cpp:756` 硬编码了此检查。任何对象（Node、RefCounted 等）引用了该 GDScript Resource，`reload()` 就会失败。这是引擎级安全机制，无法绕过。

**4. `CACHE_MODE_IGNORE` 创建新 Resource 对象**

```gdscript
var new_script = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
# new_script 是全新的 Resource 对象，与缓存中的不同
# 旧实例仍引用旧 Resource，不受影响
```

#### 热重载不可行的原因

| 方案 | 问题 |
|------|------|
| 修改 `source_code` + `reload()` | 有实例时返回 ERR_ALREADY_IN_USE |
| `CACHE_MODE_IGNORE` 加载新脚本 | 旧实例不更新，需要 `set_script()` 替换（丢失状态） |
| `reload_scene_from_path()` | 销毁运行时状态，等于 stop → replay |
| `EditorFileSystem.update_file()` | 只通知编辑器文件系统刷新，不触发脚本重编译 |

#### 替代方案

v0.5.0 提供以下端点缓解此问题（非热重载）：

- `POST /api/project/rescan` — 强制编辑器刷新文件系统缓存
- `POST /api/script/check` — 编译检查但不执行（验证代码正确性）
- `POST /api/script/hot-reload` — **已删除** — Godot 4 无可行的热重载路径

#### 对 AI Agent 工作流的影响

修改 `.gd` 文件后，AI 应：
1. 调用 `POST /api/project/rescan` 通知编辑器刷新
2. 调用 `POST /api/script/check` 验证编译通过
3. 如需生效：停止游戏 → 重新运行（`stop → replay`）

不要尝试通过 API 修改 `source_code` 并 `reload()` — 在有实例的场景中必然失败。

---

## 七、常见问题排查

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

## 八、版本对照表

| 组件 | 源码仓库版本 | 生产版本 | 说明 |
|------|------------|---------|------|
| 插件 | v0.1 | **v0.5.0** | `game/addons/hasturoperationgd/` 下为生产版本 |
| broker-server | v0.1.0 | **v0.5.0** | 运行中 API 返回 version 0.5.0 |
| CLI 工具 | 无 | **Python 3.x** | `game/tools/hastur.py` + `game/tools/editor_call.py` |

### 功能演进：v0.1 → v0.5.0

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
| 注册式路由（broker-server） | ❌ | ✅ | v0.5.0 — `sendRequest<T>` + `handleResult` 替代 4 个重复 send/handle 方法 |
| 注册式路由（broker_client.gd） | ❌ | ✅ | v0.5.0 — `_message_handlers` 字典替代 match 块 |
| `resolveExecutor` + `asyncTcpRoute` | ❌ | ✅ | v0.5.0 — http-server.ts 辅助函数消除重复代码 |
| `POST /api/project/rescan` | ❌ | ✅ | v0.5.0 — 强制编辑器刷新文件系统 |
| `POST /api/script/check` | ❌ | ✅ | v0.5.0 — 编译检查（不执行），返回 compile_success + errors |
| `GET /api/executors/:id/scene/properties` | ❌ | ✅ | v0.5.0 — 获取节点属性，支持黑名单 + 白名单过滤 |
| `POST /api/scene/save` | ❌ | ✅ | v0.5.0 — 保存当前场景到磁盘 |
| `POST /api/execute` summary 增强 | ❌ | ✅ | v0.5.0 — 响应增加 summary 字段（compile_ok/run_ok/error_count/first_error/output_count） |
| CLI `check`/`rescan`/`save`/`props` | ❌ | ✅ | v0.5.0 — 4 个新 CLI 命令 |
| GDScript Resource Reload 测试 | ❌ | ✅ | v0.5.0 — 验证 `reload()` 在有实例时返回 ERR_ALREADY_IN_USE，确认 hot-reload 不可行 |
| 编译阶段提取 `_compile_source()` | ❌ | ✅ | 2026-05-25 — `compile_only()` 和 `execute_code()` 共享编译逻辑，消除 30 行重复代码 |
| 激光束计数修复（`_count_active_projectiles`） | ❌ | ✅ | 2026-05-25 — 同时检查 `LaserBeamPool`，修复 `_is_casting` 卡死 |
| `asyncTcpRoute` 全覆盖 6 条旧路由 | ❌ | ✅ | 2026-05-25 — scene tree / create / delete 路由从手动 try/catch 迁移 |
| `scene/save` force 参数支持 | ❌ | ✅ | 2026-05-25 — `force=true` 时服务端日志记录，数据传递给 executor |
| `_executor.dispose()` 死代码清理 | ❌ | ✅ | 2026-05-25 — `disconnect_client()` 中移除 4 行无法到达的代码 |

---

## 九、安全提醒

> **⚠️ 重要**: 本插件会在编辑器中执行任意代码。Broker Server 通过 Bearer Token 进行访问控制，但仍需注意以下事项：
>
> - **切勿将 broker server 暴露至公网。** 默认绑定 `localhost`，请保持不变。
> - **妥善保管认证 token。** 这是一个 64 位随机十六进制字符串，本质上等同于密码。v0.4.0 起建议用 `HASTUR_TOKEN` 环境变量设置，而非硬编码在 CLI 命令或文档中。
> - **确保 AI Agent 来源可信。** 它能执行 GDScript 所能做的一切操作，能力范围相当于"有编辑器完整权限"。
> - **`.claude/CLAUDE.md` 和 `CLAUDE.md` 应视为敏感文件。** 其中包含 Token、API 地址等连接信息。

---

## 十、参考文档

| 文档 | 位置 | 内容 |
|------|------|------|
| 项目指南（单一起源） | `game/.claude/CLAUDE.md` | 所有操作流程、决策树、快速参考 |
| 插件技术蓝皮书 | `docs/HasturOperationGD-Technical-Whitepaper.md` | 完整架构、API、排错（即本文档） |
| AI 避坑指南 | `docs/godot-ai-pitfall-guide.md` | 常见陷阱与解决方案 |

---

*本蓝皮书于 2026-05-25 更新。涵盖 v0.5.0 全部功能：注册式路由重构、4 个新端点（rescan/script-check/properties/save）、execute summary 增强、CLI 新命令、GDScript Resource Reload 测试结论、编译阶段重构消除重复、全路由 asyncTcpRoute 迁移、激光束计数修复、以及技能自动化测试指南。*
