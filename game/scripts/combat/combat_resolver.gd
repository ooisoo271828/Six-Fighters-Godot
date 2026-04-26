extends Node

## 战斗结算系统 - 对应 Web 版本的 resolveAttackOutcome.ts

class_name CombatResolver

enum HitOutcome { MISS, GLANCE, DEFLECT, HIT }
enum DamageType { PHYSICAL, ELEMENTAL_FIRE, ELEMENTAL_ICE, ELEMENTAL_LIGHTNING, ELEMENTAL_POISON }
enum StatusToken { STUN, SHOCK, BURN, FROST, POISON }

class ResolveResult:
	var hit_outcome: HitOutcome
	var crit: bool
	var hit_damage_multiplier: float
	var instant_damage: float
	var status_updates: Array[StatusUpdate]
	var scheduled_dot_potency: float

class StatusUpdate:
	var token: StatusToken
	var added_stacks: int
	var new_stack_count: int
	var duration_remaining: float

static func clamp(v: float, lo: float, hi: float) -> float:
	return max(lo, min(hi, v))

static func sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))

static func hit_quality(attacker: CombatantStats, defender: CombatantStats, p: CombatParams) -> float:
	var x := p.hit_chance_slope * (attacker.accuracy - defender.evasion) + p.hit_chance_bias
	return clamp(sigmoid(x), p.hit_chance_min, p.hit_chance_max)

static func hit_round_table(
	e: float,
	p: CombatParams,
	rng_func: Callable
) -> Dictionary:
	var glance_avg := (p.glancing_min + p.glancing_max) / 2.0
	
	var rows := [
		{"name": HitOutcome.MISS, "m": 0.0},
		{"name": HitOutcome.GLANCE, "m": glance_avg},
		{"name": HitOutcome.DEFLECT, "m": p.deflect_mult},
		{"name": HitOutcome.HIT, "m": 1.0}
	]
	
	var k := p.hit_roundtable_softmax_k
	var weights: Array[float] = []
	for row in rows:
		weights.append(exp(-k * abs(row["m"] - e)))
	
	var sum_weight := 0.0
	for w in weights:
		sum_weight += w
	
	var probs: Array[float] = []
	for w in weights:
		probs.append(w / sum_weight)
	
	var min_p := p.hit_roundtable_min_prob
	var min_keep := maxi(1, int(p.hit_roundtable_min_outcomes))
	
	var active: Array[Dictionary] = []
	for i in range(rows.size()):
		if probs[i] >= min_p:
			active.append({"row": rows[i], "p": probs[i]})
	
	if active.size() < min_keep:
		active.clear()
		for i in range(rows.size()):
			active.append({"row": rows[i], "p": probs[i]})
		active.sort_custom(func(a, b): return b["p"] < a["p"])
		active.resize(min_keep)
	
	var s2 := 0.0
	for item in active:
		s2 += item["p"]
	
	var norm: Array[Dictionary] = []
	for item in active:
		norm.append({"row": item["row"], "p": item["p"] / s2})
	
	var roll: float = rng_func.call()
	var acc := 0.0
	var chosen: Dictionary = norm[norm.size() - 1]["row"]
	for item in norm:
		acc += item["p"]
		if roll < acc:
			chosen = item["row"]
			break
	
	var mult := 1.0
	match chosen["name"]:
		HitOutcome.MISS:
			mult = 0.0
		HitOutcome.GLANCE:
			mult = p.glancing_min + (rng_func.call() as float) * (p.glancing_max - p.glancing_min)
		HitOutcome.DEFLECT:
			mult = p.deflect_mult
	
	return {"outcome": chosen["name"], "mult": mult}

static func crit_chance(attacker: CombatantStats, p: CombatParams) -> float:
	var raw := p.crit_chance_base + p.crit_chance_rate_scale * (attacker.crit_rate / 100.0)
	return clamp(raw, p.crit_chance_min, p.crit_chance_max)

static func crit_multiplier(attacker: CombatantStats, p: CombatParams) -> float:
	var raw := p.crit_multiplier_base + p.crit_multiplier_power * log(1.0 + attacker.crit_power / 10.0)
	return clamp(raw, p.crit_multiplier_min, p.crit_multiplier_max)

static func element_resistance(dmg_type: int, defender: CombatantStats) -> float:
	match dmg_type:
		DamageType.ELEMENTAL_FIRE: return defender.element_resistance_fire
		DamageType.ELEMENTAL_ICE: return defender.element_resistance_ice
		DamageType.ELEMENTAL_LIGHTNING: return defender.element_resistance_lightning
		DamageType.ELEMENTAL_POISON: return defender.element_resistance_poison
	return 0.0

static func element_damage_mult(dmg_type: int, defender: CombatantStats, p: CombatParams) -> float:
	if dmg_type == DamageType.PHYSICAL:
		return 1.0
	var res := element_resistance(dmg_type, defender)
	var raw := p.element_damage_multiplier_base + p.element_damage_multiplier_scale * res
	return clamp(raw, p.element_damage_multiplier_min, p.element_damage_multiplier_max)

static func shock_damage_mult(stacks: int, p: CombatParams) -> float:
	if stacks <= 0:
		return 1.0
	var raw := p.shock_damage_taken_base + p.shock_damage_taken_per_stack * maxf(0.0, float(stacks - 1))
	return clamp(raw, p.shock_damage_taken_min, p.shock_damage_taken_max)

static func resolve_attack(
	attacker: CombatantStats,
	defender: CombatantStats,
	base_damage: float,
	damage_type: int,
	stun_chance: float,
	stun_duration_base: float,
	params: CombatParams,
	rng_func: Callable,
	defender_shock_stacks: int
) -> ResolveResult:
	var hq := hit_quality(attacker, defender, params)
	var rt_result := hit_round_table(hq, params, rng_func)
	var outcome: HitOutcome = rt_result["outcome"]
	var hit_mult: float = rt_result["mult"]
	
	var crit := false
	var crit_mult := 1.0
	
	if outcome == HitOutcome.HIT:
		crit = (rng_func.call() as float) < crit_chance(attacker, params)
		crit_mult = crit_multiplier(attacker, params) if crit else 1.0
	
	var base := base_damage * hit_mult * crit_mult
	var elem_mult := element_damage_mult(damage_type, defender, params)
	
	var shock_mult := 1.0
	if damage_type != DamageType.PHYSICAL and defender_shock_stacks > 0:
		shock_mult = shock_damage_mult(defender_shock_stacks, params)
	# 雷击施加 shock 时，如果目标之前没有 shock，不享受增伤
	if damage_type == DamageType.ELEMENTAL_LIGHTNING and outcome != HitOutcome.MISS and defender_shock_stacks == 0:
		shock_mult = 1.0
	
	var instant_damage := base * elem_mult * shock_mult
	
	var status_updates: Array[StatusUpdate] = []
	var scheduled_dot_potency := 0.0
	
	# 元素状态应用
	if outcome != HitOutcome.MISS and damage_type != DamageType.PHYSICAL:
		match damage_type:
			DamageType.ELEMENTAL_LIGHTNING:
				var candidate := int(hit_mult * params.shock_stack_max)
				var cand := clampi(candidate, 1, params.shock_stack_max)
				var dur := params.shock_duration_base + params.shock_duration_per_stack * float(cand - 1)
				var su := StatusUpdate.new()
				su.token = StatusToken.SHOCK
				su.added_stacks = cand
				su.new_stack_count = cand
				su.duration_remaining = dur
				status_updates.append(su)
			
			DamageType.ELEMENTAL_FIRE, DamageType.ELEMENTAL_ICE, DamageType.ELEMENTAL_POISON:
				var st: StatusToken
				var stack_max: int
				var dur_base: float
				var dur_per: float
				var ratio_base: float
				var ratio_per: float
				
				match damage_type:
					DamageType.ELEMENTAL_FIRE:
						st = StatusToken.BURN
						stack_max = params.burn_stack_max
						dur_base = params.burn_duration_base
						dur_per = params.burn_duration_per_stack
						ratio_base = params.burn_dot_ratio_base
						ratio_per = params.burn_dot_ratio_per_stack
					DamageType.ELEMENTAL_ICE:
						st = StatusToken.FROST
						stack_max = params.frost_stack_max
						dur_base = params.frost_duration_base
						dur_per = params.frost_duration_per_stack
						ratio_base = params.frost_dot_ratio_base
						ratio_per = params.frost_dot_ratio_per_stack
					_:
						st = StatusToken.POISON
						stack_max = params.poison_stack_max
						dur_base = params.poison_duration_base
						dur_per = params.poison_duration_per_stack
						ratio_base = params.poison_dot_ratio_base
						ratio_per = params.poison_dot_ratio_per_stack
				
				var add_stacks := 1
				var new_stacks := mini(stack_max, add_stacks)
				var duration := dur_base + dur_per * float(new_stacks - 1)
				
				var su := StatusUpdate.new()
				su.token = st
				su.added_stacks = add_stacks
				su.new_stack_count = new_stacks
				su.duration_remaining = duration
				status_updates.append(su)
				
				scheduled_dot_potency = instant_damage * (ratio_base + ratio_per * float(new_stacks - 1))
	
	# Stun 应用
	if outcome != HitOutcome.MISS and stun_chance > 0:
		if (rng_func.call() as float) < stun_chance:
			var contest := attacker.stun_power / (defender.stun_resistance + params.stun_resistance_offset)
			var mult := params.stun_duration_multiplier_base + params.stun_duration_multiplier_scale * (contest - 1.0)
			mult = clamp(mult, params.stun_duration_multiplier_min, params.stun_duration_multiplier_max)
			var dur: float = clamp(stun_duration_base * mult, params.stun_duration_min_sec, params.stun_duration_max_sec)
			
			var su := StatusUpdate.new()
			su.token = StatusToken.STUN
			su.added_stacks = 1
			su.new_stack_count = 1
			su.duration_remaining = dur
			status_updates.append(su)
	
	var result := ResolveResult.new()
	result.hit_outcome = outcome
	result.crit = crit
	result.hit_damage_multiplier = hit_mult
	result.instant_damage = instant_damage
	result.status_updates = status_updates
	result.scheduled_dot_potency = scheduled_dot_potency
	return result
