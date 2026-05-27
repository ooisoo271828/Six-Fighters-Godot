## EnemyRegistry — 从 CSV 加载敌人数据的注册表
## 启动时加载 enemy-values.csv，提供查询 API
class_name EnemyRegistry
extends Node

# enemy_id -> { max_hp, attack, defense, accuracy, evasion, pattern_cooldown, skill_ids: [] }
var _enemy_map: Dictionary = {}
var _ready_flag: bool = false

signal registry_ready(enemy_count: int)

func _ready() -> void:
	print("[EnemyRegistry] Ready - use initialize() from arena or GameManager")

## 初始化：加载敌人数据
func initialize() -> void:
	_load_from_csv()
	_ready_flag = true
	print("[EnemyRegistry] Initialized: %d enemies loaded" % _enemy_map.size())
	registry_ready.emit(_enemy_map.size())

func is_ready() -> bool:
	return _ready_flag

## 获取敌人数据
func get_enemy_data(enemy_id: String) -> Dictionary:
	return _enemy_map.get(enemy_id, {})

## 获取所有敌人 ID
func get_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _enemy_map:
		result.append(k)
	return result

## 获取小怪变体 ID 列表
func get_minion_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _enemy_map:
		if k.begins_with("minion_"):
			result.append(k)
	return result

## 获取精英变体 ID 列表
func get_elite_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _enemy_map:
		if k.begins_with("elite_"):
			result.append(k)
	return result

## 获取 Boss ID 列表
func get_boss_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _enemy_map:
		if k.begins_with("boss_"):
			result.append(k)
	return result

## ── 内部 ──

func _load_from_csv() -> void:
	var csv_path := "res://docs/design/combat-rules/values/enemy-values.csv"

	if not FileAccess.file_exists(csv_path):
		push_error("[EnemyRegistry] CSV file not found: %s" % csv_path)
		return

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("[EnemyRegistry] Cannot open CSV file: %s" % csv_path)
		return

	# 读取表头
	var header_line := file.get_line()
	var headers := header_line.split(",")

	# 找到关键列的索引
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
		push_error("[EnemyRegistry] Invalid CSV format: missing required columns")
		file.close()
		return

	# 临时收集：enemy_id -> { parameter -> { key -> value } }
	var raw_data: Dictionary = {}

	# 读取数据行
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue

		var row := line.split(",")
		if row.size() <= max(category_idx, parameter_idx, key_idx, value_idx):
			continue

		var enemy_id = row[category_idx].strip_edges()
		var parameter = row[parameter_idx].strip_edges()
		var key = row[key_idx].strip_edges()
		var value = row[value_idx].strip_edges()

		if not raw_data.has(enemy_id):
			raw_data[enemy_id] = {}
		if not raw_data[enemy_id].has(parameter):
			raw_data[enemy_id][parameter] = {}

		raw_data[enemy_id][parameter][key] = value

	file.close()

	# 解析为结构化数据
	for enemy_id in raw_data:
		var entry: Dictionary = {}
		var params = raw_data[enemy_id]

		# 解析 stats
		if params.has("stats"):
			var stats = params["stats"]
			entry["display_name"] = stats.get("display_name", enemy_id)
			entry["max_hp"] = float(stats.get("max_hp", "500"))
			entry["attack"] = float(stats.get("attack", "500"))
			entry["defense"] = float(stats.get("defense", "1765"))
			entry["accuracy"] = float(stats.get("accuracy", "40"))
			entry["evasion"] = float(stats.get("evasion", "15"))
			entry["pattern_cooldown"] = float(stats.get("pattern_cooldown", "7.0"))

		# 解析 skills（skill_1, skill_2, skill_3, ...）
		if params.has("skills"):
			var skills = params["skills"]
			var skill_ids: Array[String] = []
			# 按 key 排序确保顺序正确
			var skill_keys: Array = skills.keys()
			skill_keys.sort()
			for sk in skill_keys:
				skill_ids.append(skills[sk])
			entry["skill_ids"] = skill_ids
		else:
			entry["skill_ids"] = []

		_enemy_map[enemy_id] = entry

	print("[EnemyRegistry] Loaded %d enemies from CSV" % _enemy_map.size())
