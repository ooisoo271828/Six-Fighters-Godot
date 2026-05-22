extends Node

## 游戏管理器 - 全局游戏状态

var combat_params: Resource
var skill_registry: SkillRegistry
var selected_roster: Array[String] = []

func _ready() -> void:
	# 加载战斗参数
	_load_combat_params()

func _load_combat_params() -> void:
	# 从资源文件加载战斗参数
	var params_path := "res://resources/combat_params.tres"
	if ResourceLoader.exists(params_path):
		combat_params = ResourceLoader.load(params_path)
	else:
		# 使用默认参数
		combat_params = _create_default_combat_params()

func _create_default_combat_params() -> Resource:
	var params := preload("res://scripts/combat/combat_params.gd").new()
	
	# 命中判定参数
	params.hit_chance_min = 0.05
	params.hit_chance_max = 0.95
	params.hit_chance_slope = 0.05
	params.hit_chance_bias = 0.0
	params.glancing_min = 0.3
	params.glancing_max = 0.5
	params.deflect_mult = 0.75
	
	# 命中圆桌
	params.hit_roundtable_softmax_k = 2.0
	params.hit_roundtable_min_prob = 0.05
	params.hit_roundtable_min_outcomes = 2
	
	# 暴击参数
	params.crit_chance_min = 0.0
	params.crit_chance_max = 0.8
	params.crit_chance_base = 0.05
	params.crit_chance_rate_scale = 0.5
	params.crit_multiplier_min = 1.5
	params.crit_multiplier_max = 3.0
	params.crit_multiplier_base = 1.5
	params.crit_multiplier_power = 0.8
	
	# 元素抗性
	params.element_damage_multiplier_min = 0.5
	params.element_damage_multiplier_max = 2.0
	params.element_damage_multiplier_base = 1.0
	params.element_damage_multiplier_scale = 1.0
	
	# DOT 参数
	params.dot_tick_interval_sec = 1.0
	
	# Burn
	params.burn_duration_base = 3.0
	params.burn_duration_per_stack = 0.5
	params.burn_stack_max = 5
	params.burn_dot_ratio_base = 0.1
	params.burn_dot_ratio_per_stack = 0.02
	
	# Frost
	params.frost_duration_base = 2.0
	params.frost_duration_per_stack = 0.3
	params.frost_stack_max = 5
	params.frost_dot_ratio_base = 0.05
	params.frost_dot_ratio_per_stack = 0.01
	params.frost_cc_slow_per_stack = 0.1
	params.frost_cc_slow_max = 0.5
	
	# Poison
	params.poison_duration_base = 4.0
	params.poison_duration_per_stack = 0.5
	params.poison_stack_max = 5
	params.poison_dot_ratio_base = 0.08
	params.poison_dot_ratio_per_stack = 0.015
	
	# Shock
	params.shock_duration_base = 2.0
	params.shock_duration_per_stack = 0.3
	params.shock_stack_max = 5
	params.shock_damage_taken_min = 1.0
	params.shock_damage_taken_max = 2.0
	params.shock_damage_taken_base = 1.0
	params.shock_damage_taken_per_stack = 0.15
	
	# Stun
	params.stun_resistance_offset = 10.0
	params.stun_duration_multiplier_base = 1.0
	params.stun_duration_multiplier_scale = 0.2
	params.stun_duration_multiplier_min = 0.5
	params.stun_duration_multiplier_max = 2.0
	params.stun_duration_min_sec = 0.5
	params.stun_duration_max_sec = 2.0
	
	return params

## 编队容量（固定6人）
const SQUAD_SIZE := 6

## 锥形阵型偏移（箭头指向敌人方向）
## 索引: 0=前中, 1=中左, 2=中右, 3=后左, 4=后中, 5=后右
const FORMATION_OFFSETS: Array[Vector2] = [
	Vector2(0, -60),     # 0 前中
	Vector2(-45, 0),     # 1 中左
	Vector2(+45, 0),     # 2 中右
	Vector2(-70, +60),   # 3 后左
	Vector2(0, +60),     # 4 后中
	Vector2(+70, +60),   # 5 后右
]

# ── 阵容读写 ──

func set_roster(roster: Array[String]) -> void:
	selected_roster.resize(SQUAD_SIZE)
	for i in range(SQUAD_SIZE):
		selected_roster[i] = roster[i] if i < roster.size() else ""
	EventBus.emit_roster_changed(selected_roster)

func get_roster() -> Array[String]:
	if selected_roster.size() < SQUAD_SIZE:
		selected_roster.resize(SQUAD_SIZE)
	return selected_roster

## 返回非空英雄ID列表（仅用于需要纯列表的场景，如UI显示）
func get_active_roster() -> Array[String]:
	var result: Array[String] = []
	for hero_id in get_roster():
		if hero_id != "":
			result.append(hero_id)
	return result

## 获取指定槽位的阵型偏移
func get_formation_offset(slot_index: int) -> Vector2:
	return FORMATION_OFFSETS[slot_index % FORMATION_OFFSETS.size()]

# ── 英雄生成（唯一标准接口） ──

## 在指定位置按布阵生成英雄。返回 { "heroes": Array[Hero], "slot_indices": Array[int] }
## config 可选键:
##   hero_registry: HeroRegistry（必填）
##   skill_registry: SkillRegistry（可选，小镇传 null）
##   max_hp: float（默认 420）
##   add_collision_to_first: bool（默认 false，领队加碰撞体）
##   add_shadow: bool（默认 true）
##   hide_hp_bar: bool（默认 false）
func spawn_squad(parent: Node, center_pos: Vector2, config: Dictionary = {}) -> Dictionary:
	var hero_registry: HeroRegistry = config.get("hero_registry")
	var skill_registry = config.get("skill_registry", null)
	var max_hp: float = config.get("max_hp", 420.0)
	var add_collision: bool = config.get("add_collision_to_first", false)
	var add_shadow: bool = config.get("add_shadow", true)
	var hide_hp_bar: bool = config.get("hide_hp_bar", false)

	var roster := get_roster()
	var result_heroes: Array[Hero] = []
	var result_indices: Array[int] = []
	var first := true

	for slot_index in range(roster.size()):
		var hero_id: String = roster[slot_index]
		if hero_id == "":
			continue
		if not hero_registry:
			continue

		var hero_def: HeroDef = hero_registry.get_hero(hero_id)
		if not hero_def:
			continue

		var hero := Hero.new()
		hero.name = "Hero_%s" % hero_id
		hero.position = center_pos + get_formation_offset(slot_index)
		parent.add_child(hero)

		hero.setup_hero(hero_def, max_hp, skill_registry)

		if hide_hp_bar:
			if hero._hp_bar:
				hero._hp_bar.visible = false
			if hero._hp_bar_bg:
				hero._hp_bar_bg.visible = false

		if add_shadow:
			var shadow := ColorRect.new()
			shadow.name = "Shadow"
			shadow.size = Vector2(20, 8)
			shadow.position = Vector2(-10, 14)
			shadow.color = Color(0, 0, 0, 0.3)
			hero.add_child(shadow)

		if add_collision and first:
			var col := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 14.0
			col.shape = circle
			hero.add_child(col)
			first = false

		result_heroes.append(hero)
		result_indices.append(slot_index)

	return { "heroes": result_heroes, "slot_indices": result_indices }
