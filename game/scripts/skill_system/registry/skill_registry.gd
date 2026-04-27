## SkillRegistry — 全局技能数据注册中心
## 启动时加载所有 .tres 技能定义，提供查询 API
class_name SkillRegistry
extends Node

const SKILL_DEF_CLASS := preload("res://scripts/skill_system/registry/skill_def.gd")
const SKILL_VISUAL_DEF_CLASS := preload("res://scripts/skill_system/registry/skill_visual_def.gd")

var _skill_map: Dictionary = {}      # skill_id → SkillDef Resource
var _visual_map: Dictionary = {}     # skill_id → SkillVisualDef Resource
var _effect_factory: Dictionary = {} # effect_type → Effect class path
var _ready_flag: bool = false

signal registry_ready(skill_count: int)
signal registration_error(skill_id: String, message: String)

func _ready() -> void:
	print("[SkillRegistry] Ready - use initialize() from SkillRoot")
	_setup_effect_factory()

## 初始化：加载所有技能数据
func initialize() -> void:
	_setup_effect_factory()
	_load_all_skills()
	_ready_flag = true
	print("[SkillRegistry] Initialized: %d skills loaded" % _skill_map.size())
	registry_ready.emit(_skill_map.size())

func is_ready() -> bool:
	return _ready_flag

## 注册技能定义
func register_skill(skill_def: Resource) -> void:
	if skill_def == null:
		push_error("[SkillRegistry] Cannot register null skill")
		return
	
	if not skill_def.is_valid():
		push_error("[SkillRegistry] Invalid skill: missing skill_id")
		registration_error.emit("", "Invalid skill data")
		return
	
	if _skill_map.has(skill_def.skill_id):
		push_warning("[SkillRegistry] Skill '%s' already registered, skipping" % skill_def.skill_id)
		return
	
	_skill_map[skill_def.skill_id] = skill_def

## 注册视觉定义
func register_skill_visual(skill_id: String, visual_def: Resource) -> void:
	if not _skill_map.has(skill_id):
		push_error("[SkillRegistry] Cannot register visual for unknown skill: %s" % skill_id)
		return
	
	_visual_map[skill_id] = visual_def

## ── 查询 API ──

func get_skill(skill_id: String) -> Resource:
	return _skill_map.get(skill_id)

func get_skill_visual(skill_id: String) -> Resource:
	return _visual_map.get(skill_id)

func get_all_skills() -> Array[Resource]:
	var result: Array[Resource]
	for s in _skill_map.values():
		result.append(s)
	return result

func get_all_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _skill_map.keys():
		result.append(str(k))
	return result

func has_skill(skill_id: String) -> bool:
	return _skill_map.has(skill_id)

func get_skill_count() -> int:
	return _skill_map.size()

## 获取英雄的所有技能
func get_hero_skills(skill_ids: Array[String]) -> Array[SkillDef]:
	var result: Array[SkillDef] = []
	for id in skill_ids:
		var skill = get_skill(id)
		if skill != null:
			result.append(skill)
	return result

## 按类别获取英雄技能
func get_hero_skill_by_category(skill_ids: Array[String], category: int) -> SkillDef:
	for id in skill_ids:
		var skill = get_skill(id)
		if skill != null and skill.category == category:
			return skill
	return null

## 创建 Effect 实例
func create_effect_instance(effect_type: String) -> SkillEffect:
	var path: String = _effect_factory.get(effect_type, "")
	if path.is_empty():
		push_warning("[SkillRegistry] Unknown effect type: %s, using EmitProjectileEffect" % effect_type)
		return EmitProjectileEffect.new()
	return load(path).new()

## ── 内部 ──

func _setup_effect_factory() -> void:
	_effect_factory = {
		"emit_projectile": "res://scripts/skill_system/core/effects/emit_projectile.gd",
		"area_damage": "res://scripts/skill_system/core/effects/area_damage.gd",
		"apply_status": "res://scripts/skill_system/core/effects/apply_status.gd",
		"emit_burst": "res://scripts/skill_system/core/effects/emit_burst.gd",
	}

func _load_all_skills() -> void:
	var defs_path := "res://resources/skills/skill_defs/"
	var visuals_path := "res://resources/skills/skill_visual_defs/"
	
	var defs_dir := DirAccess.open(defs_path)
	if defs_dir == null:
		push_error("[SkillRegistry] FATAL: Cannot open skill_defs directory at: %s" % defs_path)
		push_error("[SkillRegistry] No fallback data available - all skills must be defined in .tres files")
		return
	
	# 加载所有技能定义
	defs_dir.list_dir_begin()
	var file_name := defs_dir.get_next()
	var loaded_count := 0
	var error_count := 0
	
	while file_name != "":
		# 跳过目录条目和非 .tres 文件
		if file_name == "." or file_name == ".." or not file_name.ends_with(".tres"):
			file_name = defs_dir.get_next()
			continue
		
		var full_path := defs_path + file_name
		var skill_def: Resource = load(full_path)
		
		if skill_def == null:
			push_error("[SkillRegistry] Failed to load skill: %s" % full_path)
			error_count += 1
		elif not (skill_def is SkillDef):
			push_warning("[SkillRegistry] Skill at %s is not a SkillDef instance (type: %s)" % [full_path, typeof(skill_def)])
			error_count += 1
		elif not skill_def.is_valid():
			push_warning("[SkillRegistry] Skill at %s has empty skill_id, skipping" % full_path)
			error_count += 1
		else:
			register_skill(skill_def)
			loaded_count += 1
			
			# 从 CSV 数值表格加载战斗数值
			var csv_data := SkillDef.load_csv_for_skill(skill_def.skill_id)
			if not csv_data.is_empty():
				skill_def.load_values_from_csv(csv_data)
			
			# 尝试加载对应的视觉定义
			var visual_def: Resource = load(visuals_path + file_name)
			if visual_def != null and visual_def is SkillVisualDef:
				register_skill_visual(skill_def.skill_id, visual_def)
		
		file_name = defs_dir.get_next()
	
	print("[SkillRegistry] Loaded %d skills, %d errors" % [loaded_count, error_count])
	
	if _skill_map.is_empty():
		push_error("[SkillRegistry] FATAL: No skills loaded! Check skill_defs directory.")
