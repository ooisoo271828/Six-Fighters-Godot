## EmitProjectileEffect — 发射抛射物（叶子 Effect）
## 这是最常用的叶子 Effect，Modifier 最终修改的对象
class_name EmitProjectileEffect
extends SkillEffect

func _init():
	effect_id = "emit_projectile"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)
	return [chain]
