extends Unit

## 敌人单位

class_name Enemy

@export var is_boss: bool = false
@export var base_attack: float = 15.0

var _enemy_id: String = ""
var _skill_ids: Array[String] = []
var _skill_index: int = 0     # Boss 多技能轮换

var pattern_cooldown: float = 0.9
var current_pattern_cd: float = 0.0
var boss_phase: int = 0
var phase_timer: float = 0.0

func setup_enemy(p_is_boss: bool, p_max_hp: float, p_base_attack: float, p_defense: float, p_pattern_cd: float) -> void:
	is_boss = p_is_boss
	base_attack = p_base_attack
	pattern_cooldown = p_pattern_cd
	current_pattern_cd = 0.0
	boss_phase = 0
	phase_timer = 0.0

	var stats := CombatantStats.create_base()
	stats.attack = p_base_attack
	stats.defense = p_defense
	setup("enemy" if not p_is_boss else "boss", "Boss" if p_is_boss else "Grunt", stats, p_max_hp)
	set_meta("is_enemy", true)

## 从 EnemyRegistry 数据初始化（新标准接口）
func setup_from_registry(enemy_id: String, data: Dictionary) -> void:
	_enemy_id = enemy_id
	is_boss = enemy_id.begins_with("boss_")

	var stats := CombatantStats.create_base()
	stats.attack = data.get("attack", 500.0)
	stats.defense = data.get("defense", 1765.0)
	stats.accuracy = data.get("accuracy", 40.0)
	stats.evasion = data.get("evasion", 15.0)

	var max_hp: float = data.get("max_hp", 500.0)
	var display_name: String = data.get("display_name", enemy_id)
	var role := "boss" if is_boss else "enemy"
	setup(role, display_name, stats, max_hp)

	pattern_cooldown = data.get("pattern_cooldown", 7.0)
	current_pattern_cd = 0.0
	boss_phase = 0
	phase_timer = 0.0

	_skill_ids.clear()
	for sid in data.get("skill_ids", []):
		_skill_ids.append(sid)
	_skill_index = 0

	set_meta("is_enemy", true)

## 获取下一个技能 ID（Boss 多技能轮换）
func get_next_skill_id() -> String:
	if _skill_ids.is_empty():
		return ""
	var sid := _skill_ids[_skill_index % _skill_ids.size()]
	_skill_index += 1
	return sid

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
