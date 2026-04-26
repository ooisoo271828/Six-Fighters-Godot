@tool
extends Control


var _code_edit: CodeEdit
var _result_edit: CodeEdit
var _status_label: Label
var _status_indicator: ColorRect  # 连接状态指示器
var _id_label: LineEdit
var _history_list: ItemList
var _backend: ExecutorBackend
var _rtt_label: Label  # RTT 显示
var _rtt_chart: Control  # RTT 图表

# 断点列表
var _breakpoints_container: VBoxContainer
var _breakpoints_scroll: ScrollContainer
var _breakpoint_items: Array[Dictionary] = []

# 执行历史统计
var _history_stats_label: Label
var _history_chart: Control  # 历史图表

# RTT 历史数据
var _rtt_history: Array[float] = []
var _rtt_ms: float = 0.0
const MAX_RTT_HISTORY := 60  # 最多保存 60 个数据点

# 执行统计
var _exec_stats: Dictionary = {
	"total": 0,
	"success": 0,
	"failed": 0,
	"avg_duration_ms": 0.0,
	"durations": []  # 用于计算平均值的队列
}
const MAX_DURATION_SAMPLES := 100


func initialize(backend: ExecutorBackend) -> void:
	_backend = backend


func _ready() -> void:
	print("[HasturExecutor] Dock ready, initializing UI...")
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# 添加版本标签（调试用）
	var version_label = Label.new()
	version_label.text = "v0.3.1"
	version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(version_label)

	# ========== 状态栏 ==========
	var status_bar = HBoxContainer.new()
	vbox.add_child(status_bar)

	# 连接状态指示器
	_status_indicator = ColorRect.new()
	_status_indicator.custom_minimum_size = Vector2(12, 12)
	_status_indicator.color = Color.RED
	var indicator_style = StyleBoxFlat.new()
	indicator_style.bg_color = Color.RED
	indicator_style.set_corner_radius_all(6)
	_status_indicator.add_theme_stylebox_override("panel", indicator_style)
	status_bar.add_child(_status_indicator)

	_status_label = Label.new()
	_status_label.text = "Disconnected"
	_status_label.add_theme_color_override("font_color", Color.RED)
	status_bar.add_child(_status_label)

	# RTT 显示
	var rtt_container = HBoxContainer.new()
	rtt_container.alignment = BoxContainer.ALIGNMENT_CENTER
	status_bar.add_child(rtt_container)

	var rtt_title = Label.new()
	rtt_title.text = " RTT:"
	rtt_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	rtt_container.add_child(rtt_title)

	_rtt_label = Label.new()
	_rtt_label.text = "-- ms"
	_rtt_label.add_theme_color_override("font_color", Color.GREEN)
	rtt_container.add_child(_rtt_label)

	# RTT 小图表
	_rtt_chart = Control.new()
	_rtt_chart.custom_minimum_size = Vector2(60, 16)
	_rtt_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rtt_chart.draw.connect(_draw_rtt_chart)
	rtt_container.add_child(_rtt_chart)

	_id_label = LineEdit.new()
	_id_label.text = ""
	_id_label.visible = false
	_id_label.editable = false
	_id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_label.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_id_label.custom_minimum_size = Vector2(200, 0)
	_id_label.tooltip_text = "Click and Ctrl+C to copy"
	status_bar.add_child(_id_label)

	# ========== 标签页容器 ==========
	var tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)

	# --- 执行标签页 ---
	var execute_tab = Control.new()
	execute_tab.name = "Execute"
	tab_container.add_child(execute_tab)
	_setup_execute_tab(execute_tab)

	# --- 断点标签页 ---
	var breakpoints_tab = Control.new()
	breakpoints_tab.name = "Breakpoints"
	tab_container.add_child(breakpoints_tab)
	_setup_breakpoints_tab(breakpoints_tab)

	# --- 历史标签页 ---
	var history_tab = Control.new()
	history_tab.name = "History"
	tab_container.add_child(history_tab)
	_setup_history_tab(history_tab)

	# --- 日志标签页 ---
	var logs_tab = Control.new()
	logs_tab.name = "Logs"
	tab_container.add_child(logs_tab)
	_setup_logs_tab(logs_tab)

	if _backend:
		_backend.connection_state_changed.connect(_on_connection_state_changed)
		_backend.execution_completed.connect(_on_execution_completed)
		_backend.history_cleared.connect(_on_history_cleared)
		_backend.rtt_updated.connect(_on_rtt_updated)


func _setup_execute_tab(tab: Control) -> void:
	print("[HasturExecutor] Setting up Execute tab...")
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab.add_child(vbox)

	_code_edit = CodeEdit.new()
	_code_edit.custom_minimum_size = Vector2(0, 200)
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code_edit.placeholder_text = "Enter GDScript code here..."
	vbox.add_child(_code_edit)

	var button = Button.new()
	button.text = "Execute"
	button.pressed.connect(_on_execute_pressed)
	vbox.add_child(button)

	_result_edit = CodeEdit.new()
	_result_edit.custom_minimum_size = Vector2(0, 100)
	_result_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_edit.editable = false
	_result_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(_result_edit)


func _setup_breakpoints_tab(tab: Control) -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab.add_child(vbox)

	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "Active Breakpoints"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var clear_btn = Button.new()
	clear_btn.text = "Clear All"
	clear_btn.pressed.connect(_on_clear_breakpoints)
	header.add_child(clear_btn)
	vbox.add_child(header)

	_breakpoints_scroll = ScrollContainer.new()
	_breakpoints_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_breakpoints_scroll)

	_breakpoints_container = VBoxContainer.new()
	_breakpoints_scroll.add_child(_breakpoints_container)

	# 空状态提示
	var empty_label = Label.new()
	empty_label.text = "No breakpoints set"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_breakpoints_container.add_child(empty_label)


func _setup_history_tab(tab: Control) -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab.add_child(vbox)

	# 统计信息
	var stats_panel = PanelContainer.new()
	vbox.add_child(stats_panel)

	var stats_vbox = VBoxContainer.new()
	stats_panel.add_child(stats_vbox)

	var stats_title = Label.new()
	stats_title.text = "Execution Statistics"
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_vbox.add_child(stats_title)

	_history_stats_label = Label.new()
	_history_stats_label.text = "Total: 0 | Success: 0 | Failed: 0 | Avg: -- ms"
	_history_stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_vbox.add_child(_history_stats_label)

	# 图表
	_history_chart = Control.new()
	_history_chart.custom_minimum_size = Vector2(0, 120)
	_history_chart.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_history_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history_chart.draw.connect(_draw_history_chart)
	vbox.add_child(_history_chart)

	# 历史列表
	var history_header = HBoxContainer.new()
	var history_title = Label.new()
	history_title.text = "Execution History"
	history_header.add_child(history_title)

	var clear_button = Button.new()
	clear_button.text = "Clear History"
	clear_button.pressed.connect(_on_clear_history)
	history_header.add_child(clear_button)
	vbox.add_child(history_header)

	_history_list = ItemList.new()
	_history_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_list.item_selected.connect(_on_history_selected)
	vbox.add_child(_history_list)


func _setup_logs_tab(tab: Control) -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab.add_child(vbox)

	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "Editor Logs (Forwarded to Broker)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_on_refresh_logs)
	header.add_child(refresh_btn)
	vbox.add_child(header)

	var logs_edit = CodeEdit.new()
	logs_edit.name = "LogsEdit"
	logs_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logs_edit.editable = false
	logs_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	logs_edit.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(logs_edit)

	var hint_label = Label.new()
	hint_label.text = "Logs captured by EditorLogCatcher are automatically forwarded to broker-server.\nUse broker API to query: GET /api/executors/{id}/logs"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint_label)


func _process(delta: float) -> void:
	# 定期更新 RTT 显示
	pass  # RTT 通过信号更新


func _draw_rtt_chart() -> void:
	if _rtt_chart == null or not _rtt_chart.is_inside_tree():
		return

	var size = _rtt_chart.size
	if size.x <= 0 or size.y <= 0:
		return

	_rtt_chart.draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.2))

	if _rtt_history.is_empty():
		return

	var max_rtt = 1000.0  # 假设最大 1000ms
	for item in _rtt_history:
		if item > max_rtt:
			max_rtt = item
	max_rtt = max(max_rtt, 100.0)  # 最小 100ms 刻度

	var step = size.x / float(max(1, _rtt_history.size() - 1))
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(_rtt_history.size()):
		var x = i * step
		var y = size.y - (_rtt_history[i] / max_rtt * size.y)
		points.append(Vector2(x, y))

	if points.size() >= 2:
		var color = Color.GREEN
		if _rtt_history[-1] > 500:
			color = Color.RED
		elif _rtt_history[-1] > 200:
			color = Color.YELLOW
		_rtt_chart.draw_polyline(points, color, 1.5)


func _draw_history_chart() -> void:
	if _history_chart == null or not _history_chart.is_inside_tree():
		return

	var size = _history_chart.size
	if size.x <= 0 or size.y <= 0:
		return

	_history_chart.draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.2))

	var durations = _exec_stats.get("durations", [])
	if durations.is_empty():
		return

	var max_dur = 5000.0  # 假设最大 5000ms
	for d in durations:
		if d > max_dur:
			max_dur = d
	max_dur = max(max_dur, 500.0)

	var step = size.x / float(max(1, durations.size() - 1))
	var success_points: PackedVector2Array = PackedVector2Array()
	var fail_points: PackedVector2Array = PackedVector2Array()
	var history = _backend.get_history() if _backend else []
	var offset = max(0, history.size() - durations.size())

	for i in range(durations.size()):
		var x = i * step
		var y = size.y - (durations[i] / max_dur * size.y)
		var is_success = true
		if i + offset < history.size():
			var entry = history[i + offset]
			is_success = entry.result.get("compile_success", false) and entry.result.get("run_success", false)
		if is_success:
			success_points.append(Vector2(x, y))
		else:
			fail_points.append(Vector2(x, y))

	if success_points.size() >= 2:
		_history_chart.draw_polyline(success_points, Color.GREEN, 2.0)
	if fail_points.size() >= 2:
		_history_chart.draw_polyline(fail_points, Color.RED, 2.0)


func _on_execute_pressed() -> void:
	if not _backend:
		return
	var code = _code_edit.text
	_backend.execute_code(code)


func _display_result(result: Dictionary) -> void:
	var text = ""

	if result.compile_success:
		text += "Compile: SUCCESS\n"
	else:
		text += "Compile: FAILED\n"
		text += result.compile_error + "\n"

	if not result.compile_success:
		text += "Run: (skipped)\n"
	elif result.run_success:
		text += "Run: SUCCESS\n"
	else:
		text += "Run: FAILED\n"
		text += result.run_error + "\n"

	if result.outputs.size() > 0:
		text += "---\n"
		text += "Output:\n"
		for entry in result.outputs:
			text += str(entry[0]) + ": " + str(entry[1]) + "\n"

	_result_edit.text = text


func _on_connection_state_changed(connected: bool, executor_id: String) -> void:
	if connected:
		_status_label.text = "Connected"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		_update_indicator_status(1.0)  # 绿色
		_id_label.text = "ID: " + executor_id
		_id_label.visible = true
	else:
		_status_label.text = "Disconnected"
		_status_label.add_theme_color_override("font_color", Color.RED)
		_update_indicator_status(0.0)  # 红色
		_id_label.text = ""
		_id_label.visible = false
		_rtt_label.text = "-- ms"
		_rtt_history.clear()
		_rtt_chart.queue_redraw()


func _update_indicator_status(health: float) -> void:
	# health: 0.0 = 红, 0.5 = 黄, 1.0 = 绿
	var color: Color
	if health >= 0.8:
		color = Color.GREEN
	elif health >= 0.4:
		color = Color.YELLOW
	else:
		color = Color.RED

	if _status_indicator:
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(6)
		_status_indicator.add_theme_stylebox_override("panel", style)


func _on_rtt_updated(rtt_ms: float) -> void:
	_rtt_ms = rtt_ms
	if rtt_ms <= 0:
		_rtt_label.text = "-- ms"
	else:
		_rtt_label.text = "%.0f ms" % rtt_ms

		# 更新 RTT 颜色
		if rtt_ms > 500:
			_rtt_label.add_theme_color_override("font_color", Color.RED)
			_update_indicator_status(0.2)
		elif rtt_ms > 200:
			_rtt_label.add_theme_color_override("font_color", Color.YELLOW)
			_update_indicator_status(0.5)
		else:
			_rtt_label.add_theme_color_override("font_color", Color.GREEN)
			_update_indicator_status(0.9)

	# 添加到历史
	_rtt_history.append(rtt_ms)
	if _rtt_history.size() > MAX_RTT_HISTORY:
		_rtt_history.pop_front()

	_rtt_chart.queue_redraw()


func _on_execution_completed(entry: Dictionary) -> void:
	if entry.source == "local":
		_display_result(entry.result)

	_refresh_history_list()
	_update_exec_stats(entry)


func _refresh_history_list() -> void:
	if not _backend:
		return
	_history_list.clear()
	var history = _backend.get_history()
	for entry in history:
		var status_str = "OK"
		if not entry.result.get("compile_success", false):
			status_str = "FAIL"
		elif not entry.result.get("run_success", false):
			status_str = "FAIL"
		var source_str = entry.source
		var display = "[%s] %s - %dms (%s)" % [status_str, entry.timestamp, entry.duration_ms, source_str]
		var idx = _history_list.add_item(display)
		if status_str == "OK":
			_history_list.set_item_custom_fg_color(idx, Color.GREEN)
		else:
			_history_list.set_item_custom_fg_color(idx, Color.RED)
	if _history_list.item_count > 0:
		_history_list.select(_history_list.item_count - 1)
		_history_list.ensure_current_is_visible()


func _update_exec_stats(entry: Dictionary) -> void:
	_exec_stats.total += 1

	var is_success = entry.result.get("compile_success", false) and entry.result.get("run_success", false)
	if is_success:
		_exec_stats.success += 1
	else:
		_exec_stats.failed += 1

	var duration_ms = entry.duration_ms
	var durations = _exec_stats.durations
	durations.append(duration_ms)
	while durations.size() > MAX_DURATION_SAMPLES:
		durations.pop_front()
	_exec_stats.durations = durations

	_exec_stats.avg_duration_ms = 0.0 if durations.is_empty() else durations.reduce(func(acc, x): return acc + x, 0.0) / durations.size()

	_history_stats_label.text = "Total: %d | Success: %d | Failed: %d | Avg: %.0f ms" % [
		_exec_stats.total,
		_exec_stats.success,
		_exec_stats.failed,
		_exec_stats.avg_duration_ms
	]

	_history_chart.queue_redraw()


func _on_history_selected(index: int) -> void:
	if not _backend:
		return
	var history = _backend.get_history()
	if index < 0 or index >= history.size():
		return
	var entry = history[index]
	_code_edit.text = entry.code
	_display_result(entry.result)


func _on_clear_history() -> void:
	if _backend:
		_backend.clear_history()


func _on_history_cleared() -> void:
	_history_list.clear()
	_exec_stats = {
		"total": 0,
		"success": 0,
		"failed": 0,
		"avg_duration_ms": 0.0,
		"durations": []
	}
	_history_stats_label.text = "Total: 0 | Success: 0 | Failed: 0 | Avg: -- ms"
	_history_chart.queue_redraw()


func _on_clear_breakpoints() -> void:
	_breakpoint_items.clear()
	_refresh_breakpoints_list()


func _refresh_breakpoints_list() -> void:
	# 清空现有项
	for child in _breakpoints_container.get_children():
		child.queue_free()

	if _breakpoint_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No breakpoints set"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_breakpoints_container.add_child(empty_label)
	else:
		for bp in _breakpoint_items:
			_add_breakpoint_item(bp)


func _add_breakpoint_item(bp: Dictionary) -> void:
	var hbox = HBoxContainer.new()

	# 状态指示
	var indicator = ColorRect.new()
	indicator.custom_minimum_size = Vector2(8, 8)
	indicator.color = Color.GREEN if bp.get("enabled", true) else Color.GRAY
	hbox.add_child(indicator)

	# 文件和行号
	var label = Label.new()
	label.text = "%s:%d" % [bp.get("file", "?"), bp.get("line", 0)]
	hbox.add_child(label)

	# 条件（如果有）
	if bp.has("condition") and bp.get("condition", "") != "":
		var cond_label = Label.new()
		cond_label.text = " [if %s]" % bp.get("condition")
		cond_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.3))
		hbox.add_child(cond_label)

	# 删除按钮
	var delete_btn = Button.new()
	delete_btn.text = "X"
	delete_btn.custom_minimum_size = Vector2(24, 20)
	delete_btn.pressed.connect(_on_delete_breakpoint.bind(bp.get("id", "")))
	hbox.add_child(delete_btn)

	_breakpoints_container.add_child(hbox)


func _on_delete_breakpoint(bp_id: String) -> void:
	# 通知 backend 移除断点
	_breakpoint_items = _breakpoint_items.filter(func(bp): return bp.get("id", "") != bp_id)
	_refresh_breakpoints_list()


func _on_refresh_logs() -> void:
	# 获取日志编辑框
	var tabs = find_children("*", "TabContainer")
	if tabs.is_empty():
		return
	var tab = tabs[0]
	var logs_tab_node = null
	for i in range(tab.tab_count):
		if tab.get_tab_title(i) == "Logs":
			logs_tab_node = tab.get_child(i)
			break

	if logs_tab_node:
		var logs_edit = logs_tab_node.find_children("*", "CodeEdit")
		if not logs_edit.is_empty():
			logs_edit[0].text = "[Log forwarding is active - check broker API for logs]\n\n"
			logs_edit[0].text += "GET /api/executors/{id}/logs - All logs\n"
			logs_edit[0].text += "GET /api/executors/{id}/logs/errors - Error logs only"
