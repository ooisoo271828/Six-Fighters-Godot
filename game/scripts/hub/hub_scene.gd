extends Control

## Hub 场景 - 英雄选择界面

var selected_heroes: Array[String] = ["ironwall", "ember", "moss"]
var hero_buttons: Dictionary = {}
var hero_registry: HeroRegistry

@onready var title_label: Label = $TitleLabel
@onready var desc_label: Label = $DescLabel
@onready var portal_button: Button = $PortalButton
@onready var hero_container: VBoxContainer = $HeroContainer

func _ready() -> void:
	hero_registry = HeroRegistry.new()
	add_child(hero_registry)
	
	_setup_ui()
	_update_button_states()

func _setup_ui() -> void:
	# 标题
	title_label = Label.new()
	title_label.text = "Six Fighter"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(170, 48)
	title_label.add_theme_font_size_override("font_size", 28)
	add_child(title_label)
	
	# 描述
	desc_label = Label.new()
	desc_label.text = "选择 1-3 名英雄，点击进入竞技场"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.position = Vector2(170, 88)
	desc_label.add_theme_font_size_override("font_size", 14)
	add_child(desc_label)
	
	# 英雄选择容器
	hero_container = VBoxContainer.new()
	hero_container.position = Vector2(150, 140)
	hero_container.add_theme_constant_override("separation", 16)
	add_child(hero_container)
	
	# 创建英雄按钮
	for hero_id in hero_registry.get_all_hero_ids():
		_create_hero_button(hero_id)
	
	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.position = Vector2(60, 520)
	btn_row.size = Vector2(420, 64)
	btn_row.add_theme_constant_override("separation", 12)
	add_child(btn_row)
	
	# 技能查看器按钮
	var skill_btn := Button.new()
	skill_btn.text = "技能查看器"
	skill_btn.custom_minimum_size = Vector2(120, 48)
	skill_btn.pressed.connect(_on_skill_viewer_pressed)
	btn_row.add_child(skill_btn)
	
	# 角色查看器按钮
	var hero_btn := Button.new()
	hero_btn.text = "角色查看器"
	hero_btn.custom_minimum_size = Vector2(120, 48)
	hero_btn.pressed.connect(_on_hero_viewer_pressed)
	btn_row.add_child(hero_btn)
	
	# 进入按钮
	portal_button = Button.new()
	portal_button.text = "进入竞技场"
	portal_button.custom_minimum_size = Vector2(140, 48)
	portal_button.add_theme_font_size_override("font_size", 18)
	portal_button.pressed.connect(_on_portal_pressed)
	btn_row.add_child(portal_button)

func _create_hero_button(hero_id: String) -> void:
	var hero_def: HeroDef = hero_registry.get_hero(hero_id)
	if not hero_def:
		return
	
	var container := HBoxContainer.new()
	
	var label := Label.new()
	label.text = "%s [%s]" % [hero_def.display_name, hero_def.get_role_name()]
	label.add_theme_font_size_override("font_size", 16)
	container.add_child(label)
	
	var button := Button.new()
	button.text = "选择"
	button.custom_minimum_size = Vector2(80, 40)
	button.pressed.connect(func(): _toggle_hero(hero_id, button, label, hero_def))
	container.add_child(button)
	
	hero_buttons[hero_id] = {"button": button, "label": label, "def": hero_def}
	hero_container.add_child(container)

func _toggle_hero(hero_id: String, button: Button, label: Label, _hero_def: HeroDef) -> void:
	if hero_id in selected_heroes:
		if selected_heroes.size() <= 1:
			return  # 至少保留一个英雄
		selected_heroes.erase(hero_id)
		button.text = "选择"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		if selected_heroes.size() >= 3:
			return  # 最多3个英雄
		selected_heroes.append(hero_id)
		button.text = "取消"
		label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	
	_update_button_states()

func _update_button_states() -> void:
	for hero_id in hero_buttons:
		var data = hero_buttons[hero_id]
		if hero_id in selected_heroes:
			data["button"].text = "取消"
			data["label"].add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			data["button"].text = "选择"
			data["label"].add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _on_portal_pressed() -> void:
	if selected_heroes.is_empty():
		return
	
	GameManager.set_roster(selected_heroes)
	get_tree().change_scene_to_file("res://scenes/arena/main.tscn")

func _on_skill_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/viewer/skill_viewer.tscn")

func _on_hero_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/viewer/hero_viewer.tscn")
