## EmitBurningHandsEffect — 火焰之手 Effect
## 扇形 AOE，持续灼烧范围内所有敌人
## 通过 skill_root._execute_chain 中的特殊路由直接 spawn BurningHandsNode
class_name EmitBurningHandsEffect
extends SkillEffect

func _init():
	effect_id = "emit_burning_hands"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)
	chain.direction = context.direction
	chain.tracking_enabled = false
	chain.trajectory_type = 0
	chain.pierce_enabled = false
	chain.bounce_remaining = 0
	chain.effect_id = "emit_burning_hands"
	return [chain]
