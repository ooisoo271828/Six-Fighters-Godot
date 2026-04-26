# skill_def.gd
# 技能战斗数据定义（资源 A）
# 包含所有技能的战斗属性，与视觉参数分离

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
