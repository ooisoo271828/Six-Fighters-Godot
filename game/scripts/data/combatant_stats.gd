extends Resource
class_name CombatantStats

## 战斗属性 - 对应 Web 版本的 CombatantStats

var attack: float
var defense: float
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
	stats.attack = 500.0
	stats.defense = 1765.0
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
	stats.attack = 300.0
	stats.defense = 6667.0
	stats.accuracy = 48.0
	stats.evasion = 14.0
	stats.crit_rate = 8.0
	stats.crit_power = 15.0
	stats.stun_power = 18.0
	return stats

static func create_ember() -> CombatantStats:
	var stats := create_base()
	stats.attack = 750.0
	stats.defense = 1111.0
	stats.accuracy = 52.0
	stats.evasion = 16.0
	stats.crit_rate = 28.0
	stats.crit_power = 45.0
	return stats

static func create_moss() -> CombatantStats:
	var stats := create_base()
	stats.attack = 500.0
	stats.defense = 2500.0
	stats.accuracy = 50.0
	stats.evasion = 15.0
	stats.crit_rate = 10.0
	stats.crit_power = 18.0
	return stats
