class_name SquadEditor
extends Control

## 小队编辑器 — 悬浮弹窗，在基地场景内叠加显示
## 用法：var editor = SquadEditorPopup.new(); ui_layer.add_child(editor)

const MAX_SLOTS := 6
const ROLE_COLORS := {
	0: Color(0.7, 0.7, 0.9),   # FRONTLINER
	1: Color(1.0, 0.7, 0.5),   # DPS
	2: Color(0.5, 0.9, 0.6),   # SUPPORT
}
const ROLE_NAMES := {
	0: "前锋",
	1: "输出",
	2: "辅助",
}

var _hero_registry: HeroRegistry
var _all_hero_ids: Array[String] = []
var _owned_heroes: Array[String] = ["ironwall", "ember", "moss"]
var _squad_slots: Array[String] = []
var _selected_hero_id: String = ""

var _hero_cards: Dictionary = {}
var _slot_buttons: Array[Button] = []
var _count_label: Label
var _backdrop: ColorRect

signal closed
signal applied(roster: Array[String])

func _ready() -> void:
	_hero_registry = HeroRegistry.new()
	add_child(_hero_registry)
	_all_hero_ids.assign(_hero_registry.get_all_hero_ids())

	# 从 GameManager 读取当前阵容
	var roster := GameManager.get_roster()
	_squad_slots.resize(MAX_SLOTS)
	_squad_slots.fill("")
	for i in range(mini(roster.size(), MAX_SLOTS)):
		_squad_slots[i] = roster[i]

	_build_ui()

func _build_ui() -> void:
	# 根节点必须撑满屏幕，子控件的居中锚点才能相对于视口生效
	anchors_preset = Control.PRESET_FULL_RECT

	# 全屏半透明遮罩（阻挡场景交互）
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.5)
	_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# 主面板 — 竖长形，占屏幕约 70%，居中略偏下
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -320
	panel.offset_bottom = 340

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.98)
	style.border_color = Color(0.4, 0.3, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(root_vbox)

	# ── 顶栏 ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "小队编辑"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 13)
	_count_label.modulate = Color(0.7, 0.7, 0.8)
	header.add_child(_count_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# ── 英雄列表（上方，可滚动） ──
	_build_hero_list(root_vbox)

	# ── 阵容站位（下方） ──
	_build_formation_panel(root_vbox)

	# ── 底部按钮 ──
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(bottom)

	var reset_btn := Button.new()
	reset_btn.text = "重置"
	reset_btn.custom_minimum_size = Vector2(70, 32)
	reset_btn.pressed.connect(_on_reset)
	bottom.add_child(reset_btn)

	var apply_btn := Button.new()
	apply_btn.text = "确认编队"
	apply_btn.custom_minimum_size = Vector2(100, 32)
	apply_btn.add_theme_font_size_override("font_size", 13)
	apply_btn.pressed.connect(_on_apply)
	bottom.add_child(apply_btn)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(70, 32)
	back_btn.pressed.connect(_on_close)
	bottom.add_child(back_btn)

	_update_count_label()

# ── 英雄列表 ──

func _build_hero_list(parent: Control) -> void:
	var list_panel := VBoxContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_constant_override("separation", 4)
	parent.add_child(list_panel)

	var list_title := Label.new()
	list_title.text = "全部英雄"
	list_title.add_theme_font_size_override("font_size", 13)
	list_title.modulate = Color(0.8, 0.8, 0.9)
	list_panel.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	list_panel.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for hero_id in _all_hero_ids:
		var card := _create_hero_card(hero_id)
		_hero_cards[hero_id] = card
		grid.add_child(card["container"])

func _create_hero_card(hero_id: String) -> Dictionary:
	var hero_def: HeroDef = _hero_registry.get_hero(hero_id)
	var is_owned := hero_id in _owned_heroes

	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(0, 110)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.18, 0.18, 0.25, 0.9) if is_owned else Color(0.12, 0.12, 0.15, 0.6)
	card_style.border_color = Color(0.3, 0.3, 0.4)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(6)
	container.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	container.add_child(vbox)

	# 英雄模型预览区域
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(0, 50)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.color = _get_hero_color(hero_def)
	if not is_owned:
		preview.modulate = Color(0.3, 0.3, 0.3, 0.8)
	vbox.add_child(preview)

	# 英雄名称
	var name_label := Label.new()
	name_label.text = hero_def.display_name if hero_def else hero_id
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not is_owned:
		name_label.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(name_label)

	# 角色标签
	var role_label := Label.new()
	var role_id := hero_def.role_family if hero_def else 0
	role_label.text = ROLE_NAMES.get(role_id, "未知")
	role_label.add_theme_font_size_override("font_size", 10)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.modulate = ROLE_COLORS.get(role_id, Color.WHITE)
	if not is_owned:
		role_label.modulate = Color(0.4, 0.4, 0.4)
	vbox.add_child(role_label)

	# 锁定标记
	if not is_owned:
		var lock_label := Label.new()
		lock_label.text = "未获得"
		lock_label.add_theme_font_size_override("font_size", 9)
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.modulate = Color(0.6, 0.3, 0.3)
		vbox.add_child(lock_label)

	# 点击事件
	if is_owned:
		container.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_hero_card_clicked(hero_id)
		)

	return {
		"container": container,
		"preview": preview,
		"name_label": name_label,
		"style": card_style,
		"is_owned": is_owned,
	}

func _get_hero_color(hero_def: HeroDef) -> Color:
	if not hero_def:
		return Color(0.5, 0.5, 0.5)
	match hero_def.role_family:
		HeroDef.RoleFamily.FRONTLINER:
			return Color(0.5, 0.5, 0.7)
		HeroDef.RoleFamily.DPS:
			return Color(0.8, 0.5, 0.3)
		HeroDef.RoleFamily.SUPPORT:
			return Color(0.4, 0.7, 0.5)
	return Color(0.5, 0.5, 0.5)

# ── 站位图（锥形/箭头阵型） ──
# 索引: 0=前中, 1=中左, 2=中右, 3=后左, 4=后中, 5=后右
const SLOT_POSITION_NAMES := ["前中", "中左", "中右", "后左", "后中", "后右"]

func _build_formation_panel(parent: Control) -> void:
	var form_panel := VBoxContainer.new()
	form_panel.add_theme_constant_override("separation", 6)
	parent.add_child(form_panel)

	var form_title := Label.new()
	form_title.text = "阵容站位（选择英雄 → 点击站位）"
	form_title.add_theme_font_size_override("font_size", 12)
	form_title.modulate = Color(0.7, 0.7, 0.8)
	form_panel.add_child(form_title)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	form_panel.add_child(vbox)

	# 前排：1 居中
	var row_front := HBoxContainer.new()
	row_front.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row_front)
	_add_slot_to_row(row_front, 0)

	# 中排：2 左右对称
	var row_mid := HBoxContainer.new()
	row_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row_mid.add_theme_constant_override("separation", 12)
	vbox.add_child(row_mid)
	_add_slot_to_row(row_mid, 1)
	_add_slot_to_row(row_mid, 2)

	# 后排：3 均匀分布
	var row_back := HBoxContainer.new()
	row_back.alignment = BoxContainer.ALIGNMENT_CENTER
	row_back.add_theme_constant_override("separation", 8)
	vbox.add_child(row_back)
	_add_slot_to_row(row_back, 3)
	_add_slot_to_row(row_back, 4)
	_add_slot_to_row(row_back, 5)

func _add_slot_to_row(row: HBoxContainer, index: int) -> void:
	var btn := _create_slot_button(index)
	_slot_buttons.append(btn)
	row.add_child(btn)

func _create_slot_button(index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 50)

	var hero_id := _squad_slots[index] if index < _squad_slots.size() else ""
	var pos_name: String = SLOT_POSITION_NAMES[index] if index < SLOT_POSITION_NAMES.size() else ""

	if hero_id != "":
		var hero_def: HeroDef = _hero_registry.get_hero(hero_id)
		btn.text = hero_def.display_name if hero_def else hero_id
		var s := StyleBoxFlat.new()
		s.bg_color = _get_hero_color(hero_def).darkened(0.3)
		s.border_color = _get_hero_color(hero_def)
		s.set_border_width_all(2)
		s.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", s)
	else:
		btn.text = "[%s]" % pos_name
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.15, 0.15, 0.2, 0.5)
		s.border_color = Color(0.3, 0.3, 0.4, 0.5)
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", s)

	btn.pressed.connect(func(): _on_slot_clicked(index))
	return btn

# ── 交互逻辑 ──

func _on_hero_card_clicked(hero_id: String) -> void:
	if _selected_hero_id == hero_id:
		_selected_hero_id = ""
		_highlight_card(hero_id, false)
	else:
		if _selected_hero_id != "":
			_highlight_card(_selected_hero_id, false)
		_selected_hero_id = hero_id
		_highlight_card(hero_id, true)

func _highlight_card(hero_id: String, highlighted: bool) -> void:
	if hero_id not in _hero_cards:
		return
	var card: Dictionary = _hero_cards[hero_id]
	var s: StyleBoxFlat = card["style"]
	if highlighted:
		s.border_color = Color(1.0, 0.85, 0.3)
		s.set_border_width_all(2)
	else:
		s.border_color = Color(0.3, 0.3, 0.4)
		s.set_border_width_all(1)

func _on_slot_clicked(index: int) -> void:
	if _selected_hero_id != "":
		# 检查是否已在其他站位
		for i in range(_squad_slots.size()):
			if _squad_slots[i] == _selected_hero_id:
				_squad_slots[i] = ""

		_squad_slots[index] = _selected_hero_id
		_highlight_card(_selected_hero_id, false)
		_selected_hero_id = ""
	else:
		if _squad_slots[index] != "":
			_squad_slots[index] = ""

	_refresh_slots()
	_update_count_label()

func _refresh_slots() -> void:
	for i in range(MAX_SLOTS):
		var btn: Button = _slot_buttons[i]
		var hero_id := _squad_slots[i] if i < _squad_slots.size() else ""
		var pos_name: String = SLOT_POSITION_NAMES[i] if i < SLOT_POSITION_NAMES.size() else ""
		if hero_id != "":
			var hero_def: HeroDef = _hero_registry.get_hero(hero_id)
			btn.text = hero_def.display_name if hero_def else hero_id
			btn.remove_theme_color_override("font_color")
			var s := StyleBoxFlat.new()
			s.bg_color = _get_hero_color(hero_def).darkened(0.3)
			s.border_color = _get_hero_color(hero_def)
			s.set_border_width_all(2)
			s.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", s)
			btn.add_theme_stylebox_override("hover", s)
		else:
			btn.text = "[%s]" % pos_name
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.15, 0.15, 0.2, 0.5)
			s.border_color = Color(0.3, 0.3, 0.4, 0.5)
			s.set_border_width_all(1)
			s.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", s)

func _update_count_label() -> void:
	var count := 0
	for s in _squad_slots:
		if s != "":
			count += 1
	_count_label.text = "%d / %d" % [count, MAX_SLOTS]

# ── 按钮操作 ──

func _on_reset() -> void:
	_squad_slots.fill("")
	_selected_hero_id = ""
	for hero_id in _hero_cards:
		_highlight_card(hero_id, false)
	_refresh_slots()
	_update_count_label()

func _save_current_roster() -> void:
	# 保存完整6个位置（含空位），不压缩
	GameManager.set_roster(_squad_slots)

func _on_apply() -> void:
	_save_current_roster()
	applied.emit(GameManager.get_roster())
	queue_free()

func _on_close() -> void:
	_save_current_roster()
	closed.emit()
	queue_free()
