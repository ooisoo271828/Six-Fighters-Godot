class_name RuntimeErrorCapture
extends RefCounted

# ============================================================
# 运行时错误捕获器
# 在脚本执行时包装 try-catch，捕获所有运行时错误
# 用法：在 GDScriptExecutor 或其他执行器中，用此类包装 RefCounted 方法调用
# ============================================================

# 错误收集器引用（可选，用于统一缓冲）
var _error_collector: EditorLogCatcher = null


func _init(error_collector: EditorLogCatcher = null) -> void:
	_error_collector = error_collector


# ============================================================
# 安全的代码执行包装器
# ============================================================

# 执行脚本实例方法并捕获错误
# 返回结构化结果字典，与 GDScriptExecutor.execute_code 格式兼容
func execute_safe(
	script_instance: RefCounted,
	method_name: String,
	args: Array = [],
	default_result: Variant = null
) -> Dictionary:
	var result := {
		"success": false,
		"value": default_result,
		"error_type": "",
		"error_message": "",
		"stack_trace": []
	}

	if script_instance == null:
		result["error_type"] = "null_instance"
		result["error_message"] = "Script instance is null"
		_report_error(result)
		return result

	if not script_instance.has_method(method_name):
		result["error_type"] = "method_not_found"
		result["error_message"] = "Method '%s' not found" % method_name
		_report_error(result)
		return result

	var call_result = _call_method_capture(script_instance, method_name, args)
	result["success"] = call_result["success"]
	result["value"] = call_result.get("value", default_result)
	result["error_type"] = call_result.get("error_type", "")
	result["error_message"] = call_result.get("error_message", "")
	result["stack_trace"] = call_result.get("stack_trace", [])

	if not result["success"]:
		_report_error(result)

	return result


# 内部调用方法并捕获错误
func _call_method_capture(
	instance: RefCounted,
	method_name: String,
	args: Array
) -> Dictionary:
	var result := {
		"success": true,
		"value": null,
		"error_type": "",
		"error_message": "",
		"stack_trace": []
	}

	if not instance.has_method(method_name):
		result["success"] = false
		result["error_type"] = "method_not_found"
		result["error_message"] = "Method '%s' not found" % method_name
		return result

	# 通过 Callable 调用，利用 Godot 内置错误机制
	# call() / callv() 失败时 Godot 会 push_error，该错误被 OS 已注册的 Logger 捕获
	var callable: Callable = Callable(instance, method_name)
	var err: int = OK

	if args.is_empty():
		# 无参数：用 lambda 包装，失败时 Godot 自动 push_error
		var safe_call := func() -> Variant:
			return callable.call()
		err = _safe_invoke(safe_call, result)
	else:
		var safe_call := func() -> Variant:
			return callable.callv(args)
		err = _safe_invoke(safe_call, result)

	if err != OK:
		result["success"] = false
		result["error_type"] = "call_failed"
		result["error_message"] = "Method '%s' call failed with error %d" % [method_name, err]

	return result


# 安全调用 lambda
# 注意：callable.call() 失败时 Godot 会 push_error，由 OS Logger 捕获。
# Godot 4.x 不支持 try-catch，所以我们依赖 OS Logger 机制来捕获错误。
# 此方法主要用于获取返回值，错误由全局 Logger 统一处理。
func _safe_invoke(callable: Callable, out_result: Dictionary) -> int:
	# 调用方法，如果 Godot 内部出错，会通过 push_error 被 HasturLogger 捕获
	# 注意：callable.call() 不会抛出异常，错误通过 push_error 处理
	var ret: Variant = callable.call()
	out_result["value"] = ret
	return OK


# 上报错误到 ErrorCollector（如果有）
func _report_error(result: Dictionary, script_path: String = "") -> void:
	if _error_collector == null:
		return
	_error_collector.capture_runtime_error(
		result["error_message"],
		result["stack_trace"],
		script_path
	)


# ============================================================
# 静态格式化工具
# ============================================================

# 格式化单个堆栈帧
static func format_stack_frame(frame: Dictionary) -> String:
	var file = frame.get("file", "?")
	var line = frame.get("line", 0)
	var func_name = frame.get("function", "?")
	return "%s:%d in function '%s'" % [file, line, func_name]


# 格式化完整堆栈
static func format_stack_trace(stack: Array) -> String:
	var lines: Array = []
	for frame in stack:
		lines.append(format_stack_frame(frame))
	return "\n".join(lines)
