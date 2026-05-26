## FlyingSwordNode — 飞剑风暴运行时节点
## 中式宝剑 + 弧线升空 → 大圈盘旋 → 竖直下插 → 插地残留
extends Node2D

# ── 常量 ──
const SWORD_W: int = 16
const SWORD_H: int = 80
const CIRCLE_HEIGHT: float = 200.0
const ASCEND_SPEED: float = 780.0
const DIVE_SPEED: float = 850.0
const TURN_RATE: float = 3.5
const STUCK_DURATION: float = 2.0
const FADE_DURATION: float = 0.5
const ORBIT_RADIUS: float = 150.0

enum Phase { LAUNCH, ASCEND, CIRCLE, DIVE, STUCK, DONE }

var _caster: Node2D
var _target: Node2D
var _damage: float
var _damage_type: String
var _skill_id: String
var _signal_bus: Node

var _phase: int = Phase.LAUNCH
var _phase_timer: float = 0.0
var _launch_delay: float = 0.0
var _launch_dir: Vector2
var _active: bool = false
var _hit_done: bool = false
var _circle_center: Vector2
var _circle_angle: float = 0.0

var _sword: Sprite2D
var _glow: Sprite2D


func _ready() -> void:
	_build_nodes()
	_make_sword_tex()


func _build_nodes() -> void:
	_sword = Sprite2D.new()
	_sword.name = "Sword"
	_sword.centered = true
	add_child(_sword)
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.centered = true
	_glow.modulate = Color(0.75, 0.8, 1.0, 0.12)
	add_child(_glow)


func _make_sword_tex() -> void:
	var img := Image.create(SWORD_W, SWORD_H, false, Image.FORMAT_RGBA8)
	for y in range(SWORD_H):
		for x in range(SWORD_W):
			img.set_pixel(x, y, _sword_pixel(x, y))
	var tex := ImageTexture.create_from_image(img)
	_sword.texture = tex
	_glow.texture = tex


func _sword_pixel(x: int, y: int) -> Color:
	var cx := 7.5
	var dx := absf(x - cx)
	if y < 12:
		var bw := 0.5 + (y / 12.0) * 4.5
		if dx > bw: return Color(0, 0, 0, 0)
		var shade := 0.6 + 0.4 * (y / 12.0) * (1.0 - dx / bw)
		return Color(0.8 * shade, 0.8 * shade, 0.9 * shade, 1.0)
	if y < 60:
		var bw := 5.0
		if dx > bw: return Color(0, 0, 0, 0)
		var shade: float
		if dx < 1.2: shade = 0.9 - dx * 0.05
		elif dx < bw - 0.8: shade = 0.75 - (dx - 1.2) * 0.08
		else: shade = 0.45 - (dx - bw + 0.8) * 0.15
		return Color(0.85 * shade, 0.85 * shade, 0.92 * shade, 1.0)
	if y < 66:
		var bw := 7.0
		if dx > bw: return Color(0, 0, 0, 0)
		var shade := 0.7 + 0.3 * (1.0 - dx / bw)
		return Color(0.9 * shade, 0.7 * shade, 0.25 * shade, 1.0)
	var bw := 4.0
	if dx > bw: return Color(0, 0, 0, 0)
	var wrap := 0.7 if (int(y * 0.4) % 2 == 0) else 1.0
	var shade := (0.55 + 0.3 * (1.0 - dx / bw)) * wrap
	return Color(0.45 * shade, 0.22 * shade, 0.1 * shade, 1.0)


func initialize(caster: Node2D, target: Node2D, damage: float, damage_type: String, skill_id: String, signal_bus: Node) -> void:
	_caster = caster
	_target = target
	_damage = damage
	_damage_type = damage_type
	_skill_id = skill_id
	_signal_bus = signal_bus
	_phase = Phase.LAUNCH
	_phase_timer = 0.0
	_launch_delay = randf_range(0.0, 0.8)
	_hit_done = false
	_active = true
	_sword.modulate = Color(1, 1, 1, 1)
	_sword.scale = Vector2(0.7, 0.7)
	_sword.region_enabled = false
	_sword.position = Vector2.ZERO
	_sword.rotation = 0.0
	_glow.modulate = Color(0.75, 0.8, 1.0, 0.12)
	set_process(true)
	visible = true
	_sword.visible = false
	_glow.visible = false


# ═══════════════════ 阶段控制 ═══════════════════

func _start_ascend() -> void:
	_phase = Phase.ASCEND
	_phase_timer = 0.0
	_sword.visible = true
	_glow.visible = true
	if not is_instance_valid(_target):
		_destroy()
		return
	_circle_center = _target.global_position + Vector2(0, -CIRCLE_HEIGHT)
	# 目标：飞到轨道圈上的一个点（半径 ORBIT_RADIUS，随机起始角）
	var entry_angle := randf_range(0, TAU)
	var entry_point := _circle_center + Vector2(cos(entry_angle), sin(entry_angle)) * ORBIT_RADIUS
	var base_dir := global_position.direction_to(entry_point)
	var offset := randf_range(0.6, 1.5) * (1.0 if randf() < 0.5 else -1.0)
	_launch_dir = base_dir.rotated(offset)
	_circle_angle = entry_angle
	_sword.rotation = _launch_dir.angle() + PI / 2.0
	_glow.rotation = _sword.rotation


func _start_circle() -> void:
	_phase = Phase.CIRCLE
	_phase_timer = 0.0


func _start_dive() -> void:
	_phase = Phase.DIVE
	_phase_timer = 0.0
	_sword.rotation = PI
	_glow.rotation = PI


func _on_hit() -> void:
	if _hit_done or not _active: return
	_hit_done = true
	if is_instance_valid(_target) and _signal_bus and _signal_bus.has_signal("skill_hit"):
		_signal_bus.skill_hit.emit(_caster, [_target], {
			"caster": _caster, "target": _target, "damage": _damage,
			"damage_type": _damage_type, "skill_id": _skill_id,
			"hit_pos": global_position,
		})
	_play_ground_explosion()
	_sword.region_enabled = true
	_sword.region_rect = Rect2(0, SWORD_H * 0.25, SWORD_W, SWORD_H * 0.75)
	_sword.position.y = -SWORD_H * 0.375
	_phase = Phase.STUCK
	_phase_timer = 0.0


func _start_fade() -> void:
	_phase = Phase.DONE
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sword, "modulate:a", 0.0, FADE_DURATION).set_ease(Tween.EASE_IN)
	tw.tween_property(_glow, "modulate:a", 0.0, FADE_DURATION * 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(_destroy).set_delay(FADE_DURATION + 0.05)


func _destroy() -> void:
	_active = false
	visible = false
	set_process(false)
	var p := get_parent()
	if p and p.has_method("despawn"):
		p.despawn(self)


# ═══════════════════ 地面爆炸特效 ═══════════════════

func _play_ground_explosion() -> void:
	var gp := global_position
	var splash := Sprite2D.new()
	splash.name = "GSplash"
	splash.centered = true
	splash.position = gp
	splash.scale = Vector2.ZERO
	splash.modulate = Color(0.75, 0.25, 0.75, 0.8)
	splash.texture = _gnd_splash_tex()
	get_parent().add_child(splash)
	var tw_s := create_tween()
	tw_s.set_parallel(true)
	tw_s.tween_property(splash, "scale", Vector2(2.5, 1.3), 0.3).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(splash, "modulate:a", 0.0, 0.2).set_delay(0.1)
	tw_s.tween_callback(splash.queue_free).set_delay(0.4)
	for i in randi_range(8, 12):
		var angle: float = randf_range(0, TAU)
		var len: float = randf_range(12, 30)
		var dir := Vector2(cos(angle), sin(angle))
		dir.y *= 0.45
		dir = dir.normalized() * len
		var ray := Line2D.new()
		ray.name = "GRay"
		ray.default_color = Color(0.85, 0.35, 0.85, 0.7)
		ray.width = randf_range(1.0, 2.5)
		ray.add_point(gp)
		ray.add_point(gp + dir)
		get_parent().add_child(ray)
		var tw_r := create_tween()
		tw_r.tween_property(ray, "default_color", Color(0.85, 0.35, 0.85, 0.0), 0.25)
		tw_r.tween_callback(ray.queue_free).set_delay(0.3)
	for i in range(40):
		var a: float = randf_range(0.0, TAU)
		var d: float = randf_range(4.0, 30.0)
		var sp := Sprite2D.new()
		sp.name = "GSpark"
		sp.texture = _circle_tex()
		sp.scale = Vector2.ONE * randf_range(0.08, 0.3)
		sp.modulate = Color(1.0, randf_range(0.35, 0.9), randf_range(0.2, 0.7))
		sp.position = gp
		get_parent().add_child(sp)
		var tw_p := create_tween()
		tw_p.set_parallel(true)
		tw_p.tween_property(sp, "position", sp.position + Vector2(cos(a), sin(a)) * d, 0.28).set_ease(Tween.EASE_OUT)
		tw_p.tween_property(sp, "modulate:a", 0.0, 0.18).set_delay(0.1)
		tw_p.tween_callback(sp.queue_free).set_delay(0.4)


# ═══════════════════ 更新循环 ═══════════════════

func _process(dt: float) -> void:
	if not _active: return
	_phase_timer += dt
	match _phase:
		Phase.LAUNCH:
			if _phase_timer >= _launch_delay:
				_start_ascend()

		Phase.ASCEND:
			if not is_instance_valid(_target):
				_destroy(); return
			_circle_center = _target.global_position + Vector2(0, -CIRCLE_HEIGHT)
			var target_pt := _circle_center + Vector2(cos(_circle_angle), sin(_circle_angle)) * ORBIT_RADIUS
			var target_dir := global_position.direction_to(target_pt)
			var diff := wrapf(target_dir.angle() - _launch_dir.angle(), -PI, PI)
			_launch_dir = _launch_dir.rotated(clampf(diff, -TURN_RATE * dt, TURN_RATE * dt))
			global_position += _launch_dir * ASCEND_SPEED * dt
			_sword.rotation = _launch_dir.angle() + PI / 2.0
			_glow.rotation = _sword.rotation
			if global_position.distance_squared_to(target_pt) < 60.0 * 60.0:
				_start_circle()

		Phase.CIRCLE:
			if not is_instance_valid(_target):
				_destroy(); return
			_circle_center = _target.global_position + Vector2(0, -CIRCLE_HEIGHT)
			# 大圈盘旋（150px 半径，3.0 rad/s ≈ 2s 一圈）
			_circle_angle += 4.5 * dt
			var radius := maxf(ORBIT_RADIUS - 60.0 * _phase_timer, 20.0)
			global_position = _circle_center + Vector2(cos(_circle_angle), sin(_circle_angle)) * radius
			# Phase A: 水平盘旋，剑尖沿轨道切线
			# Phase B: 快速倾斜到竖直
			if _phase_timer < 0.6:
				var tangent := _circle_angle + PI / 2.0
				_sword.rotation = tangent + PI / 2.0
			else:
				_sword.rotation = move_toward(_sword.rotation, PI, 9.0 * dt)
			_glow.rotation = _sword.rotation
			# 盘旋到位 + 基本竖直 → 下插
			if _phase_timer > 0.8 and absf(_sword.rotation - PI) < 0.15:
				_start_dive()

		Phase.DIVE:
			if not is_instance_valid(_target):
				_destroy(); return
			var tpos := _target.global_position
			var dir := global_position.direction_to(tpos)
			global_position += dir * DIVE_SPEED * dt
			if global_position.distance_squared_to(tpos) < 22.0 * 22.0:
				_on_hit()

		Phase.STUCK:
			if not _active: return
			_sword.modulate.a = 0.85 + sin(_phase_timer * 3.0) * 0.08
			if _phase_timer >= STUCK_DURATION:
				_start_fade()

		Phase.DONE:
			pass


func reset_for_pool() -> void:
	_active = false; _hit_done = false
	_phase = Phase.LAUNCH; _phase_timer = 0.0
	_caster = null; _target = null; _signal_bus = null
	visible = false; _sword.visible = false; _glow.visible = false
	_sword.modulate = Color.WHITE
	_glow.modulate = Color(0.75, 0.8, 1.0, 0.12)
	_sword.rotation = 0.0; _sword.position = Vector2.ZERO
	_sword.region_enabled = false
	set_process(false)


# ═══════════════════ 工具纹理 ═══════════════════

var _circle_tex_cache: Texture2D = null

func _circle_tex() -> Texture2D:
	if _circle_tex_cache: return _circle_tex_cache
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var cx := 4.0
	for y in range(8):
		for x in range(8):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a := 1.0 - clampf(d / cx, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_circle_tex_cache = ImageTexture.create_from_image(img)
	return _circle_tex_cache


var _gnd_splash_tex_cache: Texture2D = null

func _gnd_splash_tex() -> Texture2D:
	if _gnd_splash_tex_cache: return _gnd_splash_tex_cache
	var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	var cx := 24.0; var cy := 12.0; var rx := 21.0; var ry := 9.0
	for y in range(24):
		for x in range(48):
			var dx := (x - cx) / rx; var dy := (y - cy) / ry
			if dx * dx + dy * dy > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0)); continue
			var a := (1.0 - sqrt(dx * dx + dy * dy)) * 0.85
			img.set_pixel(x, y, Color(0.75, 0.25, 0.75, a))
	_gnd_splash_tex_cache = ImageTexture.create_from_image(img)
	return _gnd_splash_tex_cache
