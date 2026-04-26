## ModifierRegistry — 全局 Modifier 数据注册中心
## 启动时加载所有 .tres Modifier 定义，提供查询 API
extends Node

const MODIFIER_DEF_CLASS := preload("res://scripts/skill_system/registry/modifier_def.gd")

var _modifier_map: Dictionary = {}  # modifier_id → ModifierDef Resource
var _ready_flag: bool = false

signal registry_ready(modifier_count: int)
@warning_ignore("unused_signal")
signal registration_error(modifier_id: String, message: String)

func _ready() -> void:
	print("[ModifierRegistry] Ready - use initialize() from SkillRoot")

## 初始化
func initialize() -> void:
	_load_all_modifiers()
	_ready_flag = true
	print("[ModifierRegistry] Initialized: %d modifiers loaded" % _modifier_map.size())
	registry_ready.emit(_modifier_map.size())

func is_ready() -> bool:
	return _ready_flag

## 注册 Modifier 定义
func register_modifier(mod_def: Resource) -> void:
	if mod_def == null:
		push_error("[ModifierRegistry] Cannot register null modifier")
		return
	
	if not mod_def.is_valid():
		push_error("[ModifierRegistry] Invalid modifier: missing modifier_id")
		return
	
	if _modifier_map.has(mod_def.modifier_id):
		push_warning("[ModifierRegistry] Modifier '%s' already registered, skipping" % mod_def.modifier_id)
		return
	
	_modifier_map[mod_def.modifier_id] = mod_def

## ── 查询 API ──

func get_modifier(modifier_id: String) -> Resource:
	return _modifier_map.get(modifier_id)

func get_all_modifiers() -> Array[Resource]:
	var result: Array[Resource]
	for m in _modifier_map.values():
		result.append(m)
	return result

func get_all_modifier_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _modifier_map.keys():
		result.append(str(k))
	return result

func has_modifier(modifier_id: String) -> bool:
	return _modifier_map.has(modifier_id)

func get_modifier_count() -> int:
	return _modifier_map.size()

## 从 ModifierDef 创建实际的 SkillModifier 实例
func create_modifier_instance(modifier_id: String) -> SkillModifier:
	var def := get_modifier(modifier_id)
	if def == null:
		push_warning("[ModifierRegistry] Unknown modifier: %s" % modifier_id)
		return null
	
	var mod := SkillModifier.new()
	mod.modifier_id = def.modifier_id
	mod.modifier_type = def.modifier_type
	mod.priority = def.priority
	mod.trigger_timing = def.trigger_timing
	mod.condition_tag = def.condition_tag
	
	# 类型特定参数
	match def.modifier_type:
		0:  # TRAJECTORY
			# Scatter
			mod.num_projectiles = def.num_projectiles
			mod.fan_angle_deg = def.fan_angle_deg
			# CurvedPath
			mod.curve_type = def.curve_type
			mod.control_point_offset = def.control_point_offset
			mod.travel_time_multiplier = def.travel_time_multiplier
		
		1:  # LIFETIME
			# Bounce
			mod.max_bounces = def.max_bounces
			# Fission
			mod.half_life_distance = def.half_life_distance
			mod.split_count = def.split_count
			mod.scale_factor = def.scale_factor
			mod.damage_factor = def.damage_factor
			mod.split_angle_spread_deg = def.split_angle_spread_deg
			# ProjectileHP
			mod.projectile_hp = def.projectile_hp
			mod.destroy_on_hp_zero = def.destroy_on_hp_zero
		
		2:  # APPEARANCE
			# Expansion
			mod.size_growth_per_distance = def.size_growth_per_distance
			mod.max_scale = def.max_scale
		
		3:  # BEHAVIOR
			# SlowOnHit
			mod.slow_factor = def.slow_factor
			mod.slow_duration = def.slow_duration
		
		4:  # CONDITIONAL
			# ConditionalSuppress
			mod.suppressed_modifier_ids = def.suppressed_modifier_ids.duplicate()
	
	return mod

## 获取单位的所有激活 Modifier（聚合多个来源）
func get_entity_modifiers(
	entity_modifier_ids: Array[String],
	_equipment_modifier_ids: Array[String] = [],
	_talent_modifier_ids: Array[String] = [],
	_aura_modifier_ids: Array[String] = []
) -> Array[SkillModifier]:
	var all_ids: Array[String] = []
	all_ids.append_array(entity_modifier_ids)
	all_ids.append_array(_equipment_modifier_ids)
	all_ids.append_array(_talent_modifier_ids)
	all_ids.append_array(_aura_modifier_ids)
	
	var modifiers: Array[SkillModifier]
	for mod_id in all_ids:
		var mod := create_modifier_instance(mod_id)
		if mod != null:
			modifiers.append(mod)
	
	return modifiers

## ── 内部 ──

func _load_all_modifiers() -> void:
	var path := "res://resources/skills/modifiers/"
	var dir := DirAccess.open(path)
	
	if dir == null:
		push_warning("[ModifierRegistry] No modifiers directory at: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_count := 0
	
	while file_name != "":
		# 跳过目录条目和非 .tres 文件
		if file_name == "." or file_name == ".." or not file_name.ends_with(".tres"):
			file_name = dir.get_next()
			continue
		
		var full_path := path + file_name
		var mod_def: Resource = load(full_path)
		
		if mod_def == null:
			push_error("[ModifierRegistry] Failed to load modifier: %s" % full_path)
		elif not (mod_def is ModifierDef):
			push_warning("[ModifierRegistry] Resource at %s is not a ModifierDef (type: %s)" % [full_path, typeof(mod_def)])
		elif not mod_def.is_valid():
			push_warning("[ModifierRegistry] Modifier at %s has empty modifier_id, skipping" % full_path)
		else:
			register_modifier(mod_def)
			loaded_count += 1
		
		file_name = dir.get_next()
	
	print("[ModifierRegistry] Loaded %d modifiers" % loaded_count)
