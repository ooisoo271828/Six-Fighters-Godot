## LaserPathDef — 魔眼激光地面轨迹线定义
## 定义轨迹形状（S形/Z形/抛物线），在0~1进度采样局部位移
class_name LaserPathDef
extends Resource

enum PathType { S_SHAPE, Z_SHAPE, PARABOLA }

@export var path_type: PathType = PathType.S_SHAPE

## S形参数
@export var amplitude: float = 80.0
@export var frequency: float = 1.5

## Z形参数
@export var segment_count: int = 4
@export var turn_offset: float = 80.0

## 抛物线参数
@export var arc_height: float = 120.0

## 通用
@export var total_length: float = 400.0

## 在局部坐标系中取样轨迹上的点
## t: 0.0（起点）~ 1.0（终点）
func get_point(t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	var x: float = t * total_length - total_length * 0.5

	match path_type:
		PathType.S_SHAPE:
			return Vector2(x, amplitude * sin(t * frequency * TAU))

		PathType.Z_SHAPE:
			var seg_idx: int = mini(int(t * segment_count), segment_count - 1)
			var seg_t: float = t * segment_count - seg_idx
			var y: float = 0.0
			if seg_idx % 2 == 0:
				y = seg_t * turn_offset
			else:
				y = (1.0 - seg_t) * turn_offset
			return Vector2(x, y - turn_offset * 0.5)

		PathType.PARABOLA:
			return Vector2(x, -arc_height * 4.0 * t * (1.0 - t))

	return Vector2(x, 0.0)
