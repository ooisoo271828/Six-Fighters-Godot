## DamageResolver — 伤害结算器
## 纯数值计算，不含任何渲染/节点代码
extends Node

## ── 伤害结果 ──
class DamageResult:
	var instant_damage: float = 0.0
	var damage_type: String = "physical"
	var is_crit: bool = false
	var is_miss: bool = false
	var status_updates: Array[Dictionary] = []

## 结算一次攻击
static func resolve_attack(
	attacker_stats: Resource,
	target_stats: Resource,
	base_damage: float,
	damage_type: String,
	stun_chance: float = 0.0,
	stun_duration: float = 0.0,
	target_shock_stacks: int = 0
) -> DamageResult:
	var result := DamageResult.new()

	# 命中判定
	var accuracy: float = attacker_stats.accuracy if attacker_stats else 1.0
	var dodge: float = target_stats.dodge if target_stats else 0.0
	var rng := randf()
	if rng < dodge:
		result.is_miss = true
		return result

	# 暴击判定
	var crit_rate: float = attacker_stats.crit_rate if attacker_stats else 0.05
	result.is_crit = randf() < crit_rate

	# 基础伤害
	result.damage_type = damage_type
	result.instant_damage = base_damage

	if result.is_crit:
		var crit_mult: float = attacker_stats.crit_damage_mult if attacker_stats else 1.5
		result.instant_damage *= crit_mult

	# 元素抗性
	var resist: float = target_stats.get_element_resistance(damage_type) if target_stats else 0.0
	result.instant_damage *= maxf(0.1, 1.0 - resist)

	# 眩晕判定
	if stun_chance > 0.0 and not result.is_miss:
		var effective_chance := minf(1.0, stun_chance + target_shock_stacks * 0.05)
		if randf() < effective_chance:
			result.status_updates.append({
				"status": "stun",
				"stacks": 1,
				"duration": stun_duration
			})

	return result

## 结算区域伤害（无暴击）
static func resolve_area_damage(
	attacker_stats: Resource,
	target_stats: Resource,
	base_damage: float,
	damage_type: String
) -> DamageResult:
	var result := DamageResult.new()
	result.damage_type = damage_type
	result.instant_damage = base_damage
	var resist: float = target_stats.get_element_resistance(damage_type) if target_stats else 0.0
	result.instant_damage *= maxf(0.1, 1.0 - resist)
	return result

## 结算 DoT（持续伤害）
static func resolve_dot(
	base_damage_per_tick: float,
	damage_type: String,
	attacker_stats: Resource,
	target_stats: Resource,
	tick_count: int
) -> Dictionary:
	var total_damage := 0.0
	for i in tick_count:
		var dmg: float = base_damage_per_tick
		var resist: float = target_stats.get_element_resistance(damage_type) if target_stats else 0.0
		dmg *= maxf(0.1, 1.0 - resist)
		total_damage += dmg
	return {
		"total_damage": total_damage,
		"tick_count": tick_count,
		"damage_per_tick": base_damage_per_tick,
		"damage_type": damage_type
	}
