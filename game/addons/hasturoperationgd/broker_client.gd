class_name BrokerClient
extends RefCounted


signal connection_established(id: String)
signal connection_lost()
signal remote_execution_completed(code: String, result: Dictionary, duration_ms: int)
signal rtt_updated(rtt_ms: float)

var _tcp: StreamPeerTCP
var _host: String
var _port: int
var _connected: bool = false
var _executor_id: String = ""
var _reconnect_delay: float = 1.0
var _max_reconnect_delay: float = 30.0
var _reconnect_timer: float = 0.0
var _buffer: String = ""
var _executor: GDScriptExecutor
var _project_name: String
var _project_path: String
var _editor_pid: int
var _plugin_version: String
var _editor_version: String
var _executor_type: String = "editor"

# 日志捕获器
var _log_catcher: EditorLogCatcher
var _hastur_logger: HasturLogger
var _logger_registered: bool = false  # 防止重复注册 OS logger
var _log_flush_timer: float = 0.0
const LOG_FLUSH_INTERVAL := 0.5  # 每 0.5 秒尝试发送日志

# RTT 追踪
var _rtt_ms: float = 0.0
var _ping_sent_time: int = 0
var _last_pong_time: int = 0
var _heartbeat_timer: float = 0.0
const HEARTBEAT_INTERVAL := 5.0  # 每 5 秒发送一次心跳

var _editor_plugin_ref = null

# 注册式路由 — 替代 match 块
var _message_handlers: Dictionary = {}


func _init(host: String, port: int, executor_type: String = "editor", editor_plugin = null) -> void:
	_host = host
	_port = port
	_executor_type = executor_type
	_editor_plugin_ref = editor_plugin
	_tcp = StreamPeerTCP.new()
	_executor = GDScriptExecutor.new()
	_project_name = ProjectSettings.get_setting("application/config/name", "Unnamed")
	_project_path = ProjectSettings.globalize_path("res://")
	_editor_pid = OS.get_process_id()
	_plugin_version = "0.6.0"
	var version_info = Engine.get_version_info()
	_editor_version = str(version_info.get("major", 0)) + "." + str(version_info.get("minor", 0)) + "." + str(version_info.get("patch", 0))

	# 初始化注册式路由
	_init_handlers()

	# 初始化日志捕获器
	_init_log_catcher()

	_try_connect()


func _init_handlers() -> void:
	_message_handlers = {
		"register_result": _handle_register_result,
		"execute": _handle_execute,
		"get_scene_tree": _handle_get_scene_tree,
		"create_node": _handle_create_node,
		"delete_node": _handle_delete_node,
		"ping": _handle_ping,
		"pong": _handle_pong_msg,
		"heartbeat_ack": _handle_heartbeat_ack,
		# v0.5.0 新增
		"rescan": _handle_rescan,
		"script_check": _handle_script_check,
		"get_properties": _handle_get_properties,
		"scene_save": _handle_scene_save,
		# v0.6.0 新增
		"get_scene_inspect": _handle_scene_inspect,
		"get_signal_connections": _handle_get_signal_connections,
		"get_compile_errors": _handle_get_compile_errors,
		"get_console_stream": _handle_get_console_stream,
		"script_reload": _handle_script_reload,
	}


func _init_log_catcher() -> void:
	_log_catcher = EditorLogCatcher.new()
	_log_catcher.set_on_log_ready(_on_logs_ready)

	# 创建并注册全局日志捕获器（防重复注册）
	_hastur_logger = HasturLogger.new()
	_hastur_logger.set_log_catcher(_log_catcher)
	if not _logger_registered:
		OS.add_logger(_hastur_logger)
		_logger_registered = true
		print("[BrokerClient] Global HasturLogger registered")


# reconnect 后恢复日志捕获器
func _reinit_log_catcher() -> void:
	if _log_catcher != null:
		_log_catcher.set_on_log_ready(_on_logs_ready)
	if _hastur_logger != null and not _logger_registered:
		OS.add_logger(_hastur_logger)
		_logger_registered = true
		print("[BrokerClient] HasturLogger re-registered after reconnect")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 先 shutdown 日志捕获器（停止 Timer、清空缓冲）
		if _log_catcher != null:
			_log_catcher.shutdown()
			_log_catcher = null
		# 清理 HasturLogger（从 OS logger 列表移除）
		if _hastur_logger != null:
			if _logger_registered:
				OS.remove_logger(_hastur_logger)
				_logger_registered = false
			_hastur_logger = null
		# 清理 GDScriptExecutor（移除其 _CompileErrorCapturer OS logger）
		if _executor != null:
			_executor.dispose()
			_executor = null
		if _tcp != null:
			_tcp.disconnect_from_host()
		_connected = false
		_executor_id = ""
		_buffer = ""


func disconnect_client() -> void:
	if _log_catcher != null:
		_log_catcher.shutdown()
		_log_catcher = null
	if _hastur_logger != null:
		if _logger_registered:
			OS.remove_logger(_hastur_logger)
			_logger_registered = false
		_hastur_logger = null
	if _executor != null:
		_executor.dispose()
		_executor = null
	if _tcp:
		_tcp.disconnect_from_host()
	_connected = false
	_executor_id = ""
	_buffer = ""


func poll(delta: float) -> void:
	_tcp.poll()
	var status = _tcp.get_status()

	match status:
		StreamPeerTCP.STATUS_NONE:
			if _connected:
				_handle_disconnect()
			_reconnect_timer += delta
			if _reconnect_timer >= _reconnect_delay:
				_reconnect_timer = 0.0
				_try_connect()
		StreamPeerTCP.STATUS_CONNECTING:
			pass
		StreamPeerTCP.STATUS_CONNECTED:
			if not _connected:
				_connected = true
				_reconnect_delay = 1.0
				_reconnect_timer = 0.0
				_send_register()
			_read_data()
		StreamPeerTCP.STATUS_ERROR:
			if _connected:
				_handle_disconnect()
			_reconnect_timer += delta
			if _reconnect_timer >= _reconnect_delay:
				_reconnect_timer = 0.0
				_reconnect_delay = min(_reconnect_delay * 2.0, _max_reconnect_delay)
				_try_connect()

	# 日志刷新（无论是否连接都持续，_on_logs_ready 内部会检查 _connected 并丢弃）
	if _log_catcher != null:
		_log_flush_timer += delta
		if _log_flush_timer >= LOG_FLUSH_INTERVAL:
			_log_flush_timer = 0.0
			_log_catcher.flush()

	# 主动心跳（使 broker 端 RTT 追踪生效）
	if _connected:
		_heartbeat_timer += delta
		if _heartbeat_timer >= HEARTBEAT_INTERVAL:
			_heartbeat_timer = 0.0
			send_heartbeat()


func get_rtt_ms() -> float:
	return _rtt_ms


func get_executor_id() -> String:
	return _executor_id


func is_broker_connected() -> bool:
	return _connected


func _try_connect() -> void:
	var status = _tcp.get_status()
	if status != StreamPeerTCP.STATUS_NONE and status != StreamPeerTCP.STATUS_ERROR:
		push_warning("BrokerClient: _try_connect called in unexpected status %d, skipping connect_to_host" % status)
		return
	if status != StreamPeerTCP.STATUS_NONE:
		_tcp.disconnect_from_host()
	_tcp.connect_to_host(_host, _port)


func _handle_disconnect() -> void:
	push_warning("BrokerClient: connection lost to %s:%d (executor_id=%s)" % [_host, _port, _executor_id])
	_connected = false
	_executor_id = ""
	_buffer = ""
	_reconnect_delay = 1.0
	connection_lost.emit()


func _send_register() -> void:
	var msg = {
		"type": "register",
		"data": {
			"project_name": _project_name,
			"project_path": _project_path,
			"editor_pid": _editor_pid,
			"plugin_version": _plugin_version,
			"editor_version": _editor_version,
			"supported_languages": ["gdscript"],
			"type": _executor_type
		}
	}
	_send_message(msg)


func _read_data() -> void:
	while _tcp.get_available_bytes() > 0:
		var result = _tcp.get_partial_data(_tcp.get_available_bytes())
		if result[0] == OK:
			var data: PackedByteArray = result[1]
			_buffer += data.get_string_from_utf8()

	if "\n" not in _buffer:
		return

	var parts = _buffer.split("\n")
	_buffer = parts[-1]
	for i in range(parts.size() - 1):
		var line = parts[i].strip_edges()
		if line != "":
			_handle_message(line)


func _handle_message(raw: String) -> void:
	var json = JSON.new()
	var err = json.parse(raw)
	if err != OK:
		return

	var msg = json.data
	if not msg is Dictionary:
		return

	var type = msg.get("type", "")
	var data = msg.get("data", {})

	if _message_handlers.has(type):
		_message_handlers[type].call(data)
	else:
		push_warning("BrokerClient: unknown message type '%s'" % type)


func _handle_register_result(data: Dictionary) -> void:
	if data.get("success", false):
		_executor_id = str(data.get("id", ""))
		_reinit_log_catcher()  # reconnect 后恢复日志捕获器
		connection_established.emit(_executor_id)
	else:
		push_warning("BrokerClient: registration rejected by broker: %s" % str(data))
		_tcp.disconnect_from_host()
		_connected = false


func _handle_execute(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var code = str(data.get("code", ""))
	var execution_mode = str(data.get("execution_mode", "snippet"))
	var context_path = str(data.get("context_path", ""))
	var start_time = Time.get_ticks_msec()
	var result
	if execution_mode == "in_scene":
		result = _executor.execute_in_scene(code, context_path, {}, _editor_plugin_ref)
	else:
		result = _executor.execute_code(code, {}, _editor_plugin_ref)
	var end_time = Time.get_ticks_msec()
	var duration_ms = end_time - start_time

	# 错误同步写入 broker + 通过日志缓冲统一上报（双通道确保不丢失）
	if not result.get("compile_success", false) and result.get("compile_error", "") != "":
		if _log_catcher != null:
			_log_catcher.capture_compile_error(result["compile_error"])
	elif not result.get("run_success", false) and result.get("run_error", "") != "":
		if _log_catcher != null:
			_log_catcher.capture_runtime_error(result["run_error"])

	var msg = {
		"type": "execute_result",
		"data": {
			"request_id": request_id,
			"compile_success": result.get("compile_success", false),
			"compile_error": result.get("compile_error", ""),
			"compile_error_details": result.get("compile_error_details", []),
			"run_success": result.get("run_success", false),
			"run_error": result.get("run_error", ""),
			"run_error_details": result.get("run_error_details", []),
			"outputs": result.get("outputs", [])
		}
	}
	_send_message(msg)
	remote_execution_completed.emit(code, result, duration_ms)


func _handle_get_scene_tree(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	print("[BrokerClient] handle_get_scene_tree called, request_id: ", request_id)

	# 获取当前编辑的场景根节点
	var scene_root = null
	var editor_interface = _get_editor_interface()
	print("[BrokerClient] EditorInterface: ", editor_interface)

	if editor_interface != null:
		scene_root = editor_interface.get_edited_scene_root()
		print("[BrokerClient] Scene root: ", scene_root)

	var result = {
		"success": false,
		"tree": null,
		"error": ""
	}

	if scene_root == null:
		result["error"] = "No scene open or EditorInterface not available"
	else:
		result["success"] = true
		result["tree"] = _node_to_dict(scene_root)

	print("[BrokerClient] Sending scene_tree_result, success: ", result["success"])

	var msg = {
		"type": "scene_tree_result",
		"data": {
			"request_id": request_id,
			"tree": result.get("tree"),
			"success": result.get("success"),
			"error": result.get("error", "")
		}
	}
	_send_message(msg)


func _get_editor_interface():
	# EditorInterface 是 EditorPlugin 的方法
	# 我们需要通过 _editor_plugin_ref 来访问
	if _editor_plugin_ref == null:
		push_warning("[BrokerClient] _editor_plugin_ref is null")
		return null

	if not (_editor_plugin_ref is EditorPlugin):
		push_warning("[BrokerClient] _editor_plugin_ref is not EditorPlugin, type: %s" % typeof(_editor_plugin_ref))
		return null

	return _editor_plugin_ref.get_editor_interface()


func _node_to_dict(node: Node) -> Dictionary:
	var dict = {
		"name": node.name,
		"type": node.get_class(),
		"path": node.get_path(),
	}

	# 添加可用脚本信息（如果有）
	if node.get_script() != null:
		dict["script"] = node.get_script().get_path()

	# 添加子节点
	var children = []
	for child in node.get_children():
		children.append(_node_to_dict(child))
	dict["children"] = children

	return dict


func _handle_create_node(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var parent_path = str(data.get("parent_path", ""))
	var node_name = str(data.get("name", ""))
	var node_type = str(data.get("type", "Node"))
	var script_path = str(data.get("script", ""))

	var result = {
		"success": false,
		"node_path": "",
		"error": ""
	}

	var editor_interface = _get_editor_interface()
	if editor_interface == null:
		result["error"] = "EditorInterface not available"
	else:
		var parent = editor_interface.get_edited_scene_root()
		if parent == null:
			result["error"] = "No scene open"
		else:
			# 如果指定了父节点路径，尝试获取该节点
			if parent_path != "":
				var potential_parent = editor_interface.get_editor_main_screen().get_tree().get_root().get_node_or_null(parent_path)
				if potential_parent != null:
					parent = potential_parent

			# 创建新节点
			var new_node: Node
			if script_path != "":
				# 尝试加载脚本
				var script = load(script_path)
				if script != null:
					new_node = Node.new()
					new_node.set_script(script)
				else:
					result["error"] = "Failed to load script: " + script_path
					_send_create_node_result(request_id, result)
					return
			else:
				# 使用 ClassDB 创建节点
				if ClassDB.can_instantiate(node_type):
					new_node = ClassDB.instantiate(node_type)
				else:
					result["error"] = "Cannot instantiate type: " + node_type
					_send_create_node_result(request_id, result)
					return

			new_node.name = node_name
			parent.add_child(new_node)

			result["success"] = true
			result["node_path"] = new_node.get_path()

	_send_create_node_result(request_id, result)


func _send_create_node_result(request_id: String, result: Dictionary) -> void:
	var msg = {
		"type": "create_node_result",
		"data": {
			"request_id": request_id,
			"success": result.get("success"),
			"node_path": result.get("node_path"),
			"error": result.get("error")
		}
	}
	_send_message(msg)


func _handle_delete_node(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var node_path = str(data.get("node_path", ""))

	var result = {
		"success": false,
		"error": ""
	}

	if node_path == "":
		result["error"] = "node_path is required"
		_send_delete_node_result(request_id, result)
		return

	var editor_interface = _get_editor_interface()
	if editor_interface == null:
		result["error"] = "EditorInterface not available"
	else:
		var scene_root = editor_interface.get_edited_scene_root()
		if scene_root == null:
			result["error"] = "No scene open"
		else:
			# 智能处理路径：去除场景根名前缀
			var search_path = node_path
			if node_path.begins_with(scene_root.name + "/"):
				search_path = node_path.substr(scene_root.name.length() + 1)
			if search_path == scene_root.name or search_path == "":
				search_path = ""
			
			var node = null
			if search_path != "":
				node = scene_root.get_node_or_null(search_path)
			else:
				node = scene_root
			
			if node == null:
				result["error"] = "Node not found: " + node_path
			elif node == scene_root:
				result["error"] = "Cannot delete root node"
			else:
				var parent = node.get_parent()
				if parent != null:
					parent.remove_child(node)
					node.queue_free()
					result["success"] = true
				else:
					result["error"] = "Cannot delete root node"

	_send_delete_node_result(request_id, result)


func _send_delete_node_result(request_id: String, result: Dictionary) -> void:
	var msg = {
		"type": "delete_node_result",
		"data": {
			"request_id": request_id,
			"success": result.get("success"),
			"error": result.get("error")
		}
	}
	_send_message(msg)


func _send_message(msg: Dictionary) -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_warning("BrokerClient: _send_message called while not connected (status=%d), dropping message: %s" % [_tcp.get_status(), msg.get("type", "unknown")])
		return
	var json_str = JSON.stringify(msg) + "\n"
	var err = _tcp.put_data(json_str.to_utf8_buffer())
	if err != OK:
		push_warning("BrokerClient: put_data failed with error %d for message type: %s" % [err, msg.get("type", "unknown")])


func _handle_ping(_data: Dictionary) -> void:
	_send_message({"type": "pong"})


func _handle_pong_msg(_data: Dictionary) -> void:
	var now = Time.get_ticks_msec()
	if _ping_sent_time > 0:
		_rtt_ms = (now - _ping_sent_time) as float
		_last_pong_time = now
		rtt_updated.emit(_rtt_ms)


func _handle_heartbeat_ack(data: Dictionary) -> void:
	var server_timestamp = data.get("timestamp", 0) as int
	var now = Time.get_ticks_msec()
	if server_timestamp > 0:
		# 粗略估计单向延迟
		_rtt_ms = ((now - _ping_sent_time) / 2.0) as float if _ping_sent_time > 0 else 0.0
		rtt_updated.emit(_rtt_ms)


func _on_logs_ready(logs: Array) -> Dictionary:
	if logs.is_empty():
		return {"dropped": false}

	if not _connected:
		return {"dropped": true}

	# 转换为 broker 期望的 LogEntry 格式
	# 注意：EditorLogCatcher 已自动生成 id 和 timestamp_ms，这里直接映射类型
	var formatted_logs = []
	for log in logs:
		# 类型映射（map_log_type 会返回 broker 期望的类型名）
		var entry = {
			"id": log.get("id", str(Time.get_ticks_msec()) + "_" + str(formatted_logs.size())),
			"type": _map_log_type(log.get("type", "info")),
			"timestamp": log.get("timestamp", ""),
			"timestamp_ms": log.get("timestamp_ms", Time.get_ticks_msec()),
			"message": log.get("message", ""),
			"source": log.get("source", "editor"),
			"stack": log.get("stack", []),
			"count": 1
		}
		# 如果有上下文信息
		if log.has("context"):
			var ctx = log["context"]
			if ctx.has("file"):
				entry["script_path"] = ctx["file"]
			if ctx.has("line"):
				entry["line_number"] = ctx["line"]
			if ctx.has("frames") and ctx["frames"].size() > 0:
				entry["stack"] = ctx["frames"]
		# 如果有 script_path 字段
		if log.has("script_path") and log["script_path"]:
			entry["script_path"] = log["script_path"]
		# 如果有 line_number 字段
		if log.has("line_number"):
			entry["line_number"] = log["line_number"]
		# 如果有 output_type 字段（融合 error_collector 增强）
		if log.has("output_type") and log["output_type"]:
			entry["output_type"] = log["output_type"]
		formatted_logs.append(entry)

	# 构造日志消息
	var msg = {
		"type": "logs",
		"data": {
			"logs": formatted_logs
		}
	}
	_send_message(msg)
	return {"dropped": false}


func _map_log_type(type: String) -> String:
	match type:
		"debug":
			return "output"
		"info":
			return "output"
		"warning":
			return "warning"
		"error":
			return "runtime_error"
		"script_error":
			return "script_error"
		"validation_error":
			return "validation_error"
		"compile_error":
			return "compile_error"
		_:
			return "output"


func send_heartbeat() -> void:
	if not _connected:
		return
	_ping_sent_time = Time.get_ticks_msec()
	_send_message({"type": "heartbeat", "data": {"rtt_ms": _rtt_ms}})


# ============ v0.5.0 新增 handlers ============

func _handle_rescan(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var editor_interface = _get_editor_interface()
	if editor_interface == null:
		_send_result("rescan_result", request_id, {"success": false, "error": "No editor plugin"})
		return
	editor_interface.get_resource_filesystem().scan()
	_send_result("rescan_result", request_id, {"success": true, "scanned": true})


func _handle_script_check(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var code = str(data.get("code", ""))
	var result = _executor.compile_only(code)
	result["request_id"] = request_id
	_send_message({"type": "script_check_result", "data": result})


func _handle_get_properties(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var node_path = str(data.get("node_path", ""))
	var filter_str = str(data.get("filter", ""))

	var editor_interface = _get_editor_interface()
	if editor_interface == null:
		_send_result("scene_properties_result", request_id, {"success": false, "error": "No editor plugin"})
		return

	var scene_root = editor_interface.get_edited_scene_root()
	if scene_root == null:
		_send_result("scene_properties_result", request_id, {"success": false, "error": "No scene open"})
		return

	# 解析节点路径
	var node: Node = null
	if node_path == "" or node_path == "/":
		node = scene_root
	else:
		var search_path = node_path
		if node_path.begins_with("/root/"):
			search_path = node_path.substr(6)
		if search_path.begins_with(scene_root.name + "/"):
			search_path = search_path.substr(scene_root.name.length() + 1)
		elif search_path == scene_root.name:
			search_path = ""
		if search_path == "":
			node = scene_root
		else:
			node = scene_root.get_node_or_null(search_path)

	if node == null:
		_send_result("scene_properties_result", request_id, {"success": false, "error": "Node not found: " + node_path})
		return

	# 黑名单 — 始终排除
	var blacklist := ["_meta", "_import_path", "script", "owner"]
	# 解析白名单过滤器
	var whitelist: Array = []
	if filter_str.strip_edges() != "":
		for part in filter_str.split(","):
			var trimmed = part.strip_edges()
			if trimmed != "":
				whitelist.append(trimmed)

	var properties := {}
	var prop_list := node.get_property_list()
	for prop in prop_list:
		var prop_name: String = prop.get("name", "")
		var usage: int = prop.get("usage", 0)
		# 只返回有 STORAGE 或 EDITOR 标志的属性
		if not (usage & PROPERTY_USAGE_STORAGE) and not (usage & PROPERTY_USAGE_EDITOR):
			continue
		# 排除黑名单
		if prop_name.begins_with("_") or prop_name in blacklist:
			continue
		# 白名单过滤
		if whitelist.size() > 0 and not (prop_name in whitelist):
			continue
		var value = node.get(prop_name)
		properties[prop_name] = _serialize_value(value)

	var result_data := {
		"success": true,
		"node_path": str(node.get_path()),
		"node_type": node.get_class(),
		"property_count": properties.size(),
		"properties": properties
	}
	_send_result("scene_properties_result", request_id, result_data)


func _handle_scene_save(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var editor_interface = _get_editor_interface()
	if editor_interface == null:
		_send_result("scene_save_result", request_id, {"success": false, "saved": false, "path": "", "error": "No editor plugin"})
		return

	var scene_root = editor_interface.get_edited_scene_root()
	if scene_root == null:
		_send_result("scene_save_result", request_id, {"success": false, "saved": false, "path": "", "error": "No scene open"})
		return

	var scene_path = scene_root.scene_file_path
	if scene_path == "":
		_send_result("scene_save_result", request_id, {"success": false, "saved": false, "path": "", "error": "Scene has no file path (unsaved scene?)"})
		return

	var err = editor_interface.save_scene()
	if err == OK:
		_send_result("scene_save_result", request_id, {"success": true, "saved": true, "path": scene_path})
	else:
		_send_result("scene_save_result", request_id, {"success": false, "saved": false, "path": scene_path, "error": "Save failed with error code: %d" % err})


# ============ 辅助方法 ============



func _handle_scene_inspect(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var path = str(data.get("path", "/root"))
	var depth = int(data.get("depth", 2))
	var include_children = bool(data.get("include_children", true))
	var include_properties = bool(data.get("include_properties", true))
	var include_signals = bool(data.get("include_signals", false))
	var property_filter = str(data.get("property_filter", ""))
	var filter_arr = property_filter.split(",") if property_filter != "" else []

	var editor_interface = _get_editor_interface()
	if editor_interface == null:
		_send_result("scene_inspect_result", request_id, {"success": false, "node": null, "error": "No editor plugin"})
		return

	var root_node = editor_interface.get_edited_scene_root()
	if root_node == null:
		_send_result("scene_inspect_result", request_id, {"success": false, "node": null, "error": "No scene open"})
		return

	var target = _resolve_scene_path(root_node, path)
	if target == null:
		_send_result("scene_inspect_result", request_id, {"success": false, "node": null, "error": "Node not found: " + path})
		return

	var snapshot = _inspect_node(target, depth, include_children, include_properties, include_signals, filter_arr)
	_send_result("scene_inspect_result", request_id, {"success": true, "node": snapshot})


func _inspect_node(node: Node, depth: int, include_children: bool, include_properties: bool, include_signals: bool, filter_arr: Array) -> Dictionary:
	var result := {"name": node.name, "type": node.get_class()}
	var script = node.get_script()
	if script:
		result["script"] = script.resource_path if script.resource_path else "[built-in]"

	if include_properties:
		var props := {}
		var filter_empty = filter_arr.is_empty()
		for prop in node.get_property_list():
			var name: String = prop.name
			if name in ["_meta", "_import_path", "script", "owner"] or name.begins_with("_") or name == "unique_id_in_owner":
				continue
			if not (prop.usage & PROPERTY_USAGE_STORAGE or prop.usage & PROPERTY_USAGE_EDITOR):
				continue
			if not filter_empty and not name in filter_arr:
				continue
			props[name] = _serialize_value(node.get(name))
		if not props.is_empty():
			result["properties"] = props

	if include_signals:
		var sigs := _get_node_signals(node)
		if not sigs.is_empty():
			result["signals"] = sigs

	if include_children and depth > 0:
		var children: Array = []
		for child in node.get_children():
			children.append(_inspect_node(child, depth - 1, include_children, include_properties, include_signals, filter_arr))
		if not children.is_empty():
			result["children"] = children
	return result


func _get_node_signals(node: Node) -> Dictionary:
	var result := {}
	for signal_dict in node.get_signal_list():
		var signal_name: String = signal_dict.name
		var connections = node.get_signal_connection_list(signal_name)
		if connections.is_empty():
			continue
		var conn_list: Array = []
		for conn in connections:
			var bind_args: Array = []
			for b in conn.get("binds", []):
				bind_args.append(str(b))
			var target_path = ""
			var sig = conn.get("signal")
			if sig != null:
				if typeof(sig) == TYPE_OBJECT and sig.has_method("get_object"):
					var obj = sig.get_object()
					if obj:
						target_path = str(obj.get_path())
				elif typeof(sig) == TYPE_DICTIONARY:
					var obj = sig.get("object")
					if obj:
						target_path = str(obj.get_path())
			conn_list.append({
				"node_path": target_path,
				"signal_name": signal_name,
				"connected_to": str(conn.get("callable", "")),
				"method": str(conn.get("method", "")),
				"flags": conn.get("flags", 0),
				"binds": bind_args,
			})
		result[signal_name] = conn_list
	return result


func _handle_get_signal_connections(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var path = str(data.get("path", "/root"))
	var editor_interface = _get_editor_interface()
	if editor_interface == null:
		_send_result("signal_connections_result", request_id, {"success": false, "node_path": path, "signal_count": 0, "signals": {}, "error": "No editor plugin"})
		return
	var root_node = editor_interface.get_edited_scene_root()
	if root_node == null:
		_send_result("signal_connections_result", request_id, {"success": false, "node_path": path, "signal_count": 0, "signals": {}, "error": "No scene open"})
		return
	var target = _resolve_scene_path(root_node, path)
	if target == null:
		_send_result("signal_connections_result", request_id, {"success": false, "node_path": path, "signal_count": 0, "signals": {}, "error": "Node not found: " + path})
		return
	var signals = _get_node_signals(target)
	_send_result("signal_connections_result", request_id, {
		"success": true, "node_path": path, "signal_count": signals.size(), "signals": signals
	})


func _handle_get_console_stream(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var since_timestamp = float(data.get("since_timestamp", 0.0))
	var limit = int(data.get("limit", 50))
	var entries = []
	if _log_catcher != null and _log_catcher.has_method("get_console_entries"):
		entries = _log_catcher.get_console_entries(since_timestamp, limit)
	var next_ts = 0
	for e in entries:
		var ts = e.get("timestamp_ms", 0)
		if ts > next_ts:
			next_ts = ts
	_send_result("console_stream_result", request_id, {
		"success": true, "entries": entries, "next_timestamp_ms": next_ts
	})


func _handle_get_compile_errors(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var errors = []
	if _log_catcher != null and _log_catcher.has_method("get_compile_errors"):
		errors = _log_catcher.get_compile_errors()
	_send_result("compile_errors_result", request_id, {
		"success": true, "error_count": errors.size(), "errors": errors
	})


func _handle_script_reload(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var path = str(data.get("path", ""))

	if path.is_empty():
		_send_result("script_reload_result", request_id, {"success": false, "reloaded": false, "compile_success": false, "error": "No path provided"})
		return

	# 安全防护：禁止重载 Hastur 插件自身的脚本（会导致编辑器崩溃）
	var _script_blacklist := [
		"broker_client.gd", "executor_backend.gd",
		"editor_log_catcher.gd", "hastur_logger.gd", "executor_dock.gd",
		"execution_context.gd", "game_executor.gd", "runtime_error_capture.gd",
	]
	for _bad in _script_blacklist:
		if path.ends_with(_bad):
			_send_result("script_reload_result", request_id, {"success": false, "reloaded": false, "compile_success": false, "error": "Cannot reload Hastur core script: " + _bad})
			return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_send_result("script_reload_result", request_id, {"success": false, "reloaded": false, "compile_success": false, "error": "File not found: " + path})
		return
	var disk_source = file.get_as_text()
	file.close()
	var script = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if not script:
		_send_result("script_reload_result", request_id, {"success": false, "reloaded": false, "compile_success": false, "error": "Failed to load script"})
		return
	script.source_code = disk_source
	var err = script.reload()
	if err != OK:
		_send_result("script_reload_result", request_id, {
			"success": true, "reloaded": true, "compile_success": false, "method_count": 0, "error": "Compile error"
		})
		return
	_send_result("script_reload_result", request_id, {
		"success": true, "reloaded": true, "compile_success": true, "method_count": script.get_script_method_list().size(), "error": ""
	})


func _resolve_scene_path(root: Node, path: String) -> Node:
	if path == "/root" or path == "":
		return root
	var clean = path.trim_prefix("/root").trim_prefix("/")
	if clean.is_empty():
		return root
	var parts = clean.split("/")
	if parts.size() > 0 and parts[0] == root.name:
		parts = parts.slice(1)
	if parts.is_empty():
		return root
	return _find_node_by_path(root, parts, 0)


func _find_node_by_path(current: Node, parts, idx: int) -> Node:
	if idx >= parts.size():
		return current
	var child = current.get_node_or_null(parts[idx])
	if child:
		return _find_node_by_path(child, parts, idx + 1)
	return null

func _send_result(type: String, request_id: String, data: Dictionary) -> void:
	data["request_id"] = request_id
	_send_message({"type": type, "data": data})


func _serialize_value(value) -> Variant:
	if value == null:
		return null
	if value is bool or value is int or value is float or value is String:
		return value
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Vector3:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Color:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value is Rect2:
		return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
	if value is Transform2D:
		return {"origin": _serialize_value(value.origin), "x": _serialize_value(value.x), "y": _serialize_value(value.y)}
	if value is Array:
		var arr := []
		for item in value:
			arr.append(_serialize_value(item))
		return arr
	if value is Dictionary:
		var dict := {}
		for key in value:
			dict[str(key)] = _serialize_value(value[key])
		return dict
	if value is Object:
		if value.has_method("to_string"):
			return "[%s: %s]" % [value.get_class(), value.to_string()]
		return "[%s]" % value.get_class()
	return str(value)
