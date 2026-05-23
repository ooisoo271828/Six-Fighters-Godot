class_name SpawnZone
extends RefCounted

## 刷怪区域定义 — 描述怪物在空间中的分布范围

enum Type {
	RECT,       # 矩形区域 (center, size)
	CIRCLE,     # 圆形区域 (center, radius)
	VALIDATED,  # 包裹子区域 + 验证回调，确保每个落点满足条件
}

var type: int
var center: Vector2
var size: Vector2     # RECT→(w,h)  CIRCLE→(radius,0)
var inner_zone: SpawnZone  # VALIDATED 包装的子区域
var validator: Callable    # VALIDATED 验证回调 func(pos) -> bool

func _init(p_type: int, p_center: Vector2 = Vector2.ZERO, p_size: Vector2 = Vector2.ZERO):
	type = p_type
	center = p_center
	size = p_size

## 在区域内返回一个随机位置
## rng: 返回 [0,1) 的随机函数，用于确定性随机
func get_position(rng: Callable) -> Vector2:
	match type:
		Type.RECT:
			var hw := size.x * 0.5
			var hh := size.y * 0.5
			var x: float = center.x - hw + rng.call() * size.x
			var y: float = center.y - hh + rng.call() * size.y
			return Vector2(x, y)

		Type.CIRCLE:
			var angle: float = rng.call() * TAU
			var dist: float = rng.call() * size.x
			return center + Vector2(cos(angle), sin(angle)) * dist

		Type.VALIDATED:
			if inner_zone == null:
				return center
			for _attempt in range(30):
				var pos := inner_zone.get_position(rng)
				if validator.is_null() or validator.call(pos):
					return pos
			# 保底返回子区域中心
			return inner_zone.get_position(rng)

	return center

# ── 便捷工厂方法 ──

static func rect(p_center: Vector2, rect_size: Vector2) -> SpawnZone:
	return SpawnZone.new(Type.RECT, p_center, rect_size)

static func circle(p_center: Vector2, radius: float) -> SpawnZone:
	return SpawnZone.new(Type.CIRCLE, p_center, Vector2(radius, 0))

## 在子区域基础上附加可通行验证
static func validated(inner: SpawnZone, validate: Callable) -> SpawnZone:
	var z := SpawnZone.new(Type.VALIDATED)
	z.inner_zone = inner
	z.validator = validate
	return z
