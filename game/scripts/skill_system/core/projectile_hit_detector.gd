## ProjectileHitDetector — 投射物碰撞检测工具
## 提供统一的碰撞检测逻辑，确保所有投射物遵守相同的规则
## 所有投射物节点（ProjectileNode、ShurikenNode、FlyingSwordNode等）都应使用此工具
class_name ProjectileHitDetector

## 检测投射物与所有敌人的碰撞
## 返回命中的第一个敌人，如果没有命中返回 null
## projectile_pos: 投射物当前位置
## available_targets: 所有可用目标列表
## hit_radius: 命中半径阈值
## hit_targets: 已命中目标列表（用于穿透模式排除）
static func check_collision(
	projectile_pos: Vector2,
	available_targets: Array,
	hit_radius: float,
	hit_targets: Array = []
) -> Node2D:
	if available_targets.is_empty():
		return null

	var closest_target: Node2D = null
	var closest_dist: float = INF

	for target in available_targets:
		# 跳过无效目标
		if target == null or not is_instance_valid(target):
			continue

		# 跳过已命中目标（穿透模式）
		if target in hit_targets:
			continue

		# 跳过死亡目标
		if target.has_method("get") and target.get("is_alive") == false:
			continue

		# 计算距离
		var dist := projectile_pos.distance_to(target.global_position)

		# 检查是否在命中半径内
		if dist < hit_radius:
			# 选择最近的目标（如果多个目标同时在命中半径内）
			if dist < closest_dist:
				closest_dist = dist
				closest_target = target

	return closest_target


## 检测投射物与所有敌人的碰撞（距离平方版本，性能优化）
## 返回命中的第一个敌人，如果没有命中返回 null
static func check_collision_squared(
	projectile_pos: Vector2,
	available_targets: Array,
	hit_radius_squared: float,
	hit_targets: Array = []
) -> Node2D:
	if available_targets.is_empty():
		return null

	var closest_target: Node2D = null
	var closest_dist_sq: float = INF

	for target in available_targets:
		# 跳过无效目标
		if target == null or not is_instance_valid(target):
			continue

		# 跳过已命中目标（穿透模式）
		if target in hit_targets:
			continue

		# 跳过死亡目标
		if target.has_method("get") and target.get("is_alive") == false:
			continue

		# 计算距离平方
		var dist_sq := projectile_pos.distance_squared_to(target.global_position)

		# 检查是否在命中半径内
		if dist_sq < hit_radius_squared:
			# 选择最近的目标
			if dist_sq < closest_dist_sq:
				closest_dist_sq = dist_sq
				closest_target = target

	return closest_target


## 检测穿透模式下的碰撞
## 返回所有命中的目标列表（按距离排序）
static func check_pierce_collision(
	projectile_pos: Vector2,
	available_targets: Array,
	hit_radius: float,
	hit_targets: Array = []
) -> Array:
	var hit_list: Array = []

	for target in available_targets:
		# 跳过无效目标
		if target == null or not is_instance_valid(target):
			continue

		# 跳过已命中目标
		if target in hit_targets:
			continue

		# 跳过死亡目标
		if target.has_method("get") and target.get("is_alive") == false:
			continue

		# 计算距离
		var dist := projectile_pos.distance_to(target.global_position)

		# 检查是否在命中半径内
		if dist < hit_radius:
			hit_list.append({"target": target, "distance": dist})

	# 按距离排序
	hit_list.sort_custom(func(a, b): return a.distance < b.distance)

	# 返回目标列表
	var result: Array = []
	for item in hit_list:
		result.append(item.target)

	return result
