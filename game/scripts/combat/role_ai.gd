extends Node

## 固定角色 AI v2.0 — 独立触发 + 释放队列

class_name RoleAI

# 技能类别常量（与 SkillDef.category 对应）
const CAT_BASIC: int = 0
const CAT_SMALL_A: int = 1
const CAT_SMALL_B: int = 2
const CAT_ULTIMATE: int = 3

# 释放队列间隔（秒）
const QUEUE_INTERVAL := 0.2

# 怒气常量
const MAX_RAGE := 100.0
const RAGE_GAIN_RATE := 0.02  # 攻击怒气系数（统一2.0%）

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
	var target: Node2D

	func _init(p_skill: SkillDef, p_label: String, p_target: Node2D = null) -> void:
		skill = p_skill
		label = p_label
		target = p_target
		cooldown_key = _label_to_key(p_label)

	static func _label_to_key(lbl: String) -> String:
		match lbl:
			"ultimate": return "rage"
			"smallA", "1": return "small_a"
			"smallB", "2": return "small_b"
			"basic", "0": return "basic"
		return "basic"

## 释放队列
class CastQueue:
	var queue: Array[AutonomyPick] = []
	var queue_timer: float = 0.0

	func add(pick: AutonomyPick) -> void:
		queue.append(pick)

	func update(dt: float) -> AutonomyPick:
		if queue.is_empty():
			return null
		queue_timer -= dt
		if queue_timer <= 0:
			queue_timer = QUEUE_INTERVAL
			return queue.pop_front()
		return null

	func clear() -> void:
		queue.clear()
		queue_timer = 0.0

	func size() -> int:
		return queue.size()

# ── 工厂方法 ──

static func create_timers() -> AutonomyTimers:
	return AutonomyTimers.new()

static func create_cast_queue() -> CastQueue:
	return CastQueue.new()

# ── CD更新 ──

static func tick_timers(timers: AutonomyTimers, dt: float) -> void:
	timers.basic -= dt
	timers.small_a -= dt
	timers.small_b -= dt

# ── 怒气管理 ──

static func add_rage(timers: AutonomyTimers, amount: float) -> void:
	timers.rage = minf(MAX_RAGE, timers.rage + amount)

## 攻击怒气：造成伤害时调用
static func add_attack_rage(timers: AutonomyTimers, damage: float) -> void:
	add_rage(timers, damage * RAGE_GAIN_RATE)

## 受伤怒气：受到伤害时调用
static func add_damage_taken_rage(timers: AutonomyTimers, damage: float, damage_taken_rage_rate: float) -> void:
	add_rage(timers, damage * damage_taken_rage_rate)

# ── 核心逻辑：独立触发 ──

## 独立检查每个技能是否满足释放条件，返回所有满足条件的技能列表
## 目标选择逻辑是技能的内禀属性，由 SkillDef.find_target() 执行
static func check_casts(
	hero_def: HeroDef,
	timers: AutonomyTimers,
	skill_registry: SkillRegistry,
	hero_pos: Vector2,
	enemies: Array
) -> Array[AutonomyPick]:

	var result: Array[AutonomyPick] = []
	var skill_ids := hero_def.skill_ids

	# 1. 检查大招（怒气满 + 有目标）
	var ultimate := skill_registry.get_hero_skill_by_category(skill_ids, CAT_ULTIMATE)
	if ultimate and timers.rage >= ultimate.rage_cost:
		var target := ultimate.find_target(hero_pos, enemies)
		if target:
			timers.rage = 0.0
			result.append(AutonomyPick.new(ultimate, "ultimate", target))

	# 2. 检查small_a（CD好了 + 有目标）
	var small_a := skill_registry.get_hero_skill_by_category(skill_ids, CAT_SMALL_A)
	if small_a and timers.small_a <= 0:
		var target := small_a.find_target(hero_pos, enemies)
		if target:
			timers.small_a = small_a.cooldown
			result.append(AutonomyPick.new(small_a, "smallA", target))

	# 3. 检查small_b（CD好了 + 有目标）
	var small_b := skill_registry.get_hero_skill_by_category(skill_ids, CAT_SMALL_B)
	if small_b and timers.small_b <= 0:
		var target := small_b.find_target(hero_pos, enemies)
		if target:
			timers.small_b = small_b.cooldown
			result.append(AutonomyPick.new(small_b, "smallB", target))

	# 4. 检查普攻（CD好了 + 所有小技能都在CD + 有目标）
	var all_small_on_cd := true
	if small_a and timers.small_a > 0:
		all_small_on_cd = true
	elif small_a and timers.small_a <= 0:
		all_small_on_cd = false
	if small_b and timers.small_b > 0:
		all_small_on_cd = all_small_on_cd
	elif small_b and timers.small_b <= 0:
		all_small_on_cd = false

	if all_small_on_cd:
		var basic := skill_registry.get_hero_skill_by_category(skill_ids, CAT_BASIC)
		if basic and timers.basic <= 0:
			var target := basic.find_target(hero_pos, enemies)
			if target:
				timers.basic = basic.cooldown
				result.append(AutonomyPick.new(basic, "basic", target))

	return result
