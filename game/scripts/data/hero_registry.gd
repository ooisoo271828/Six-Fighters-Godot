extends Node
class_name HeroRegistry

## 英雄注册表 — 从 hero-values.csv 加载

var _heroes: Dictionary = {}
var _ready_flag: bool = false

signal registry_ready(hero_count: int)

func _ready() -> void:
	initialize()

func initialize() -> void:
	_load_from_csv()
	_ready_flag = true
	print("[HeroRegistry] Initialized: %d heroes loaded" % _heroes.size())
	registry_ready.emit(_heroes.size())

func is_ready() -> bool:
	return _ready_flag

func get_hero(hero_id: String) -> HeroDef:
	return _heroes.get(hero_id)

func get_all_hero_ids() -> Array[String]:
	var result: Array[String] = []
	for key in _heroes.keys():
		result.append(key)
	return result

## 获取英雄的 max_hp（从 CSV 数据）
func get_hero_max_hp(hero_id: String) -> float:
	var hero := get_hero(hero_id)
	if hero and hero.stats:
		# max_hp 存在 HeroDef 或直接从 CSV 数据读取
		return hero.get_meta("max_hp", 600.0)
	return 600.0

## ── 内部 ──

func _load_from_csv() -> void:
	var csv_path := "res://docs/design/combat-rules/values/hero-values.csv"

	if not FileAccess.file_exists(csv_path):
		push_error("[HeroRegistry] CSV file not found: %s" % csv_path)
		# 回退到硬编码
		_register_fallback()
		return

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("[HeroRegistry] Cannot open CSV file: %s" % csv_path)
		_register_fallback()
		return

	# 读取表头
	var header_line := file.get_line()
	var headers := header_line.split(",")

	var category_idx := -1
	var parameter_idx := -1
	var key_idx := -1
	var value_idx := -1

	for i in range(headers.size()):
		var h := headers[i].strip_edges()
		if h == "category":
			category_idx = i
		elif h == "parameter":
			parameter_idx = i
		elif h == "key":
			key_idx = i
		elif h == "value":
			value_idx = i

	if category_idx == -1 or parameter_idx == -1 or key_idx == -1 or value_idx == -1:
		push_error("[HeroRegistry] Invalid CSV format: missing required columns")
		file.close()
		_register_fallback()
		return

	# 临时收集：hero_id -> { parameter -> { key -> value } }
	var raw_data: Dictionary = {}

	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue

		var row := line.split(",")
		if row.size() <= max(category_idx, parameter_idx, key_idx, value_idx):
			continue

		var hero_id = row[category_idx].strip_edges()
		var parameter = row[parameter_idx].strip_edges()
		var key = row[key_idx].strip_edges()
		var value = row[value_idx].strip_edges()

		if not raw_data.has(hero_id):
			raw_data[hero_id] = {}
		if not raw_data[hero_id].has(parameter):
			raw_data[hero_id][parameter] = {}

		raw_data[hero_id][parameter][key] = value

	file.close()

	# 解析为 HeroDef
	for hero_id in raw_data:
		var data = raw_data[hero_id]
		_build_hero(hero_id, data)

func _build_hero(hero_id: String, data: Dictionary) -> void:
	var stats := CombatantStats.new()

	# 解析 stats
	if data.has("stats"):
		var s = data["stats"]
		stats.attack = float(s.get("attack", "500"))
		stats.defense = float(s.get("defense", "1765"))
		stats.accuracy = float(s.get("accuracy", "40"))
		stats.evasion = float(s.get("evasion", "15"))
		stats.crit_rate = float(s.get("crit_rate", "12"))
		stats.crit_power = float(s.get("crit_power", "20"))
		stats.stun_power = float(s.get("stun_power", "10"))
		stats.stun_resistance = float(s.get("stun_resistance", "10"))
		# 元素抗性用默认值
		stats.element_resistance_fire = 0.05
		stats.element_resistance_ice = 0.05
		stats.element_resistance_lightning = 0.05
		stats.element_resistance_poison = 0.05

	var display_name: String = ""
	if data.has("stats"):
		display_name = data["stats"].get("display_name", hero_id)

	# 确定角色类型
	var role_family: int = HeroDef.RoleFamily.DPS
	match hero_id:
		"ironwall": role_family = HeroDef.RoleFamily.FRONTLINER
		"ember": role_family = HeroDef.RoleFamily.DPS
		"moss": role_family = HeroDef.RoleFamily.SUPPORT

	var hero := HeroDef.new(hero_id, display_name, role_family, stats)

	# 解析 skills
	if data.has("skills"):
		var skills = data["skills"]
		var skill_keys: Array = skills.keys()
		skill_keys.sort()
		var skill_ids: Array[String] = []
		for sk in skill_keys:
			skill_ids.append(skills[sk])
		# 补齐到 4 个
		while skill_ids.size() < 4:
			skill_ids.append("")
		hero.set_skills(skill_ids[0], skill_ids[1], skill_ids[2], skill_ids[3])

	# 存储 max_hp 到 meta
	var max_hp := 600.0
	if data.has("stats"):
		max_hp = float(data["stats"].get("max_hp", "600"))
	hero.set_meta("max_hp", max_hp)

	_register_hero(hero)

func _register_hero(hero: HeroDef) -> void:
	_heroes[hero.hero_id] = hero

## CSV 加载失败时的回退
func _register_fallback() -> void:
	push_warning("[HeroRegistry] Using fallback hero data")
	# Ember
	var ember_stats := CombatantStats.create_ember()
	var ember := HeroDef.new("ember", "Ember", HeroDef.RoleFamily.DPS, ember_stats)
	ember.set_skills("fireball_basic", "ice_arrow", "", "")
	ember.set_meta("max_hp", 600.0)
	_register_hero(ember)

	# Moss
	var moss_stats := CombatantStats.create_moss()
	var moss := HeroDef.new("moss", "Moss", HeroDef.RoleFamily.SUPPORT, moss_stats)
	moss.set_skills("water_wave", "small_laser_beam", "", "")
	moss.set_meta("max_hp", 600.0)
	_register_hero(moss)

	# Ironwall
	var ironwall_stats := CombatantStats.create_ironwall()
	var ironwall := HeroDef.new("ironwall", "Ironwall", HeroDef.RoleFamily.FRONTLINER, ironwall_stats)
	ironwall.set_skills("burning_hands", "falling_meteor", "", "")
	ironwall.set_meta("max_hp", 600.0)
	_register_hero(ironwall)
