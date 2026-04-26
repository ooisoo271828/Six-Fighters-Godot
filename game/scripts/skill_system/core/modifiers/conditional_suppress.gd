## ConditionalSuppressModifier — 条件压制修改器
## 满足条件时压制其他 Modifier（如 BOSS 光环抑制分裂效果）
class_name ConditionalSuppressModifier
extends SkillModifier

func _init():
	modifier_id = "conditional_suppress"
	modifier_type = 4  # CONDITIONAL
	priority = 0   # 最优先执行
	trigger_timing = 0  # ON_CAST
	# 设置默认值
	suppressed_modifier_ids = []
	condition_tag = ""

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
	if not condition_tag.is_empty():
		if not ConditionEvaluator.evaluate(condition_tag, chain.caster):
			return []  # 条件不满足，Modifier 不生效
	# 压制指定的 Modifier
	for mod_id in suppressed_modifier_ids:
		chain.suppress_modifier(mod_id)
	return []
