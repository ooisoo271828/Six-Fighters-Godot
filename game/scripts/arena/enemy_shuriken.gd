extends Node2D

## 敌人忍者飞镖 — 直线飞行的旋转投射物

var _direction: Vector2
var _target: Node2D
var speed: float = 280.0
var damage: float = 0.0
var _rot_speed: float = 12.0
var _hit_callback: Callable
var _hit: bool = false

func setup(p_target: Node2D, p_damage: float, p_callback: Callable = Callable()) -> void:
	_target = p_target
	_direction = global_position.direction_to(p_target.global_position)
	damage = p_damage
	_hit_callback = p_callback

func _process(delta: float) -> void:
	if _hit:
		return
	global_position += _direction * speed * delta
	rotation += _rot_speed * delta
	_check_hit()

func _check_hit() -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	if global_position.distance_to(_target.global_position) < 16.0:
		_hit = true
		if _hit_callback.is_valid():
			_hit_callback.call(damage)
		queue_free()

func _draw() -> void:
	var pts: PackedVector2Array = []
	var r_outer := 7.0
	var r_inner := 2.5
	for i in range(8):
		var angle := i * PI / 4.0
		var r := r_outer if i % 2 == 0 else r_inner
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(pts, Color(0.85, 0.85, 0.95))
	draw_circle(Vector2.ZERO, 1.5, Color(0.3, 0.3, 0.4))
