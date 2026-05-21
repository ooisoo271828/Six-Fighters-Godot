extends Node2D

## 战斗场景地面 — 网格背景
## 绘制大范围网格，为镜头移动和角色移动提供空间参照

@export var grid_size: int = 64        # 网格单元尺寸（像素）
@export var major_every: int = 4       # 每 N 格一条主网格线
@export var world_half_size: float = 2000.0  # 半径（覆盖 4000×4000 世界区域）

# 颜色
@export var color_base := Color(0.13, 0.13, 0.17)
@export var color_minor := Color(0.19, 0.19, 0.25, 0.4)
@export var color_major := Color(0.26, 0.26, 0.34, 0.6)
@export var color_zone_enemy := Color(0.3, 0.15, 0.15, 0.15)
@export var color_zone_hero := Color(0.15, 0.2, 0.3, 0.15)

func _draw() -> void:
	var half := world_half_size
	var rect := Rect2(-half, -half, half * 2, half * 2)

	# 底色
	draw_rect(rect, color_base)

	# 敌人区域标记（上方）
	draw_rect(Rect2(-half, -half, half * 2, half * 0.4), color_zone_enemy)

	# 英雄区域标记（下方）
	draw_rect(Rect2(-half, half * 0.2, half * 2, half * 0.8), color_zone_hero)

	# 网格线
	var steps := int(half * 2 / grid_size)
	for i in range(steps + 1):
		var pos := -half + i * grid_size
		var is_major := i % major_every == 0
		var col := color_major if is_major else color_minor
		var width := 1.0 if is_major else 0.5

		# 竖线
		draw_line(Vector2(pos, -half), Vector2(pos, half), col, width)
		# 横线
		draw_line(Vector2(-half, pos), Vector2(half, pos), col, width)

	# 中心十字标记
	var cross_color := Color(0.4, 0.55, 0.75, 0.5)
	var cross_len := 40.0
	draw_line(Vector2(-cross_len, 0), Vector2(cross_len, 0), cross_color, 1.5)
	draw_line(Vector2(0, -cross_len), Vector2(0, cross_len), cross_color, 1.5)

	# 边界虚线框（可视范围提示）
	var border_color := Color(0.5, 0.3, 0.3, 0.3)
	draw_rect(Rect2(-half, -half, half * 2, half * 2), border_color, false, 2.0)
