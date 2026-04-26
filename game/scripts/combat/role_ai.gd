extends Node

## 固定角色 AI - 对应 Web 版本的 autonomy.ts

class_name RoleAI

# 技能类别常量（与 SkillDef.category 对应）
const CAT_BASIC: int = 0
const CAT_SMALL_A: int = 1
const CAT_SMALL_B: int = 2
const CAT_ULTIMATE: int = 3

class AutonomyTimers:
	var basic: float = 0.0
	var small_a: float = 0.0
	var small_b: float = 0.0
	var rage: float = 0.0
	
	func reset() -> void:
		basic = 0.0
		small_a = 0.0
		small_b = 0.0
		rage = 0.0
	
	func get_value(key: String) -> float:
		match key:
			"basic": return basic
			"small_a": return small_a
			"small_b": return small_b
			"rage": return rage
		return 0.0
	
	func set_value(key: String, val: float) -> void:
		match key:
			"basic": basic = val
			"small_a": small_a = val
			"small_b": small_b = val
			"rage": rage = val

class AutonomyPick:
	var skill: SkillDef
	var label: String
	var cooldown_key: String
	
	func _init(p_skill: SkillDef, p_label: String) -> void:
		skill = p_skill
		label = p_label
		cooldown_key = _label_to_key(p_label)
	
	static func _label_to_key(lbl: String) -> String:
		match lbl:
			"ultimate": return "rage"
			"smallA", "smallA_survival": return "small_a"
			"smallB", "smallB_survival": return "small_b"
		return "basic"

const SURVIVAL_HP_FRAC := 0.35
const MAX_RAGE := 100.0

static func create_timers() -> AutonomyTimers:
	return AutonomyTimers.new()

static func tick_timers(timers: AutonomyTimers, dt: float) -> void:
	timers.basic -= dt
	timers.small_a -= dt
	timers.small_b -= dt

static func add_rage(timers: AutonomyTimers, amount: float) -> void:
	timers.rage = minf(MAX_RAGE, timers.rage + amount)

static func pick_action(
	hero: HeroDef,
	timers: AutonomyTimers,
	self_hp_frac: float,
	skill_registry: SkillRegistry
) -> AutonomyPick:
	var skill_ids := hero.skill_ids
	
	# 终极技能：怒气满时释放
	var ultimate := skill_registry.get_hero_skill_by_category(skill_ids, CAT_ULTIMATE)
	if ultimate and timers.rage >= ultimate.rage_cost:
		timers.rage = 0.0
		return AutonomyPick.new(ultimate, "ultimate")
	
	# 生存技能：低血量时优先
	if self_hp_frac < SURVIVAL_HP_FRAC:
		match hero.role_family:
			HeroDef.RoleFamily.FRONTLINER:
				var s := skill_registry.get_hero_skill_by_category(skill_ids, CAT_SMALL_A)
				if s and timers.small_a <= 0:
					timers.small_a = s.cooldown
					return AutonomyPick.new(s, "smallA_survival")
			HeroDef.RoleFamily.SUPPORT:
				var s := skill_registry.get_hero_skill_by_category(skill_ids, CAT_SMALL_B)
				if s and timers.small_b <= 0:
					timers.small_b = s.cooldown
					return AutonomyPick.new(s, "smallB_survival")
	
	# 角色职业优先级
	var role_order: Array[int] = []
	match hero.role_family:
		HeroDef.RoleFamily.DPS:
			role_order = [CAT_SMALL_A, CAT_SMALL_B]
		HeroDef.RoleFamily.FRONTLINER:
			role_order = [CAT_SMALL_B, CAT_SMALL_A]
		HeroDef.RoleFamily.SUPPORT:
			role_order = [CAT_SMALL_A, CAT_SMALL_B]
	
	for cat in role_order:
		var s := skill_registry.get_hero_skill_by_category(skill_ids, cat)
		var key := AutonomyPick._label_to_key("rage" if cat == CAT_ULTIMATE else str(cat))
		if s and timers.get_value(key) <= 0:
			timers.set_value(key, s.cooldown)
			return AutonomyPick.new(s, str(cat))
	
	# 普通攻击
	var basic := skill_registry.get_hero_skill_by_category(skill_ids, CAT_BASIC)
	if basic and timers.basic <= 0:
		timers.basic = basic.cooldown
		return AutonomyPick.new(basic, "basic")
	
	return null
