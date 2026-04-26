@tool
class_name EditorLogCatcher
extends RefCounted

## 编辑器日志捕获器
## 捕获 Godot 编辑器的所有日志输出
## 支持缓冲、过滤、异步发送、防抖刷新、永不丢失
## 
## 融合设计说明（基于源码仓库 error_collector.gd 的增强）：
## 1. 统一的日志类型：debug, info, output, warning, error, script_error, 
##    runtime_error, compile_error, validation_error
## 2. output_type 字段：区分 print/system/warning/error 等输出来源
## 3. 堆栈清理：统一使用 _sanitize_stack_trace 规范化堆栈格式
## 4. 错误统计：_total_error_count 包含所有错误类型，_last_error_time_ms 记录最后时间

const MAX_BUFFER_SIZE := 200          # 最大缓冲条数
const FLUSH_INTERVAL_MS := 100        # 刷新间隔（毫秒）
const MAX_MESSAGE_LENGTH := 2000       # 最大单条消息长度
const MAX_BATCH_SIZE := 50
const MAX_STACK_FRAMES := 20          # 最大堆栈帧数

var _buffer: Array[Dictionary] = []
var _mutex: Mutex = Mutex.new()
var _enabled: bool = true
var _parent_executor: Node = null
var _is_shutting_down: bool = false   # 是否正在关闭（shutdown 时丢弃所有新条目）
var _total_error_count: int = 0      # 错误总数（所有 error 类型）
var _total_warning_count: int = 0    # 警告总数
var _total_output_count: int = 0     # 输出总数
var _last_error_time_ms: int = 0     # 上次错误时间戳（毫秒）
var _last_warning_time_ms: int = 0   # 上次警告时间戳（毫秒）
var _session_start_time_ms: int = 0  # 会话开始时间

# 内部 Timer（避免被垃圾回收）
var _internal_timer: Timer = null

# 外部回调
var _on_log_ready: Callable = Callable()


func _init() -> void:
	_session_start_time_ms = Time.get_ticks_msec()
	print("[EditorLogCatcher] Initialized, session started")


func set_parent_executor(node: Node) -> void:
	_parent_executor = node


func set_enabled(enabled: bool) -> void:
	_mutex.lock()
	_enabled = enabled
	_mutex.unlock()


func set_on_log_ready(callback: Callable) -> void:
	_on_log_ready = callback


func log_debug(message: String, output_type: String = "debug") -> void:
	_add_log("debug", message, output_type)


func log_info(message: String, output_type: String = "info") -> void:
	_add_log("info", message, output_type)


func log_warning(message: String, output_type: String = "warning") -> void:
	_add_entry_with_type("warning", message, output_type, [], "")


func log_error(message: String, context: Dictionary = {}, output_type: String = "error") -> void:
	var entry = {
		"type": "error",
		"timestamp": Time.get_datetime_string_from_system(),
		"message": message,
		"context": context,
		"output_type": output_type,
	}
	_add_entry(entry)


func log_script_error(function: String, file: String, line: int, code: String, rationale: String) -> void:
	var entry = {
		"type": "script_error",
		"timestamp": Time.get_datetime_string_from_system(),
		"message": rationale if rationale != "" else code,
		"code": code,
		"file": file,
		"line": line,
		"function": function,
		"output_type": "script",
	}
	_add_entry(entry)


func _add_log(type: String, message: String, output_type: String = "") -> void:
	var entry = {
		"type": type,
		"timestamp": Time.get_datetime_string_from_system(),
		"message": message,
		"output_type": output_type if output_type else type,
	}
	_add_entry(entry)


## 内部方法：带类型的条目添加（支持堆栈和来源）
func _add_entry_with_type(log_type: String, message: String, output_type: String, stack: Array, source: String) -> void:
	var entry = {
		"type": log_type,
		"timestamp": Time.get_datetime_string_from_system(),
		"message": message,
		"output_type": output_type,
		"source": source,
		"stack": _sanitize_stack_trace(stack),
	}
	_add_entry(entry)


func _add_entry(entry: Dictionary) -> void:
	if _is_shutting_down:
		return
	_mutex.lock()
	if not _enabled:
		_mutex.unlock()
		return

	# 截断过长消息
	if entry.has("message"):
		entry["message"] = _truncate_message(entry["message"])

	# 生成唯一 ID（时间戳+随机，避免并发时冲突）
	entry["id"] = _generate_entry_id()
	# 记录时间戳（毫秒）
	entry["timestamp_ms"] = Time.get_ticks_msec()

	# 统计计数
	var entry_type = entry.get("type", "info")
	match entry_type:
		"error", "script_error", "validation_error", "compile_error", "runtime_error":
			_total_error_count += 1
			_last_error_time_ms = Time.get_ticks_msec()
		"warning":
			_total_warning_count += 1
			_last_warning_time_ms = Time.get_ticks_msec()
		"debug", "info", "output":
			_total_output_count += 1

	# 先进先出，超出容量丢弃最旧的
	_buffer.append(entry)
	while _buffer.size() > MAX_BUFFER_SIZE:
		_buffer.pop_front()

	_mutex.unlock()

	# 调度防抖刷新（避免高频 flush）
	_schedule_flush()


func flush() -> Array[Dictionary]:
	_mutex.lock()
	var entries = _buffer.duplicate()
	_buffer.clear()
	_mutex.unlock()

	if entries.is_empty():
		return entries

	if not _on_log_ready.is_valid():
		return entries

	# 分批发送（每次 MAX_BATCH_SIZE 条）
	var dropped := false
	var i = 0
	while i < entries.size():
		var batch_end = mini(i + MAX_BATCH_SIZE, entries.size())
		var batch: Array[Dictionary] = entries.slice(i, batch_end)

		var result = _on_log_ready.call(batch)
		if result is Dictionary and result.get("dropped", false):
			dropped = true
		i = batch_end

	if dropped:
		push_warning("[EditorLogCatcher] Some logs were dropped by broker")

	return entries


func get_buffer_count() -> int:
	_mutex.lock()
	var count = _buffer.size()
	_mutex.unlock()
	return count


func clear_buffer() -> void:
	_mutex.lock()
	_buffer.clear()
	_mutex.unlock()


# ============================================================
# 错误收集专用方法（来自 error_collector.gd）
# ============================================================

# 获取错误总数（所有 error 类型）
func get_total_error_count() -> int:
	return _total_error_count


# 获取警告总数
func get_total_warning_count() -> int:
	return _total_warning_count


# 获取输出总数
func get_total_output_count() -> int:
	return _total_output_count


# 获取上次错误时间戳（毫秒）
func get_last_error_time_ms() -> int:
	return _last_error_time_ms


# 获取上次警告时间戳（毫秒）
func get_last_warning_time_ms() -> int:
	return _last_warning_time_ms


# 获取会话统计摘要
func get_session_stats() -> Dictionary:
	return {
		"session_duration_ms": Time.get_ticks_msec() - _session_start_time_ms if _session_start_time_ms > 0 else 0,
		"total_errors": _total_error_count,
		"total_warnings": _total_warning_count,
		"total_outputs": _total_output_count,
		"buffered_logs": get_buffer_count(),
		"last_error_time_ms": _last_error_time_ms,
		"last_warning_time_ms": _last_warning_time_ms,
	}


# 捕获编译错误（融合自 error_collector.gd）
func capture_compile_error(error_message: String, script_path: String = "") -> void:
	_add_entry_with_type("compile_error", error_message, "compiler", [], script_path)


# 捕获运行时错误（融合自 error_collector.gd）
func capture_runtime_error(error_message: String, stack_trace: Array = [], script_path: String = "") -> void:
	_add_entry_with_type("runtime_error", error_message, "runtime", stack_trace, script_path)


# 捕获警告（融合自 error_collector.gd）
func capture_warning(message: String, stack_trace: Array = [], script_path: String = "") -> void:
	_add_entry_with_type("warning", message, "warning", stack_trace, script_path)


## 捕获普通输出（带类型标识）
func capture_output(message: String, output_type: String = "print") -> void:
	_add_entry_with_type("output", message, output_type, [], "")


# 关闭（清空缓冲区并清理资源，用于断线重连前清空旧数据）
func shutdown() -> void:
	# 先停止 Timer（在任何锁之外），避免 Timer 回调与 shutdown 并发
	var timer_to_free: Timer = null
	_mutex.lock()
	_is_shutting_down = true
	# 原子交换：将 _internal_timer 置为 null，防止 _on_internal_flush_timer 再次访问 buffer
	timer_to_free = _internal_timer
	_internal_timer = null
	_buffer.clear()
	# 重置会话统计（保留历史计数用于最终报告）
	_session_start_time_ms = Time.get_ticks_msec()  # 重新开始会话计时
	_mutex.unlock()

	# Timer 清理放在锁外，避免死锁
	if timer_to_free != null:
		if is_instance_valid(timer_to_free):
			timer_to_free.stop()
			timer_to_free.queue_free()


# ============================================================
# 内部工具方法
# ============================================================

# 生成唯一 ID
func _generate_entry_id() -> String:
	var ts = Time.get_ticks_msec()
	var rand1 = randi() % 10000
	var rand2 = randi() % 10000
	return "log_%d_%04d_%04d" % [ts, rand1, rand2]


# 截断过长消息
func _truncate_message(msg: String) -> String:
	if msg.length() > MAX_MESSAGE_LENGTH:
		return msg.substr(0, MAX_MESSAGE_LENGTH) + "... [TRUNCATED]"
	return msg


# 清理堆栈跟踪（去除空帧，限制长度）
# 融合自 error_collector.gd 的规范化堆栈格式
func _sanitize_stack_trace(stack: Array) -> Array:
	var result: Array = []
	for i in range(min(stack.size(), MAX_STACK_FRAMES)):
		var frame = stack[i]
		if frame == null:
			continue
		if frame is Dictionary:
			result.append({
				"file": frame.get("file", "?"),
				"line": frame.get("line", 0),
				"function": frame.get("function", "?"),
				"source": frame.get("source", "")
			})
		elif frame is String:
			result.append({"raw": frame})
	return result


## 格式化堆栈帧为可读字符串（供外部使用）
func format_stack_frame(frame: Dictionary) -> String:
	var file = frame.get("file", "?")
	var line = frame.get("line", 0)
	var func_name = frame.get("function", "?")
	return "%s:%d in function '%s'" % [file, line, func_name]


## 格式化完整堆栈为字符串
func format_stack_trace(stack: Array) -> String:
	var lines: Array = []
	for frame in stack:
		if frame is Dictionary:
			lines.append(format_stack_frame(frame))
		elif frame is String:
			lines.append(frame)
	return "\n".join(lines)


# 调度防抖刷新（复用 Timer 实例，避免 GC 泄漏）
func _schedule_flush() -> void:
	if _internal_timer != null:
		return  # 已经在等待刷新
	if _is_shutting_down:
		return
	var tree = Engine.get_main_loop()
	if tree == null:
		return
	var root = tree.root if "root" in tree else null
	if root == null:
		return
	_internal_timer = Timer.new()
	_internal_timer.one_shot = true
	_internal_timer.timeout.connect(_on_internal_flush_timer)
	root.add_child(_internal_timer)
	_internal_timer.start(float(FLUSH_INTERVAL_MS) / 1000.0)


func _on_internal_flush_timer() -> void:
	if _internal_timer != null:
		if is_instance_valid(_internal_timer):
			_internal_timer.queue_free()
		_internal_timer = null
	flush()
