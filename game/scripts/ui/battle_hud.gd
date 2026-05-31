class_name BattleHUD
extends Control

## 战斗HUD主控制器
## 管理所有英雄状态卡片，每帧更新数据

const CARD_SPACING := 8
const PANEL_PADDING := 6
const MARGIN_LEFT := 10
const MARGIN_TOP := 10

var _hero_cards: Array[HeroStatusCard] = []
var _cards_container: HBoxContainer
var _panel: PanelContainer

func _init() -> void:
	# 设置为左上角定位
	anchors_preset = Control.PRESET_TOP_LEFT
	offset_left = MARGIN_LEFT
	offset_top = MARGIN_TOP

func _ready() -> void:
	_build_panel()

## 构建面板
func _build_panel() -> void:
	# 外层面板（半透明背景）
	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.7)
	panel_style.border_color = Color(0.25, 0.25, 0.35, 0.8)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(PANEL_PADDING)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# 卡片容器
	_cards_container = HBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", CARD_SPACING)
	_panel.add_child(_cards_container)

## 初始化英雄卡片
func setup_heroes(heroes: Array[Hero], skill_registry: SkillRegistry) -> void:
	# 清除旧卡片
	for card in _hero_cards:
		card.queue_free()
	_hero_cards.clear()

	# 为每个英雄创建卡片
	for hero in heroes:
		if hero and is_instance_valid(hero):
			var card := HeroStatusCard.new()
			_cards_container.add_child(card)
			card.setup(hero, skill_registry)
			_hero_cards.append(card)

	# 调整面板大小
	_update_panel_size()

func _update_panel_size() -> void:
	var card_count := _hero_cards.size()
	if card_count == 0:
		return

	var total_width := card_count * HeroStatusCard.CARD_WIDTH + (card_count - 1) * CARD_SPACING + PANEL_PADDING * 2
	var total_height := HeroStatusCard.CARD_HEIGHT + PANEL_PADDING * 2

	_panel.custom_minimum_size = Vector2(total_width, total_height)
	_panel.size = Vector2(total_width, total_height)
	custom_minimum_size = Vector2(total_width, total_height)
	size = Vector2(total_width, total_height)

## 每帧更新（由arena_scene调用）
func update_all() -> void:
	for card in _hero_cards:
		if card and is_instance_valid(card):
			card.update_status()
