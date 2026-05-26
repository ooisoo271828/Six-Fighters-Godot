## EmitBubbleBombArrayEffect — 气泡炸弹阵 Effect
## 通过 skill_root._cast_bubble_bomb_array 中的特殊路由直接 spawn
class_name EmitBubbleBombArrayEffect
extends SkillEffect

func _init():
	effect_id = "emit_bubble_bomb_array"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)
	chain.effect_id = "emit_bubble_bomb_array"
	return [chain]
