# HasturOperationGD v0.5.0 Upgrade Proposal

> Status: **Implemented** | Created: 2026-05-25 | Implemented: 2026-05-25 | Current: v0.5.0

---

## 1. Motivation

经过大激光术技能开发全流程（从方案设计到多轮调试到最终交付），系统梳理了 Hastur 插件在工作流中的所有摩擦点。归纳为四类：

| 缺口类型 | 数量 | 核心问题 | 影响 |
|---------|------|---------|------|
| 错误报告缺口 | 10 | 静默失败太多，无报错或报错误导 | 调试靠猜，反复试验 |
| 工具缺口 | 8 | 需要的能力不存在 | 绕路写 GDSnippet 替代 |
| 可见性缺口 | 7 | 数据存在但 API 没暴露 | 信息盲区 |
| 工作流缺口 | 8 | 流程不顺 | 反复手动操作 |

### 关于 Hot-Reload 的决策

原方案包含 `POST /api/script/hot-reload` 端点。经评估后**决定删除**，原因：

Godot 4 没有官方脚本热重载 API。`ResourceLoader.load(path, "GDScript", CACHE_MODE_IGNORE)` 只返回一个新的 Resource 对象，**已经实例化的脚本对象不会被替换**。场景树中已 `add_child` 的节点仍使用旧版本脚本。这意味着所谓的"热重载"只能刷新编辑器缓存，不能替代 stop → replay 的工作流。不做半截子工程。

### 注册式路由升级

当前 broker-server 的 `tcp-server.ts` 存在严重的代码重复：4 个 `send*` 方法（~150 行）结构完全相同，4 个 `handle*Result` 方法（~48 行）逻辑完全相同。`http-server.ts` 的 executor 查找模式重复 14 次，超时错误处理重复 8 次。新增端点意味着复制粘贴更多重复代码。

v0.5.0 将 broker-server 和 Godot 插件同时升级为注册式路由，作为新端点的结构性前置。

---

## 2. Design Principles

1. **一次性交付** — 不分 alpha/beta，所有变更在同一个版本中发布
2. **路由重构优先** — 先消除重复代码，再添加新端点
3. **向后兼容** — v0.4.0 的所有 API 不变，新增端点和字段不破坏现有客户端
4. **force 参数** — `scene/save` 默认 `force=false`，需显式 `force=true` 覆盖
5. **无 hot-reload** — 不做 Godot 4 无法真正实现的功能

---

## 3. Phase 1 — Registration-Based Routing Refactor

所有新端点依赖泛型路由基础设施。此阶段不新增功能，只消除重复代码。

### 3.1 tcp-server.ts: Generic `sendRequest` / `handleResult`

**问题**：4 个 `send*` 方法（`sendExecute`, `sendSceneTreeRequest`, `sendCreateNodeRequest`, `sendDeleteNodeRequest`）结构完全相同 — 唯一差异是 `type` 字符串和 `data` 负载形状。4 个 `handle*Result` 方法逻辑完全相同 — 提取 `request_id`，查找 pending request，清除 timer，resolve promise。

**方案**：

```typescript
// 替代 4 个 send* 方法（~150 行 → ~25 行）
async sendRequest<T = Record<string, unknown>>(
    executorId: string,
    type: string,
    data: Record<string, unknown>,
    timeoutMs: number = 10000
): Promise<T> {
    for (const [, ctx] of this.connections) {
        if (ctx.executorId === executorId) {
            const requestId = crypto.randomUUID()
            const message = JSON.stringify({
                type,
                data: { request_id: requestId, ...data },
            }) + '\n'

            return new Promise<T>((resolve, reject) => {
                const timer = setTimeout(() => {
                    ctx.pendingRequests.delete(requestId)
                    reject(new Error('TIMEOUT'))
                }, timeoutMs)
                ctx.pendingRequests.set(requestId, { resolve, reject, timer })
                ctx.socket.write(message)
            })
        }
    }
    return Promise.reject(new Error('Executor not connected'))
}
```

```typescript
// 替代 4 个 handle*Result 方法（~48 行 → ~10 行）
private handleResult(socketId: string, data: Record<string, unknown>): void {
    const ctx = this.connections.get(socketId)
    if (!ctx) return
    const requestId = data.request_id as string
    const pending = ctx.pendingRequests.get(requestId)
    if (pending) {
        clearTimeout(pending.timer)
        ctx.pendingRequests.delete(requestId)
        pending.resolve(data)
    }
}
```

**`handleMessage` 重构**：用 `RESULT_TYPES` Set + 泛型 `handleResult` 替代 switch/case 中的 4 个 result case：

```typescript
const RESULT_TYPES = new Set([
    'execute_result', 'scene_tree_result', 'create_node_result',
    'delete_node_result', 'rescan_result', 'script_check_result',
    'scene_properties_result', 'scene_save_result'
])

if (RESULT_TYPES.has(message.type)) {
    this.handleResult(socketId, message.data as Record<string, unknown>)
    return
}

// 仅剩 4 个特殊 case（非 request/response 模式）
switch (message.type) {
    case 'register':   this.handleRegister(...); break
    case 'pong':       /* inline RTT calc */;    break
    case 'heartbeat':  /* inline ack reply */;   break
    case 'logs':       this.handleLogs(...);     break
}
```

**调用方变为一行**：

```typescript
// Before: sendSceneTreeRequest(executorId, timeout) — 30 行方法
// After:
this.sendRequest(executorId, 'get_scene_tree', {}, timeout)
```

### 3.2 http-server.ts: `resolveExecutor` + `asyncTcpRoute` Helpers

**问题**：executor 查找模式（7 行）重复 14 次，try/catch 超时处理（~15 行）重复 8 次。

**方案**：

```typescript
// 替代 14 处 executor 查找（98 行 → 14×1 + 10 = 24 行）
function resolveExecutor(req, res, executorManager): ExecutorInfo | null {
    const executor = executorManager.findById(req.params.id)
    if (!executor) {
        res.status(404).json({ success: false, error: 'Executor not found', hint: '...' })
        return null
    }
    return executor
}

// 替代 8 处 try/catch 超时处理（120 行 → 8×1 + 20 = 28 行）
function asyncTcpRoute(handler: () => Promise<any>, res: Response, errorMsg: string): void {
    handler()
        .then(result => res.json({ success: true, data: result }))
        .catch(err => {
            const status = err.message === 'TIMEOUT' ? 504 : 500
            res.status(status).json({ success: false, error: err.message || errorMsg })
        })
}
```

**路由变为一行**：

```typescript
// Before: 35 行
// After:
app.get('/api/executors/:id/scene/tree', (req, res) => {
    const executor = resolveExecutor(req, res, executorManager)
    if (!executor) return
    asyncTcpRoute(() => tcpServer.sendRequest(executor.id, 'get_scene_tree', {}, 10000), res, 'Failed to get scene tree')
})
```

### 3.3 broker_client.gd: `_message_handlers` Dictionary

**问题**：`_handle_message()` 的 match 块有 13 个 case，每新增消息类型需修改 match 块。

**方案**：

```gdscript
var _message_handlers: Dictionary = {}

func _init_handlers() -> void:
    _message_handlers = {
        "register_result": _handle_register_result,
        "execute": _handle_execute,
        "ping": func(_data): _send_message({"type": "pong"}),
        "heartbeat_ack": _handle_heartbeat_ack,
        "pong": _handle_pong,
        "get_scene_tree": _handle_get_scene_tree_request,
        "create_node": _handle_create_node_request,
        "delete_node": _handle_delete_node_request,
        # v0.5.0 新增:
        "rescan": _handle_rescan_request,
        "script_check": _handle_script_check_request,
        "get_properties": _handle_get_properties_request,
        "scene_save": _handle_scene_save_request,
    }

func _handle_message(raw: String) -> void:
    # ... parse JSON ...
    var type = msg.get("type", "")
    var data = msg.get("data", {})
    if _message_handlers.has(type):
        _message_handlers[type].call(data)
    else:
        push_warning("BrokerClient: unknown message type '%s'" % type)
```

新增消息类型 = 新增一行字典条目，零修改已有代码。

### 3.4 Duplication Metrics

| File | Before | After | Delta |
|------|--------|-------|-------|
| `tcp-server.ts` | ~691 行 | ~568 行 | **-123 行** |
| `http-server.ts` | ~760 行 | ~624 行 | **-136 行** |
| `broker_client.gd` | ~778 行 | ~867 行 | +89 行（4 个新 handler） |
| **合计** | ~2229 行 | ~2059 行 | **-170 行重复代码** |

新增端点代码 +220 行。净效果：代码总量基本不变，但重复代码消除、可维护性大幅提升。

---

## 4. Phase 2 — New Endpoints

### 4.1 `POST /api/project/rescan`

**目的**：强制编辑器刷新文件系统和脚本类缓存。

**痛点**：修改 `.gd` 或 `.tres` 后编辑器仍使用旧缓存。避坑指南 3.1、3.5、5.1、5.6 均涉及此问题。

**API**：

```bash
POST /api/project/rescan
Authorization: Bearer <token>

# Response 200:
{"success": true, "data": {"scanned": true}}
```

**Godot 端实现**：

```gdscript
func _handle_rescan_request(data: Dictionary) -> void:
    var request_id = str(data.get("request_id", ""))
    var ei = _get_editor_interface()
    if ei == null:
        _send_result("rescan_result", request_id, {"success": false, "error": "No editor plugin"})
        return
    ei.get_resource_filesystem().scan()
    _send_result("rescan_result", request_id, {"success": true, "scanned": true})
```

**注意**：`scan()` 是异步操作，响应表示扫描已触发而非已完成。对使用场景（执行代码前强制 rescan）足够，因为 Godot 内部队列会在下次脚本执行前处理完扫描。

**涉及文件**：`tcp-server.ts`（无新增方法，用 `sendRequest`）、`http-server.ts`（1 条路由）、`broker_client.gd`（1 个 handler）、`types.ts`（`RescanResult`）

---

### 4.2 `POST /api/script/check`

**目的**：编译 GDScript 但不执行，返回详细编译错误。

**痛点**：脚本编译失败时返回 zombie（`get_script_method_list() == 0`），报错行号不准确。需人工用 `CACHE_MODE_IGNORE` 检测。

**API**：

```bash
POST /api/script/check
Authorization: Bearer <token>
Content-Type: application/json

{"code": "extends Node2D\nfunc _ready():\n    pass"}

# Response 200 (成功):
{"success": true, "data": {"compile_success": true, "method_count": 5, "errors": []}}

# Response 200 (编译失败):
{"success": true, "data": {"compile_success": false, "method_count": 0, "errors": [
    {"line": 3, "column": 1, "message": "Parse Error: Unexpected token", "file": "memory"}
]}}
```

**Godot 端实现**：从 `gdscript_executor.gd` 的 `execute_code()` 提取 Phase A（源码准备）+ Phase B（编译）为独立的 `compile_only()` 方法：

```gdscript
func compile_only(code: String) -> Dictionary:
    var result = {"compile_success": false, "compile_error": "", "method_count": 0, "errors": []}
    if code.strip_edges() == "":
        result.compile_error = "Code is empty"
        return result

    var source := _ensure_tool_annotation(code) if _is_full_class(code) else _wrap_snippet(code)
    var script := GDScript.new()
    script.source_code = source
    _error_capturer.start_capture(script.resource_path)
    var err := script.reload()
    var captured := _error_capturer.stop_capture()

    if err != OK:
        result.compile_error = "\n".join(captured) if captured.size() > 0 else _error_code_to_string(err)
        for msg in captured:
            result.errors.append(_parse_compile_error(msg))
        return result

    result.compile_success = true
    result.method_count = script.get_script_method_list().size()
    return result
```

现有 `execute_code()` 内部调用 `compile_only()` 获取编译结果，编译失败则直接返回，成功则继续执行阶段。

**涉及文件**：`gdscript_executor.gd`（提取 `compile_only`）、`broker_client.gd`（1 个 handler）、`http-server.ts`（1 条路由）、`types.ts`（`ScriptCheckResult`）

---

### 4.3 `GET /api/executors/:id/scene/properties`

**目的**：获取场景树中指定节点的属性值。

**痛点**：检查节点状态（position、scale、visible 等）必须写 GDSnippet 单次执行，频次高、重复劳动。

**API**：

```bash
GET /api/executors/:id/scene/properties?path=/root/SkillDemo/Caster&filter=position,visible
Authorization: Bearer <token>

# Response 200:
{
    "success": true,
    "data": {
        "node_path": "/root/SkillDemo/Caster",
        "node_type": "Node2D",
        "property_count": 2,
        "properties": {
            "position": {"x": 0, "y": 150},
            "visible": true
        }
    }
}
```

**过滤策略**：黑名单 + 可选白名单

- **黑名单**（始终排除）：`_meta`、`_import_path`、`script`、`owner`、所有 `_` 前缀属性
- **可选白名单**：`filter` 查询参数（逗号分隔），指定时只返回列出的属性
- **类型限制**：只返回带 `PROPERTY_USAGE_STORAGE` 或 `PROPERTY_USAGE_EDITOR` 标志的属性

**序列化**：`_serialize_value()` 将 Godot 类型转为 JSON 兼容格式。不可序列化类型（`Callable`、`RID`、`Object` 引用）降级为 `"[<type>: <info>]"` 字符串。

**涉及文件**：`broker_client.gd`（1 个 handler + `_get_node_properties` + `_serialize_value` 辅助方法）、`http-server.ts`（1 条路由）、`types.ts`（`ScenePropertiesResult`）

---

### 4.4 `POST /api/scene/save`

**目的**：保存编辑器中当前打开的 `.tscn` 到磁盘。

**痛点**：`create_node` 创建的节点不会自动持久化，重新打开场景后丢失。

**API**：

```bash
POST /api/scene/save
Authorization: Bearer <token>
Content-Type: application/json

{"force": false}

# Response 200:
{"success": true, "data": {"saved": true, "path": "res://scenes/dev/skill_demo.tscn"}}
```

**force 参数说明**：

Godot 4 的 EditorInterface 不暴露 `has_unsaved_changes()` API，无法在服务端检测编辑器是否有未保存修改。`force` 参数作为调用方承诺机制：

- `force=false`（默认）：调用方确认无冲突
- `force=true`：调用方接受覆盖风险

如果 Godot 未来版本增加此 API，可在不改变 API 契约的前提下增加服务端检查。

**涉及文件**：`broker_client.gd`（1 个 handler）、`http-server.ts`（1 条路由）、`types.ts`（`SceneSaveResult`）

---

### 4.5 `POST /api/execute` Response Enhancement

**目的**：在执行结果中增加 `summary` 字段，让 AI 和 CLI 快速判断成功/失败。

**实现**：纯 broker-server 端修改，无需新 TCP 消息类型。在 `http-server.ts` 的 `/api/execute` 路由中，收到 `execute_result` 后构造 summary：

```typescript
const summary = {
    compile_ok: result.compile_success,
    run_ok: result.run_success,
    error_count: (result.compile_error ? 1 : 0) + (result.run_error ? 1 : 0),
    first_error: result.compile_error
        ? { message: result.compile_error, line: extractLine(result.compile_error) }
        : result.run_error
        ? { message: result.run_error, line: extractLine(result.run_error) }
        : null,
    output_count: result.outputs?.length || 0,
}
```

**新增 `extractLine` 辅助函数**：从 Godot 错误字符串中提取行号（匹配 `at line N` 或 `(N:M)` 模式）。

**涉及文件**：`http-server.ts`（修改 execute 路由 + extractLine 函数）

---

## 5. Phase 3 — CLI Commands

`game/tools/hastur.py` 新增 4 个命令：

```bash
# 编译检查
python tools/hastur.py check 'print("hello")'
# → {"compile_success": true, "method_count": N, "errors": []}

# 文件系统刷新
python tools/hastur.py rescan
# → {"scanned": true}

# 场景保存
python tools/hastur.py save              # force=false
python tools/hastur.py save --force      # force=true

# 节点属性
python tools/hastur.py props /root/Main/Caster
python tools/hastur.py props /root/Main/Caster --filter position,visible
```

`game/tools/editor_call.py` 标记为 deprecated，不再新增功能。

---

## 6. File Modification Matrix

### Broker Server (TypeScript)

| File | Modification |
|------|-------------|
| `src/types.ts` | 新增接口：`RescanResult`, `ScriptCheckResult`, `ScenePropertiesResult`, `SceneSaveResult`, `ExecuteSummary` |
| `src/tcp-server.ts` | 重构：`sendRequest()` + `handleResult()` + `RESULT_TYPES` Set；删除 4 个旧 `send*` 和 4 个旧 `handle*Result` |
| `src/http-server.ts` | 重构：`resolveExecutor()` + `asyncTcpRoute()` 辅助函数；新增 4 条路由；execute 路由增加 summary |

### Godot Plugin (GDScript)

| File | Modification |
|------|-------------|
| `broker_client.gd` | 重构：`_message_handlers` 字典替代 match 块；新增 4 个 handler |
| `gdscript_executor.gd` | 新增 `compile_only()` 方法；`execute_code()` 内部调用 `compile_only()` |

### CLI (Python)

| File | Modification |
|------|-------------|
| `game/tools/hastur.py` | 新增 `check`、`rescan`、`save`、`props` 命令 |

### Version

| File | Change |
|------|--------|
| `game/addons/hasturoperationgd/plugin.cfg` | `version="0.5.0"` |
| `broker-server/package.json` | `"version": "0.5.0"` |
| `broker_client.gd` | `_plugin_version = "0.5.0"` |
| `http-server.ts` | `version: '0.5.0'` |

---

## 7. Implementation Order

| Step | Files | Description | Est. |
|------|-------|-------------|------|
| 1 | `types.ts` | 新增所有接口定义 | 15 min |
| 2 | `tcp-server.ts` | 添加 `sendRequest` + `handleResult`；转换现有 4 个 send 方法调用 `sendRequest`；删除旧方法 | 45 min |
| 3 | `http-server.ts` | 添加 `resolveExecutor` + `asyncTcpRoute`；转换现有路由；验证无回归 | 60 min |
| 4 | All TS | `tsc --noEmit` 编译检查 | 10 min |
| 5 | `gdscript_executor.gd` | 提取 `compile_only()` 方法；`execute_code()` 内部调用 | 30 min |
| 6 | `broker_client.gd` | 添加 `_message_handlers` 字典 + `_init_handlers()`；添加 4 个新 handler | 60 min |
| 7 | `http-server.ts` | 添加 4 条新路由 + execute summary 增强 | 45 min |
| 8 | `hastur.py` | 添加 4 个 CLI 命令 | 30 min |
| 9 | Integration | 端到端验证所有端点（与 Godot 编辑器联调） | 60 min |
| 10 | Version | `plugin.cfg` + `package.json` 版本号 → 0.5.0 | 5 min |
| 11 | Docs | 更新技术蓝皮书 v0.5.0 变更记录 | 60 min |

**Total: ~6.5 hours**

---

## 8. Testing & Verification Strategy

### Layer 1: Unit-level（无需 Godot）

- `sendRequest` 生成唯一 request_id
- `sendRequest` 无匹配 executor 时 reject
- `sendRequest` 超时后 reject with "TIMEOUT"
- `handleResult` 正确 resolve 匹配的 pending request
- `handleResult` 对未知 request_id 静默忽略
- `tsc --noEmit` 编译通过

### Layer 2: Integration（broker-server + Godot 编辑器）

| Endpoint | Test | Success Criteria |
|----------|------|-----------------|
| `POST /api/project/rescan` | 外部创建新 `.gd` 文件后调用 | `scanned: true`，Godot FileSystem 面板显示新文件 |
| `POST /api/script/check` (valid) | 发送 `print("hello")` | `compile_success: true`, `method_count > 0` |
| `POST /api/script/check` (invalid) | 发送语法错误代码 | `compile_success: false`, `errors` 有 line + message |
| `GET .../scene/properties` | 查询已知节点 | 返回 position, scale 等属性 |
| `GET .../properties?filter=position` | 带过滤查询 | properties 只含 position |
| `POST /api/scene/save` (force=false) | 无修改时保存 | `saved: true, path` 正确 |
| `POST /api/scene/save` (force=true) | 有修改时保存 | `saved: true`，磁盘文件更新 |
| `POST /api/execute` summary | 执行任意代码 | 响应含 `summary` 字段 |

### Layer 3: CLI

```bash
python tools/hastur.py check 'print("hello")'    # compile_success: true
python tools/hastur.py check 'var x = '           # compile_success: false
python tools/hastur.py rescan                      # scanned: true
python tools/hastur.py save                        # saved: true
python tools/hastur.py save --force                # saved: true
python tools/hastur.py props /root/Main            # properties dict
```

### Layer 4: Regression

验证 v0.4.0 功能不受影响：

```bash
python tools/hastur.py exec 'print("hello")'
python tools/hastur.py scene-tree
python tools/hastur.py logs 10
curl http://localhost:5302/api/health
```

---

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| `scan()` 异步，rescan 响应先于扫描完成 | 低 — 下次 execute 前扫描已完成 | 文档说明；如需同步可后续加 `scan_status` 端点 |
| Godot 4 无 `has_unsaved_changes()` API | 中 — force 参数无法服务端强制 | 作为调用方承诺机制；文档明确风险 |
| 属性序列化复杂类型（Callable, RID） | 低 — 少数属性不可序列化 | `_serialize_value` 降级为字符串表示 |
| `_message_handlers` 字典的 Callable 生命周期 | 中 — Lambda 可能被 GC | 用方法引用而非 lambda；`_init_handlers()` 在 `_init()` 中调用一次 |
| 注册式路由破坏 Godot 端 outbound 回调 | 低 — 回调通过 result type 路由 | 字典天然支持双向路由 |

---

## 10. Version Bump Checklist

- [ ] `game/addons/hasturoperationgd/plugin.cfg` → `version="0.5.0"`
- [ ] `broker/hastur-operation-plugin-main/broker-server/package.json` → `"version": "0.5.0"`
- [ ] `broker_client.gd` → `_plugin_version = "0.5.0"`
- [ ] `http-server.ts` → health endpoint `version: '0.5.0'`
- [ ] `docs/HasturOperationGD-Technical-Whitepaper.md` → 更新版本对照表和功能演进
- [ ] `docs/hastur-v0.5.0-upgrade-proposal.md` → 标记为 "Implemented"

---

*本方案于 2026-05-25 定稿，基于 v0.4.0 生产版本和大激光术开发全流程的实践反馈。*
