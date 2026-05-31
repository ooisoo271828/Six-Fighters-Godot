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

	# 设置受伤怒气系数（从HeroDef meta读取）
	var damage_taken_rate: float = p_hero_def.get_meta("damage_taken_rage_rate", 0.0)
	set_meta("damage_taken_rage_rate", damage_taken_rate)
	
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

## 旧版tick_ai已废弃，新版RoleAI使用独立触发 + 释放队列
## 由CombatMediator._update_hero_combat()直接调用RoleAI.check_casts()
## 保留此方法签名以兼容可能的外部调用
func tick_ai(_dt: float, _target: Node2D, _combat_params: CombatParams, _rng_func: Callable) -> Variant:
	return null
