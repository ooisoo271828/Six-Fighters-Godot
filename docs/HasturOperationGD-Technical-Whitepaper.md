# HasturOperationGD 插件技术蓝皮书

> **版本**: v0.3.1（插件） / v0.1.0（broker-server）
> **最后更新**: 2026-04-26
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
- **默认认证 Token**: `995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7`

### 1.3 目录结构

```
工作区根目录/
├── six-fighter-gd/                          # Godot 项目（插件实际加载位置）
│   ├── addons/hasturoperationgd/            # ⭐ 插件运行位置（v0.3.1）
│   │   ├── broker_client.gd                  # TCP 通信 + 场景树/节点操作
│   │   ├── gdscript_executor.gd             # GDScript 代码编译执行引擎
│   │   ├── execution_context.gd             # 执行上下文（output 方法）
│   │   ├── editor_log_catcher.gd            # 编辑器日志捕获（缓冲+批处理）
│   │   ├── hastur_logger.gd                 # 全局日志捕获器
│   │   ├── runtime_error_capture.gd         # 运行时错误安全包装
│   │   ├── executor_backend.gd              # 执行后端（连接管理）
│   │   ├── executor_dock.gd                 # 编辑器面板 UI（4 标签页）
│   │   ├── executor_dock.tscn               # UI 场景文件
│   │   ├── game_executor.gd                # 游戏运行时代码执行（仅 debug）
│   │   ├── hasturoperationgd.gd            # 插件主入口
│   │   ├── hastur_operation_gd_plugin_settings.gd  # 设置管理（host/port/输出长度）
│   │   └── plugin.cfg                       # 插件清单
│   ├── tools/                               # ⭐ CLI 工具集
│   │   ├── editor_call.py                   # 主推：GDScript 执行器（Python 3.12+）
│   │   ├── editor_call.js                   # 备选：GDScript 执行器（Node.js）
│   │   ├── hastur.py                        # 主推：全功能 CLI（Python 3.12+）
│   │   └── hastur.sh                        # 兼容包装：委托给 hastur.py
│   ├── .claude/CLAUDE.md                    # 项目指南（单一起源）
│   └── scenes/scripts/...                   # 游戏源码
│
├── hastur-operation-plugin-main/           # 插件源码仓库（参考/备份）
│   ├── addons/hasturoperationgd/            # v0.1 源码
│   └── broker-server/                       # broker-server 源码
│       ├── src/
│       │   ├── index.ts                     # 启动入口（CLI args）
│       │   ├── tcp-server.ts                # TCP 消息路由（5301）
│       │   ├── http-server.ts               # HTTP REST API（5302）
│       │   ├── executor-manager.ts          # 执行器状态管理
│       │   ├── auth.ts                      # Bearer Token 认证
│       │   └── types.ts                     # TypeScript 类型定义
│       └── package.json
```

> **⚠️ 关键警告**: Godot 4.x 只会加载 `six-fighter-gd/addons/hasturoperationgd/` 下的插件源码，**绝不会**加载 `hastur-operation-plugin-main/addons/` 下的源码。所有开发修改必须在 `six-fighter-gd/addons/` 目录下进行。

---

## 二、快速启动

### 2.1 前置条件

- Python 3.12+（推荐，主推工具链）
- Node.js >= 18.x（备选，仅运行 broker-server 需要）
- Godot 4.x 编辑器（当前项目使用 4.6.2-stable）
- Git Bash 或类似 Unix 风格终端

### 2.2 最短路径：从零搭建环境

**Step 1: 启动 broker-server**

```bash
cd hastur-operation-plugin-main/broker-server
npm install
npm run dev
```

验证 broker-server 是否运行：

```bash
curl http://localhost:5302/api/health
# 应返回 {"success":true, "data": {"status": "ok", "version": "0.3.0", ...}}
```

**Step 2: 在 Godot 编辑器中启用插件**

1. 用 Godot 打开 `six-fighter-gd/` 项目
2. 进入 **Project → Project Settings → Plugins**
3. 将 **HasturOperationGD** 设为 **Enabled**
4. 在编辑器右侧面板应看到 **Executor** 面板（显示 Connected）

**Step 3: 验证连接**

```bash
# 使用 Python CLI（主推）
python tools/editor_call.py --health
python tools/editor_call.py --executors

# 或使用全功能 CLI
python tools/hastur.py status
```

**Step 4: 执行第一条代码**

```bash
python tools/editor_call.py 'print("Hello from Godot!")'
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
| **接收** | `ping` | 心跳请求 |
| **发送** | `execute_result` | 代码执行结果 |
| **发送** | `scene_tree_result` | 场景树数据 |
| **发送** | `create_node_result` | 节点创建结果 |
| **发送** | `delete_node_result` | 节点删除结果 |
| **发送** | `logs` | 日志流数据 |
| **发送** | `heartbeat` | 主动心跳（每 5 秒） |

**关键设计**:

- 自动重连（指数退避 1s → 30s 上限）
- RTT 追踪（通过 ping/pong 测量）
- EditorInterface 通过 BrokerClient 持有 EditorPlugin 引用间接访问
- 日志系统：HasturLogger（全局）→ EditorLogCatcher（缓冲 + 每 100ms 批量发送）
- 缓冲区最大 200 条，每批发送最大 50 条，Mutex 线程安全

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
  EditorLogCatcher（缓冲 + 批处理，200 条上限）
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
        "run_success": true,
        "run_error": "",
        "outputs": [
            ["scene", "SkillTestScene"]
        ],
        "execution_time_ms": 12
    }
}
```

#### 3.2.3 executor_id 生成机制

executor_id 通过 SHA-256 哈希 `project_name|project_path|editor_pid` 生成，确保同一编辑器实例重连后 ID 不变。每次 broker-server 重启后重新注册。

---

## 四、CLI 工具集

### 4.1 主推：Python 工具链

| 工具 | 用途 | 命令 |
|------|------|------|
| `tools/editor_call.py` | 轻量 GDScript 执行 + 场景树查询 | `python tools/editor_call.py 'print("hi")'` |
| `tools/hastur.py` | 全功能 CLI 管理 | `python tools/hastur.py status` |

**`editor_call.py` 用法**:

```bash
python tools/editor_call.py 'print("hello")'              # 执行单行
python tools/editor_call.py --file script.gd               # 从文件执行
python tools/editor_call.py --executors                    # 列出编辑器
python tools/editor_call.py --health                       # 健康检查
python tools/editor_call.py --scene-tree                   # 场景树
```

**`hastur.py` 用法**:

```bash
python tools/hastur.py status       # 当前状态总览（健康检查+连接状态）
python tools/hastur.py health       # 健康检查
python tools/hastur.py executors    # 已连接编辑器列表
python tools/hastur.py exec '<code>' # 执行 GDScript
python tools/hastur.py scene-tree   # 场景树
python tools/hastur.py logs [N]     # 获取最近 N 条日志
python tools/hastur.py start        # 启动 broker-server
python tools/hastur.py stop         # 停止 broker-server
```

### 4.2 备选方案

| 工具 | 用途 | 命令 |
|------|------|------|
| `tools/editor_call.js` | Node.js 版 GDScript 执行 | `node tools/editor_call.js 'print("hi")'` |
| `tools/hastur.sh` | Shell 版 CLI（委托给 hastur.py） | `bash tools/hastur.sh status` |

### 4.3 GDScript 缩进规则（致命）

**缩进必须使用 Tab 字符**，绝对不能用空格。在 Python 字符串中：

```python
# ✅ 正确：用 \t 表示缩进
code = 'if ei:\n\tctx.output("k", "v")'

# ❌ 错误：用空格缩进 → Mixed use of tabs and spaces
code = 'if ei:\n    ctx.output("k", "v")'

# ❌ 错误：在 shell heredoc 中嵌入 GDScript（PowerShell 自动转 Tab 为空格）
```

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

### 诊断流程

```bash
# 1. broker 是否运行？
python tools/editor_call.py --health

# 2. Godot 是否连接？
python tools/editor_call.py --executors

# 3. 查看最近日志排查错误
python tools/hastur.py logs 20

# 4. 如果编译错误 → 检查 Tab 缩进
# 5. 如果运行时错误 → 检查日志中的详细 stack trace
```

---

## 七、版本对照表

| 组件 | 源码仓库版本 | 生产版本 | 说明 |
|------|------------|---------|------|
| 插件 | v0.1 | **v0.3.1** | `six-fighter-gd/addons/` 下为生产版本 |
| broker-server | v0.1.0 | **v0.1.0** | 运行中 API 返回 version 0.3.0 |
| CLI 工具 | 无 | **Python 3.12+** | `editor_call.py` + `hastur.py` |

### 功能演进：v0.1 → v0.3.1

| 特性 | v0.1 | v0.3.1 | 状态 |
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

---

## 八、安全提醒

> **⚠️ 重要**: 本插件会在编辑器中执行任意代码。Broker Server 通过 Bearer Token 进行访问控制，但仍需注意以下事项：
>
> - **切勿将 broker server 暴露至公网。** 默认绑定 `localhost`，请保持不变。
> - **妥善保管认证 token。** 这是一个 64 位随机十六进制字符串，本质上等同于密码。
> - **确保 AI Agent 来源可信。** 它能执行 GDScript 所能做的一切操作，能力范围相当于"有编辑器完整权限"。
> - **`.claude/CLAUDE.md` 和 `CLAUDE.md` 应视为敏感文件。** 其中包含 Token、API 地址等连接信息。

---

## 九、参考文档

| 文档 | 位置 | 内容 |
|------|------|------|
| 项目指南（单一起源） | `six-fighter-gd/.claude/CLAUDE.md` | 所有操作流程、决策树、快速参考 |
| 插件能力全参考 | AI memory: `plugin_capability_reference.md` | REST API、TCP 消息、执行引擎完整目录 |
| 编辑器操作守则 | AI memory: `godot_operation_rules.md` | 已验证的 16 条规则和陷阱 |
| 标准调用方式 | AI memory: `editor_call_standard.md` | Python 工具链用法 |
| Python 环境 | AI memory: `python_environment.md` | 环境安装和 shell 配置 |

---

*本蓝皮书于 2026-04-26 更新，反映插件 v0.3.1 和 Python 工具链的完整状态。*
