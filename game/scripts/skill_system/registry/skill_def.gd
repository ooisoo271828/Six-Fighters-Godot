# skill_def.gd
# 技能战斗数据定义（资源 A）
# 包含所有技能的战斗属性，与视觉参数分离
# v2.0：支持从 CSV 数值表格加载数值

class_name SkillDef
extends Resource

# ── 基础信息 ──
@export var skill_id: String = ""
@export var display_name: String = ""

# ── 技能类别 ──
@export_enum("BASIC:0", "SMALL_A:1", "SMALL_B:2", "ULTIMATE:3")
var category: int = 0

# ── 战斗属性（B 系核心） ──
@export_enum("PHYSICAL:0", "ELEMENTAL_FIRE:1", "ELEMENTAL_ICE:2", "ELEMENTAL_LIGHTNING:3", "ELEMENTAL_POISON:4")
var damage_type: int = 0
@export var base_damage: float = 25.0
@export var cooldown: float = 2.0
@export var rage_cost: float = 0.0
@export var stun_chance: float = 0.0
@export var stun_duration: float = 0.0

# ── 施法参数 ──
@export var cast_range: float = 300.0
@export var cast_time: float = 0.0       # 0 = 瞬发
@export var telegraph_ms: int = 350      # 预警时间（毫秒）

# ── 目标选取 ──
@export_enum("NEAREST:0", "FARTHEST:1", "LOWEST_HP:2", "HIGHEST_HP:3", "RANDOM:4", "ALL:5")
var target_mode: int = 0
@export var max_targets: int = 1

# ── Effect 类型 ──
@export var effect_type: String = "emit_projectile"

# ── 内置 Modifier（基础配置，运行时会被装备/天赋等覆盖） ──
@export var base_modifier_ids: Array[String] = []

# ── 描述文本（用于 UI） ──
@export_multiline var description: String = ""

# ── CSV 数值加载 ──

## 从 CSV 行数据加载数值
## csv_data 格式：Dictionary { "base_damage": 42, "cooldown": 2.8, ... }
func load_values_from_csv(csv_data: Dictionary) -> void:
	## 基础信息
	#if csv_data.has("skill_id"):
	#	skill_id = csv_data["skill_id"]  # 通常不覆盖，因为 .tres 文件名就是 skill_id
	#if csv_data.has("display_name"):
	#	display_name = csv_data["display_name"]
	
	# 战斗属性
	if csv_data.has("base_damage"):
		base_damage = float(csv_data["base_damage"])
	if csv_data.has("damage_type"):
		# damage_type 是枚举，需要转换
		var dt_str = csv_data["damage_type"]
		match dt_str:
			"physical": damage_type = 0
			"elemental_fire": damage_type = 1
			"elemental_ice": damage_type = 2
			"elemental_lightning": damage_type = 3
			"elemental_poison": damage_type = 4
	if csv_data.has("cooldown"):
		cooldown = float(csv_data["cooldown"])
	if csv_data.has("rage_cost"):
		rage_cost = float(csv_data["rage_cost"])
	if csv_data.has("stun_chance"):
		stun_chance = float(csv_data["stun_chance"])
	if csv_data.has("stun_duration"):
		stun_duration = float(csv_data["stun_duration"])
	
	# 施法参数
	if csv_data.has("cast_range"):
		cast_range = float(csv_data["cast_range"])
	if csv_data.has("cast_time"):
		cast_time = float(csv_data["cast_time"])
	if csv_data.has("telegraph_ms"):
		telegraph_ms = int(csv_data["telegraph_ms"])
	
	# 目标选取
	#if csv_data.has("target_mode"):
	#	target_mode = int(csv_data["target_mode"])
	if csv_data.has("max_targets"):
		max_targets = int(csv_data["max_targets"])
	
	# Effect 类型
	#if csv_data.has("effect_type"):
	#	effect_type = csv_data["effect_type"]
	
	# 行为参数（特殊，因为不是所有技能都有）
	# 这些参数可能不存储在 SkillDef 中，而是存储在 SkillVisualDef 或 Effect 参数中
	# 这里只处理通用参数
	
	print("[SkillDef] Loaded CSV values for %s: base_damage=%.1f, cooldown=%.1f" % [skill_id, base_damage, cooldown])

## 静态方法：从 CSV 文件加载某个 skill_id 的所有数值
## 返回：Dictionary { "base_damage": 42, "cooldown": 2.8, ... }
static func load_csv_for_skill(search_id: String) -> Dictionary:
	var result := {}
	var csv_path := "res://docs/design/combat-rules/values/skill-values.csv"
	
	if not FileAccess.file_exists(csv_path):
		push_error("[SkillDef] CSV file not found: %s" % csv_path)
		return result
	
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("[SkillDef] Cannot open CSV file: %s" % csv_path)
		return result
	
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
		push_error("[SkillDef] Invalid CSV format: missing required columns")
		file.close()
		return result
	
	# 读取数据行
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		
		var row := line.split(",")
		if row.size() <= max(category_idx, parameter_idx, key_idx, value_idx):
			continue
		
		var row_category = row[category_idx].strip_edges()
		if row_category != search_id:
			continue
		
		var _parameter = row[parameter_idx].strip_edges()
		var key = row[key_idx].strip_edges()
		var value = row[value_idx].strip_edges()
		
		# 存储到 result 中
		# 使用 parameter + "_" + key 作为复合键，或者只用 key
		# 这里选择只用 key，因为 parameter 主要用于分类
		result[key] = value
	
	file.close()
	
	if result.is_empty():
		push_warning("[SkillDef] No CSV data found for skill_id: %s" % search_id)
	
	return result

# ── 验证 ──
func is_valid() -> bool:
	return skill_id != "" and base_damage >= 0

# ── 辅助方法 ──
func get_category_name() -> String:
	match category:
		0: return "BASIC"
		1: return "SMALL_A"
		2: return "SMALL_B"
		3: return "ULTIMATE"
	return "UNKNOWN"

func get_damage_type_name() -> String:
	match damage_type:
		0: return "PHYSICAL"
		1: return "ELEMENTAL_FIRE"
		2: return "ELEMENTAL_ICE"
		3: return "ELEMENTAL_LIGHTNING"
		4: return "ELEMENTAL_POISON"
	return "UNKNOWN"

func get_target_mode_name() -> String:
	match target_mode:
		0: return "NEAREST"
		1: return "FARTHEST"
		2: return "LOWEST_HP"
		3: return "HIGHEST_HP"
		4: return "RANDOM"
		5: return "ALL"
	return "NEAREST"
