extends Control

## 角色模型查看器 - 浏览英雄的属性和外观

var hero_registry: HeroRegistry

var hero_list: ItemList
var preview_container: Control
var stat_labels: Dictionary = {}

var current_hero: HeroDef = null
var preview_hero: Hero = null

func _ready() -> void:
	hero_registry = HeroRegistry.new()
	add_child(hero_registry)
	
	_setup_ui()
	_load_heroes()

func _setup_ui() -> void:
	# 标题
	var title := Label.new()
	title.text = "角色模型查看器"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 16
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	
	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(16, 16)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	
	# 主布局 - 水平分割
	var hsplit := HSplitContainer.new()
	hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hsplit.offset_left = 16
	hsplit.offset_top = 60
	hsplit.offset_right = -16
	hsplit.offset_bottom = -16
	hsplit.split_offset = 160
	add_child(hsplit)
	
	# 左侧 - 英雄列表
	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(left_panel)
	
	var hero_label := Label.new()
	hero_label.text = "英雄列表"
	hero_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(hero_label)
	
	hero_list = ItemList.new()
	hero_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_list.item_selected.connect(_on_hero_selected)
	left_panel.add_child(hero_list)
	
	# 右侧 - 详情面板
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right_vbox)
	
	# 预览区域
	var preview_label := Label.new()
	preview_label.text = "外观预览"
	preview_label.add_theme_font_size_override("font_size", 16)
	right_vbox.add_child(preview_label)
	
	preview_container = Control.new()
	preview_container.custom_minimum_size = Vector2(300, 200)
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(preview_container)
	
	# 属性面板
	var stat_label := Label.new()
	stat_label.text = "战斗属性"
	stat_label.add_theme_font_size_override("font_size", 16)
	right_vbox.add_child(stat_label)
	
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(stat_grid)
	
	# 创建属性标签
	var stat_names := {
		"accuracy": "命中",
		"evasion": "闪避",
		"crit_rate": "暴击率",
		"crit_power": "暴击威力",
		"element_resistance_fire": "火焰抗性",
		"element_resistance_ice": "冰霜抗性",
		"element_resistance_lightning": "雷电抗性",
		"element_resistance_poison": "毒素抗性",
		"stun_power": "眩晕强度",
		"stun_resistance": "眩晕抗性"
	}
	
	for key in stat_names:
		var name_label := Label.new()
		name_label.text = stat_names[key] + ":"
		stat_grid.add_child(name_label)
		
		var value_label := Label.new()
		value_label.text = "--"
		stat_grid.add_child(value_label)
		stat_labels[key] = value_label

func _load_heroes() -> void:
	hero_list.clear()
	for hero_id in hero_registry.get_all_hero_ids():
		var hero_def := hero_registry.get_hero(hero_id)
		if hero_def:
			hero_list.add_item("%s [%s]" % [hero_def.display_name, hero_def.get_role_name()])
			hero_list.set_item_metadata(hero_list.item_count - 1, hero_id)

func _on_hero_selected(index: int) -> void:
	var hero_id: String = hero_list.get_item_metadata(index)
	var hero_def := hero_registry.get_hero(hero_id)
	if not hero_def:
		return
	
	current_hero = hero_def
	
	# 更新预览
	_update_preview(hero_def)
	
	# 更新属性显示
	_update_stats(hero_def.base_stats)

func _update_preview(hero_def: HeroDef) -> void:
	# 清除旧的预览
	if preview_hero and is_instance_valid(preview_hero):
		preview_hero.queue_free()
	
	# 创建新的预览英雄
	preview_hero = Hero.new()
	preview_hero.position = preview_container.size / 2
	preview_container.add_child(preview_hero)
	
	# 创建一个临时的 SkillRegistry
	var temp_registry := SkillRegistry.new()
	preview_hero.add_child(temp_registry)
	
	preview_hero.setup_hero(hero_def, 420.0, temp_registry)
	
	# 放大预览
	preview_hero.scale = Vector2(2.5, 2.5)

func _update_stats(stats: CombatantStats) -> void:
	if not stats:
		return
	
	stat_labels["accuracy"].text = "%.1f" % stats.accuracy
	stat_labels["evasion"].text = "%.1f" % stats.evasion
	stat_labels["crit_rate"].text = "%.1f" % stats.crit_rate
	stat_labels["crit_power"].text = "%.1f" % stats.crit_power
	stat_labels["element_resistance_fire"].text = "%.2f" % stats.element_resistance_fire
	stat_labels["element_resistance_ice"].text = "%.2f" % stats.element_resistance_ice
	stat_labels["element_resistance_lightning"].text = "%.2f" % stats.element_resistance_lightning
	stat_labels["element_resistance_poison"].text = "%.2f" % stats.element_resistance_poison
	stat_labels["stun_power"].text = "%.1f" % stats.stun_power
	stat_labels["stun_resistance"].text = "%.1f" % stats.stun_resistance

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/main.tscn")
