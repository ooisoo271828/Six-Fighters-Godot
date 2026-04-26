## ModifierProcessor — Modifier 执行引擎
## 每次施放技能时：
##  1. 构建基础 ExecutionChain
##  2. 按优先级排序所有 Modifier
##  3. 依次调用每个 Modifier 的 apply()
##  4. 返回完整的叶子链列表
extends Node

var _chain_id_counter: int = 0

func _ready() -> void:
	print("[ModifierProcessor] Ready")

func generate_chain_id() -> int:
	_chain_id_counter += 1
	return _chain_id_counter

## 解析技能执行，返回所有叶子链
func resolve(
	effect: SkillEffect,
	modifiers: Array[SkillModifier],
	context: SkillEffect.SkillExecutionContext
) -> Array[ExecutionChain]:
	# 1. 构建根链
	var root_chain := ExecutionChain.new()
	root_chain.chain_id = generate_chain_id()
	root_chain.effect = effect
	root_chain.effect_id = effect.get_effect_id()
	root_chain.caster = context.caster
	root_chain.target = context.target
	root_chain.target_pos = context.target_pos
	root_chain.direction = context.direction
	root_chain.position = context.caster.global_position
	root_chain.damage = context.damage
	root_chain.damage_type = context.damage_type
	root_chain.base_damage = context.damage
	root_chain.skill_id = context.skill_id
	root_chain.current_radius = 4.0
	root_chain.base_radius = 4.0
	root_chain.scale = 1.0
	root_chain.base_scale = 1.0
	root_chain.projectile_hp = 0.0
	root_chain.can_be_targeted = false
	root_chain.speed = 300.0
	root_chain.behavior_state = "Flying"
	root_chain.travel_time_multiplier = 1.0
	root_chain.modifier_stack = modifiers.duplicate()

	# 2. 按优先级排序（从小到大）
	var sorted_mods := modifiers.duplicate()
	sorted_mods.sort_custom(_sort_by_priority)

	# 3. 执行 Modifier 链
	var all_chains := _process_chain(root_chain, sorted_mods)

	# 4. 过滤掉 Destroyed 状态的链
	var result: Array[ExecutionChain]
	for c in all_chains:
		if c.behavior_state != "Destroyed":
			result.append(c)

	return result

## 递归处理一条链及其子链
func _process_chain(
	chain: ExecutionChain,
	sorted_mods: Array[SkillModifier]
) -> Array[ExecutionChain]:
	var all_chains: Array[ExecutionChain] = [chain]
	var pending: Array[ExecutionChain] = [chain]

	while not pending.is_empty():
		var current: ExecutionChain = pending.pop_front()

		# 找出该链还需要处理的 Modifier
		var remaining_mods: Array[SkillModifier]
		for mod in sorted_mods:
			# 检查是否已被压制
			if _is_mod_suppressed(current, mod.modifier_id):
				continue
			remaining_mods.append(mod)

		# 按优先级顺序处理
		for mod in remaining_mods:
			if not mod.is_active(current.caster):
				continue

			current.modifier_index += 1
			var children: Array[ExecutionChain] = mod.apply(current)

			for child in children:
				child.chain_id = generate_chain_id()
				child.parent_chain = current
				current.add_child(child)
				all_chains.append(child)
				pending.push_back(child)

	return all_chains

## 检查某 Modifier 是否被压制
func _is_mod_suppressed(chain: ExecutionChain, mod_id: String) -> bool:
	for mod in chain.modifier_stack:
		if mod.modifier_id == mod_id and mod._suppressed:
			return true
	return false

## 优先级比较函数
func _sort_by_priority(a: SkillModifier, b: SkillModifier) -> bool:
	return a.priority < b.priority
