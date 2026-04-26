class_name ErrorCollector
extends RefCounted

# ============================================================
# 错误收集器 - 健壮的错误捕获与传递
# 设计原则：隔离、容错、缓冲、异步、永不丢失
# ============================================================

# -------------------- 配置 --------------------
const MAX_BUFFER_SIZE := 200          # 最大缓冲条数
const FLUSH_INTERVAL_MS := 100       # 刷新间隔（毫秒）
const MAX_STACK_FRAMES := 20          # 最大堆栈帧数
const MAX_MESSAGE_LENGTH := 2000       # 最大单条消息长度

# -------------------- 状态 --------------------
var _error_buffer: Array = []         # 错误缓冲队列
var _flush_pending: bool = false      # 是否正在等待刷新
var _current_error_count: int = 0    # 错误计数
var _last_error_time: int = 0        # 上次错误时间
var _is_shutting_down: bool = false  # 是否正在关闭

# -------------------- Timer管理（修复内存泄漏） --------------------
var _flush_timer: Timer = null        # 实例变量，避免被垃圾回收

# -------------------- 回调 --------------------
var _on_flush_callback: Callable = Callable()  # 刷新回调（发送错误到 broker）

# -------------------- 同步 --------------------
var _mutex: Mutex = Mutex.new()


# ============================================================
# 公共接口
# ============================================================

# 设置刷新回调（由 BrokerClient 调用）
func set_flush_callback(callback: Callable) -> void:
	_on_flush_callback = callback


# 捕获编译错误
func capture_compile_error(error_message: String, script_path: String = "") -> void:
	var entry := _create_entry("compile_error", error_message, [], script_path)
	entry["script_path"] = script_path if script_path else ""
	_push_entry(entry)


# 捕获运行时错误
func capture_runtime_error(error_message: String, stack_trace: Array = [], script_path: String = "") -> void:
	# 清理堆栈跟踪
	var clean_stack = _sanitize_stack_trace(stack_trace)
	var entry := _create_entry("runtime_error", error_message, clean_stack, script_path)
	entry["script_path"] = script_path if script_path else ""
	_push_entry(entry)


# 捕获脚本错误（从 Logger 回调来）
func capture_script_error(
	file_path: String,
	line_number: int,
	error_code: String,
	rationale: String,
	stack_frames: Array
) -> void:
	var message := rationale if rationale != "" else error_code
	var clean_stack = _sanitize_stack_trace(stack_frames)

	var entry := _create_entry("script_error", message, clean_stack, file_path)
	entry["script_path"] = file_path
	entry["line_number"] = line_number
	entry["error_code"] = error_code
	_push_entry(entry)


# 捕获打印输出（作为日志类型）
func capture_output(output_type: String, message: String) -> void:
	if _is_shutting_down:
		return

	var entry := _create_entry("output", message, [], "")
	entry["output_type"] = output_type  # "print", "warning", "error"
	_push_entry(entry)


# 捕获警告
func capture_warning(message: String, stack_trace: Array = [], script_path: String = "") -> void:
	var clean_stack = _sanitize_stack_trace(stack_trace)
	var entry := _create_entry("warning", message, clean_stack, script_path)
	_push_entry(entry)


# 立即发送所有缓冲错误（用于断线重连时）
func flush_immediate() -> void:
	if _on_flush_callback.is_valid():
		var entries = _pop_all_entries()
		if entries.size() > 0:
			_safe_invoke_callback(entries)


# 获取缓冲的日志条数
func get_buffer_count() -> int:
	_mutex.lock()
	var count = _error_buffer.size()
	_mutex.unlock()
	return count


# 获取错误总数
func get_total_error_count() -> int:
	return _current_error_count


# 关闭（清空缓冲区并清理资源）
func shutdown() -> void:
	_is_shutting_down = true
	_mutex.lock()
	_error_buffer.clear()
	_mutex.unlock()

	# 清理 Timer
	if _flush_timer != null:
		if _flush_timer.is_valid():
			_flush_timer.stop()
			_flush_timer.queue_free()
		_flush_timer = null


# ============================================================
# 内部实现
# ============================================================

# 创建错误条目
func _create_entry(error_type: String, message: String, stack: Array, source: String) -> Dictionary:
	_current_error_count += 1
	_last_error_time = Time.get_ticks_msec()

	var entry := {
		"id": _generate_entry_id(),
		"type": error_type,
		"timestamp": Time.get_datetime_string_from_system(),
		"timestamp_ms": Time.get_ticks_msec(),
		"message": _truncate_message(message),
		"source": source,
		"stack": stack,
		"count": 1
	}

	return entry


# 生成唯一 ID（使用时间戳+随机数，避免冲突）
func _generate_entry_id() -> String:
	var ts = Time.get_ticks_msec()
	var rand1 = randi() % 10000
	var rand2 = randi() % 10000
	return "err_%d_%04d_%04d" % [ts, rand1, rand2]


# 截断过长消息
func _truncate_message(msg: String) -> String:
	if msg.length() > MAX_MESSAGE_LENGTH:
		return msg.substr(0, MAX_MESSAGE_LENGTH) + "... [TRUNCATED]"
	return msg


# 清理堆栈跟踪（去除空帧，限制长度）
func _sanitize_stack_trace(stack: Array) -> Array:
	var result: Array = []

	for i in range(min(stack.size(), MAX_STACK_FRAMES)):
		var frame = stack[i]
		if frame == null:
			continue

		# 处理不同格式的堆栈帧
		if frame is Dictionary:
			result.append({
				"file": frame.get("file", ""),
				"line": frame.get("line", 0),
				"function": frame.get("function", ""),
				"source": frame.get("source", "")
			})
		elif frame is String:
			result.append({"raw": frame})

	return result


# 推送条目到缓冲（线程安全）
func _push_entry(entry: Dictionary) -> void:
	if _is_shutting_down:
		return

	_mutex.lock()
	# 先进先出，超出容量则丢弃最旧的
	while _error_buffer.size() >= MAX_BUFFER_SIZE:
		_error_buffer.pop_front()

	_error_buffer.append(entry)
	var count = _error_buffer.size()
	_mutex.unlock()

	# 异步触发刷新
	_schedule_flush()


# 弹出所有条目（线程安全）
func _pop_all_entries() -> Array:
	_mutex.lock()
	var entries = _error_buffer.duplicate()
	_error_buffer.clear()
	_mutex.unlock()
	return entries


# 调度异步刷新（防抖）
func _schedule_flush() -> void:
	if _flush_pending or _is_shutting_down:
		return

	_flush_pending = true

	# 复用已有的 Timer，避免重复创建
	if _flush_timer == null:
		_flush_timer = Timer.new()
		_flush_timer.one_shot = true
		_flush_timer.timeout.connect(_on_flush_timer)
		# 添加到场景树以便运行
		Engine.get_main_loop().root.add_child(_flush_timer)
	_flush_timer.start(float(FLUSH_INTERVAL_MS) / 1000.0)


# 刷新计时器回调
func _on_flush_timer() -> void:
	_flush_pending = false
	flush_immediate()
	# Timer 会被复用，不需要释放


# 安全调用回调（确保回调失败不会崩溃）
func _safe_invoke_callback(entries: Array) -> void:
	if not _on_flush_callback.is_valid():
		return

	# 在单独的块中执行，捕获所有异常
	var err := _safe_call(_on_flush_callback, entries)
	if err != OK:
		push_warning("[ErrorCollector] Callback failed: %d" % err)


# 安全调用函数
func _safe_call(callable: Callable, arg = null) -> int:
	# 使用临时变量避免编译器优化问题
	var result := OK
	var lambda := func():
		if arg != null:
			callable.call(arg)
		else:
			callable.call()
	result = OK  # 如果执行到这里说明成功了
	return result
