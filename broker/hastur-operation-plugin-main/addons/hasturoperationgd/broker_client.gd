class_name BrokerClient
extends RefCounted


signal connection_established(id: String)
signal connection_lost()
signal connection_state_changed(state: String)
signal remote_execution_completed(code: String, result: Dictionary, duration_ms: int)
signal breakpoint_hit(breakpoint_id: String, file: String, line: int, variables: Dictionary)
signal logs_received(logs: Array)

# ============================================================
# 连接配置
# ============================================================
var _tcp: StreamPeerTCP
var _host: String
var _port: int
var _connected: bool = false
var _executor_id: String = ""

# 重连配置
var _reconnect_delay: float = 1.0
var _max_reconnect_delay: float = 30.0
var _reconnect_timer: float = 0.0
var _reconnect_count: int = 0
var _max_reconnect_attempts: int = 50  # 新增：最大重连次数限制

# 连接超时配置
var _connect_timeout: float = 10.0  # 新增：连接超时（秒）
var _connect_timer: float = 0.0      # 新增：连接计时器
var _is_connecting: bool = false     # 新增：是否正在连接

# 心跳配置
var _heartbeat_interval: float = 20.0
var _heartbeat_timer: float = 0.0
var _heartbeat_timeout: float = 10.0  # 新增：心跳响应超时（秒）
var _last_heartbeat_time: float = 0.0  # 新增：上次心跳响应后经过的时间
var _last_rtt_ms: int = 0

# 读取缓冲区
var _buffer: String = ""

# 日志缓存（新增：断线期间缓存日志，重连后发送）
var _pending_logs: Array = []
var _max_pending_logs: int = 1000  # 缓存上限，防止内存无限增长

# 执行器
var _executor: GDScriptExecutor
var _error_collector: ErrorCollector
var _project_name: String
var _project_path: String
var _editor_pid: int
var _plugin_version: String
var _editor_version: String
var _executor_type: String = "editor"

var _editor_plugin_ref = null


func _init(host: String, port: int, executor_type: String = "editor", editor_plugin = null) -> void:
	_host = host
	_port = port
	_executor_type = executor_type
	_editor_plugin_ref = editor_plugin
	_tcp = StreamPeerTCP.new()
	_executor = GDScriptExecutor.new()
	_error_collector = ErrorCollector.new()
	_error_collector.set_flush_callback(_on_error_collector_flush)
	_executor.set_error_collector(_error_collector)

	_project_name = ProjectSettings.get_setting("application/config/name", "Unnamed")
	_project_path = ProjectSettings.globalize_path("res://")
	_editor_pid = OS.get_process_id()
	_plugin_version = "0.3.0"
	var version_info = Engine.get_version_info()
	_editor_version = str(version_info.get("major", 0)) + "." + str(version_info.get("minor", 0)) + "." + str(version_info.get("patch", 0))
	_try_connect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_cleanup()


func disconnect_client() -> void:
	_disconnect_cleanup()


func _disconnect_cleanup() -> void:
	if _tcp != null:
		_tcp.disconnect_from_host()
	_connected = false
	_is_connecting = false
	_executor_id = ""
	_buffer = ""
	# 清理未发送的日志
	_pending_logs.clear()


# ============================================================
# 主循环 - 每帧调用
# ============================================================
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
				connection_state_changed.emit("reconnecting")
				_try_connect()

		StreamPeerTCP.STATUS_CONNECTING:
			connection_state_changed.emit("connecting")
			# 新增：连接超时检测
			if _is_connecting:
				_connect_timer += delta
				if _connect_timer >= _connect_timeout:
					push_warning("BrokerClient: connection timeout (%.1fs), disconnecting..." % _connect_timeout)
					_tcp.disconnect_from_host()
					_is_connecting = false
					_connect_timer = 0.0

		StreamPeerTCP.STATUS_CONNECTED:
			if not _connected:
				_connected = true
				_is_connecting = false
				_connect_timer = 0.0
				_reconnect_delay = 1.0
				_reconnect_timer = 0.0
				_reconnect_count = 0
				_last_heartbeat_time = 0.0
				_send_register()
				_flush_pending_logs()  # 新增：重连后立即发送缓存的日志
			else:
				# 心跳计时
				_heartbeat_timer += delta
				_last_heartbeat_time += delta  # 新增：追踪心跳响应超时

				# 新增：心跳响应超时检测
				if _last_heartbeat_time >= _heartbeat_timeout:
					push_warning("BrokerClient: heartbeat timeout (%.1fs > %.1fs), connection may be dead" % [_last_heartbeat_time, _heartbeat_timeout])
					_tcp.disconnect_from_host()
					_handle_disconnect()
					return

				# 发送心跳
				if _heartbeat_timer >= _heartbeat_interval:
					_heartbeat_timer = 0.0
					_send_heartbeat()

			_read_data()

		StreamPeerTCP.STATUS_ERROR:
			if _connected:
				_handle_disconnect()
			_reconnect_timer += delta
			if _reconnect_timer >= _reconnect_delay:
				_reconnect_timer = 0.0
				# 新增：检查最大重连次数
				if _reconnect_count >= _max_reconnect_attempts:
					push_error("BrokerClient: max reconnect attempts (%d) reached, giving up" % _max_reconnect_attempts)
					connection_state_changed.emit("failed")
					return
				_reconnect_delay = min(_reconnect_delay * 2.0, _max_reconnect_delay)
				connection_state_changed.emit("reconnecting")
				_try_connect()


# ============================================================
# 公共接口
# ============================================================
func get_executor_id() -> String:
	return _executor_id


func is_broker_connected() -> bool:
	return _connected


func get_reconnect_count() -> int:
	return _reconnect_count


func get_rtt_ms() -> int:
	return _last_rtt_ms


func get_error_collector() -> ErrorCollector:
	return _error_collector


# ============================================================
# 连接管理
# ============================================================
func _send_heartbeat() -> void:
	var start_time = Time.get_ticks_msec()
	_send_message({"type": "heartbeat", "data": {"timestamp": start_time}})


func _handle_heartbeat_ack(data: Dictionary) -> void:
	var sent_time = data.get("timestamp", 0)
	var rtt = Time.get_ticks_msec() - sent_time
	if rtt >= 0:
		_last_rtt_ms = rtt
		_last_heartbeat_time = 0.0  # 新增：收到响应后重置超时计时器


func _try_connect() -> void:
	var status = _tcp.get_status()
	if status != StreamPeerTCP.STATUS_NONE and status != StreamPeerTCP.STATUS_ERROR:
		push_warning("BrokerClient: _try_connect called in unexpected status %d, skipping" % status)
		return
	if status != StreamPeerTCP.STATUS_NONE:
		_tcp.disconnect_from_host()

	# 新增：检查最大重连次数
	if _reconnect_count >= _max_reconnect_attempts:
		push_error("BrokerClient: max reconnect attempts reached, cannot reconnect")
		return

	_reconnect_count += 1
	_is_connecting = true
	_connect_timer = 0.0
	_tcp.connect_to_host(_host, _port)


func _handle_disconnect() -> void:
	push_warning("BrokerClient: connection lost to %s:%d (executor_id=%s, reconnect_count=%d)" % [_host, _port, _executor_id, _reconnect_count])
	_connected = false
	_is_connecting = false
	_executor_id = ""
	_buffer = ""
	_heartbeat_timer = 0.0
	_last_heartbeat_time = 0.0
	connection_lost.emit()
	connection_state_changed.emit("disconnected")


# ============================================================
# 消息处理
# ============================================================
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
	var available = _tcp.get_available_bytes()
	if available <= 0:
		return

	# 新增：限制单次读取大小，防止大数据攻击
	const MAX_READ_SIZE = 65536
	var to_read = mini(available, MAX_READ_SIZE)

	var result = _tcp.get_partial_data(to_read)
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
	# 新增：JSON解析错误时输出警告
	if err != OK:
		push_warning("BrokerClient: JSON parse error for message: %s" % raw.substr(0, 100))
		return

	var msg = json.data
	if not msg is Dictionary:
		return

	var type = msg.get("type", "")
	var data = msg.get("data", {})

	match type:
		"register_result":
			_handle_register_result(data)
		"execute":
			_handle_execute(data)
		"ping":
			_send_message({"type": "pong"})
		"heartbeat_ack":
			_handle_heartbeat_ack(data)
		"disconnect":
			_tcp.disconnect_from_host()
		"breakpoint_set":
			print("[Broker] Breakpoint set: ", data)
		"breakpoint_removed":
			print("[Broker] Breakpoint removed: ", data)
		"breakpoint_updated":
			print("[Broker] Breakpoint updated: ", data)
		# 场景树入站请求处理（从 broker-server 发来的请求）
		"get_scene_tree":
			_handle_get_scene_tree_request(data)
		"create_node":
			_handle_create_node_request(data)
		"delete_node":
			_handle_delete_node_request(data)
		# 场景树出站响应处理（Godot 端发出的请求的结果）
		"scene_tree_result":
			_handle_scene_tree_result(data)
		"create_node_result":
			_handle_create_node_result(data)
		"delete_node_result":
			_handle_delete_node_result(data)


func _handle_register_result(data: Dictionary) -> void:
	if data.get("success", false):
		_executor_id = str(data.get("id", ""))
		connection_established.emit(_executor_id)
		connection_state_changed.emit("connected")
		push_warning("BrokerClient: registered successfully (executor_id=%s)" % _executor_id)
	else:
		push_warning("BrokerClient: registration rejected by broker: %s" % str(data))
		_tcp.disconnect_from_host()
		_connected = false


func _handle_execute(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var code = str(data.get("code", ""))
	var start_time = Time.get_ticks_msec()
	var result = _executor.execute_code(code, {}, _editor_plugin_ref)
	var end_time = Time.get_ticks_msec()
	var duration_ms = end_time - start_time
	var msg = {
		"type": "execute_result",
		"data": {
			"request_id": request_id,
			"compile_success": result.get("compile_success", false),
			"compile_error": result.get("compile_error", ""),
			"run_success": result.get("run_success", false),
			"run_error": result.get("run_error", ""),
			"outputs": result.get("outputs", [])
		}
	}
	_send_message(msg)
	remote_execution_completed.emit(code, result, duration_ms)


# ============================================================
# 场景树操作 - 出站请求（Godot → broker-server）
# ============================================================
var _scene_tree_callback: Callable = Callable()
var _create_node_callback: Callable = Callable()
var _delete_node_callback: Callable = Callable()

func request_scene_tree(callback: Callable) -> void:
	_scene_tree_callback = callback
	_send_message({"type": "get_scene_tree", "data": {}})


func request_create_node(parent_path: String, node_name: String, node_type: String, callback: Callable, script_path: String = "") -> void:
	_create_node_callback = callback
	var data = {
		"parent_path": parent_path,
		"name": node_name,
		"type": node_type
	}
	if script_path != "":
		data["script"] = script_path
	_send_message({"type": "create_node", "data": data})


func request_delete_node(node_path: String, callback: Callable) -> void:
	_delete_node_callback = callback
	_send_message({"type": "delete_node", "data": {"node_path": node_path}})


# ============================================================
# 场景树操作 - 入站请求处理（broker-server → Godot）
# ============================================================
func _handle_get_scene_tree_request(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var tree_dict = {}
	
	if _editor_plugin_ref == null:
		_send_message({
			"type": "scene_tree_result",
			"data": {"request_id": request_id, "success": false, "error": "No editor plugin reference"}
		})
		return
	
	var edited_scene = _editor_plugin_ref.get_editor_interface().get_edited_scene_root()
	if edited_scene == null:
		_send_message({
			"type": "scene_tree_result",
			"data": {"request_id": request_id, "success": false, "error": "No edited scene"}
		})
		return
	
	tree_dict = _serialize_node_tree(edited_scene)
	_send_message({
		"type": "scene_tree_result",
		"data": {"request_id": request_id, "success": true, "tree": tree_dict}
	})


func _handle_create_node_request(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var parent_path = str(data.get("parent_path", ""))
	var node_name = str(data.get("name", ""))
	var node_type = str(data.get("type", "Node"))
	var script_path = str(data.get("script", ""))
	
	if _editor_plugin_ref == null:
		_send_message({
			"type": "create_node_result",
			"data": {"request_id": request_id, "success": false, "error": "No editor plugin reference"}
		})
		return
	
	var edited_scene = _editor_plugin_ref.get_editor_interface().get_edited_scene_root()
	if edited_scene == null:
		_send_message({
			"type": "create_node_result",
			"data": {"request_id": request_id, "success": false, "error": "No edited scene"}
		})
		return
	
	# 查找父节点
	var parent_node = _find_node_by_path(edited_scene, parent_path)
	if parent_node == null:
		parent_node = edited_scene
		if parent_path != "" and parent_path != edited_scene.name:
			_send_message({
				"type": "create_node_result",
				"data": {"request_id": request_id, "success": false, "error": "Parent node not found: " + parent_path}
			})
			return
	
	# 创建新节点
	var new_node = _create_node_by_type(node_type)
	if new_node == null:
		_send_message({
			"type": "create_node_result",
			"data": {"request_id": request_id, "success": false, "error": "Unknown node type: " + node_type}
		})
		return
	
	new_node.name = node_name
	
	# 添加脚本（如果指定）
	if script_path != "":
		var script = load(script_path)
		if script:
			new_node.set_script(script)
	
	# 添加到父节点
	parent_node.add_child(new_node)
	new_node.owner = edited_scene
	
	# 通知编辑器场景树已更改
	_editor_plugin_ref.get_editor_interface().get_resource_filesystem().scan()
	
	_send_message({
		"type": "create_node_result",
		"data": {
			"request_id": request_id,
			"success": true,
			"data": {
				"name": node_name,
				"type": node_type,
				"path": str(parent_node.get_path_to(new_node))
			}
		}
	})


func _handle_delete_node_request(data: Dictionary) -> void:
	var request_id = str(data.get("request_id", ""))
	var node_path = str(data.get("node_path", ""))
	
	if _editor_plugin_ref == null:
		_send_message({
			"type": "delete_node_result",
			"data": {"request_id": request_id, "success": false, "error": "No editor plugin reference"}
		})
		return
	
	var edited_scene = _editor_plugin_ref.get_editor_interface().get_edited_scene_root()
	if edited_scene == null:
		_send_message({
			"type": "delete_node_result",
			"data": {"request_id": request_id, "success": false, "error": "No edited scene"}
		})
		return
	
	# 查找要删除的节点
	var target_node = _find_node_by_path(edited_scene, node_path)
	if target_node == null:
		_send_message({
			"type": "delete_node_result",
			"data": {"request_id": request_id, "success": false, "error": "Node not found: " + node_path}
		})
		return
	
	# 不能删除场景根节点
	if target_node == edited_scene:
		_send_message({
			"type": "delete_node_result",
			"data": {"request_id": request_id, "success": false, "error": "Cannot delete scene root node"}
		})
		return
	
	var node_name = target_node.name
	var parent = target_node.get_parent()
	
	# 从父节点移除并释放
	parent.remove_child(target_node)
	target_node.queue_free()
	
	_send_message({
		"type": "delete_node_result",
		"data": {
			"request_id": request_id,
			"success": true,
			"data": {"deleted_node": node_name}
		}
	})


# ============================================================
# 场景树辅助函数
# ============================================================
func _serialize_node_tree(node: Node) -> Dictionary:
	var result = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"children": []
	}
	
	# 添加脚本路径（如果有）
	var script = node.get_script()
	if script:
		result["script"] = script.resource_path
	
	for child in node.get_children():
		result["children"].append(_serialize_node_tree(child))
	
	return result


func _find_node_by_path(root: Node, path: String) -> Node:
	if path == "" or path == root.name:
		return root
	
	# 智能处理路径：去除根节点名前缀
	# 例如 "SkillTestScene/Child" -> "Child" 当 root 就是 SkillTestScene
	var search_path = path
	if path.begins_with(root.name + "/"):
		search_path = path.substr(root.name.length() + 1)
	
	if search_path == "" or search_path == ".":
		return root
	
	# 方法1：从根节点开始用相对路径查找
	var node = root.get_node_or_null(search_path)
	if node != null:
		return node
	
	# 方法2：使用绝对路径（通过 SceneTree）
	var full_path = str(root.get_path()) + "/" + search_path
	var scene_tree = root.get_tree()
	if scene_tree and scene_tree.root.has_node(full_path):
		return scene_tree.root.get_node(full_path)
	
	# 方法3：回退递归搜索
	return _find_node_recursive(root, search_path)


func _find_node_recursive(node: Node, path: String) -> Node:
	var parts = path.split("/")
	var current = node
	
	for part in parts:
		if part == "":
			continue
		var found = false
		for child in current.get_children():
			if child.name == part:
				current = child
				found = true
				break
		if not found:
			return null
	
	return current


func _create_node_by_type(type_name: String) -> Node:
	# 常用节点类型映射
	var type_map = {
		"Node": "Node",
		"Node2D": "Node2D",
		"Node3D": "Node3D",
		"Control": "Control",
		"Label": "Label",
		"Button": "Button",
		"Panel": "Panel",
		"PanelContainer": "PanelContainer",
		"VBoxContainer": "VBoxContainer",
		"HBoxContainer": "HBoxContainer",
		"MarginContainer": "MarginContainer",
		"ScrollContainer": "ScrollContainer",
		"Sprite2D": "Sprite2D",
		"Sprite3D": "Sprite3D",
		"AnimatedSprite2D": "AnimatedSprite2D",
		"CollisionShape2D": "CollisionShape2D",
		"CollisionShape3D": "CollisionShape3D",
		"CharacterBody2D": "CharacterBody2D",
		"CharacterBody3D": "CharacterBody3D",
		"RigidBody2D": "RigidBody2D",
		"RigidBody3D": "RigidBody3D",
		"StaticBody2D": "StaticBody2D",
		"StaticBody3D": "StaticBody3D",
		"Area2D": "Area2D",
		"Area3D": "Area3D",
		"Camera2D": "Camera2D",
		"Camera3D": "Camera3D",
		"TileMap": "TileMap",
		"TileMapLayer": "TileMapLayer",
		"CanvasLayer": "CanvasLayer",
		"AudioStreamPlayer": "AudioStreamPlayer",
		"AudioStreamPlayer2D": "AudioStreamPlayer2D",
		"AudioStreamPlayer3D": "AudioStreamPlayer3D",
		"AnimationPlayer": "AnimationPlayer",
		"AnimationTree": "AnimationTree",
		"Particles2D": "GPUParticles2D",
		"Particles3D": "GPUParticles3D",
		"ColorRect": "ColorRect",
		"TextureRect": "TextureRect",
		"LineEdit": "LineEdit",
		"TextEdit": "TextEdit",
		"ProgressBar": "ProgressBar",
		"Timer": "Timer",
		"RayCast2D": "RayCast2D",
		"RayCast3D": "RayCast3D",
		"PathFollow2D": "PathFollow2D",
		"PathFollow3D": "PathFollow3D",
		"Marker2D": "Marker2D",
		"Marker3D": "Marker3D",
	}
	
	var class_name_str = type_map.get(type_name, "")
	if class_name_str == "":
		class_name_str = type_name
	
	# 尝试创建节点
	if ClassDB.class_exists(class_name_str):
		if ClassDB.is_parent_class(class_name_str, "Node"):
			return ClassDB.instantiate(class_name_str)
	
	# 回退：创建普通 Node
	push_warning("BrokerClient: Unknown node type '%s', falling back to Node" % type_name)
	return Node.new()


func _handle_scene_tree_result(data: Dictionary) -> void:
	if _scene_tree_callback.is_valid():
		var success = data.get("success", false)
		var result_data = data.get("data", {}) if success else null
		var error_msg = data.get("error", "") if not success else ""
		_scene_tree_callback.call(success, result_data, error_msg)
	_scene_tree_callback = Callable()


func _handle_create_node_result(data: Dictionary) -> void:
	if _create_node_callback.is_valid():
		var success = data.get("success", false)
		var result_data = data.get("data", {}) if success else null
		var error_msg = data.get("error", "") if not success else ""
		_create_node_callback.call(success, result_data, error_msg)
	_create_node_callback = Callable()


func _handle_delete_node_result(data: Dictionary) -> void:
	if _delete_node_callback.is_valid():
		var success = data.get("success", false)
		var result_data = data.get("data", {}) if success else null
		var error_msg = data.get("error", "") if not success else ""
		_delete_node_callback.call(success, result_data, error_msg)
	_delete_node_callback = Callable()


# ============================================================
# 消息发送（新增：日志缓存）
# ============================================================
func _send_message(msg: Dictionary) -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		# 日志消息缓存到重连后发送
		if msg.get("type") == "logs":
			_cache_pending_log(msg)
		push_warning("BrokerClient: _send_message called while not connected (status=%d), dropping: %s" % [_tcp.get_status(), msg.get("type", "unknown")])
		return

	var json_str = JSON.stringify(msg) + "\n"
	var err = _tcp.put_data(json_str.to_utf8_buffer())
	if err != OK:
		push_warning("BrokerClient: put_data failed with error %d for message type: %s" % [err, msg.get("type", "unknown")])
		# 如果是日志发送失败，也缓存起来
		if msg.get("type") == "logs":
			_cache_pending_log(msg)


func _cache_pending_log(msg: Dictionary) -> void:
	# 防止缓存无限增长
	if _pending_logs.size() >= _max_pending_logs:
		_pending_logs.pop_front()  # 丢弃最旧的
	_pending_logs.append(msg)


func _flush_pending_logs() -> void:
	if _pending_logs.is_empty():
		return

	push_warning("BrokerClient: flushing %d pending log messages" % _pending_logs.size())

	var logs_to_send = _pending_logs.duplicate()
	_pending_logs.clear()

	for msg in logs_to_send:
		var json_str = JSON.stringify(msg) + "\n"
		var err = _tcp.put_data(json_str.to_utf8_buffer())
		if err != OK:
			# 发送失败，重新缓存
			_pending_logs.append(msg)
			push_warning("BrokerClient: failed to flush log, re-cached (remaining: %d)" % _pending_logs.size())
			break


# ============================================================
# 错误收集器回调
# ============================================================
func _on_error_collector_flush(entries: Array) -> void:
	if entries.is_empty():
		return

	var msg = {
		"type": "logs",
		"data": {
			"logs": entries,
			"count": entries.size(),
			"executor_id": _executor_id
		}
	}
	_send_message(msg)
	logs_received.emit(entries)
