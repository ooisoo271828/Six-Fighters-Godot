## FissionModifier — 分裂修改器
## 抛射物每飞行 half_life_distance 距离后，分裂成 split_count 个子抛射物
class_name FissionModifier
extends SkillModifier

func _init():
	modifier_id = "fission"
	modifier_type = 1  # LIFETIME
	priority = 50
	trigger_timing = 3  # DISTANCE_TRAVELED
	# 设置默认值
	half_life_distance = 150.0
	split_count = 2
	scale_factor = 0.7
	damage_factor = 0.6
	split_angle_spread_deg = 30.0

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
	# 注册距离触发器
	chain.add_distance_trigger(half_life_distance, _on_fission)
	return []

func _on_fission(chain: ExecutionChain) -> void:
	var parent := chain
	var base_angle := chain.direction.angle()
	var step := split_angle_spread_deg / (split_count - 1) if split_count > 1 else 0.0
	var start_angle := base_angle - split_angle_spread_deg / 2.0

	for i in split_count:
		var angle := start_angle + step * i
		var child := chain.duplicate()
		child.chain_id = 0  # 由 SkillRoot 分配
		child.direction = Vector2.from_angle(angle)
		child.position = chain.position  # 在母体当前位置分裂
		child.distance_traveled = 0.0  # 子体重新计算距离
		child.scale *= scale_factor
		child.damage *= damage_factor
		child.current_radius *= scale_factor
		child.modifier_index = chain.modifier_index
		# 移除自身的 Fission，防止无限分裂
		child.modifier_stack = _remove_modifier_from_stack(chain.modifier_stack, "fission")
		parent.add_child(child)

	chain.destroy()  # 母体消失
