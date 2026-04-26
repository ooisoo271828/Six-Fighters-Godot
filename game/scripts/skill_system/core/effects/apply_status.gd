## ApplyStatusEffect — 施加状态效果
class_name ApplyStatusEffect
extends SkillEffect

var status_id: String = ""
var stacks: int = 1
var duration_sec: float = 3.0

func _init():
	effect_id = "apply_status"
	effect_type = EffectType.APPLY_STATUS

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var chain := _create_chain(context)
	chain.behavior_state = "Instant"
	return [chain]
