extends Unit

## 敌人单位

class_name Enemy

@export var is_boss: bool = false
@export var base_attack: float = 15.0

var pattern_cooldown: float = 0.9
var current_pattern_cd: float = 0.0
var boss_phase: int = 0
var phase_timer: float = 0.0

func setup_enemy(p_is_boss: bool, p_max_hp: float, p_base_attack: float, p_pattern_cd: float) -> void:
	is_boss = p_is_boss
	base_attack = p_base_attack
	pattern_cooldown = p_pattern_cd
	current_pattern_cd = 0.0
	boss_phase = 0
	phase_timer = 0.0
	
	setup("enemy" if not p_is_boss else "boss", "Boss" if p_is_boss else "Grunt", CombatantStats.create_base(), p_max_hp)

func _ready() -> void:
	super._ready()
	if is_boss:
		modulate = Color(0.5, 0.1, 0.7)  # 紫色
	else:
		modulate = Color(0.7, 0.2, 0.2)  # 红色

func can_attack() -> bool:
	return is_alive and not status_effects.is_stunned()

func get_status() -> EntityStatus:
	return status_effects

func tick_ai(dt: float, _target: Node2D) -> bool:
	if not can_attack():
		return false
	
	current_pattern_cd -= dt
	if current_pattern_cd <= 0:
		current_pattern_cd = pattern_cooldown
		return true  # 触发攻击
	
	return false

func update_boss_phases(dt: float, arena_config: ArenaConfig) -> void:
	if not is_boss or not is_alive:
		return
	
	phase_timer += dt
	var frac := 1.0 - get_hp_fraction()
	var th := arena_config.boss_hp_phase_fraction * float(boss_phase + 1)
	
	if frac >= th or phase_timer >= arena_config.boss_time_phase_sec:
		boss_phase = mini(arena_config.boss_phase_count - 1, boss_phase + 1)
		phase_timer = 0.0
