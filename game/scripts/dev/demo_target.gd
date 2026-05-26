## DemoTarget — 演示器受体木偶
## 简单箭靶/训练假人视觉效果
extends Area2D

var is_alive: bool = true

func take_damage(_dmg: float) -> void:
	pass  # demo target: no actual damage handling

const RADIUS: float = 14.0
const RING_WIDTH: float = 3.0

func _ready() -> void:
	var _s := CollisionShape2D.new()
	_s.shape = CircleShape2D.new()
	_s.shape.radius = 17.0
	add_child(_s)
	collision_layer = 4

func _draw() -> void:
	# 靶心
	draw_circle(Vector2.ZERO, RADIUS, Color(0.85, 0.3, 0.2))
	draw_circle(Vector2.ZERO, RADIUS * 0.6, Color(0.95, 0.5, 0.3))
	draw_circle(Vector2.ZERO, RADIUS * 0.25, Color(1.0, 0.8, 0.4))

	# 十字靶线
	var c := Color(1, 1, 1, 0.3)
	draw_line(Vector2(-RADIUS, 0), Vector2(RADIUS, 0), c, 1.0)
	draw_line(Vector2(0, -RADIUS), Vector2(0, RADIUS), c, 1.0)

	# 外环
	draw_arc(Vector2.ZERO, RADIUS + RING_WIDTH, 0, TAU, 32, Color(1, 1, 1, 0.15), 1.0)

	# 底部影子偏移
	draw_circle(Vector2(2, 2), RADIUS * 0.5, Color(0, 0, 0, 0.15))
