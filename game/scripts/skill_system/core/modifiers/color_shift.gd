## ColorShiftModifier — 色彩偏移修改器
## 改变抛射物的颜色
class_name ColorShiftModifier
extends SkillModifier

var color: Color = Color.WHITE

func _init():
	modifier_id = "color_shift"
	modifier_type = 2  # APPEARANCE
	priority = 90
	trigger_timing = 0  # ON_CAST

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
	chain.color_override = color
	return []
