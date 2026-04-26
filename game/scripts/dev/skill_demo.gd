## SkillDemo — 技能演示器主控
## 用游戏内一致的镜头和单位布局来测试技能表现
extends Node2D

## ── 受体模式 ──
## 每个模式定义了多个靶标相对于锚点的偏移位置
const TARGET_POSITIONS: Dictionary = {
	"single": {
		"name": "单受体",
		"positions": [Vector2(0, -260)],
	},
	"dual": {
		"name": "双目标",
		"positions": [Vector2(-90, -260), Vector2(90, -260)],
	},
	"triangle": {
		"name": "三角阵",
		"positions": [Vector2(0, -210), Vector2(-100, -290), Vector2(100, -290)],
	},
	"scatter": {
		"name": "散开群",
		"positions": [
			Vector2(0, -200), Vector2(-130, -250),
			Vector2(130, -250), Vector2(-70, -320),
			Vector2(70, -320),
		],
	},
	"line": {
		"name": "一字排",
		"positions": [Vector2(-180, -260), Vector2(-90, -260),
			Vector2(0, -260), Vector2(90, -260), Vector2(180, -260)],
	},
}
const TARGET_MODE_KEYS: Array[String] = ["single", "dual", "triangle", "scatter", "line"]
const SPEEDS: Array[float] = [0.5, 1.0, 2.0]
## 速度倍率按钮标签
const SPEED_LABELS: Array[String] = ["0.5×", "1×", "2×"]

## ── 节点引用 ──
@warning_ignore("unused_private_class_variable")
@onready var _camera_anchor: Node2D = $CameraAnchor
@warning_ignore("unused_private_class_variable")
@onready var _camera: Camera2D = $CameraAnchor/Camera2D
@onready var _skill_system: Node = $SkillSystem

## ── 运行时单位 ──
var _caster: Node2D
var _targets: Array[Node2D] = []

## ── 状态 ──
var _current_mode_idx: int = 0
var _selected_skill: String = ""
var _speed_idx: int = 1             # 默认 1×
var _looping: bool = false
var _is_frozen: bool = false        # pause 冻结（Engine.time_scale = 0）
var _is_casting: bool = false       # 正在播放中
var _saved_speed: float = 1.0       # pause 前保存的倍率

## ── UI ──
var _panel: PanelContainer
var _skill_option: OptionButton
var _play_btn: Button
var _pause_btn: Button
var _stop_btn: Button
var _speed_btn: Button
var _mode_btn: Button
var _loop_check: CheckBox
var _status_label: Label

## ── 内部 ──
var _cast_timer: float = 0.0
var _had_projectiles: bool = false   # 本次施放是否发射过投射物

func _ready() -> void:
	Engine.time_scale = 1.0
	_setup_background()
	_setup_caster()
	_setup_ui()
	_setup_skill_system()
	_update_targets()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _setup_background() -> void:
	var bg := Node2D.new()
	bg.name = "Background"
	bg.set_script(preload("res://scripts/dev/demo_bg.gd"))
	add_child(bg)

func _setup_caster() -> void:
	_caster = Node2D.new()
	_caster.name = "Caster"
	_caster.set_script(preload("res://scripts/dev/demo_caster.gd"))
	add_child(_caster)
	# 施法者位置：锚点 + 阵型偏移
	_caster.position = Vector2(0, 170)

## ── 技能系统 ──

func _setup_skill_system() -> void:
	# 等待 SkillSystem 初始化
	await get_tree().create_timer(0.3).timeout
	_refresh_skill_list()

func _refresh_skill_list() -> void:
	var registry = _skill_system.get_node_or_null("SkillRegistry")
	if not registry or not registry.has_method("get_all_skill_ids"):
		_status_label.text = "SkillRegistry 未就绪"
		return

	var ids: Array[String] = registry.get_all_skill_ids()
	if ids.is_empty():
		_status_label.text = "未加载到技能"
		return

	_skill_option.clear()
	for id in ids:
		var def_res = registry.get_skill(id)
		var label = id
		if def_res and "display_name" in def_res and def_res.display_name != "":
			label = "%s（%s）" % [def_res.display_name, id]
		_skill_option.add_item(label)
		_skill_option.set_item_metadata(_skill_option.item_count - 1, id)

	_selected_skill = ids[0]
	_skill_option.select(0)
	_status_label.text = "就绪 — %d 个技能" % ids.size()

func _on_skill_selected(idx: int) -> void:
	if idx < 0:
		return
	var meta = _skill_option.get_item_metadata(idx)
	if meta != null:
		_selected_skill = str(meta)

## ── 靶标管理 ──

func _update_targets() -> void:
	# 清除旧靶标
	for t in _targets:
		if is_instance_valid(t):
			t.queue_free()
	_targets.clear()

	var mode_key = TARGET_MODE_KEYS[_current_mode_idx]
	var mode_def = TARGET_POSITIONS[mode_key]
	var positions: Array = mode_def["positions"]

	for pos in positions:
		var t := Node2D.new()
		t.name = "Target_%s_%d" % [mode_key, _targets.size()]
		t.set_script(preload("res://scripts/dev/demo_target.gd"))
		t.position = pos as Vector2
		add_child(t)
		_targets.append(t)

	# 更新 UI
	if _mode_btn:
		_mode_btn.text = mode_def["name"]

## ── 播放控制 ──

func _on_play_pressed() -> void:
	if _is_casting:
		return
	if _selected_skill.is_empty():
		_status_label.text = "未选择技能"
		return
	Engine.time_scale = SPEEDS[_speed_idx]
	_do_cast()

func _on_pause_pressed() -> void:
	_is_frozen = not _is_frozen
	if _is_frozen:
		_saved_speed = Engine.time_scale
		Engine.time_scale = 0.0
		_pause_btn.text = "▶"
		_status_label.text = "已暂停"
	else:
		Engine.time_scale = _saved_speed
		_pause_btn.text = "⏸"
		_status_label.text = "播放中"

func _on_stop_pressed() -> void:
	_clear_all_projectiles()
	_is_casting = false
	_is_frozen = false
	Engine.time_scale = 1.0
	_pause_btn.text = "⏸"
	_status_label.text = "已停止"

func _on_loop_toggled(toggled: bool) -> void:
	_looping = toggled

func _on_speed_pressed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	_speed_btn.text = SPEED_LABELS[_speed_idx]
	if _is_casting and not _is_frozen:
		Engine.time_scale = SPEEDS[_speed_idx]
	_status_label.text = "倍率: %s" % SPEED_LABELS[_speed_idx]

func _on_mode_pressed() -> void:
	_current_mode_idx = (_current_mode_idx + 1) % TARGET_MODE_KEYS.size()
	_update_targets()
	if not _is_casting:
		_status_label.text = TARGET_POSITIONS[TARGET_MODE_KEYS[_current_mode_idx]]["name"]

## ── 技能施放 ──

func _do_cast() -> void:
	if _skill_system == null:
		_status_label.text = "SkillSystem 不可用"
		return

	# 选第一个靶标作为主目标
	if _targets.is_empty():
		_status_label.text = "无靶标"
		return

	_is_casting = true
	_is_frozen = false
	_had_projectiles = false
	_cast_timer = 0.0
	_pause_btn.text = "⏸"
	_status_label.text = "施放: %s" % _selected_skill

	var primary_target: Node2D = _targets[0]
	_skill_system.cast_skill(_caster, _selected_skill, primary_target)

func _count_active_projectiles() -> int:
	var pool = _skill_system.get_node_or_null("ProjectilePool")
	if pool and pool.has_method("get_active_count"):
		return pool.get_active_count()
	return 0

func _clear_all_projectiles() -> void:
	var pool = _skill_system.get_node_or_null("ProjectilePool")
	if pool and pool.has_method("clear_all"):
		pool.clear_all()

func _process(dt: float) -> void:
	if not _is_casting:
		return

	_cast_timer += dt

	# 检查是否所有投射物都已结束
	var active = _count_active_projectiles()
	if active > 0:
		_had_projectiles = true

	if _had_projectiles and active == 0 and _cast_timer > 0.1:
		_is_casting = false
		if _looping:
			Engine.time_scale = 1.0
			await get_tree().create_timer(0.3).timeout
			if _looping and not _is_casting:  # 防止在循环间隙被 stop
				Engine.time_scale = SPEEDS[_speed_idx]
				_do_cast()
		else:
			Engine.time_scale = 1.0
			_status_label.text = "施放完成"

func _input(event: InputEvent) -> void:
	# 空格键：播放/停止快捷操作
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if _is_casting:
					_on_stop_pressed()
				else:
					_on_play_pressed()
				get_viewport().set_input_as_handled()
			KEY_R:
				# R 键切换循环
				_looping = not _looping
				if _loop_check:
					_loop_check.button_pressed = _looping
				get_viewport().set_input_as_handled()

## ── UI ──

func _setup_ui() -> void:
	var cl := CanvasLayer.new()
	cl.name = "CanvasLayer"
	add_child(cl)

	_panel = PanelContainer.new()
	_panel.name = "ControlPanel"
	cl.add_child(_panel)

	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	_panel.add_theme_stylebox_override("panel", style)

	# 锚定到底部
	_panel.anchor_left = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -104.0
	_panel.offset_bottom = -4.0
	_panel.offset_left = 4.0
	_panel.offset_right = -4.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# ── 第一行 ──
	var row1 := HBoxContainer.new()
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	# 技能下拉
	var skill_label := Label.new()
	skill_label.text = "技能"
	skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row1.add_child(skill_label)

	_skill_option = OptionButton.new()
	_skill_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skill_option.item_selected.connect(_on_skill_selected)
	row1.add_child(_skill_option)

	# 播放按钮组
	var btns := { "▶": "_on_play_pressed", "⏸": "_on_pause_pressed", "⏹": "_on_stop_pressed" }
	for label_text in btns:
		var btn := Button.new()
		btn.text = label_text
		btn.flat = true
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(36, 30)
		btn.connect("pressed", Callable(self, btns[label_text]))
		row1.add_child(btn)
		match label_text:
			"▶": _play_btn = btn
			"⏸": _pause_btn = btn
			"⏹": _stop_btn = btn

	# 速度倍率
	_speed_btn = Button.new()
	_speed_btn.text = SPEED_LABELS[_speed_idx]
	_speed_btn.flat = true
	_speed_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed_btn.add_theme_font_size_override("font_size", 14)
	_speed_btn.pressed.connect(_on_speed_pressed)
	row1.add_child(_speed_btn)

	# ── 第二行 ──
	var row2 := HBoxContainer.new()
	row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_theme_constant_override("separation", 8)
	vbox.add_child(row2)

	# 受体模式切换
	_mode_btn = Button.new()
	_mode_btn.text = TARGET_POSITIONS[TARGET_MODE_KEYS[_current_mode_idx]]["name"]
	_mode_btn.flat = true
	_mode_btn.add_theme_font_size_override("font_size", 13)
	_mode_btn.pressed.connect(_on_mode_pressed)
	row2.add_child(_mode_btn)

	# 循环
	_loop_check = CheckBox.new()
	_loop_check.text = "循环"
	_loop_check.toggled.connect(_on_loop_toggled)
	row2.add_child(_loop_check)

	# 状态标签
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.text = "初始化中..."
	row2.add_child(_status_label)
