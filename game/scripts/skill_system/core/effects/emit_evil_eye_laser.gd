## EmitEvilEyeLaserEffect — 魔眼激光 Effect
## 通过 skill_root._execute_chain 中的特殊路由直接 spawn EvilEyeNode
class_name EmitEvilEyeLaserEffect
extends SkillEffect

func _init():
	effect_id = "emit_evil_eye_laser"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)
	chain.effect_id = "emit_evil_eye_laser"
	return [chain]
