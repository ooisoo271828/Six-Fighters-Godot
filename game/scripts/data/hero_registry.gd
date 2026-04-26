extends Node
class_name HeroRegistry

## 英雄注册表 - 对应 Web 版本的 heroes.ts

var _heroes: Dictionary = {}

func _ready() -> void:
	_register_all_heroes()

func _register_all_heroes() -> void:
	_register_hero(_create_ironwall())
	_register_hero(_create_ember())
	_register_hero(_create_moss())

func _register_hero(hero: HeroDef) -> void:
	_heroes[hero.hero_id] = hero

func get_hero(hero_id: String) -> HeroDef:
	return _heroes.get(hero_id)

func get_all_hero_ids() -> Array[String]:
	var result: Array[String] = []
	for key in _heroes.keys():
		result.append(key)
	return result

func _create_ironwall() -> HeroDef:
	var hero := HeroDef.new("ironwall", "Ironwall", HeroDef.RoleFamily.FRONTLINER, CombatantStats.create_ironwall())
	hero.set_skills("ironwall_basic", "ironwall_small_a", "ironwall_small_b", "ironwall_ultimate")
	return hero

func _create_ember() -> HeroDef:
	var hero := HeroDef.new("ember", "Ember", HeroDef.RoleFamily.DPS, CombatantStats.create_ember())
	hero.set_skills("ember_basic", "ember_small_a", "ember_small_b", "ember_ultimate")
	return hero

func _create_moss() -> HeroDef:
	var hero := HeroDef.new("moss", "Moss", HeroDef.RoleFamily.SUPPORT, CombatantStats.create_moss())
	hero.set_skills("moss_basic", "moss_small_a", "moss_small_b", "moss_ultimate")
	return hero
