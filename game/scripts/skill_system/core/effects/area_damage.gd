## AreaDamageEffect — 区域伤害（瞬发叶子 Effect）
class_name AreaDamageEffect
extends SkillEffect

var radius: float = 50.0
var max_targets: int = 5

func _init():
	effect_id = "area_damage"
	effect_type = EffectType.AREA_DAMAGE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	# 瞬发伤害不产生投射物，直接产生结算链
	var chain := _create_chain(context)
	chain.behavior_state = "Instant"  # 特殊状态，表示瞬发
	return [chain]
