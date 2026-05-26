## EmitFlyingSwordStormEffect — 飞剑风暴 Effect
class_name EmitFlyingSwordStormEffect
extends SkillEffect

func _init():
	effect_id = "emit_flying_sword_storm"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)
	chain.effect_id = "emit_flying_sword_storm"
	return [chain]
