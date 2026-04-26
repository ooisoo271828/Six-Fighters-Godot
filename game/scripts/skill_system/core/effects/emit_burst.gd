## EmitBurstEffect — 爆发效果（纯视觉叶子 Effect）
class_name EmitBurstEffect
extends SkillEffect

var burst_radius: float = 30.0

func _init():
	effect_id = "emit_burst"
	effect_type = EffectType.EMIT_BURST

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)
	chain.behavior_state = "Burst"
	return [chain]
