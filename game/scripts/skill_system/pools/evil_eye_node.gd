## EvilEyeNode — 魔眼激光运行时节点
extends Node2D

# ── 常量 ──
const DURATION: float = 5.0
const DAMAGE_INTERVAL: float = 0.5
const FADE_OUT_DURATION: float = 0.8
const BEAM_WIDTH_EYE: float = 10.0
const BEAM_WIDTH_GROUND: float = 18.0
const ELLIPSE_A: float = 60.0
const ELLIPSE_B: float = 25.0
const EYE_SIZE: int = 64
const GLOW_SIZE: int = 80

const BEAM_COLORS: Array[Color] = [
	Color(0.55, 0.02, 0.02, 0.25),
	Color(0.75, 0.04, 0.04, 0.45),
	Color(1.0,  0.25, 0.08, 0.85),
]
const BEAM_TA: Array[float] = [0.15, 0.30, 0.60]
const BEAM_BA: Array[float] = [0.35, 0.60, 0.95]

# ── 状态 ──
var _caster: Node2D
var _path_origin: Vector2
var _path_angle: float
var _path_def: LaserPathDef
var _damage: float
var _damage_type: String
var _skill_id: String
var _signal_bus: Node
var _targets: Array = []
var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _fading: bool = false
var _active: bool = false
var _hit_tick: Array = []

# ── 子节点 ──
var _eye: Sprite2D
var _glow: Sprite2D
var _beam: Array[Polygon2D] = []
var _marker: Node2D
var _fx: Sprite2D
var _ring: Sprite2D
var _flame: GPUParticles2D
var _ember: GPUParticles2D


# ═══════════════════ 生命周期 ═══════════════════

func _ready() -> void:
	_build_nodes()
	_make_eye_tex()
	_make_glow_tex()
	_make_ground_tex()


func _build_nodes() -> void:
	_eye = Sprite2D.new()
	_eye.name = "Eye"
	add_child(_eye)

	_glow = Sprite2D.new()
	_glow.name = "Glow"
	add_child(_glow)

	for i in range(3):
		var p := Polygon2D.new()
		p.name = "Beam%d" % i
		add_child(p)
		_beam.append(p)

	_marker = Node2D.new()
	_marker.name = "Marker"
	add_child(_marker)

	_fx = Sprite2D.new()
	_fx.name = "FX"
	_fx.centered = true
	_marker.add_child(_fx)

	_ring = Sprite2D.new()
	_ring.name = "Ring"
	_ring.centered = true
	_ring.modulate = Color(0.9, 0.1, 0.05, 0.0)
	_marker.add_child(_ring)

	_flame = GPUParticles2D.new()
	_flame.name = "Flame"
	_flame.one_shot = false
	_flame.emitting = false
	_flame.amount = 60
	_flame.lifetime = 0.5
	_flame.preprocess = 0.2
	_flame.explosiveness = 0.0
	_flame.randomness = 0.35
	_flame.texture = _fire_tex()
	_flame.process_material = _fire_mat()
	_marker.add_child(_flame)

	_ember = GPUParticles2D.new()
	_ember.name = "Ember"
	_ember.one_shot = false
	_ember.emitting = false
	_ember.amount = 120
	_ember.lifetime = 0.4
	_ember.preprocess = 0.1
	_ember.explosiveness = 0.0
	_ember.randomness = 0.4
	_ember.texture = _ember_tex()
	_ember.process_material = _ember_mat()
	_marker.add_child(_ember)


# ═══════════════════ 纹理 ═══════════════════

func _make_eye_tex() -> void:
	var s := EYE_SIZE
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cx := s * 0.5
	var cy := s * 0.5
	var r := s * 0.5 - 2.0
	for y in range(s):
		for x in range(s):
			var dx := x - cx
			var dy := y - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var px := absf(dx) / (r * 0.25)
			var py := absf(dy) / (r * 0.65)
			if px * px + py * py <= 1.0:
				var pd := sqrt(px * px + py * py)
				if pd < 0.25:
					img.set_pixel(x, y, Color(1.0, 0.92, 0.4, 1.0))
				elif pd < 0.55:
					img.set_pixel(x, y, Color(1.0, 0.5, 0.08, 1.0))
				else:
					img.set_pixel(x, y, Color(0.8, 0.18, 0.04, 1.0))
				continue
			var a := atan2(dy, dx)
			var v := sin(a * 5.0 + d * 0.25) * 0.5 + 0.5
			var rr := 0.08 + v * 0.12
			img.set_pixel(x, y, Color(rr, 0.005 + v * 0.015, 0.005, 1.0))
	_eye.texture = ImageTexture.create_from_image(img)

func _make_glow_tex() -> void:
	var s := GLOW_SIZE
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cx := s * 0.5
	var br := EYE_SIZE * 0.3
	for y in range(s):
		for x in range(s):
			var d := Vector2(x - cx, y - cx).length()
			var a := exp(-d * d / (br * br * 2.5)) * 0.55
			if a > 0.005:
				img.set_pixel(x, y, Color(0.5, 0.01, 0.01, a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_glow.texture = ImageTexture.create_from_image(img)
	_glow.position = Vector2(-(GLOW_SIZE - EYE_SIZE) * 0.5, -(GLOW_SIZE - EYE_SIZE) * 0.5)

func _make_ground_tex() -> void:
	var w := maxi(int(ELLIPSE_A * 3), 4)
	var h := maxi(int(ELLIPSE_B * 3), 4)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w * 0.5
	var cy := h * 0.5
	for y in range(h):
		for x in range(w):
			var dx := (x - cx) / ELLIPSE_A
			var dy := (y - cy) / ELLIPSE_B
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				img.set_pixel(x, y, Color(1.0, 0.15, 0.05, 1.0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_fx.texture = ImageTexture.create_from_image(img)

	var rim := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rc := 8.0
	for ry in range(16):
		for rx in range(16):
			var rd := Vector2(rx - rc, ry - rc).length()
			if rd >= 5.0 and rd <= 8.0:
				var ra := 1.0 - absf(rd - 6.5) / 2.0
				rim.set_pixel(rx, ry, Color(1.0, 1.0, 1.0, ra * 0.7))
			else:
				rim.set_pixel(rx, ry, Color(0, 0, 0, 0))
	_ring.texture = ImageTexture.create_from_image(rim)
	_ring.scale = Vector2(ELLIPSE_A * 2.0 / 16.0, ELLIPSE_B * 2.0 / 16.0)


# ═══════════════════ 初始化 ═══════════════════

func initialize(
	caster: Node2D,
	path_origin: Vector2,
	path_angle: float,
	path_def: LaserPathDef,
	damage: float,
	damage_type: String,
	skill_id: String,
	signal_bus: Node,
	targets: Array
) -> void:
	_caster = caster
	_path_origin = path_origin
	_path_angle = path_angle
	_path_def = path_def
	_damage = damage
	_damage_type = damage_type
	_skill_id = skill_id
	_signal_bus = signal_bus
	_targets = targets.duplicate()
	_elapsed = 0.0
	_tick_timer = 0.0
	_fading = false
	_active = true
	_hit_tick.clear()
	_flame.emitting = true
	_ember.emitting = true
	_show_all()
	set_process(true)
	visible = true

func _show_all() -> void:
	_eye.visible = true
	_glow.visible = true
	for p in _beam:
		p.visible = true
	_marker.visible = true
	_fx.visible = true
	_ring.visible = true
	_flame.visible = true
	_ember.visible = true


# ═══════════════════ 更新 ═══════════════════

func _process(dt: float) -> void:
	if not _active or _fading:
		return
	_elapsed += dt
	if _elapsed >= DURATION - FADE_OUT_DURATION and not _fading:
		_start_fade()
		return
	if _elapsed >= DURATION:
		_destroy()
		return

	var t := _elapsed / DURATION
	var lp := _path_def.get_point(t).rotated(_path_angle)
	_marker.global_position = _path_origin + lp
	_update_beam()
	_update_pulse(dt)

	_tick_timer += dt
	if _tick_timer >= DAMAGE_INTERVAL:
		_tick_timer = 0.0
		_apply_damage()

func _update_beam() -> void:
	var local := _marker.position
	if local.length_squared() < 1.0:
		return
	var dir := local.normalized()
	var perp := Vector2(-dir.y, dir.x)
	for i in range(3):
		var p: Polygon2D = _beam[i]
		var wm := 0.4 + i * 0.3
		var tw := BEAM_WIDTH_EYE * wm * 0.5
		var bw := BEAM_WIDTH_GROUND * wm * 0.5
		p.polygon = PackedVector2Array([
			perp * tw, -perp * tw,
			local + Vector2(bw, 0), local - Vector2(bw, 0),
		])
		var bc := BEAM_COLORS[i]
		var ta := BEAM_TA[i]
		var ba := BEAM_BA[i]
		p.vertex_colors = PackedColorArray([
			Color(bc.r, bc.g, bc.b, ta),
			Color(bc.r, bc.g, bc.b, ta),
			Color(bc.r, bc.g, bc.b, ba),
			Color(bc.r, bc.g, bc.b, ba),
		])

func _update_pulse(_dt: float) -> void:
	var p := 1.0 + sin(_elapsed * 4.0) * 0.04
	_glow.scale = Vector2(p, p)
	var gp := 1.0 + sin(_elapsed * 8.0) * 0.12
	_fx.modulate.a = 0.25 + gp * 0.25
	_fx.scale = Vector2.ONE * (1.0 + sin(_elapsed * 10.0) * 0.04)


# ═══════════════════ 伤害 ═══════════════════

func _apply_damage() -> void:
	var gp := _marker.global_position
	_hit_tick.clear()
	for u in _targets:
		if not (u and is_instance_valid(u) and u.get("is_alive") == true):
			continue
		var dx := absf(u.global_position.x - gp.x)
		var dy := absf(u.global_position.y - gp.y)
		if (dx * dx) / (ELLIPSE_A * ELLIPSE_A) + (dy * dy) / (ELLIPSE_B * ELLIPSE_B) <= 1.0:
			_hit_tick.append(u)
			if _signal_bus and _signal_bus.has_signal("skill_hit") and is_instance_valid(_caster):
				_signal_bus.skill_hit.emit(_caster, [u], {
					"caster": _caster, "target": u, "damage": _damage,
					"damage_type": _damage_type, "skill_id": _skill_id, "hit_pos": u.global_position,
				})
			_spark(u.global_position)

func _spark(pos: Vector2) -> void:
	var tree := get_tree()
	if not tree:
		return
	for i in randi_range(3, 6):
		var a := float(i) / float(randi_range(3, 6)) * TAU + randf_range(-0.3, 0.3)
		var d := Vector2(cos(a), sin(a))
		var s := Sprite2D.new()
		s.texture = _circle()
		s.scale = Vector2.ONE * randf_range(0.12, 0.3)
		s.modulate = Color(1.0, 0.3, 0.08)
		s.global_position = pos
		tree.root.add_child(s)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "global_position", s.global_position + d * randf_range(4.0, 14.0), 0.2)
		tw.tween_property(s, "modulate:a", 0.0, 0.15).set_delay(0.05)
		tw.tween_callback(s.queue_free).set_delay(0.3)


# ═══════════════════ 淡出 ═══════════════════

func _start_fade() -> void:
	if _fading:
		return
	_fading = true
	_flame.emitting = false
	_ember.emitting = false
	var ft := create_tween()
	ft.set_parallel(true)
	var dur := FADE_OUT_DURATION
	for i in range(3):
		ft.tween_property(_beam[i], "modulate:a", 0.0, dur * (0.3 + i * 0.2)).set_ease(Tween.EASE_IN)
	ft.tween_property(_eye, "modulate:a", 0.0, dur * 0.5).set_ease(Tween.EASE_IN)
	ft.tween_property(_glow, "modulate:a", 0.0, dur * 0.6).set_ease(Tween.EASE_IN)
	ft.tween_property(_fx, "modulate:a", 0.0, dur * 0.4).set_ease(Tween.EASE_IN)
	ft.tween_property(_ring, "modulate:a", 0.0, dur * 0.4).set_ease(Tween.EASE_IN)
	ft.finished.connect(_destroy)

func _destroy() -> void:
	set_process(false)
	_active = false
	visible = false
	_hit_tick.clear()
	_targets.clear()
	var p := get_parent()
	if p and p.has_method("despawn"):
		p.despawn(self)


# ═══════════════════ 池重置 ═══════════════════

func reset_for_pool() -> void:
	_active = false
	_fading = false
	_elapsed = 0.0
	_tick_timer = 0.0
	_hit_tick.clear()
	_targets.clear()
	_caster = null
	_signal_bus = null
	_flame.emitting = false
	_ember.emitting = false
	_eye.modulate = Color.WHITE
	_glow.modulate = Color.WHITE
	_glow.scale = Vector2.ONE
	for p in _beam:
		p.modulate = Color.WHITE
	_fx.modulate = Color(1.0, 0.15, 0.05, 1.0)
	_ring.modulate = Color(0.9, 0.1, 0.05, 0.3)
	visible = false
	set_process(false)


# ═══════════════════ 工具 ═══════════════════

var _circle_tex: Texture2D = null

func _circle() -> Texture2D:
	if _circle_tex:
		return _circle_tex
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var cx := 4.0
	for y in range(8):
		for x in range(8):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a := 1.0 - clampf(d / cx, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_circle_tex = ImageTexture.create_from_image(img)
	return _circle_tex

func _ember_tex() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var cx := 4.0
	for y in range(8):
		for x in range(8):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a := exp(-d * d / 4.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _ember_mat() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(1, 0, 0)
	m.spread = 360.0
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 30.0
	m.initial_velocity_max = 100.0
	m.scale_min = 0.15
	m.scale_max = 0.4
	var g := Gradient.new()
	g.colors = [Color(1.0, 0.98, 0.6, 0.9), Color(1.0, 0.9, 0.4, 0.4), Color(1.0, 0.85, 0.3, 0.0)]
	var gt := GradientTexture2D.new()
	gt.gradient = g
	m.color_ramp = gt
	return m


func _fire_tex() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var cx := 4.0
	for y in range(8):
		for x in range(8):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a := exp(-d * d / 6.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

func _fire_mat() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 170.0
	m.gravity = Vector3(0, -20, 0)
	m.initial_velocity_min = 50.0
	m.initial_velocity_max = 160.0
	m.scale_min = 0.3
	m.scale_max = 0.9
	m.scale_curve = null
	var g := Gradient.new()
	g.colors = [Color(1.0, 0.95, 0.5, 0.95), Color(1.0, 0.5, 0.08, 0.7), Color(0.6, 0.02, 0.02, 0.0)]
	var gt = GradientTexture2D.new()
	gt.gradient = g
	m.color_ramp = gt
	return m
