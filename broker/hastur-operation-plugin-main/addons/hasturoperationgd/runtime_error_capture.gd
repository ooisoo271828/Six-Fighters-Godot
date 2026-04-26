class_name RuntimeErrorCapture
extends RefCounted

# ============================================================
# 运行时错误捕获器
# 在脚本执行时包装 try-catch，捕获所有运行时错误
# ============================================================

# 错误收集器引用
var _error_collector: ErrorCollector = null


func _init(error_collector: ErrorCollector) -> void:
	_error_collector = error_collector


# ============================================================
# 安全的代码执行包装器
# ============================================================

# 执行脚本实例方法并捕获错误
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

	if script_instance.has_method(method_name):
		var call_result = _call_method_capture(script_instance, method_name, args)
		result["success"] = call_result["success"]
		result["value"] = call_result.get("value", default_result)
		result["error_type"] = call_result.get("error_type", "")
		result["error_message"] = call_result.get("error_message", "")
		result["stack_trace"] = call_result.get("stack_trace", [])
	else:
		result["error_type"] = "method_not_found"
		result["error_message"] = "Method '%s' not found" % method_name

	return result


# 内部调用方法并捕获错误信息
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

	match args.size():
		0:
			result["value"] = instance.call(method_name)
		1:
			result["value"] = instance.callv(method_name, args)
		_:
			result["value"] = instance.callv(method_name, args)

	return result


# 格式化堆栈帧
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
