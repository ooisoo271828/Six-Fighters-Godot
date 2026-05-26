extends Node2D

const BEAM_WIDTH: float = 90.0
const BEAM_LENGTH: float = 900.0
const INNER_RATIO: float = 0.5
const MID_RATIO: float = 0.8
const OUTER_RATIO: float = 1.0

const INNER_COLOR: Color = Color(1.0, 0.98, 0.85, 1.0)
const MID_COLOR: Color = Color(1.0, 0.65, 0.25, 0.75)
const OUTER_COLOR: Color = Color(1.0, 0.2, 0.05, 0.4)

const JITTER_AMP: float = 3.5
const JITTER_FREQ: float = 14.0
const BEAM_LIFETIME: float = 4.0
const DAMAGE_INTERVAL: float = 0.5
const FADE_OUT_DURATION: float = 0.8
const TEX_W: float = 4.0
const TEX_H: float = 4.0

const EXP_W: Array = [0.8, 0.6, 0.4, 0.2]
const EXP_H: float = 20.0
const EXP_TOTAL: float = 80.0

const BASE_STEPS: Array = [0.8, 0.6, 0.4, 0.2]
const BASE_SEG: float = 15.0
const BASE_LEN: float = 60.0

var _caster: Node2D
var _direction: Vector2
var _skill_id: String
var _damage: float
var _damage_type: String
var _signal_bus: Node
var _initialized: bool = false

var _elapsed: float = 0.0
var _damage_timer: float = 0.0
var _fading: bool = false
var _hit_targets: Array = []
var _all_hit_targets: Array = []

var _sprite_outer: Sprite2D
var _sprite_mid: Sprite2D
var _sprite_inner: Sprite2D
var _sprite_tip: Sprite2D
var _exp_sprites: Array[Sprite2D] = []
var _base_sprite: Array[Array] = [[], [], []]  # 3 layers × 4 segments
var _muzzle_particles: GPUParticles2D
var _hit_area: Area2D
var _collision_shape: CollisionShape2D
var _rect_shape: RectangleShape2D
var _noise: FastNoiseLite
var _tex_outer: Texture2D
var _tex_mid: Texture2D
var _tex_inner: Texture2D
var _tex_tip: Texture2D
var _circle_tex: Texture2D = null

var _fade_progress: float = 1.0
var _init_outer_sx: float
var _init_mid_sx: float
var _init_inner_sx: float


func _ready() -> void:
	_setup_nodes()
	_generate_textures()


func _setup_nodes() -> void:
	_hit_area = Area2D.new()
	add_child(_hit_area)
	_collision_shape = CollisionShape2D.new()
	_rect_shape = RectangleShape2D.new()
	_rect_shape.size = Vector2(BEAM_LENGTH * 0.95, BEAM_WIDTH * 0.8)
	_collision_shape.shape = _rect_shape
	_collision_shape.position = Vector2(BEAM_LENGTH * 0.475, 0)
	_hit_area.add_child(_collision_shape)

	# 三层光柱体
	_sprite_outer = Sprite2D.new()
	_sprite_outer.centered = false
	_sprite_outer.position = Vector2(0, -BEAM_WIDTH * OUTER_RATIO * 0.5)
	_init_outer_sx = BEAM_LENGTH / TEX_W
	_sprite_outer.scale = Vector2(_init_outer_sx, BEAM_WIDTH * OUTER_RATIO / TEX_H)
	add_child(_sprite_outer)

	_sprite_mid = Sprite2D.new()
	_sprite_mid.centered = false
	_sprite_mid.position = Vector2(0, -BEAM_WIDTH * MID_RATIO * 0.5)
	_init_mid_sx = BEAM_LENGTH / TEX_W
	_sprite_mid.scale = Vector2(_init_mid_sx, BEAM_WIDTH * MID_RATIO / TEX_H)
	add_child(_sprite_mid)

	_sprite_inner = Sprite2D.new()
	_sprite_inner.centered = false
	_sprite_inner.position = Vector2(0, -BEAM_WIDTH * INNER_RATIO * 0.5)
	_init_inner_sx = BEAM_LENGTH / TEX_W
	_sprite_inner.scale = Vector2(_init_inner_sx, BEAM_WIDTH * INNER_RATIO / TEX_H)
	add_child(_sprite_inner)

	# 基座分段（3层 × 4段：由宽到窄向施法者方向阶梯缩进）
	var layer_ratios: Array = [OUTER_RATIO, MID_RATIO, INNER_RATIO]
	for li in range(3):
		var lr: float = layer_ratios[li]
		var segs: Array[Sprite2D] = []
		for si in range(4):
			var sw: float = BEAM_WIDTH * lr * BASE_STEPS[si]
			var sx: float = -BASE_LEN + si * BASE_SEG
			var sl: float = BASE_LEN - si * BASE_SEG
			var sp := Sprite2D.new()
			sp.centered = false
			sp.position = Vector2(sx, -sw * 0.5)
			sp.scale = Vector2(sl / TEX_W, sw / TEX_H)
			sp.modulate.a = 0.3 + (3 - si) * 0.18
			segs.append(sp)
			add_child(sp)
		_base_sprite[li] = segs

	# 末端光晕
	_sprite_tip = Sprite2D.new()
	_sprite_tip.centered = false
	_sprite_tip.position = Vector2(BEAM_LENGTH - 2.0, -BEAM_WIDTH * 0.5)
	_sprite_tip.scale = Vector2(24.0 / TEX_W, BEAM_WIDTH / TEX_H)
	add_child(_sprite_tip)

	# 尖端扩展
	for i in range(4):
		var w: float = BEAM_WIDTH * EXP_W[i]
		var sp := Sprite2D.new()
		sp.centered = false
		sp.position = Vector2(BEAM_LENGTH - EXP_TOTAL + i * EXP_H, -w * 0.5)
		sp.scale = Vector2(EXP_H / TEX_W, w / TEX_H)
		sp.modulate = Color(1.0, 1.0, 1.0, 0.85 - i * 0.05)
		_exp_sprites.append(sp)
		add_child(sp)

	# 枪口粒子
	_muzzle_particles = GPUParticles2D.new()
	_muzzle_particles.one_shot = false
	_muzzle_particles.emitting = false
	_muzzle_particles.amount = 25
	_muzzle_particles.lifetime = 0.6
	_muzzle_particles.preprocess = 0.3
	_muzzle_particles.explosiveness = 0.0
	_muzzle_particles.randomness = 0.25
	var muzzle_mat := ParticleProcessMaterial.new()
	muzzle_mat.direction = Vector3(1, 0, 0)
	muzzle_mat.spread = 60.0
	muzzle_mat.gravity = Vector3(0, 0, 0)
	muzzle_mat.initial_velocity_min = 10.0
	muzzle_mat.initial_velocity_max = 50.0
	muzzle_mat.scale_min = 0.2
	muzzle_mat.scale_max = 0.8
	muzzle_mat.color = Color(1.0, 0.7, 0.3, 0.8)
	_muzzle_particles.texture = _gen_circle_tex()
	_muzzle_particles.process_material = muzzle_mat
	add_child(_muzzle_particles)

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.08
	_noise.fractal_octaves = 2


func _generate_textures() -> void:
	_tex_outer = _make_beam_texture(4, 4, OUTER_COLOR, 0.8)
	_tex_mid = _make_beam_texture(4, 4, MID_COLOR, 0.5)
	_tex_inner = _make_beam_texture(4, 4, INNER_COLOR, 0.0)
	_sprite_outer.texture = _tex_outer
	_sprite_mid.texture = _tex_mid
	_sprite_inner.texture = _tex_inner

	# 基座分段使用光柱体纹理（宽度视觉与光柱一致）
	var base_texs: Array = [_tex_outer, _tex_mid, _tex_inner]
	for li in range(3):
		for si in range(4):
			_base_sprite[li][si].texture = base_texs[li]

	# 末端光晕
	var tip_img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in range(4):
		for x in range(4):
			var tx: float = float(x) / 3.0
			tx = pow(tx, 1.5)
			var alpha: float = 1.0 - tx
			tip_img.set_pixel(x, y, Color(1.0, 0.85, 0.5, alpha * 0.6))
	_sprite_tip.texture = ImageTexture.create_from_image(tip_img)

	# 尖端扩展纹理
	for i in range(4):
		var bright: float = 1.0 - i * 0.12
		_exp_sprites[i].texture = _gen_fill_tex(Color(bright, bright, bright * 0.92, 1.0))


func _gen_fill_tex(color: Color) -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in range(4):
		for x in range(4):
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _gen_circle_tex() -> Texture2D:
	if _circle_tex:
		return _circle_tex
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var cx: float = 4.0
	for y in range(8):
		for x in range(8):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a: float = 1.0 - clampf(d / cx, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_circle_tex = ImageTexture.create_from_image(img)
	return _circle_tex


func _make_beam_texture(tex_w: int, tex_h: int, color: Color, inner_radius: float) -> Texture2D:
	var img := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	var cy: float = tex_h / 2.0
	for y in range(tex_h):
		var dist: float = absf(y - cy) / cy
		var alpha: float
		if dist <= inner_radius:
			alpha = 1.0
		elif dist >= 1.0:
			alpha = 0.0
		else:
			var t: float = (dist - inner_radius) / (1.0 - inner_radius)
			t = t * t * (3.0 - 2.0 * t)
			alpha = 1.0 - t
		var c: Color = color
		c.a = alpha * color.a
		for x in range(tex_w):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func initialize(caster: Node2D, direction: Vector2, damage: float, damage_type: String, skill_id: String, signal_bus: Node) -> void:
	_caster = caster
	_direction = direction.normalized()
	_damage = damage
	_damage_type = damage_type
	_skill_id = skill_id
	_signal_bus = signal_bus
	_initialized = true
	_fading = false
	_elapsed = 0.0
	_damage_timer = 0.0
	_hit_targets.clear()
	_all_hit_targets.clear()
	global_position = caster.global_position + _direction * 90.0
	rotation = _direction.angle()
	_hit_area.collision_mask = 4
	_muzzle_particles.emitting = true
	_show_all()
	set_process(true)
	visible = true


func _show_all() -> void:
	_sprite_outer.visible = true
	_sprite_mid.visible = true
	_sprite_inner.visible = true
	_sprite_tip.visible = true
	for li in range(3):
		for si in range(4):
			_base_sprite[li][si].visible = true
	for sp in _exp_sprites:
		sp.visible = true


func _process(dt: float) -> void:
	if not _initialized:
		return
	if _fading:
		return
	_elapsed += dt
	if _elapsed >= BEAM_LIFETIME - FADE_OUT_DURATION and not _fading:
		_start_fade_out()
		return
	if _elapsed >= BEAM_LIFETIME:
		_destroy_beam()
		return
	_update_jitter(dt)
	_update_pulse(dt)
	_damage_timer += dt
	if _damage_timer >= DAMAGE_INTERVAL:
		_damage_timer = 0.0
		_apply_damage()


func _update_jitter(dt: float) -> void:
	var time: float = _elapsed
	var nx: float = _noise.get_noise_2d(time * JITTER_FREQ, 0.0)
	var ny: float = _noise.get_noise_2d(0.0, time * JITTER_FREQ)
	var jv: Vector2 = Vector2(nx, ny) * JITTER_AMP
	position += jv * dt * 10.0
	var dx: float = position.x - global_position.x
	var dy: float = position.y - global_position.y
	position.x = global_position.x + clampf(dx, -JITTER_AMP, JITTER_AMP)
	position.y = global_position.y + clampf(dy, -JITTER_AMP, JITTER_AMP)
	var wj: float = 1.0 + sin(time * 24.0) * 0.012
	_sprite_outer.scale.y = (BEAM_WIDTH * OUTER_RATIO / TEX_H) * wj
	_sprite_mid.scale.y = (BEAM_WIDTH * MID_RATIO / TEX_H) * wj
	_sprite_inner.scale.y = (BEAM_WIDTH * INNER_RATIO / TEX_H) * wj


func _update_pulse(_dt: float) -> void:
	var pulse: float = 1.0 + sin(_elapsed * 6.0) * 0.03
	_sprite_inner.modulate.a = clampf(INNER_COLOR.a * pulse, 0.85, 1.0)
	_sprite_mid.modulate.a = clampf(MID_COLOR.a * (1.0 + sin(_elapsed * 4.0 + 1.0) * 0.05), 0.55, 0.9)


func _apply_damage() -> void:
	_hit_targets.clear()
	_all_hit_targets.clear()
	if not _hit_area or not _hit_area.monitoring:
		return
	var bodies: Array = []
	bodies.append_array(_hit_area.get_overlapping_bodies())
	bodies.append_array(_hit_area.get_overlapping_areas())
	for body in bodies:
		if body == _caster:
			continue
		if not body.has_method("take_damage"):
			continue
		if body in _all_hit_targets:
			continue
		_hit_targets.append(body)
		_all_hit_targets.append(body)
		if _signal_bus and _signal_bus.has_signal("skill_hit"):
			var info: Dictionary = {"caster": _caster, "target": body, "damage": _damage, "damage_type": _damage_type, "skill_id": _skill_id, "hit_pos": body.global_position}
			_signal_bus.skill_hit.emit(_caster, [body], info)
		_spawn_hit_effect(body.global_position)


func _spawn_hit_effect(pos: Vector2) -> void:
	var tex := _gen_circle_tex()
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var count: int = randi_range(4, 8)
	for i in range(count):
		var angle: float = float(i) / float(count) * TAU + randf_range(-0.25, 0.25)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var spark := Sprite2D.new()
		spark.texture = tex
		spark.scale = Vector2.ONE * randf_range(0.15, 0.4)
		spark.modulate = Color(1.0, 0.7, 0.15)
		spark.global_position = pos
		tree.root.add_child(spark)
		var tw := create_tween()
		tw.set_parallel(true)
		var target: Vector2 = spark.global_position + dir * randf_range(6.0, 20.0)
		tw.tween_property(spark, "global_position", target, 0.2)
		tw.tween_property(spark, "modulate:a", 0.0, 0.15).set_delay(0.05)
		tw.tween_callback(spark.queue_free).set_delay(0.3)


func _start_fade_out() -> void:
	if _fading:
		return
	_fading = true
	_muzzle_particles.emitting = false
	var ft := create_tween()
	ft.set_parallel(true)
	var dur: float = FADE_OUT_DURATION
	ft.tween_method(_set_inner_sx.bind(_init_inner_sx), _init_inner_sx, 0.0, dur * 0.65).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	ft.tween_method(_set_mid_sx.bind(_init_mid_sx), _init_mid_sx, 0.0, dur * 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	ft.tween_method(_set_outer_sx.bind(_init_outer_sx), _init_outer_sx, 0.0, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	ft.tween_property(_sprite_inner, "modulate:a", 0.0, dur * 0.65).set_ease(Tween.EASE_IN)
	ft.tween_property(_sprite_mid, "modulate:a", 0.0, dur * 0.8).set_ease(Tween.EASE_IN)
	ft.tween_property(_sprite_outer, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	for li in range(3):
		for si in range(4):
			ft.tween_property(_base_sprite[li][si], "modulate:a", 0.0, dur * (0.4 + li * 0.15)).set_ease(Tween.EASE_IN)
	ft.tween_property(_sprite_tip, "modulate:a", 0.0, dur * 0.5).set_ease(Tween.EASE_IN)
	for sp in _exp_sprites:
		ft.tween_property(sp, "modulate:a", 0.0, dur * 0.5).set_ease(Tween.EASE_IN)
	ft.tween_method(_update_collision_size, 1.0, 0.0, dur).set_ease(Tween.EASE_IN)
	ft.finished.connect(_destroy_beam)


func _set_outer_sx(val: float, init: float) -> void:
	_fade_progress = val / init if init > 0 else 0.0
	_sprite_outer.scale.x = maxf(val, 0.01)


func _set_mid_sx(val: float, init: float) -> void:
	_sprite_mid.scale.x = maxf(val, 0.01)


func _set_inner_sx(val: float, init: float) -> void:
	_sprite_inner.scale.x = maxf(val, 0.01)


func _update_collision_size(ratio: float) -> void:
	if _collision_shape and _rect_shape:
		_rect_shape.size = Vector2(BEAM_LENGTH * 0.95 * ratio, BEAM_WIDTH * 0.8 * ratio)
		_collision_shape.position = Vector2(BEAM_LENGTH * 0.475 * ratio, 0)


func _destroy_beam() -> void:
	_muzzle_particles.emitting = false
	set_process(false)
	visible = false
	_initialized = false
	_hit_targets.clear()
	_all_hit_targets.clear()
	var pool = get_parent()
	if pool and pool.has_method("despawn"):
		pool.despawn(self)


func reset_for_pool() -> void:
	_initialized = false
	_fading = false
	_elapsed = 0.0
	_damage_timer = 0.0
	_hit_targets.clear()
	_all_hit_targets.clear()
	_caster = null
	_signal_bus = null
	_muzzle_particles.emitting = false
	_sprite_outer.modulate.a = OUTER_COLOR.a
	_sprite_mid.modulate.a = MID_COLOR.a
	_sprite_inner.modulate.a = INNER_COLOR.a
	_sprite_tip.modulate.a = 0.6
	_init_outer_sx = BEAM_LENGTH / TEX_W
	_init_mid_sx = BEAM_LENGTH / TEX_W
	_init_inner_sx = BEAM_LENGTH / TEX_W
	_sprite_outer.scale = Vector2(_init_outer_sx, BEAM_WIDTH * OUTER_RATIO / TEX_H)
	_sprite_mid.scale = Vector2(_init_mid_sx, BEAM_WIDTH * MID_RATIO / TEX_H)
	_sprite_inner.scale = Vector2(_init_inner_sx, BEAM_WIDTH * INNER_RATIO / TEX_H)
	_sprite_tip.scale = Vector2(24.0 / TEX_W, BEAM_WIDTH / TEX_H)
	_sprite_tip.position = Vector2(BEAM_LENGTH - 2.0, -BEAM_WIDTH * 0.5)

	var layer_ratios: Array = [OUTER_RATIO, MID_RATIO, INNER_RATIO]
	for li in range(3):
		var lr: float = layer_ratios[li]
		for si in range(4):
			var sw: float = BEAM_WIDTH * lr * BASE_STEPS[si]
			var sx: float = -BASE_LEN + si * BASE_SEG
			var sl: float = BASE_LEN - si * BASE_SEG
			_base_sprite[li][si].scale = Vector2(sl / TEX_W, sw / TEX_H)
			_base_sprite[li][si].position = Vector2(sx, -sw * 0.5)
			_base_sprite[li][si].modulate.a = 0.3 + (3 - si) * 0.18

	for i in range(4):
		var w: float = BEAM_WIDTH * EXP_W[i]
		_exp_sprites[i].scale = Vector2(EXP_H / TEX_W, w / TEX_H)
		_exp_sprites[i].position = Vector2(BEAM_LENGTH - EXP_TOTAL + i * EXP_H, -w * 0.5)
		_exp_sprites[i].modulate = Color(1.0, 1.0, 1.0, 0.85 - i * 0.05)
	if _rect_shape:
		_rect_shape.size = Vector2(BEAM_LENGTH * 0.95, BEAM_WIDTH * 0.8)
		_collision_shape.position = Vector2(BEAM_LENGTH * 0.475, 0)
	set_process(false)
