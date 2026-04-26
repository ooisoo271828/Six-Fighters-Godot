extends CharacterBody2D

## 单位基类 - 英雄和敌人的共同父类

class_name Unit

@export var unit_id: String = ""
@export var display_name: String = ""

var max_hp: float
var current_hp: float
var stats: CombatantStats
var status_effects = null  # EntityStatus
var is_alive: bool = true

# 视觉节点
var _sprite: ColorRect
var _label: Label
var _hp_bar: ColorRect
var _hp_bar_bg: ColorRect

func _ready() -> void:
	status_effects = EntityStatus.new()
	_setup_visuals()

func _setup_visuals() -> void:
	# 身体
	_sprite = ColorRect.new()
	_sprite.size = Vector2(28, 28)
	_sprite.color = Color.WHITE
	add_child(_sprite)
	
	# 名称标签
	_label = Label.new()
	_label.text = display_name
	_label.add_theme_font_size_override("font_size", 11)
	_label.position = Vector2(-20, -24)
	add_child(_label)
	
	# HP条背景
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.size = Vector2(40, 6)
	_hp_bar_bg.color = Color(0.2, 0.2, 0.2)
	_hp_bar_bg.position = Vector2(-20, 16)
	add_child(_hp_bar_bg)
	
	# HP条
	_hp_bar = ColorRect.new()
	_hp_bar.size = Vector2(40, 6)
	_hp_bar.color = Color(0.2, 0.8, 0.2)
	_hp_bar.position = Vector2(-20, 16)
	add_child(_hp_bar)

func setup(p_unit_id: String, p_display_name: String, p_stats: CombatantStats, p_max_hp: float) -> void:
	unit_id = p_unit_id
	display_name = p_display_name
	stats = p_stats
	max_hp = p_max_hp
	current_hp = p_max_hp
	is_alive = true
	
	if _label:
		_label.text = display_name
	
	update_hp_bar()

func take_damage(damage: float) -> void:
	if not is_alive:
		return
	
	current_hp -= damage
	if current_hp <= 0:
		current_hp = 0
		is_alive = false
		die()
	
	update_hp_bar()

func heal(amount: float) -> void:
	if not is_alive:
		return
	current_hp = minf(current_hp + amount, max_hp)
	update_hp_bar()

func update_hp_bar() -> void:
	if _hp_bar and max_hp > 0:
		var ratio := current_hp / max_hp
		_hp_bar.size.x = 40 * ratio
		if ratio < 0.3:
			_hp_bar.color = Color(0.8, 0.2, 0.2)
		elif ratio < 0.6:
			_hp_bar.color = Color(0.8, 0.8, 0.2)
		else:
			_hp_bar.color = Color(0.2, 0.8, 0.2)

func die() -> void:
	queue_free()

func get_hp_fraction() -> float:
	if max_hp <= 0:
		return 0.0
	return current_hp / max_hp

func apply_status_updates(updates: Array[CombatResolver.StatusUpdate], params: CombatParams) -> void:
	for update in updates:
		status_effects.apply_status_update(update.token, update.new_stack_count, update.duration_remaining, params)

func _physics_process(_dt: float) -> void:
	pass
