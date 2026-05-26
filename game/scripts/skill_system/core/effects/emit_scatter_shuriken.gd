## EmitScatterShurikenEffect — 霰弹手里剑 Effect
## 90度扇形选域 + 9发连射 + 间隔递减 + 避重选目标
class_name EmitScatterShurikenEffect
extends SkillEffect

const SHOT_COUNT: int = 9
const FAN_ANGLE_DEG: float = 90.0

# 间隔递减：0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2, 0.15, 0.1
const INTERVALS: Array[float] = [0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2, 0.15, 0.1]


func _init():
	effect_id = "emit_scatter_shuriken"
	effect_type = EffectType.EMIT_PROJECTILE


func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	# 90度扇形目标选择
	var fan_targets := _select_fan_targets(context)
	if fan_targets.is_empty():
		return []

	# 生成9条链，每条有递减的spawn_delay
	var chains: Array[ExecutionChain] = []
	var last_target: Node2D = null

	for i in range(SHOT_COUNT):
		var chain := _create_chain(context)

		# 选择目标（优先不同于上次）
		var target := _pick_target(fan_targets, last_target)
		if target == null:
			target = fan_targets[0] if not fan_targets.is_empty() else context.target

		chain.target = target
		chain.target_pos = target.global_position if is_instance_valid(target) else context.target_pos
		chain.direction = chain.position.direction_to(chain.target_pos)

		# 间隔递减
		var delay: float = 0.0
		for j in range(i):
			delay += INTERVALS[j]
		chain.spawn_delay = delay

		# 伤害微调 +/-10%
		chain.damage = context.damage * randf_range(0.9, 1.1)
		chain.damage = maxf(1.0, chain.damage)

		# 速度微调 +/-15%
		chain.speed = 350.0 * randf_range(0.85, 1.15)

		# 位置微调（发射点随机偏移）
		chain.position += Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0))

		last_target = target
		chains.append(chain)

	return chains


## 90度扇形内选择目标
func _select_fan_targets(context: SkillEffect.SkillExecutionContext) -> Array:
	var caster_pos: Vector2 = context.caster.global_position
	var targets: Array = context.available_targets
	var max_range: float = context.cast_range

	if targets.is_empty():
		return []

	# 计算扇形中心方向（朝向目标质心或单个目标）
	var center_dir: Vector2
	if context.target and is_instance_valid(context.target):
		center_dir = caster_pos.direction_to(context.target.global_position)
	else:
		# 计算质心方向
		var centroid := Vector2.ZERO
		var count := 0
		for t in targets:
			if t and is_instance_valid(t) and t.get("is_alive") == true:
				centroid += t.global_position
				count += 1
		if count > 0:
			centroid /= count
			center_dir = caster_pos.direction_to(centroid)
		else:
			return []

	# 筛选扇形内目标
	var half_fan := deg_to_rad(FAN_ANGLE_DEG * 0.5)
	var fan_targets: Array = []

	for t in targets:
		if not (t and is_instance_valid(t) and t.get("is_alive") == true):
			continue
		var to_target := caster_pos.direction_to(t.global_position)
		var dist := caster_pos.distance_to(t.global_position)

		# 距离检查
		if dist > max_range or dist < 1.0:
			continue

		# 角度检查
		var angle_diff := absf(center_dir.angle_to(to_target))
		if angle_diff <= half_fan:
			fan_targets.append(t)

	# 按距离排序
	fan_targets.sort_custom(func(a, b): return caster_pos.distance_to(a.global_position) < caster_pos.distance_to(b.global_position))

	return fan_targets


## 从目标列表中选择一个（优先不同于上次）
func _pick_target(targets: Array, last_target: Node2D) -> Node2D:
	if targets.is_empty():
		return null

	# 如果只有一个目标，直接返回
	if targets.size() == 1:
		return targets[0]

	# 优先选择不同于上次的目标
	if last_target != null:
		var different: Array = []
		for t in targets:
			if t != last_target:
				different.append(t)
		if not different.is_empty():
			return different[randi() % different.size()]

	# 随机选择
	return targets[randi() % targets.size()]
