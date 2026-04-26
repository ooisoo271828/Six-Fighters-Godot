## ScatterModifier — 散射修改器
## 把单个抛射物复制为 N 枚扇形发射的子抛射物
class_name ScatterModifier
extends SkillModifier

func _init():
	modifier_id = "scatter"
	modifier_type = 0  # TRAJECTORY
	priority = 10
	trigger_timing = 0  # ON_CAST
	# 设置默认值
	num_projectiles = 5
	fan_angle_deg = 60.0

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
	if chain.modifier_index > 0:
		return []  # Scatter 只在最外层生效，不递归

	var base_angle := chain.direction.angle()
	var step := fan_angle_deg / (num_projectiles - 1) if num_projectiles > 1 else 0.0
	var start_angle := base_angle - fan_angle_deg / 2.0

	var children: Array[ExecutionChain]
	for i in num_projectiles:
		var angle := start_angle + step * i
		var child := chain.duplicate()
		child.direction = Vector2.from_angle(angle)
		child.modifier_index = chain.modifier_index + 1
		children.append(child)

	# 母体消失（被子链替代）
	chain.behavior_state = "Destroyed"
	return children
