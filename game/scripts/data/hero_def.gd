extends Resource
class_name HeroDef

## 角色定义 - 对应 Web 版本的 HeroDef

enum RoleFamily { FRONTLINER, DPS, SUPPORT }

var hero_id: String
var display_name: String
var role_family: RoleFamily
var base_stats: CombatantStats
var skill_ids: Array[String]

func _init(
	p_id: String = "",
	p_name: String = "",
	p_family: RoleFamily = RoleFamily.FRONTLINER,
	p_stats: CombatantStats = null
) -> void:
	hero_id = p_id
	display_name = p_name
	role_family = p_family
	base_stats = p_stats if p_stats else CombatantStats.create_base()
	skill_ids = []

func get_role_name() -> String:
	match role_family:
		RoleFamily.FRONTLINER: return "frontliner"
		RoleFamily.DPS: return "dps"
		RoleFamily.SUPPORT: return "support"
	return "frontliner"

func set_skills(basic: String, small_a: String, small_b: String, ultimate: String) -> void:
	skill_ids = [basic, small_a, small_b, ultimate]
