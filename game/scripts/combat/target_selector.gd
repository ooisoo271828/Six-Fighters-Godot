## TargetSelector — 静态目标选择工具
## 提供通用的目标搜索函数，供 CombatMediator、SkillRoot 和 ProjectileNode（弹射）复用
class_name TargetSelector

# ── 验证 Callable ──

## 默认验证：存活 + 实例有效
static func _is_valid_target(u) -> bool:
	return u and is_instance_valid(u) and u.get("is_alive") == true

## 验证 + 排除指定目标
static func _is_valid_excluding(exclude: Node2D) -> Callable:
	return func(u): return u != exclude and _is_valid_target(u)

# ── 射程过滤 ──

## 返回射程内的存活目标列表
static func filter_in_range(pos: Vector2, units: Array, max_range: float) -> Array:
	var result: Array = []
	for u in units:
		if not _is_valid_target(u):
			continue
		if pos.distance_to(u.position) <= max_range:
			result.append(u)
	return result

# ── 通用搜索 ──

## 通用最近单位搜索
static func find_nearest(pos: Vector2, units: Array, validate: Callable) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for unit in units:
		if not validate.call(unit):
			continue
		var dist: float = pos.distance_to(unit.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	return nearest


## 查找最近的存活敌人
static func find_nearest_alive_enemy(pos: Vector2, enemies: Array) -> Node2D:
	return find_nearest(pos, enemies, func(e): return _is_valid_target(e))


## 查找最近的存活英雄
static func find_nearest_alive_hero(pos: Vector2, heroes: Array) -> Node2D:
	return find_nearest(pos, heroes, func(h): return _is_valid_target(h))


## 查找最近单位（排除指定目标）— 用于弹射和穿透排除
static func find_nearest_excluding(pos: Vector2, units: Array, exclude: Node2D) -> Node2D:
	return find_nearest(pos, units, _is_valid_excluding(exclude))

# ── 目标选择策略 ──

## 射程内随机选一个
static func find_random(pos: Vector2, units: Array, max_range: float) -> Node2D:
	var candidates := filter_in_range(pos, units, max_range)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


## 射程内血量比例最低的
static func find_lowest_hp(pos: Vector2, units: Array, max_range: float) -> Node2D:
	var candidates := filter_in_range(pos, units, max_range)
	if candidates.is_empty():
		return null
	var best: Node2D = candidates[0]
	var best_ratio: float = INF
	for u in candidates:
		var hp_ratio: float = 0.0
		var u_max_hp = u.get("max_hp")
		var u_hp = u.get("current_hp")
		if u_max_hp and u_max_hp > 0:
			hp_ratio = float(u_hp) / float(u_max_hp)
		if hp_ratio < best_ratio:
			best_ratio = hp_ratio
			best = u
	return best
static func find_nearest_in_range(pos: Vector2, units: Array, max_range: float) -> Node2D:
	var candidates := filter_in_range(pos, units, max_range)
	if candidates.is_empty():
		return null
	return find_nearest(pos, candidates, func(_u): return true)


## 统一入口：根据 target_mode 选择目标
## target_mode: 0=NEAREST, 1=FARTHEST, 2=LOWEST_HP, 3=HIGHEST_HP, 4=RANDOM, 5=ALL
## 返回单个 Node2D（ALL 模式除外，但 ALL 模式不在本函数处理）
static func select_target(pos: Vector2, units: Array, target_mode: int, max_range: float, exclude: Array = []) -> Node2D:
	# 先过滤掉已排除的目标
	var filtered: Array = []
	for u in units:
		if u in exclude:
			continue
		if _is_valid_target(u):
			filtered.append(u)

	match target_mode:
		0:  # NEAREST
			return find_nearest_in_range(pos, filtered, max_range)
		1:  # FARTHEST
			var candidates := filter_in_range(pos, filtered, max_range)
			if candidates.is_empty():
				return null
			var farthest: Node2D = null
			var farthest_dist: float = -1.0
			for c in candidates:
				var d: float = pos.distance_to(c.position)
				if d > farthest_dist:
					farthest_dist = d
					farthest = c
			return farthest
		2:  # LOWEST_HP
			return find_lowest_hp(pos, filtered, max_range)
		3:  # HIGHEST_HP
			var candidates_hp := filter_in_range(pos, filtered, max_range)
			if candidates_hp.is_empty():
				return null
			var highest: Node2D = null
			var highest_ratio: float = -1.0
			for c in candidates_hp:
				var ratio: float = 0.0
				var c_max_hp = c.get("max_hp")
				var c_hp = c.get("current_hp")
				if c_max_hp and c_max_hp > 0:
					ratio = float(c_hp) / float(c_max_hp)
				if ratio > highest_ratio:
					highest_ratio = ratio
					highest = c
			return highest
		4:  # RANDOM
			return find_random(pos, filtered, max_range)
		_:
			return find_nearest_in_range(pos, filtered, max_range)


## 最大覆盖角度选择：找到能让射线型技能覆盖最多敌方单位的角度
## 返回最优角度（弧度），如果没有合法目标返回 INF
## beam_width: 射线宽度（像素）
## beam_length: 射线长度（像素）
static func find_max_coverage_angle(caster_pos: Vector2, units: Array, beam_width: float, beam_length: float, max_range: float) -> float:
	var candidates: Array = []
	for u in units:
		if not _is_valid_target(u):
			continue
		var dist: float = caster_pos.distance_to(u.position)
		if dist <= max_range:
			candidates.append(u)

	if candidates.is_empty():
		return INF

	# 如果只有一个目标，直接朝向它
	if candidates.size() == 1:
		return caster_pos.angle_to_point(candidates[0].position)

	# 将所有目标转换为相对于施法者的角度和距离
	var target_data: Array = []
	for u in candidates:
		var offset: Vector2 = u.position - caster_pos
		var angle: float = offset.angle()
		var dist: float = offset.length()
		target_data.append({"unit": u, "angle": angle, "dist": dist, "pos": u.position})

	# 收集所有候选角度（每个目标的角度 + 边界角度）
	var angles_to_test: Array = []
	for td in target_data:
		angles_to_test.append(td["angle"])

	# 对于每个目标，计算激光柱能覆盖它的角度范围
	# 激光柱是一个矩形：从施法者位置沿某个方向延伸 beam_length，宽度 beam_width
	# 目标被覆盖的条件：目标到射线中心线的垂直距离 <= beam_width/2，且沿射线方向的距离 <= beam_length
	for td in target_data:
		var dist: float = td["dist"]
		if dist > beam_length:
			continue
		# 计算能让激光柱覆盖此目标的角度偏移范围
		var max_lateral: float = beam_width * 0.5
		if dist > 0:
			var half_angle: float = atan2(max_lateral, dist)
			var base_angle: float = td["angle"]
			angles_to_test.append(base_angle - half_angle)
			angles_to_test.append(base_angle + half_angle)

	# 对每个候选角度，计算覆盖的目标数量
	var best_angle: float = 0.0
	var best_count: int = 0

	for test_angle in angles_to_test:
		var count: int = 0
		var dir: Vector2 = Vector2(cos(test_angle), sin(test_angle))
		var perp: Vector2 = Vector2(-dir.y, dir.x)

		for td in target_data:
			var offset: Vector2 = td["pos"] - caster_pos
			var along: float = offset.dot(dir)
			var lateral: float = absf(offset.dot(perp))

			if along >= 0 and along <= beam_length and lateral <= beam_width * 0.5:
				count += 1

		if count > best_count:
			best_count = count
			best_angle = test_angle

	return best_angle


## 弹射目标选择：排除已命中目标，无射程限制
## target_mode: 0=NEAREST, 2=LOWEST_HP, 4=RANDOM
static func select_for_bounce(pos: Vector2, units: Array, target_mode: int, exclude: Array) -> Node2D:
	var filtered: Array = []
	for u in units:
		var skip := false
		for e in exclude:
			if e == u:
				skip = true
				break
		if skip:
			continue
		if _is_valid_target(u):
			filtered.append(u)
	if filtered.is_empty():
		return null
	match target_mode:
		0:
			return find_nearest(pos, filtered, func(_u): return true)
		2:
			return _find_lowest_hp_no_range(pos, filtered)
		4:
			return filtered[randi() % filtered.size()]
		_:
			return find_nearest(pos, filtered, func(_u): return true)


## 魔眼激光最优路径放置
## 找到能覆盖最多目标的轨迹位置和朝向
## 返回 {path_origin, path_angle, eye_position, covered_count}
static func find_optimal_laser_path(
	caster_pos: Vector2,
	units: Array,
	cast_range: float,
	path_def: LaserPathDef,
	ellipse_a: float,
	ellipse_b: float,
	eye_height: float = 180.0
) -> Dictionary:
	var candidates: Array = []
	for u in units:
		if not _is_valid_target(u):
			continue
		if caster_pos.distance_to(u.position) <= cast_range:
			candidates.append(u)

	if candidates.is_empty():
		return {"path_origin": Vector2(), "path_angle": 0.0, "eye_position": Vector2(), "covered_count": 0}

	if candidates.size() == 1:
		var origin: Vector2 = candidates[0].position
		return {
			"path_origin": origin,
			"path_angle": 0.0,
			"eye_position": origin + Vector2(0, -eye_height),
			"covered_count": 1,
		}

	# 计算质心
	var centroid: Vector2 = Vector2()
	for u in candidates:
		centroid += u.position
	centroid /= candidates.size()

	var best_angle: float = 0.0
	var best_count: int = 0
	var angles_to_try: int = 12

	for ai in angles_to_try:
		var angle: float = float(ai) / float(angles_to_try) * TAU
		var count: int = 0

		for u in candidates:
			# 在轨迹上采样10个点，检查目标是否落入椭圆
			for ti in range(10):
				var t: float = float(ti) / 9.0
				var local_pt: Vector2 = path_def.get_point(t).rotated(angle)
				var world_pt: Vector2 = centroid + local_pt

				var dx: float = absf(u.position.x - world_pt.x)
				var dy: float = absf(u.position.y - world_pt.y)
				if (dx * dx) / (ellipse_a * ellipse_a) + (dy * dy) / (ellipse_b * ellipse_b) <= 1.0:
					count += 1
					break  # 每个目标只计一次

		if count > best_count:
			best_count = count
			best_angle = angle

	return {
		"path_origin": centroid,
		"path_angle": best_angle,
		"eye_position": centroid + Vector2(0, -eye_height),
		"covered_count": best_count,
	}


## 无射程限制的血量比例最低目标
static func _find_lowest_hp_no_range(_pos: Vector2, units: Array) -> Node2D:
	var candidates: Array = []
	for u in units:
		if _is_valid_target(u):
			candidates.append(u)
	if candidates.is_empty():
		return null
	var best: Node2D = candidates[0]
	var best_ratio: float = INF
	for u in candidates:
		var hp_ratio: float = 0.0
		var u_max_hp = u.get("max_hp")
		var u_hp = u.get("current_hp")
		if u_max_hp and u_max_hp > 0:
			hp_ratio = float(u_hp) / float(u_max_hp)
		if hp_ratio < best_ratio:
			best_ratio = hp_ratio
			best = u
	return best
## Small laser beam: 120-degree cone targeting
static func find_best_cone_angle(caster_pos: Vector2, units: Array, cone_deg: float, max_range: float) -> float:
	var candidates: Array = []
	for u in units:
		if not _is_valid_target(u):
			continue
		var dist: float = caster_pos.distance_to(u.position)
		if dist <= max_range and dist > 1.0:
			candidates.append(u)
	if candidates.is_empty():
		return INF
	if candidates.size() == 1:
		return rad_to_deg(caster_pos.angle_to_point(candidates[0].position))
	var half_cone := cone_deg * 0.5
	var best_angle_deg: float = 0.0
	var best_count: int = -1
	var step_deg := 5.0
	var test_deg := 0.0
	while test_deg < 360.0:
		var count := 0
		var cone_dir := Vector2.RIGHT.rotated(deg_to_rad(test_deg))
		for u in candidates:
			var to_u: Vector2 = u.position - caster_pos
			var angle_diff := rad_to_deg(absf(to_u.angle_to(cone_dir)))
			if angle_diff <= half_cone:
				count += 1
		if count > best_count:
			best_count = count
			best_angle_deg = test_deg
		test_deg += step_deg
	return best_angle_deg


## 气泡炸弹阵：找覆盖最多目标的椭圆区域
## 返回椭圆中心（局部坐标）和覆盖目标数
static func find_optimal_ellipse(caster_pos: Vector2, units: Array, cast_range: float,
		ellipse_w: float = 300.0, ellipse_h: float = 200.0) -> Dictionary:
	var candidates: Array = []
	for u in units:
		if not _is_valid_target(u):
			continue
		var dist: float = caster_pos.distance_to(u.position)
		if dist <= cast_range and dist > 1.0:
			candidates.append(u)
	if candidates.is_empty():
		return {"ellipse_center": Vector2.ZERO, "covered_count": 0}

	var hw := ellipse_w * 0.5
	var hh := ellipse_h * 0.5
	var best_center: Vector2 = candidates[0].position
	var best_count := -1

	# 候选中心：每个目标位置 + 所有目标质心
	var test_centers: Array[Vector2] = []
	for u in candidates:
		test_centers.append(u.position)
	# 质心
	var centroid := Vector2.ZERO
	for u in candidates:
		centroid += u.position
	centroid /= candidates.size()
	test_centers.append(centroid)

	for center in test_centers:
		# 椭圆中心必须在射程内
		if caster_pos.distance_to(center) > cast_range:
			continue
		var count := 0
		for u in candidates:
			var dx := absf(u.position.x - center.x)
			var dy := absf(u.position.y - center.y)
			if (dx * dx) / (hw * hw) + (dy * dy) / (hh * hh) <= 1.0:
				count += 1
		if count > best_count:
			best_count = count
			best_center = center

	return {"ellipse_center": best_center, "covered_count": best_count}
