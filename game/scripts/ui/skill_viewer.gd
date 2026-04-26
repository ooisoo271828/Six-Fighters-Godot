extends Control

## 技能查看器 - 浏览所有英雄的技能详情

var skill_registry: SkillRegistry
var hero_registry: HeroRegistry

var hero_list: ItemList
var skill_list: ItemList
var detail_panel: VBoxContainer

func _ready() -> void:
	skill_registry = SkillRegistry.new()
	add_child(skill_registry)
	hero_registry = HeroRegistry.new()
	add_child(hero_registry)
	
	_setup_ui()
	_load_heroes()

func _setup_ui() -> void:
	# 标题
	var title := Label.new()
	title.text = "技能查看器"
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
	hero_label.text = "英雄"
	hero_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(hero_label)
	
	hero_list = ItemList.new()
	hero_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_list.item_selected.connect(_on_hero_selected)
	left_panel.add_child(hero_list)
	
	# 右侧 - 技能详情
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right_vbox)
	
	var skill_label := Label.new()
	skill_label.text = "技能列表"
	skill_label.add_theme_font_size_override("font_size", 16)
	right_vbox.add_child(skill_label)
	
	skill_list = ItemList.new()
	skill_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_list.item_selected.connect(_on_skill_selected)
	right_vbox.add_child(skill_list)
	
	# 详情面板
	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(detail_panel)

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
	
	# 加载该英雄的技能
	skill_list.clear()
	for skill_id in hero_def.skill_ids:
		var skill := skill_registry.get_skill(skill_id)
		if skill:
			var cat_name := _get_category_display_name(skill.category)
			skill_list.add_item("[%s] %s" % [cat_name, skill.skill_id])
			skill_list.set_item_metadata(skill_list.item_count - 1, skill_id)
	
	# 默认选中第一个技能
	if skill_list.item_count > 0:
		skill_list.select(0)
		_on_skill_selected(0)

func _on_skill_selected(index: int) -> void:
	var skill_id: String = skill_list.get_item_metadata(index)
	var skill := skill_registry.get_skill(skill_id)
	if not skill:
		return
	
	# 清空详情面板
	for child in detail_panel.get_children():
		child.queue_free()
	
	# 技能名称
	var name_label := Label.new()
	name_label.text = skill.skill_id
	name_label.add_theme_font_size_override("font_size", 18)
	detail_panel.add_child(name_label)
	
	# 分类
	var cat_label := Label.new()
	cat_label.text = "分类: %s" % _get_category_display_name(skill.category)
	detail_panel.add_child(cat_label)
	
	# 伤害类型
	var dmg_label := Label.new()
	dmg_label.text = "伤害类型: %s" % _get_damage_type_display_name(skill.damage_type)
	detail_panel.add_child(dmg_label)
	
	# 基础伤害
	var base_dmg_label := Label.new()
	base_dmg_label.text = "基础伤害: %.1f" % skill.base_damage
	detail_panel.add_child(base_dmg_label)
	
	# 冷却
	var cd_label := Label.new()
	cd_label.text = "冷却时间: %.1f 秒" % skill.cooldown
	detail_panel.add_child(cd_label)
	
	# 怒气消耗
	if skill.rage_cost > 0:
		var rage_label := Label.new()
		rage_label.text = "怒气消耗: %.0f" % skill.rage_cost
		detail_panel.add_child(rage_label)
	
	# 眩晕几率
	if skill.stun_chance > 0:
		var stun_label := Label.new()
		stun_label.text = "眩晕几率: %.0f%%" % (skill.stun_chance * 100)
		detail_panel.add_child(stun_label)
	
	# 眩晕持续时间
	if skill.stun_duration > 0:
		var stun_dur_label := Label.new()
		stun_dur_label.text = "眩晕时长: %.1f 秒" % skill.stun_duration
		detail_panel.add_child(stun_dur_label)

func _get_category_display_name(cat: int) -> String:
	match cat:
		0: return "普通攻击"  # BASIC
		1: return "技能A"    # SMALL_A
		2: return "技能B"    # SMALL_B
		3: return "终极技能" # ULTIMATE
	return "未知"

func _get_damage_type_display_name(dmg_type: int) -> String:
	match dmg_type:
		0: return "物理"       # PHYSICAL
		1: return "火焰"       # ELEMENTAL_FIRE
		2: return "冰霜"       # ELEMENTAL_ICE
		3: return "雷电"       # ELEMENTAL_LIGHTNING
		4: return "毒素"       # ELEMENTAL_POISON
	return "未知"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/main.tscn")
