## EmitSmallLaserBeamEffect — 小激光术 Effect
## 生成一条冰蓝色激光柱，经 skill_root 特殊路由到 SmallLaserBeamPool
class_name EmitSmallLaserBeamEffect
extends SkillEffect

func _init():
	effect_id = "emit_small_laser_beam"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)
	chain.direction = context.direction
	chain.tracking_enabled = false
	chain.trajectory_type = 0
	chain.pierce_enabled = false
	chain.bounce_remaining = 0
	chain.effect_id = "emit_small_laser_beam"
	return [chain]
