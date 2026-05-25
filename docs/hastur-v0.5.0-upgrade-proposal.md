# HasturOperationGD v0.5.0 升级方案

> 状态：已定稿待实施 | 创建：2026-05-25 | 当前版本：v0.4.0 | 目标版本：v0.5.0

---

## 一、动机

经过大激光术技能开发全流程（从方案设计到多轮调试到最终交付），系统梳理了 Hastur 插件在工作流中的所有摩擦点。归纳为四类：

| 缺口类型 | 数量 | 核心问题 | 影响 |
|---------|------|---------|------|
| 错误报告缺口 | 10 | 静默失败太多，无报错或报错误导 | 调试靠猜，反复试验 |
| 工具缺口 | 8 | 需要的能力不存在 | 绕路写 GDSnippet 替代 |
| 可见性缺口 | 7 | 数据存在但 API 没暴露 | 信息盲区 |
| 工作流缺口 | 8 | 流程不顺 | 反复手动操作 |

**设计原则**：
- 所有新增 API 为独立端点，向后兼容 v0.4.0
- 优先解决"无报错"类错误（最难定位）
- 优先解决高频操作（资源扫描、属性查询、脚本编译）

---

## 二、P0 — 核心增强（必须做）

### P0-1: `POST /api/project/rescan`

**目的**：强制编辑器刷新文件系统和脚本类缓存。

**痛点**：修改 `.gd` 或 `.tres` 后编辑器仍使用旧缓存。避坑指南 3.1、3.5、5.1、5.6 均涉及此问题，反复出现。

**API 规范**：
```
POST /api/project/rescan
Authorization: Bearer <token>

Response 200:
{
  "success": true,
  "data": {
    "scanned": true
  }
}
```

**实现方案**：
- Godot 端 `broker_client.gd` 增 `_handle_message` case: `"rescan"`
- 调 `ei.get_resource_filesystem().scan()` 触发异步扫描
- 返回结果

**涉及文件**：
- `broker-server/src/types.ts` — 加 `RescanResult` 接口
- `broker-server/src/tcp-server.ts` — 加 `sendRescanRequest()`
- `broker-server/src/http-server.ts` — 加 `POST /api/project/rescan`
- `game/addons/hasturoperationgd/broker_client.gd` — 加 `_handle_rescan()`


### P0-2: `POST /api/script/check`

**目的**：编译 GDScript 但不执行，返回详细编译错误。

**痛点**：脚本编译失败时返回 zombie（`get_script_method_list() == 0`），报错行号不准确。需人工用 `CACHE_MODE_IGNORE` 检测。

**API 规范**：
```
POST /api/script/check
Authorization: Bearer <token>
Content-Type: application/json

{
  "code": "extends Node2D\nfunc _ready():\n    pass",
  "language": "gdscript"
}

Response 200 (成功):
{
  "success": true,
  "data": {
    "compile_success": true,
    "method_count": 5,
    "errors": []
  }
}

Response 200 (编译失败):
{
  "success": true,
  "data": {
    "compile_success": false,
    "method_count": 0,
    "errors": [
      {
        "line": 3,
        "column": 1,
        "message": "Parse Error: Unexpected token",
        "file": "memory"
      }
    ]
  }
}
```

**实现方案**：
- 复用 `GDScriptExecutor.execute_code()` 的编译阶段逻辑
- 创建 `GDScript` 对象 → `source_code = code` → `reload()`
- 捕获编译错误并返回
- 不执行 `run()`
- Python CLI 增加 `hastur.py check 'code'` 命令

**涉及文件**：
- `broker-server/src/types.ts` — 加 `ScriptCheckResult`
- `broker-server/src/tcp-server.ts` — 加 `sendScriptCheckRequest()`
- `broker-server/src/http-server.ts` — 加 `POST /api/script/check`
- `game/addons/hasturoperationgd/broker_client.gd` — 加 `_handle_script_check()`
- `game/tools/hastur.py` — 加 `cmd_check()`


### P0-3: `GET /api/executors/:id/scene/properties`

**目的**：获取场景树中指定节点的属性值。

**痛点**：检查节点状态（position、scale、visible 等）必须写 GDSnippet 单次执行，频次高、重复劳动。`/api/scene/tree` 只返回节点名称/类型/路径，不返回属性值。

**API 规范**：
```
GET /api/executors/:id/scene/properties?path=/root/SkillDemo/Caster
Authorization: Bearer <token>

Response 200:
{
  "success": true,
  "data": {
    "node_path": "/root/SkillDemo/Caster",
    "node_type": "Node2D",
    "property_count": 12,
    "properties": {
      "position": {"x": 0, "y": 150},
      "rotation": 0.0,
      "scale": {"x": 1.0, "y": 1.0},
      "visible": true,
      "script": "res://scripts/dev/demo_caster.gd"
    }
  }
}
```

**返回哪些属性**：过滤掉 Godot 内部属性（`_meta`、`_import_path` 等），只返回对用户有意义的值。
**安全**：编辑器执行器可用（通过 `EditorInterface`）；游戏执行器返回不可用。

**涉及文件**：
- `broker-server/src/types.ts` — `ScenePropertiesResult`
- `broker-server/src/tcp-server.ts` — `sendGetPropertiesRequest()`
- `broker-server/src/http-server.ts` — `GET /api/executors/:id/scene/properties`
- `game/addons/hasturoperationgd/broker_client.gd` — `_handle_get_properties()`


### P0-4: `POST /api/scene/save`

**目的**：保存编辑器中当前打开的 `.tscn` 到磁盘。

**痛点**：`create_node` 创建的节点不会自动持久化。重新打开场景后丢失。

**API 规范**：
```
POST /api/scene/save
Authorization: Bearer <token>

Response 200:
{
  "success": true,
  "data": {
    "saved": true,
    "path": "res://scenes/dev/skill_demo.tscn"
  }
}
```

**实现**：`ei.save_scene()`（保存当前场景）或根据需要 `ei.save_scene_as()`。

**风险**：覆盖磁盘上的 `.tscn`。如果编辑器中有未保存的手动编辑可能丢失。

**涉及文件**：
- `broker-server/src/types.ts` — `SceneSaveResult`
- `broker-server/src/tcp-server.ts` — `sendSceneSaveRequest()`
- `broker-server/src/http-server.ts` — `POST /api/scene/save`
- `game/addons/hasturoperationgd/broker_client.gd` — `_handle_scene_save()`


### P0-5: `POST /api/script/hot-reload`

**目的**：强制 Godot 重新加载磁盘上指定路径的脚本文件，清除内存缓存。

**痛点**：修改 `.gd` 文件后编辑器继续使用旧版本缓存（避坑指南 3.1、3.4）。改代码后必须 stop→replay，迭代周期长。

**API 规范**：
```
POST /api/script/hot-reload
Authorization: Bearer <token>
Content-Type: application/json

{
  "path": "res://scripts/skill_system/pools/laser_beam_node.gd"
}

Response 200:
{
  "success": true,
  "data": {
    "reloaded": true,
    "path": "res://scripts/skill_system/pools/laser_beam_node.gd",
    "compile_success": true,
    "method_count": 20
  }
}
```

**实现方案**：
1. `ei.get_resource_filesystem().update_file(path)` — 通知编辑器文件系统文件已变更
2. `ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)` — 用忽略缓存模式加载
3. 检查 `get_script_method_list().size() > 0` 确认编译成功
4. 如果编译失败，返回具体错误

**限制**：已实例化节点的运行中脚本实例不会被替换。仅影响下一次 `load()` 调用。

**涉及文件**：
- `broker-server/src/types.ts` — `HotReloadResult`
- `broker-server/src/tcp-server.ts` — `sendHotReloadRequest()`
- `broker-server/src/http-server.ts` — `POST /api/script/hot-reload`
- `game/addons/hasturoperationgd/broker_client.gd` — `_handle_hot_reload()`


---

## 三、P1 — 重要增强

### P1-1: 错误报告可读性增强

**目的**：让编译/运行时错误更易于 AI 和 CLI 消费，减少"error JSON 太大看不懂"的问题。

**实现**：在 `http-server.ts` 的 `POST /api/execute` 响应中增加 `summary` 字段：

```json
{
  "success": true,
  "data": {
    "summary": {
      "compile_ok": false,
      "run_ok": false,
      "error_count": 1,
      "first_error": {
        "line": 3,
        "message": "Parse Error: ..."
      }
    },
    "compile_error": "...",
    "compile_error_details": [...],
    ...
  }
}
```

**工作量**：~15 行（纯 broker-server 端修改）


### P1-2: 游戏运行时日志接入

**目的**：让游戏进程（`EditorInterface.play_custom_scene()`）中的 `print()` 和 `push_error()` 也能通过 Hastur broker 访问。

**需求**：完整行号、堆栈、文件路径。

**现状**：`game_executor.gd` 在游戏进程内初始化 `BrokerClient`，`BrokerClient._init_log_catcher()` 创建 `EditorLogCatcher` 和 `HasturLogger` 并注册到 OS。理论上日志管道已建立。

**验证步骤**：
1. 启动游戏场景
2. 通过 `GET /api/executors/:id/logs` 检查是否能获取游戏进程的 `print()` 输出
3. 如果不可见，排查 OS Logger 是否跨进程工作

**如果跨进程不通**：让 `game_executor.gd` 在 `_process()` 中主动轮询日志缓存并通过 TCP 批量上报。

**工作量**：~50-80 行（验证 + 实现）


---

## 四、文件修改清单

### Broker Server（TypeScript）

| 文件 | 修改 |
|------|------|
| `src/types.ts` | 新增 6 个接口定义 |
| `src/tcp-server.ts` | 新增 5 个 `sendXxxRequest()` 方法 |
| `src/http-server.ts` | 新增 5 条路由 + 错误摘要处理 |

### Godot 插件（GDScript）

| 文件 | 修改 |
|------|------|
| `broker_client.gd` | `_handle_message()` 新增 5 个 case + handler |
| `gdscript_executor.gd` | 可选暴露 compile-only 入口 |

### CLI（Python）

| 文件 | 修改 |
|------|------|
| `game/tools/hastur.py` | 新增 `check`、`rescan`、`hot-reload`、`props`、`save` 命令 |

### 版本号

| 文件 | 修改 |
|------|------|
| `game/addons/hasturoperationgd/plugin.cfg` | `version=0.5.0` |
| `broker-server/package.json` | `"version": "0.5.0"` |

---

## 五、实施顺序建议

1. 先改版本号 + 文档
2. rescan（最简单，验证全流程）
3. scene/save（次简单，独立端点）
4. script/check（需要理解 GDScriptExecutor 编译逻辑）
5. hot-reload（依赖 script/check 的实现）
6. scene/properties（需要理解场景树遍历）
7. 错误报告可读性（纯 broker-server 端）
8. 游戏运行时日志（需验证，可能需要额外调试）

---

## 六、风险与注意

1. **游戏运行时日志**：需要先验证 `play_custom_scene()` 的场景是否独立进程。如果是独立进程，OS Logger 不跨进程通信，需要改用 TCP 推送。
2. **热重载限制**：Godot 4 无官方脚本热重载 API。`update_file()` 只能通知编辑器文件系统刷新，无法替换运行中脚本实例。
3. **场景保存覆盖**：`save_scene()` 无条件覆盖磁盘 .tscn。如果编辑器中有用户手动编辑但未保存的内容，调用此 API 可能导致丢失。
4. **向后兼容**：v0.4.0 的所有 API 不变。新增端点和字段不会破坏现有客户端。
