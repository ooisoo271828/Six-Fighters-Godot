class_name HeroStatusCard
extends PanelContainer

## 英雄状态卡片
## 显示头像、名字、血条、3个技能CD

const CARD_WIDTH := 80
const CARD_HEIGHT := 80
const PORTRAIT_SIZE := 36
const HP_BAR_HEIGHT := 6
const SKILL_ICON_SIZE := 18

var _hero: Hero
var _skill_registry: SkillRegistry

# UI 组件
var _portrait_texture: TextureRect
var _name_label: Label
var _hp_bar_bg: ColorRect
var _hp_bar: ColorRect
var _hp_label: Label
var _skill_icons: Array[SkillIcon] = []

# 技能引用
var _skill_small_a: SkillDef
var _skill_small_b: SkillDef
var _skill_ultimate: SkillDef

func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	# 卡片背景样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)

func _ready() -> void:
	_build_ui()

## 初始化卡片数据
func setup(hero: Hero, skill_registry: SkillRegistry) -> void:
	_hero = hero
	_skill_registry = skill_registry

	# 获取技能定义
	if hero.hero_def and skill_registry:
		var skill_ids := hero.hero_def.skill_ids
		_skill_small_a = skill_registry.get_hero_skill_by_category(skill_ids, RoleAI.CAT_SMALL_A)
		_skill_small_b = skill_registry.get_hero_skill_by_category(skill_ids, RoleAI.CAT_SMALL_B)
		_skill_ultimate = skill_registry.get_hero_skill_by_category(skill_ids, RoleAI.CAT_ULTIMATE)

	# 设置头像
	if _portrait_texture and hero.hero_id:
		_portrait_texture.texture = PortraitGenerator.generate(hero.hero_id, PORTRAIT_SIZE * 2)

	# 设置名字
	if _name_label and hero.hero_def:
		_name_label.text = hero.hero_def.display_name

	# 设置技能图标
	_setup_skill_icons()

func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 2)
	add_child(main_vbox)

	# 第一行：头像 + 名字
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 4)
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(top_hbox)

	# 头像
	_portrait_texture = TextureRect.new()
	_portrait_texture.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_texture.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_hbox.add_child(_portrait_texture)

	# 名字
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(_name_label)

	# 第二行：血条
	var hp_container := Control.new()
	hp_container.custom_minimum_size = Vector2(CARD_WIDTH - 8, HP_BAR_HEIGHT + 8)
	hp_container.size = Vector2(CARD_WIDTH - 8, HP_BAR_HEIGHT + 8)
	main_vbox.add_child(hp_container)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.2, 0.2, 0.2)
	_hp_bar_bg.custom_minimum_size = Vector2(CARD_WIDTH - 8, HP_BAR_HEIGHT)
	_hp_bar_bg.size = Vector2(CARD_WIDTH - 8, HP_BAR_HEIGHT)
	_hp_bar_bg.position = Vector2(0, 2)
	hp_container.add_child(_hp_bar_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.2, 0.8, 0.2)
	_hp_bar.custom_minimum_size = Vector2(CARD_WIDTH - 8, HP_BAR_HEIGHT)
	_hp_bar.size = Vector2(CARD_WIDTH - 8, HP_BAR_HEIGHT)
	_hp_bar.position = Vector2(0, 2)
	hp_container.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 8)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hp_label.custom_minimum_size = Vector2(CARD_WIDTH - 8, HP_BAR_HEIGHT + 4)
	_hp_label.size = Vector2(CARD_WIDTH - 8, HP_BAR_HEIGHT + 4)
	_hp_label.position = Vector2(0, 0)
	hp_container.add_child(_hp_label)

	# 第三行：技能图标
	var skill_hbox := HBoxContainer.new()
	skill_hbox.add_theme_constant_override("separation", 4)
	skill_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(skill_hbox)

	for i in range(3):
		var icon := SkillIcon.new()
		_skill_icons.append(icon)
		skill_hbox.add_child(icon)

func _setup_skill_icons() -> void:
	if not _hero or not _skill_registry:
		return

	# 小技能A
	if _skill_small_a and _skill_icons.size() > 0:
		_skill_icons[0].set_icon(SkillIconGenerator.generate(_skill_small_a, false, SKILL_ICON_SIZE * 2))

	# 小技能B
	if _skill_small_b and _skill_icons.size() > 1:
		_skill_icons[1].set_icon(SkillIconGenerator.generate(_skill_small_b, false, SKILL_ICON_SIZE * 2))

	# 大招
	if _skill_ultimate and _skill_icons.size() > 2:
		_skill_icons[2].set_icon(SkillIconGenerator.generate_ultimate(_skill_ultimate, SKILL_ICON_SIZE * 2))
		_skill_icons[2].set_ultimate(true)

## 每帧更新
func update_status() -> void:
	if not _hero or not is_instance_valid(_hero):
		return

	# 更新存活状态
	if not _hero.is_alive:
		modulate = Color(0.4, 0.4, 0.4, 0.7)
		_update_hp_bar(0.0)
		_update_skill_icons_dead()
		return
	else:
		modulate = Color(1, 1, 1, 1)

	# 更新血条
	_update_hp_bar(_hero.get_hp_fraction())

	# 更新技能CD
	_update_skill_icons()

func _update_hp_bar(hp_ratio: float) -> void:
	hp_ratio = clampf(hp_ratio, 0.0, 1.0)
	var bar_width := (CARD_WIDTH - 8) * hp_ratio
	_hp_bar.size.x = bar_width

	# 颜色变化：绿→黄→红
	if hp_ratio > 0.6:
		_hp_bar.color = Color(0.2, 0.8, 0.2)
	elif hp_ratio > 0.3:
		_hp_bar.color = Color(0.8, 0.8, 0.2)
	else:
		_hp_bar.color = Color(0.8, 0.2, 0.2)

	# 血量文字
	if _hero and is_instance_valid(_hero):
		_hp_label.text = "%d/%d" % [_hero.current_hp, _hero.max_hp]

func _update_skill_icons() -> void:
	if not _hero or not _hero.timers:
		return

	var timers: RoleAI.AutonomyTimers = _hero.timers

	# 小技能A - CD比 = timer / cooldown
	if _skill_icons.size() > 0 and _skill_small_a:
		var cd_timer := timers.small_a
		var cd_total := _skill_small_a.cooldown
		var ratio := clampf(cd_timer / cd_total, 0.0, 1.0) if cd_total > 0 else 0.0
		var remaining := maxf(0.0, cd_timer)
		_skill_icons[0].update_cd(ratio, remaining)

	# 小技能B
	if _skill_icons.size() > 1 and _skill_small_b:
		var cd_timer := timers.small_b
		var cd_total := _skill_small_b.cooldown
		var ratio := clampf(cd_timer / cd_total, 0.0, 1.0) if cd_total > 0 else 0.0
		var remaining := maxf(0.0, cd_timer)
		_skill_icons[1].update_cd(ratio, remaining)

	# 大招 - 怒气充能 (rage / 100)
	if _skill_icons.size() > 2:
		var rage := timers.rage
		# 大招显示逻辑：rage满=可用，否则显示充能进度
		# CD ratio = 1.0 - rage/100（越接近0越接近可用）
		var charge_ratio := clampf(rage / RoleAI.MAX_RAGE, 0.0, 1.0)
		var cd_ratio := 1.0 - charge_ratio
		_skill_icons[2].update_cd(cd_ratio, 0.0)

func _update_skill_icons_dead() -> void:
	for icon in _skill_icons:
		icon.update_cd(1.0, 0.0)
