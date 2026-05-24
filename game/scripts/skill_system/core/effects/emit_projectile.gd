## EmitProjectileEffect -- projectile spawning leaf effect
## v2.3: per-skill trajectory control + tracking angle offset + configurable stagger
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

	# build target list for multi-target seeking
	var targets: Array = []
	if context.available_targets.size() > 1:
		targets = context.available_targets.duplicate()
		targets.shuffle()

	var is_multi: bool = count > 1
	var is_tracking: bool = context.tracking_enabled

	var chains: Array[ExecutionChain] = []
	for i in range(count):
		var chain := _create_chain(context)

		# multi-target seeking: assign different targets
		if targets.size() > 0:
			var t = targets[i % targets.size()]
			if t and is_instance_valid(t):
				chain.target = t
				chain.target_pos = t.global_position
				chain.direction = chain.position.direction_to(t.global_position)

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
		# two ranges: +45..+115 deg and -115..-45 deg
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
