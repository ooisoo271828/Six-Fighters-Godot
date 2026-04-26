extends Resource
class_name CombatantStats

## 战斗属性 - 对应 Web 版本的 CombatantStats

var accuracy: float
var evasion: float
var crit_rate: float
var crit_power: float
var element_resistance_fire: float
var element_resistance_ice: float
var element_resistance_lightning: float
var element_resistance_poison: float
var stun_power: float
var stun_resistance: float

static func create_base() -> CombatantStats:
	var stats := CombatantStats.new()
	stats.accuracy = 40.0
	stats.evasion = 15.0
	stats.crit_rate = 12.0
	stats.crit_power = 20.0
	stats.element_resistance_fire = 0.05
	stats.element_resistance_ice = 0.05
	stats.element_resistance_lightning = 0.05
	stats.element_resistance_poison = 0.05
	stats.stun_power = 10.0
	stats.stun_resistance = 10.0
	return stats

static func create_ironwall() -> CombatantStats:
	var stats := create_base()
	stats.accuracy = 35.0
	stats.evasion = 10.0
	stats.crit_rate = 8.0
	stats.crit_power = 15.0
	stats.stun_power = 18.0
	return stats

static func create_ember() -> CombatantStats:
	var stats := create_base()
	stats.accuracy = 48.0
	stats.evasion = 18.0
	stats.crit_rate = 28.0
	stats.crit_power = 45.0
	return stats

static func create_moss() -> CombatantStats:
	var stats := create_base()
	stats.accuracy = 38.0
	stats.evasion = 22.0
	stats.crit_rate = 10.0
	stats.crit_power = 18.0
	return stats
