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
	var best: Node2D = null
	var best_ratio: float = INF
	for u in units:
		if not _is_valid_target(u):
			continue
		if pos.distance_to(u.position) > max_range:
			continue
		var hp_ratio: float = 0.0
		var stats = u.get("stats")
		if stats and stats.max_hp > 0:
			hp_ratio = float(stats.hp) / float(stats.max_hp)
		if hp_ratio < best_ratio:
			best_ratio = hp_ratio
			best = u
	return best


## 射程内最近目标（带射程过滤）
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
				var c_stats = c.get("stats")
				if c_stats and c_stats.max_hp > 0:
					ratio = float(c_stats.hp) / float(c_stats.max_hp)
				if ratio > highest_ratio:
					highest_ratio = ratio
					highest = c
			return highest
		4:  # RANDOM
			return find_random(pos, filtered, max_range)
		_:
			return find_nearest_in_range(pos, filtered, max_range)


## 弹射目标选择：排除已命中目标，无射程限制
## target_mode: 0=NEAREST, 2=LOWEST_HP, 4=RANDOM
static func select_for_bounce(pos: Vector2, units: Array, target_mode: int, exclude: Array) -> Node2D:
	var filtered: Array = []
	for u in units:
		if u in exclude:
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


## 无射程限制的血量比例最低目标
static func _find_lowest_hp_no_range(_pos: Vector2, units: Array) -> Node2D:
	var best: Node2D = null
	var best_ratio: float = INF
	for u in units:
		if not _is_valid_target(u):
			continue
		var hp_ratio: float = 0.0
		var stats = u.get("stats")
		if stats and stats.max_hp > 0:
			hp_ratio = float(stats.hp) / float(stats.max_hp)
		if hp_ratio < best_ratio:
			best_ratio = hp_ratio
			best = u
	return best
