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
	# 1. 让 Effect 生成基础链（多弹道技能返回 N 条链，单弹道返回 1 条）
	var leaf_chains: Array[ExecutionChain] = effect.execute(context)

	# 2. 按优先级排序 Modifier（从小到大）
	var sorted_mods := modifiers.duplicate()
	sorted_mods.sort_custom(_sort_by_priority)

	# 3. 对每条叶子链执行 Modifier 链，汇总所有结果
	var result: Array[ExecutionChain]
	for chain in leaf_chains:
		chain.chain_id = generate_chain_id()
		chain.modifier_stack = modifiers.duplicate()
		var processed := _process_chain(chain, sorted_mods)
		for c in processed:
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
