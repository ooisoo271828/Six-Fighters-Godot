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
	# 设置膨胀参数，由 ProjectileNode 每帧计算（不用 one-shot trigger）
	chain.expansion_growth_rate = size_growth_per_distance
	chain.expansion_max_scale = max_scale
	return []
