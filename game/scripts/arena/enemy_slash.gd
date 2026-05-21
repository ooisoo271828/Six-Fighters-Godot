extends Node2D

## 敌人弧形刀光 — 近战挥砍特效，朝目标方向挥出

var _time: float = 0.0
var _duration: float = 0.25
var _arc_radius: float = 70.0
var _arc_span: float = PI * 0.6
var _center_angle: float = 0.0  # 弧形中心朝向（由 setup 设定）
var _color1 := Color(0.9, 0.95, 1.0, 0.9)
var _color2 := Color(0.6, 0.7, 0.9, 0.0)
var _thickness: float = 3.0

func setup(p_target: Node2D = null, _p2 = null, _p3 = null) -> void:
	if p_target and is_instance_valid(p_target):
		_center_angle = global_position.angle_to_point(p_target.global_position)

func _process(delta: float) -> void:
	_time += delta
	if _time >= _duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := _time / _duration
	var alpha := 1.0 - progress
	var segments := 16
	var start_angle := _center_angle - _arc_span * 0.5

	for i in range(segments):
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a0 := start_angle + t0 * _arc_span
		var a1 := start_angle + t1 * _arc_span
		var p0 := Vector2(cos(a0), sin(a0)) * _arc_radius * (0.7 + progress * 0.3)
		var p1 := Vector2(cos(a1), sin(a1)) * _arc_radius * (0.7 + progress * 0.3)
		var c := _color1.lerp(_color2, t0)
		c.a *= alpha
		draw_line(p0, p1, c, _thickness * (1.0 - progress * 0.5))
