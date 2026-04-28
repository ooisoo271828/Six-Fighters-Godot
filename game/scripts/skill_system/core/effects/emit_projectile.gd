## EmitProjectileEffect — 发射抛射物（叶子 Effect）
## 这是最常用的叶子 Effect，Modifier 最终修改的对象
## v2.2: 多弹道差异 + 错峰发射
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

		# ── 各导弹差异化参数 v2.2 ──
		# 强制使用贝塞尔曲线轨迹（确保弧线弹道）
		chain.trajectory_type = 1  # BEZIER_QUAD

		# ① 曲线控制点：随机前推距离 + 垂直偏移，让每条弧线各不相同
		var forward_dist := randf_range(0.35, 0.75)  # 控制点在路径前段 35%~75% 位置
		var perp_offset := randf_range(20.0, 160.0) * (1.0 if randi() % 2 == 0 else -1.0)
		chain.control_point_offset = perp_offset
		# 额外存储前推比例供 ProjectileNode 使用
		if not "bezier_forward_ratio" in chain or chain.get("bezier_forward_ratio") == null:
			chain.set_meta("bezier_forward_ratio", forward_dist)
		else:
			chain.bezier_forward_ratio = forward_dist

		# ② 速度差异化：基础 ±20%
		chain.speed *= randf_range(0.8, 1.2)

		# ③ 发射起始位置扩散
		var spread := Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0))
		chain.position += spread

		# ④ 伤害微量浮动
		chain.damage = context.damage * randf_range(0.85, 1.0)
		chain.damage = maxf(1.0, chain.damage)

		# ⑤ 错峰发射：在 0~0.8 秒窗口内随机选延迟时间
		chain.spawn_delay = randf_range(0.05, 0.8)

		chains.append(chain)
	return chains
