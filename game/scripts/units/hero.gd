extends Unit

## 英雄单位

class_name Hero

@export var hero_id: String = ""
var hero_def: HeroDef
var role_family: HeroDef.RoleFamily
var skill_registry: SkillRegistry
var timers: RoleAI.AutonomyTimers

const ATTACK_RANGE := 155.0
const MOVE_SPEED := 180.0

func setup_hero(p_hero_def: HeroDef, p_max_hp: float, p_skill_registry: SkillRegistry) -> void:
	hero_id = p_hero_def.hero_id
	hero_def = p_hero_def
	role_family = p_hero_def.role_family
	skill_registry = p_skill_registry
	timers = RoleAI.create_timers()
	
	setup(hero_id, p_hero_def.display_name, p_hero_def.base_stats, p_max_hp)
	
	# 设置颜色表示职业
	match role_family:
		HeroDef.RoleFamily.FRONTLINER:
			modulate = Color(0.7, 0.7, 0.9)
		HeroDef.RoleFamily.DPS:
			modulate = Color(1.0, 0.7, 0.5)
		HeroDef.RoleFamily.SUPPORT:
			modulate = Color(0.5, 0.9, 0.6)

func _ready() -> void:
	super._ready()

func can_attack() -> bool:
	return is_alive and not status_effects.is_stunned()

func get_status() -> EntityStatus:
	return status_effects

func tick_ai(dt: float, _target: Node2D, _combat_params: CombatParams, _rng_func: Callable) -> RoleAI.AutonomyPick:
	if not can_attack():
		return null
	
	RoleAI.tick_timers(timers, dt)
	
	# 直接使用保存的 hero_def，不需要从 registry 重新查找
	if not hero_def:
		return null
	
	var reg: SkillRegistry = skill_registry
	if not reg:
		if GameManager and GameManager.skill_registry:
			reg = GameManager.skill_registry
		else:
			return null
	
	var pick := RoleAI.pick_action(hero_def, timers, get_hp_fraction(), reg)
	
	if pick:
		RoleAI.add_rage(timers, 0.0)
	
	return pick
