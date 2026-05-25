## EmitLaserBeamEffect — 大激光术 Effect
## 从施法者身前射出一根持续激光柱
## 通过 skill_root._execute_chain 中的特殊路由直接 spawn LaserBeamNode
class_name EmitLaserBeamEffect
extends SkillEffect

func _init():
	effect_id = "emit_laser_beam"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)

	# 激光柱方向 = 施法者朝向目标的方向
	chain.direction = context.direction

	# 激光柱不需要追踪、弹射、穿透等
	chain.tracking_enabled = false
	chain.trajectory_type = 0  # LINEAR
	chain.pierce_enabled = false
	chain.bounce_remaining = 0

	# 标记为激光柱类型，skill_root._execute_chain 识别后走 LaserBeamPool
	chain.effect_id = "emit_laser_beam"

	return [chain]
