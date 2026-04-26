class_name GDScriptExecutor


var _error_capturer: _CompileErrorCapturer
var _disposed: bool = false  # 防止重复释放


func _init() -> void:
	_error_capturer = _CompileErrorCapturer.new()
	OS.add_logger(_error_capturer)


# RefCounted 没有 _notification，需要通过显式清理
# 调用此方法在不再需要执行器时清理资源
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	if _error_capturer != null:
		OS.remove_logger(_error_capturer)
		_error_capturer = null


func _notification(what: int) -> void:
	# 只有 Node 子类才会收到 NOTIFICATION_PREDELETE
	# 对于 RefCounted，只能依赖显式调用 dispose() 或等待引用计数归零
	if what == NOTIFICATION_PREDELETE:
		dispose()


func execute_code(code: String, execute_context: Dictionary = {}, editor_plugin = null) -> Dictionary:
	var result = {
		"compile_success": false,
		"compile_error": "",
		"run_success": false,
		"run_error": "",
		"outputs": []
	}

	if code.strip_edges() == "":
		result.compile_error = "Code is empty"
		return result

	var is_full_class = _is_full_class(code)

	var source: String
	if is_full_class:
		source = _ensure_tool_annotation(code)
	else:
		source = _wrap_snippet(code)

	var script = GDScript.new()
	script.source_code = source
	var script_path = script.resource_path

	_error_capturer.start_capture(script_path)
	var compile_err = script.reload()
	var captured_errors = _error_capturer.stop_capture()

	if compile_err != OK:
		if captured_errors.size() > 0:
			result.compile_error = "\n".join(captured_errors)
		else:
			result.compile_error = _error_code_to_string(compile_err)
		script = null
		return result

	result.compile_success = true

	if not script.can_instantiate():
		result.compile_error = "Script compiled but cannot be instantiated"
		result.compile_success = false
		script = null
		return result

	_error_capturer.start_capture(script_path)
	var instance = script.new()
	captured_errors = _error_capturer.stop_capture()
	script = null

	if instance == null:
		if captured_errors.size() > 0:
			result.run_error = "\n".join(captured_errors)
		else:
			result.run_error = "Failed to instantiate script"
		return result

	var ctx = ExecutionContext.new(editor_plugin)

	_error_capturer.start_capture(script_path)
	if is_full_class:
		_execute_full_class(instance, ctx, result)
	else:
		_execute_snippet(instance, ctx, result)
	captured_errors = _error_capturer.stop_capture()

	result.outputs = ctx.get_outputs()

	if captured_errors.size() > 0:
		result.run_success = false
		result.run_error = "\n".join(captured_errors)

	instance = null
	return result


func _is_full_class(code: String) -> bool:
	return "extends" in code


func _wrap_snippet(code: String) -> String:
	# 第一步：将独立 print() 语句捕获到 executeContext
	code = _capture_print_statements(code)

	var lines = code.split("\n")
	var indented = ""
	for line in lines:
		indented += "\t" + line + "\n"

	return "@tool\nextends RefCounted\n\nvar executeContext: RefCounted\n\nfunc run(_ec: RefCounted):\n\texecuteContext = _ec\n" + indented


func _capture_print_statements(code: String) -> String:
	# 将独立的 print(...) 语句转换为 executeContext.output("print", str(...))
	# 策略: 逐行扫描，每行独立判断。转换后用占位符避免对 output("print", ...) 重复扫描
	var result = ""
	var scan_from = 0  # 下一轮扫描的起始位置
	var length = code.length()

	while scan_from < length:
		# 在 [scan_from, length) 范围内找下一个 "print("
		var next_print = _find_string(code, "print(", scan_from)
		if next_print < 0:
			# 没有更多 print 了，复制剩余并退出
			result += code.substr(scan_from)
			break

		# 复制到 print 之前的内容
		result += code.substr(scan_from, next_print - scan_from)

		# 验证这是独立的 print(（前面不是标识符字符）
		if next_print > 0:
			var prev = code[next_print - 1]
			if (prev >= "a" and prev <= "z") or (prev >= "A" and prev <= "Z") or (prev >= "0" and prev <= "9") or prev == "_":
				# 是嵌入的 print(...)，不替换，只复制
				result += "print"
				scan_from = next_print + 1
				continue

		# 找 print() 的参数
		var arg_start = next_print + 6
		var depth = 1
		var j = arg_start
		var in_string = false
		var string_char = ""

		while j < length and depth > 0:
			var c = code[j]
			if not in_string:
				if c == "(":
					depth += 1
				elif c == ")":
					depth -= 1
				elif c == '"' or c == "'":
					in_string = true
					string_char = c
			else:
				if c == string_char and (j == 0 or code[j - 1] != "\\"):
					in_string = false
			j += 1

		if depth != 0:
			# 括号不匹配，原样复制
			result += code.substr(next_print)
			scan_from = next_print + 1
			continue

		var args = code.substr(arg_start, j - 1 - arg_start)

		# 检查 print 后面：分号？还是换行/空白？
		var k = j
		while k < length and (code[k] == " " or code[k] == "\t"):
			k += 1

		var has_semicolon = k < length and code[k] == ";"
		# 找行尾（换行或文件末尾）
		var line_end = k
		while line_end < length and code[line_end] != "\n" and code[line_end] != "\r":
			line_end += 1

		var remaining = code.substr(k, line_end - k).strip_edges()
		var is_line_end = remaining == "" or remaining == ";"

		if has_semicolon or is_line_end:
			# 独立 print 语句 → 替换（用占位符避免对参数内的 "print" 递归）
			result += "executeContext.output(\"__PK__\", str(" + args + "))"
			if has_semicolon:
				result += ";"
			# 下一轮扫描从换行后开始
			scan_from = k
			if has_semicolon:
				scan_from += 1
			# 跳过该行剩余的空白和换行（保持原有结构）
			while scan_from < length and (code[scan_from] == "\n" or code[scan_from] == "\r"):
				result += code[scan_from]
				scan_from += 1
		else:
			# 嵌入在表达式中的 print(...)，不替换
			result += "print"
			scan_from = next_print + 1

	# 把占位符替换回 "print"
	return result.replace("__PK__", "print")


func _find_string(text: String, pattern: String, from: int) -> int:
	var idx = text.find(pattern, from)
	return idx


func _ensure_tool_annotation(code: String) -> String:
	if code.strip_edges().begins_with("@tool"):
		return code
	return "@tool\n" + code


func _execute_snippet(instance: RefCounted, execute_context: ExecutionContext, result: Dictionary) -> void:
	instance.run(execute_context)
	result.run_success = true


func _execute_full_class(instance: RefCounted, execute_context: ExecutionContext, result: Dictionary) -> void:
	if not instance.has_method("execute"):
		result.run_error = "Full class mode requires an 'execute(executeContext)' method"
		return
	instance.execute(execute_context)
	result.run_success = true


func _error_code_to_string(error_code: int) -> String:
	match error_code:
		ERR_PARSE_ERROR:
			return "Parse error in script"
		ERR_COMPILATION_FAILED:
			return "Script compilation failed"
		ERR_SCRIPT_FAILED:
			return "Script execution failed"
		_:
			return "Compile error (code: %d)" % error_code


class _CompileErrorCapturer extends Logger:
	# Godot 4.x Logger.ErrorType 枚举值（使用硬编码避免兼容性问题）
	const _ERROR_TYPE_ERROR: int = 0
	const _ERROR_TYPE_WARNING: int = 1
	const _ERROR_TYPE_SCRIPT: int = 2

	var _capturing: bool = false
	var _filter_path: String = ""
	var _captured: PackedStringArray = PackedStringArray()
	var _mutex: Mutex = Mutex.new()

	func start_capture(script_path: String) -> void:
		_mutex.lock()
		_captured.clear()
		_filter_path = script_path
		_capturing = true
		_mutex.unlock()

	func stop_capture() -> PackedStringArray:
		_mutex.lock()
		_capturing = false
		_filter_path = ""
		var result = _captured.duplicate()
		_captured.clear()
		_mutex.unlock()
		return result

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
		_mutex.lock()
		if not _capturing:
			_mutex.unlock()
			return
		if not file.begins_with(_filter_path):
			_mutex.unlock()
			return
		# 捕获脚本错误和警告（Godot 4.6: 0=ERROR, 1=WARNING, 2=SCRIPT）
		if error_type == _ERROR_TYPE_ERROR or error_type == _ERROR_TYPE_WARNING or error_type == _ERROR_TYPE_SCRIPT:
			var msg = rationale if rationale != "" else code
			if msg != "":
				_captured.append(msg)
		_mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		pass
