## EmitProjectileEffect — projectile spawning leaf effect
## v2.4: per-projectile target selection with avoidance support
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

	var is_multi: bool = count > 1
	var is_tracking: bool = context.tracking_enabled

	# 每弹独立选目标，维护已选排除列表
	var already_selected: Array = []

	var chains: Array[ExecutionChain] = []
	for i in range(count):
		var chain := _create_chain(context)

		# 每弹独立调用目标选择策略（支持避弹排除）
		if context.available_targets.size() > 0:
			var t: Node2D = TargetSelector.select_target(
				chain.position, context.available_targets,
				context.target_mode, context.cast_range, already_selected
			)
			# 降级：排除后无目标，允许重复
			if not t:
				t = TargetSelector.select_target(
					chain.position, context.available_targets,
					context.target_mode, context.cast_range
				)
			if t and is_instance_valid(t):
				chain.target = t
				chain.target_pos = t.global_position
				chain.direction = chain.position.direction_to(t.global_position)
				already_selected.append(t)

		# trajectory: use visual_def setting; add bezier variation for multi-projectile bezier skills
		if is_multi and not is_tracking and chain.trajectory_type == 1:
			var forward_dist := randf_range(0.35, 0.75)
			var perp_offset := randf_range(20.0, 160.0) * (1.0 if randi() % 2 == 0 else -1.0)
			chain.control_point_offset = perp_offset
			if not "bezier_forward_ratio" in chain or chain.get("bezier_forward_ratio") == null:
				chain.set_meta("bezier_forward_ratio", forward_dist)
			else:
				chain.bezier_forward_ratio = forward_dist

		# tracking angle offset: wide angles only, no frontal spread
		if is_tracking and is_multi:
			var offset_angle: float
			if randf() < 0.5:
				offset_angle = randf_range(0.785, 2.01)
			else:
				offset_angle = randf_range(-2.01, -0.785)
			chain.direction = chain.direction.rotated(offset_angle)

		# speed variation +/-20%
		chain.speed *= randf_range(0.8, 1.2)

		# spawn spread
		var spread := Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0))
		chain.position += spread

		# damage variance
		chain.damage = context.damage * randf_range(0.85, 1.0)
		chain.damage = maxf(1.0, chain.damage)

		# stagger: multi-projectile tracking -> 3s window; multi non-tracking -> 0.8s; single -> 0
		if is_multi and is_tracking:
			chain.spawn_delay = randf_range(0.0, 1.5)
		elif is_multi:
			chain.spawn_delay = randf_range(0.05, 0.8)

		chains.append(chain)
	return chains
