## DemoCaster — 演示器施法单位
## 简单几何图形 + 4 方向指示器
extends Node2D

var _facing: Vector2 = Vector2.RIGHT
var _dir_label: Label  # 覆盖标签

const BODY_RADIUS: float = 18.0
const BODY_COLOR: Color = Color(0.3, 0.6, 1.0, 1.0)
const RING_COLOR: Color = Color(0.5, 0.8, 1.0, 0.4)

func _ready() -> void:
	# 方向指示文字（简单 4 方向箭头文字）
	_dir_label = Label.new()
	_dir_label.text = "▶"
	_dir_label.add_theme_font_size_override("font_size", 24)
	_dir_label.modulate = Color(1, 1, 1, 0.6)
	add_child(_dir_label)

func _draw() -> void:
	# 身体（圆形）
	draw_circle(Vector2.ZERO, BODY_RADIUS, BODY_COLOR)
	draw_circle(Vector2.ZERO, BODY_RADIUS, Color(1, 1, 1, 0.15), false, 2.0)

	# 外环
	draw_arc(Vector2.ZERO, BODY_RADIUS + 6.0, 0, TAU, 32, RING_COLOR, 2.0)

func _process(_dt: float) -> void:
	# 让方向文字始终面向镜头（CanvasLayer 独立旋转）
	pass

## 设置朝向（4 方向量化）
func set_facing_4(dir: Vector2) -> void:
	if dir.length_squared() < 0.001:
		return
	_facing = dir

	# 量化 4 方向
	var angle := dir.angle()
	var label_text: String
	if angle > -PI/4 and angle <= PI/4:
		label_text = "▶"
	elif angle > PI/4 and angle <= 3*PI/4:
		label_text = "▼"
	elif angle > -3*PI/4 and angle <= -PI/4:
		label_text = "▲"
	else:
		label_text = "◀"

	if _dir_label:
		_dir_label.text = label_text
