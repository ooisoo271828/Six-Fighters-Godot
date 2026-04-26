class_name HasturLogger
extends Logger

## 全局日志捕获器
## 通过 OS.add_logger() 注册，捕获所有 Godot 日志输出
## 将日志转发到 broker_client 进行发送

# Godot 4.x Logger.ErrorType 枚举值（使用硬编码避免兼容性问题）
# Godot 4.6: ERROR_TYPE_ERROR=0, ERROR_TYPE_WARNING=1, ERROR_TYPE_SCRIPT=2
const _ERROR_TYPE_ERROR: int = 0
const _ERROR_TYPE_WARNING: int = 1
const _ERROR_TYPE_SCRIPT: int = 2

var _log_catcher: EditorLogCatcher = null
var _mutex: Mutex = Mutex.new()

func set_log_catcher(catcher: EditorLogCatcher) -> void:
	_mutex.lock()
	_log_catcher = catcher
	_mutex.unlock()


func _log_message(message: String, error: bool) -> void:
	# Godot Logger 机制：push_error → _log_message(msg, true)，push_warning → _log_message(msg, false)
	# 统一通过 _log 路由，_log 会根据 level 分配到对应的日志方法
	_log("error" if error else "info", message)


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	editor_notify: bool,
	error_type: int,
	script_backtraces: Array
) -> void:
	_mutex.lock()
	var catcher = _log_catcher
	_mutex.unlock()

	if catcher == null:
		return

	var msg = rationale if rationale != "" else code
	if msg == "":
		msg = "[error_type:%d]" % error_type

	var ctx := {
		"function": function,
		"file": file,
		"line": line,
		"code": code,
		"backtrace": script_backtraces,
		"error_type": error_type,
	}

	# 按 error_type 分类路由到对应的 capture 方法
	# Godot 4.6 只有 ERROR_TYPE_ERROR(0) 和 ERROR_TYPE_WARNING(1)
	# ERROR_TYPE_SCRIPT(2) 是脚本编译错误
	match error_type:
		_ERROR_TYPE_ERROR:
			catcher.log_error(msg, ctx, "runtime")
		_ERROR_TYPE_WARNING:
			catcher.capture_warning(msg, script_backtraces, file)
		_ERROR_TYPE_SCRIPT:
			catcher.log_script_error(function, file, line, code, rationale)
		_:
			# 未知类型，统一作为运行时错误处理
			catcher.capture_runtime_error(msg, script_backtraces, file)


func _log(level: String, message: String) -> void:
	_mutex.lock()
	var catcher = _log_catcher
	_mutex.unlock()

	if catcher == null:
		return

	match level:
		"debug":
			catcher.log_debug(message, "debug")
		"info":
			catcher.log_info(message, "print")
		"warning":
			catcher.log_warning(message, "warning")
		"error", "script", "validation_error":
			catcher.log_error(message, {}, "error")
		_:
			catcher.log_info(message, "system")
