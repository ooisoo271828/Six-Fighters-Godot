## DemoBG — 演示器俯视网格背景
## 绘制深色地砖网格，提供空间参考系
extends Node2D

## 网格尺寸（世界坐标）
const GRID_SIZE: int = 50
const MAJOR_GRID: int = 4  # 每 4 格一条主网格线
const AREA: float = 1200.0

func _draw() -> void:
	# 底色
	var rect := Rect2(-AREA/2, -AREA/2, AREA, AREA)
	draw_rect(rect, Color(0.12, 0.12, 0.16))

	# 网格线
	var half := AREA / 2.0
	var minor_color := Color(0.18, 0.18, 0.24, 0.5)
	var major_color := Color(0.25, 0.25, 0.32, 0.7)

	for i in range(0, int(AREA / GRID_SIZE) + 1):
		var pos := -half + i * GRID_SIZE
		var is_major := i % MAJOR_GRID == 0

		# 竖线
		draw_line(Vector2(pos, -half), Vector2(pos, half), major_color if is_major else minor_color, 1.0 if is_major else 0.5)
		# 横线
		draw_line(Vector2(-half, pos), Vector2(half, pos), major_color if is_major else minor_color, 1.0 if is_major else 0.5)

	# 中心十字参考线
	var cross_color := Color(0.35, 0.5, 0.7, 0.6)
	var cross_len: float = 30.0
	draw_line(Vector2(-cross_len, 0), Vector2(cross_len, 0), cross_color, 2.0)
	draw_line(Vector2(0, -cross_len), Vector2(0, cross_len), cross_color, 2.0)

	# 软跟随半径参考圈（350px）
	draw_arc(Vector2.ZERO, 350.0, 0, TAU, 48, Color(0.35, 0.5, 0.7, 0.15), 1.0)
