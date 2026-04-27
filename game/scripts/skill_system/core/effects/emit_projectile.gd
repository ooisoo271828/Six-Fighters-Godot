## EmitProjectileEffect — 发射抛射物（叶子 Effect）
## 这是最常用的叶子 Effect，Modifier 最终修改的对象
## v2.1: 支持多弹道（projectile_count_min/max）
class_name EmitProjectileEffect
extends SkillEffect

func _init():
	effect_id = "emit_projectile"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	var visual_def = context.visual_def
	var count_min: int = visual_def.get("projectile_count_min") if visual_def and "projectile_count_min" in visual_def else 1
	var count_max: int = visual_def.get("projectile_count_max") if visual_def and "projectile_count_max" in visual_def else 1
	var count: int = randi_range(count_min, count_max)

	var chains: Array[ExecutionChain] = []
	for i in range(count):
		var chain := _create_chain(context)
		if count > 1:
			# 各导弹随机弧线偏移
			var offset_mag := randf_range(30.0, 130.0)
			var side := 1.0 if randi() % 2 == 0 else -1.0
			chain.control_point_offset = offset_mag * side
			# 发射位置微散开
			var spread := Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0))
			chain.position += spread
			# 伤害微量浮动
			chain.damage = context.damage * randf_range(0.85, 1.0)
			chain.damage = maxf(1.0, chain.damage)
		# 强制使用贝塞尔曲线轨迹（确保弧线弹道）
		chain.trajectory_type = 1  # BEZIER_QUAD
		chains.append(chain)
	return chains
