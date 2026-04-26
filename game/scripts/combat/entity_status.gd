extends RefCounted

## 状态效果系统 - 对应 Web 版本的 entityState.ts

class_name EntityStatus

var burn_stacks: int = 0
var burn_duration: float = 0.0
var burn_dot_potency: float = 0.0

var frost_stacks: int = 0
var frost_duration: float = 0.0
var frost_dot_potency: float = 0.0

var poison_stacks: int = 0
var poison_duration: float = 0.0
var poison_dot_potency: float = 0.0

var shock_stacks: int = 0
var shock_duration: float = 0.0

var stun_duration: float = 0.0

var tick_accumulator: float = 0.0

func _init() -> void:
	reset()

func reset() -> void:
	burn_stacks = 0
	burn_duration = 0.0
	burn_dot_potency = 0.0
	frost_stacks = 0
	frost_duration = 0.0
	frost_dot_potency = 0.0
	poison_stacks = 0
	poison_duration = 0.0
	poison_dot_potency = 0.0
	shock_stacks = 0
	shock_duration = 0.0
	stun_duration = 0.0
	tick_accumulator = 0.0

func get_shock_stacks_for_resolution() -> int:
	return shock_stacks if shock_duration > 0 else 0

func is_stunned() -> bool:
	return stun_duration > 0

func apply_stun(duration: float) -> void:
	stun_duration = maxf(stun_duration, duration)

func merge_dot(token: String, stacks_added: int, duration: float, potency: float, max_stacks: int) -> void:
	match token:
		"burn":
			burn_stacks = mini(max_stacks, burn_stacks + stacks_added)
			burn_duration = maxf(burn_duration, duration)
			burn_dot_potency = potency
		"frost":
			frost_stacks = mini(max_stacks, frost_stacks + stacks_added)
			frost_duration = maxf(frost_duration, duration)
			frost_dot_potency = potency
		"poison":
			poison_stacks = mini(max_stacks, poison_stacks + stacks_added)
			poison_duration = maxf(poison_duration, duration)
			poison_dot_potency = potency

func merge_shock(candidate_stacks: int, duration: float, max_stacks: int) -> void:
	if shock_duration <= 0:
		shock_stacks = candidate_stacks
		shock_duration = duration
		return
	
	if candidate_stacks > shock_stacks:
		shock_stacks = mini(max_stacks, candidate_stacks)
	shock_duration = maxf(shock_duration, duration)

func tick(dt: float, dot_interval: float, on_dot: Callable) -> void:
	# 减少持续时间
	if stun_duration > 0:
		stun_duration -= dt
	
	if burn_duration > 0:
		burn_duration -= dt
		if burn_duration <= 0:
			burn_stacks = 0
			burn_dot_potency = 0.0
	
	if frost_duration > 0:
		frost_duration -= dt
		if frost_duration <= 0:
			frost_stacks = 0
			frost_dot_potency = 0.0
	
	if poison_duration > 0:
		poison_duration -= dt
		if poison_duration <= 0:
			poison_stacks = 0
			poison_dot_potency = 0.0
	
	if shock_duration > 0:
		shock_duration -= dt
		if shock_duration <= 0:
			shock_stacks = 0
	
	# DOT 触发
	tick_accumulator += dt
	while tick_accumulator >= dot_interval:
		tick_accumulator -= dot_interval
		var dealt := 0.0
		if burn_duration > 0 and burn_stacks > 0:
			dealt += burn_dot_potency * float(burn_stacks)
		if frost_duration > 0 and frost_stacks > 0:
			dealt += frost_dot_potency * float(frost_stacks)
		if poison_duration > 0 and poison_stacks > 0:
			dealt += poison_dot_potency * float(poison_stacks)
		if dealt > 0:
			on_dot.call(dealt)

func apply_status_update(token: CombatResolver.StatusToken, new_stack_count: int, duration: float, params: CombatParams) -> void:
	match token:
		CombatResolver.StatusToken.STUN:
			apply_stun(duration)
		CombatResolver.StatusToken.SHOCK:
			merge_shock(new_stack_count, duration, params.shock_stack_max)
		CombatResolver.StatusToken.BURN:
			merge_dot("burn", new_stack_count, duration, 0.0, params.burn_stack_max)
		CombatResolver.StatusToken.FROST:
			merge_dot("frost", new_stack_count, duration, 0.0, params.frost_stack_max)
		CombatResolver.StatusToken.POISON:
			merge_dot("poison", new_stack_count, duration, 0.0, params.poison_stack_max)

func get_frost_slow() -> float:
	if frost_duration <= 0 or frost_stacks <= 0:
		return 0.0
	return minf(float(frost_stacks) * 0.1, 0.5)
