extends Node2D

## 传送门视觉效果 — 脉冲动画同心圆环

const INNER_RADIUS := 20.0
const MID_RADIUS := 36.0
const OUTER_RADIUS := 52.0
const GLOW_RADIUS := 64.0

const COLOR_INNER := Color(0.3, 0.1, 0.5, 0.9)
const COLOR_MID := Color(0.5, 0.2, 0.8, 0.7)
const COLOR_OUTER := Color(0.6, 0.3, 0.9, 0.4)
const COLOR_GLOW := Color(0.4, 0.15, 0.7, 0.15)

var _time := 0.0
var _is_highlighted := false

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func set_highlighted(highlighted: bool) -> void:
	_is_highlighted = highlighted

func _draw() -> void:
	# 外层光晕（脉冲透明度）
	var glow_alpha := 0.1 + sin(_time * 2.0) * 0.08
	if _is_highlighted:
		glow_alpha += 0.12
	draw_circle(Vector2.ZERO, GLOW_RADIUS, Color(COLOR_GLOW.r, COLOR_GLOW.g, COLOR_GLOW.b, glow_alpha))

	# 外环
	var outer_alpha := COLOR_OUTER.a + sin(_time * 1.5) * 0.1
	draw_arc(Vector2.ZERO, OUTER_RADIUS, 0, TAU, 48, Color(COLOR_OUTER.r, COLOR_OUTER.g, COLOR_OUTER.b, outer_alpha), 3.0)

	# 中环
	draw_arc(Vector2.ZERO, MID_RADIUS, 0, TAU, 48, COLOR_MID, 2.5)

	# 内环（旋转效果）
	var inner_start := _time * 1.2
	draw_arc(Vector2.ZERO, INNER_RADIUS, inner_start, inner_start + PI * 1.6, 32, COLOR_INNER, 2.0)
	draw_arc(Vector2.ZERO, INNER_RADIUS, inner_start + PI, inner_start + PI * 2.6, 32, COLOR_INNER, 2.0)

	# 中心亮点
	var center_alpha := 0.5 + sin(_time * 3.0) * 0.2
	draw_circle(Vector2.ZERO, 6.0, Color(0.8, 0.5, 1.0, center_alpha))

	# 高亮时显示交互提示
	if _is_highlighted:
		draw_arc(Vector2.ZERO, OUTER_RADIUS + 8, 0, TAU, 48, Color(1.0, 0.85, 0.3, 0.5 + sin(_time * 4.0) * 0.3), 2.0)
