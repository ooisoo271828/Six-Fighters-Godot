## TargetSelector — 静态目标选择工具
## 提供通用的目标搜索函数，供 CombatMediator 和 ProjectileNode（弹射）复用
class_name TargetSelector

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
	return find_nearest(pos, enemies, func(e): return e and is_instance_valid(e) and e.is_alive)


## 查找最近的存活英雄
static func find_nearest_alive_hero(pos: Vector2, heroes: Array) -> Node2D:
	return find_nearest(pos, heroes, func(h): return h and is_instance_valid(h) and h.is_alive)


## 查找最近单位（排除指定目标）— 用于弹射和穿透排除
static func find_nearest_excluding(pos: Vector2, units: Array, exclude: Node2D) -> Node2D:
	return find_nearest(pos, units, func(u): return u != exclude and is_instance_valid(u) and u.is_alive)
