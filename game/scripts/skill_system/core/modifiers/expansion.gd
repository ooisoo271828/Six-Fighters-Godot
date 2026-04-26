## ExpansionModifier — 膨胀修改器
## 抛射物尺寸随飞行距离线性增长
class_name ExpansionModifier
extends SkillModifier

func _init():
	modifier_id = "expansion"
	modifier_type = 2  # APPEARANCE
	priority = 80
	trigger_timing = 3  # DISTANCE_TRAVELED
	# 设置默认值
	size_growth_per_distance = 0.02  # 每像素距离增加 2%
	max_scale = 3.0

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
	# 注册每1像素触发一次检查
	chain.add_distance_trigger(1.0, _on_expand)
	return []

func _on_expand(chain: ExecutionChain) -> void:
	if chain.distance_traveled > 0.0:
		var new_scale := chain.base_scale + chain.distance_traveled * size_growth_per_distance
		chain.scale = minf(new_scale, max_scale)
		chain.current_radius = chain.base_radius * chain.scale
