class_name GDScriptExecutor

# 错误收集器（可选，由 BrokerClient 注入）
var _error_collector: ErrorCollector = null
var _error_capturer: _CompileErrorCapturer


func _init() -> void:
	_error_capturer = _CompileErrorCapturer.new()
	OS.add_logger(_error_capturer)


func set_error_collector(collector: ErrorCollector) -> void:
	_error_collector = collector


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		OS.remove_logger(_error_capturer)
		_error_capturer = null


# 向错误收集器报告错误（异步，不阻塞）
func _emit_error_to_collector(error_type: String, message: String, script_path: String = "") -> void:
	if _error_collector == null:
		return
	match error_type:
		"compile_error":
			_error_collector.capture_compile_error(message, script_path)
		"runtime_error":
			_error_collector.capture_runtime_error(message, [], script_path)
		_:
			_error_collector.capture_runtime_error(message, [], script_path)


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
			# 报告给错误收集器
			for err_msg in captured_errors:
				_emit_error_to_collector("compile_error", err_msg, script_path)
		else:
			result.compile_error = _error_code_to_string(compile_err)
			_emit_error_to_collector("compile_error", _error_code_to_string(compile_err), script_path)
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
	# 捕获 print() 调用到 executeContext
	code = _capture_print_statements(code)
	# 捕获变量 watch() 调用
	code = _capture_watch_statements(code)

	var lines = code.split("\n")
	var indented = ""
	for line in lines:
		indented += "\t" + line + "\n"

	return "@tool\nextends RefCounted\n\nvar executeContext\n\nfunc run():\n" + indented


func _capture_watch_statements(code: String) -> String:
	# 将 watch(var_name) 或 watch(expression) 转换为 executeContext.set_variable()
	# 匹配模式: watch(...) 后跟 ; 或换行
	var result = ""
	var pos = 0
	var length = code.length()

	while pos < length:
		var next_watch = code.find("watch(", pos)
		if next_watch == -1:
			result += code.substr(pos)
			break

		result += code.substr(pos, next_watch - pos)

		var bracket_start = next_watch + 6  # "watch(" 的长度
		var bracket_end = _find_matching_bracket(code, bracket_start - 1, "(", ")")
		if bracket_end == -1:
			result += code.substr(next_watch)
			break

		var args = code.substr(bracket_start, bracket_end - bracket_start)

		var after_bracket = bracket_end + 1
		while after_bracket < length and code[after_bracket] == " ":
			after_bracket += 1

		var has_semicolon = after_bracket < length and code[after_bracket] == ";"

		if has_semicolon:
			result += "executeContext.set_variable(\"result\", " + args + ")"
			result += ";"
			pos = after_bracket + 1
		else:
			var line_end = code.find("\n", after_bracket)
			if line_end == -1:
				result += "executeContext.set_variable(\"result\", " + args + ")"
				pos = length
			else:
				var remaining = code.substr(after_bracket, line_end - after_bracket).strip_edges()
				if remaining == "":
					result += "executeContext.set_variable(\"result\", " + args + ")"
					pos = line_end + 1
				else:
					result += code.substr(next_watch, bracket_end - next_watch + 1)
					pos = bracket_end + 1

	return result


func _capture_print_statements(code: String) -> String:
	# 将独立的 print() 语句转换为 executeContext.output("print", ...)
	# 匹配模式: print(...) 后跟 ; 或换行
	var result = ""
	var pos = 0
	var length = code.length()

	while pos < length:
		# 跳过字符串字面量和注释
		var next_print = code.find("print(", pos)
		if next_print == -1:
			result += code.substr(pos)
			break

		# 复制到 print 之前的内容
		result += code.substr(pos, next_print - pos)

		# 找到匹配的括号
		var bracket_start = next_print + 6  # "print(" 的长度
		var bracket_end = _find_matching_bracket(code, bracket_start - 1, "(", ")")
		if bracket_end == -1:
			result += code.substr(next_print)
			break

		# 提取 print 的参数
		var args = code.substr(bracket_start, bracket_end - bracket_start)

		# 检查 print 后面是否有分号
		var after_bracket = bracket_end + 1
		while after_bracket < length and code[after_bracket] == " ":
			after_bracket += 1

		var has_semicolon = after_bracket < length and code[after_bracket] == ";"

		# 生成转换后的代码
		if has_semicolon:
			result += "executeContext.output(\"print\", str(" + args + "))"
			result += ";"
			pos = after_bracket + 1
		else:
			# 检查是否是行尾
			var line_end = code.find("\n", after_bracket)
			if line_end == -1:
				result += "executeContext.output(\"print\", str(" + args + "))"
				pos = length
			else:
				# 检查这一行后面是否只有空白
				var remaining = code.substr(after_bracket, line_end - after_bracket).strip_edges()
				if remaining == "":
					result += "executeContext.output(\"print\", str(" + args + "))"
					pos = line_end + 1
				else:
					result += code.substr(next_print, bracket_end - next_print + 1)
					pos = bracket_end + 1

	return result


func _find_matching_bracket(text: String, start: int, open: String, close: String) -> int:
	var depth = 1
	var i = start + 1
	while i < text.length() and depth > 0:
		var c = text[i]
		if c == open:
			depth += 1
		elif c == close:
			depth -= 1
		elif c == "\"" or c == "'":
			i = _find_string_end(text, i, c)
		i += 1
	return i if depth == 0 else -1


func _find_string_end(text: String, start: int, quote: String) -> int:
	var i = start + 1
	while i < text.length():
		if text[i] == quote and (i == 0 or text[i - 1] != "\\"):
			return i
		i += 1
	return text.length()


func _ensure_tool_annotation(code: String) -> String:
	if code.strip_edges().begins_with("@tool"):
		return code
	return "@tool\n" + code


func _execute_snippet(instance: RefCounted, execute_context: ExecutionContext, result: Dictionary) -> void:
	instance.executeContext = execute_context
	instance.run()
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
	var _capturing: bool = false
	var _filter_path: String = ""
	var _captured: PackedStringArray = PackedStringArray()
	var _mutex: Mutex = Mutex.new()
	var _error_collector: ErrorCollector = null  # 外部错误收集器
	var _current_script_path: String = ""

	# 设置错误收集器
	func set_error_collector(collector: ErrorCollector) -> void:
		_error_collector = collector

	func start_capture(script_path: String) -> void:
		_mutex.lock()
		_captured.clear()
		_filter_path = script_path
		_capturing = true
		_current_script_path = script_path
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
		if error_type == Logger.ERROR_TYPE_SCRIPT and file.begins_with(_filter_path):
			var msg = rationale if rationale != "" else code
			if msg != "":
				_captured.append(msg)

			# 同时转发到错误收集器（如果存在）
			if _error_collector != null:
				var stack: Array = []
				for trace in script_backtraces:
					if trace is Dictionary:
						stack.append({
							"file": trace.get("file", ""),
							"line": trace.get("line", 0),
							"function": trace.get("function", ""),
							"source": trace.get("source", "")
						})

				# 异步调用，避免死锁
				var collector = _error_collector
				var error_msg = msg
				var script_file = file
				var error_line = line
				var error_stack = stack
				_mutex.unlock()

				# 在主线程安全调用
				call_deferred("_emit_to_collector", error_msg, script_file, error_line, error_stack)
				return
		_mutex.unlock()

	func _emit_to_collector(msg: String, file: String, line: int, stack: Array) -> void:
		if _error_collector != null:
			_error_collector.capture_script_error(file, line, "script_error", msg, stack)

	func _log_message(message: String, error: bool) -> void:
		# 捕获 print 输出和警告
		_mutex.lock()
		if _capturing and _error_collector != null:
			var collector = _error_collector
			var msg = message
			_mutex.unlock()
			call_deferred("_emit_output_to_collector", msg, error)
		else:
			_mutex.unlock()

	func _emit_output_to_collector(msg: String, is_error: bool) -> void:
		if _error_collector != null:
			var output_type = "warning" if is_error else "print"
			_error_collector.capture_output(output_type, msg)
