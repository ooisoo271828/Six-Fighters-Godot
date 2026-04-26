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

func set_roster(roster: Array[String]) -> void:
	selected_roster = roster
	EventBus.emit_roster_changed(roster)

func get_roster() -> Array[String]:
	return selected_roster
