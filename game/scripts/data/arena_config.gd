extends Resource
class_name ArenaConfig

## 竞技场配置 - 对应 Web 版本的 ArenaConfig

var wave_count: int
var wave_enemy_counts: Array[int]
var spawn_interval_sec: float
var wave_break_sec: float
var minion_base_hp: float
var minion_base_attack: float
var boss_base_hp: float
var boss_phase_count: int
var boss_hp_phase_fraction: float
var boss_time_phase_sec: float
var boss_base_attack: float
var boss_pattern_cooldown_sec: float

static func create_default() -> ArenaConfig:
	var config := ArenaConfig.new()
	config.wave_count = 3
	config.wave_enemy_counts = [4, 6, 8]
	config.spawn_interval_sec = 1.5
	config.wave_break_sec = 3.0
	config.minion_base_hp = 80.0
	config.minion_base_attack = 15.0
	config.boss_base_hp = 600.0
	config.boss_phase_count = 3
	config.boss_hp_phase_fraction = 0.3
	config.boss_time_phase_sec = 20.0
	config.boss_base_attack = 35.0
	config.boss_pattern_cooldown_sec = 2.0
	return config
