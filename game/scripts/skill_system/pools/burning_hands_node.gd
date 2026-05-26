## BurningHandsNode — 火焰之手运行时节点
## 双掌推出火浪 → 三层波浪翻涌 → 持续灼烧 → 余烬消散
extends Node2D

# ── 常量 ──
const FAN_RADIUS: float = 300.0
const FAN_HALF_ANGLE: float = PI / 4.0  # ±45°
const ARC_STEPS: int = 24

const TOTAL_DURATION: float = 5.0
const WINDUP_DURATION: float = 0.2
const BURST_DURATION: float = 0.3
const BURN_DURATION: float = 4.0
const FADE_DURATION: float = 0.3

const DAMAGE_INTERVAL: float = 0.5
const DAMAGE_TICKS: int = 9

const WAVE_LAYERS: int = 3
const FIRE_SPRITE_COUNT: int = 8
const EMBER_COUNT: int = 40

const COLOR_RED: Color = Color(1.0, 0.13, 0.0, 1.0)
const COLOR_ORANGE: Color = Color(1.0, 0.42, 0.0, 1.0)
const COLOR_YELLOW: Color = Color(1.0, 0.8, 0.0, 1.0)

# ── 状态 ──
var _caster: Node2D
var _damage: float
var _damage_type: String
var _skill_id: String
var _signal_bus: Node
var _targets: Array = []

var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _tick_count: int = 0
var _active: bool = false
var _fading: bool = false
var _wave_distortion: float = 0.0

# ── 子节点 ──
var _fan_fill: Polygon2D
var _wave_layers: Array[Polygon2D] = []
var _wave_base_alphas: Array[float] = [0.375, 0.525, 0.675]
var _wave_base_scales: Array[float] = [1.0, 0.82, 0.6]
var _fire_sprites: Array[Sprite2D] = []
var _fire_base_alphas: Array[float] = []
var _ember_particles: GPUParticles2D
var _spray_particles: GPUParticles2D
var _swirl_l: Sprite2D
var _swirl_r: Sprite2D
var _fan_base_polygon: PackedVector2Array

var _circle_tex_cache: Texture2D = null


# ═══════════════════ 生命周期 ═══════════════════

func _ready() -> void:
	_build_nodes()
	_generate_textures()


func _build_nodes() -> void:
	# 扇形底层填充
	_fan_fill = Polygon2D.new()
	_fan_fill.name = "FanFill"
	_fan_fill.color = Color(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.0)
	add_child(_fan_fill)

	# 三层波浪（index 0 = 最外层红色，index 1 = 中间橙色，index 2 = 最内层黄色）
	var wave_colors: Array[Color] = [COLOR_RED, COLOR_ORANGE, COLOR_YELLOW]
	for i in range(WAVE_LAYERS):
		var wave := Polygon2D.new()
		wave.name = "Wave%d" % i
		wave.color = Color(wave_colors[i].r, wave_colors[i].g, wave_colors[i].b, 0.0)
		add_child(wave)
		_wave_layers.append(wave)

	# 8个火苗精灵
	for i in range(FIRE_SPRITE_COUNT):
		var sp := Sprite2D.new()
		sp.name = "Fire%d" % i
		sp.centered = true
		sp.visible = false
		sp.modulate = Color(1.0, 0.6, 0.2, 0.0)
		add_child(sp)
		_fire_sprites.append(sp)
		_fire_base_alphas.append(0.0)

	# 余烬粒子
	_ember_particles = GPUParticles2D.new()
	_ember_particles.name = "Embers"
	_ember_particles.one_shot = false
	_ember_particles.emitting = false
	_ember_particles.amount = EMBER_COUNT
	_ember_particles.lifetime = 1.2
	_ember_particles.preprocess = 0.3
	_ember_particles.explosiveness = 0.0
	_ember_particles.randomness = 0.4
	_ember_particles.texture = _circle_tex()
	_ember_particles.process_material = _make_ember_mat()
	_ember_particles.position = Vector2(FAN_RADIUS * 0.5, 0)
	add_child(_ember_particles)

	# 径向火焰喷射粒子（从圆心沿扇形方向向外喷射）
	_spray_particles = GPUParticles2D.new()
	_spray_particles.name = "FireSpray"
	_spray_particles.one_shot = false
	_spray_particles.emitting = false
	_spray_particles.amount = 200
	_spray_particles.lifetime = 0.6
	_spray_particles.preprocess = 0.3
	_spray_particles.explosiveness = 0.0
	_spray_particles.randomness = 0.3
	_spray_particles.texture = _spray_tex()
	_spray_particles.process_material = _make_spray_mat()
	add_child(_spray_particles)

	# 蓄力旋涡（左右两个，反向旋转）
	_swirl_l = Sprite2D.new()
	_swirl_l.name = "SwirlL"
	_swirl_l.centered = true
	_swirl_l.visible = false
	add_child(_swirl_l)

	_swirl_r = Sprite2D.new()
	_swirl_r.name = "SwirlR"
	_swirl_r.centered = true
	_swirl_r.visible = false
	add_child(_swirl_r)


func _generate_textures() -> void:
	_fan_fill.texture = _make_fill_tex()
	for i in range(WAVE_LAYERS):
		_wave_layers[i].texture = _make_fill_tex()
	for sp in _fire_sprites:
		sp.texture = _make_fire_sprite_tex()
	_swirl_l.texture = _make_swirl_tex()
	_swirl_r.texture = _make_swirl_tex()


# ═══════════════════ 初始化 ═══════════════════

func initialize(
	caster: Node2D,
	direction: Vector2,
	damage: float,
	damage_type: String,
	skill_id: String,
	signal_bus: Node,
	targets: Array
) -> void:
	_caster = caster
	_damage = damage
	_damage_type = damage_type
	_skill_id = skill_id
	_signal_bus = signal_bus
	_targets = targets.duplicate()
	_elapsed = 0.0
	_tick_timer = -WINDUP_DURATION  # 第一发 tick 在 burst 开始后 0.5s 触发
	_tick_count = 0
	_active = true
	_fading = false
	_wave_distortion = 0.0

	global_position = caster.global_position
	rotation = direction.angle()

	# 计算扇形基础多边形
	_fan_base_polygon = _compute_fan_polygon(1.0)
	_fan_fill.polygon = _fan_base_polygon

	# 波浪层初始状态（半径=0，透明）
	for i in range(WAVE_LAYERS):
		_wave_layers[i].polygon = _compute_fan_polygon(0.01)
		_wave_layers[i].color.a = 0.0

	# 火苗隐藏
	for i in range(FIRE_SPRITE_COUNT):
		_fire_sprites[i].visible = false
		_fire_sprites[i].modulate = Color(1.0, 0.8, 0.3, 0.0)
		_fire_base_alphas[i] = 0.0

	# 旋涡初始状态
	_swirl_l.visible = true
	_swirl_l.position = Vector2(30, -25)
	_swirl_l.scale = Vector2.ONE * 1.2
	_swirl_l.modulate = Color(1.0, 0.5, 0.1, 1.0)
	_swirl_r.visible = true
	_swirl_r.position = Vector2(30, 25)
	_swirl_r.scale = Vector2.ONE * 1.2
	_swirl_r.modulate = Color(1.0, 0.5, 0.1, 1.0)

	_fan_fill.color.a = 0.0
	_ember_particles.emitting = true
	_spray_particles.emitting = true

	set_process(true)
	visible = true


# ═══════════════════ 更新循环 ═══════════════════

func _process(dt: float) -> void:
	if not _active or _fading:
		return

	_elapsed += dt
	_wave_distortion += dt

	# ── 蓄力阶段 ──
	if _elapsed < WINDUP_DURATION:
		_update_windup(dt)
		return

	# ── 喷发阶段 ──
	if _elapsed < WINDUP_DURATION + BURST_DURATION:
		_update_burst(dt)
		_update_damage(dt)
		return

	# ── 持续灼烧阶段 ──
	if _elapsed < TOTAL_DURATION - FADE_DURATION:
		_update_burn(dt)
		_update_damage(dt)
		return

	# ── 收尾淡出 ──
	if not _fading:
		_start_fade()


func _update_windup(dt: float) -> void:
	var t := _elapsed / WINDUP_DURATION
	var eased_t := t * t  # ease-in
	# 旋涡向中心收缩聚拢
	_swirl_l.position = Vector2(30, -25) * (1.0 - eased_t * 0.6)
	_swirl_l.scale = Vector2.ONE * (1.2 - eased_t * 0.4)
	_swirl_l.rotation += 12.0 * dt
	_swirl_l.modulate.a = 1.0

	_swirl_r.position = Vector2(30, 25) * (1.0 - eased_t * 0.6)
	_swirl_r.scale = Vector2.ONE * (1.2 - eased_t * 0.4)
	_swirl_r.rotation -= 12.0 * dt
	_swirl_r.modulate.a = 1.0


func _update_burst(_dt: float) -> void:
	var burst_t := (_elapsed - WINDUP_DURATION) / BURST_DURATION
	burst_t = clampf(burst_t, 0.0, 1.0)
	var eased := burst_t * burst_t * (3.0 - 2.0 * burst_t)  # smoothstep

	# 隐藏旋涡
	_swirl_l.visible = false
	_swirl_r.visible = false

	# 底层填充淡入
	_fan_fill.color.a = 0.375 * eased

	# 三层波浪从中心向外扩展（扩展到各自的 resting scale）
	for i in range(WAVE_LAYERS):
		var delay := float(i) * 0.08
		var layer_t := clampf((burst_t - delay) / (1.0 - delay), 0.0, 1.0)
		layer_t = layer_t * layer_t * (3.0 - 2.0 * layer_t)
		var radius := layer_t * _wave_base_scales[i]
		_wave_layers[i].polygon = _compute_fan_polygon(radius)
		# alpha: 快速亮起，然后稳定
		var alpha_t := clampf(burst_t * 3.0, 0.0, 1.0)
		_wave_layers[i].color.a = _wave_base_alphas[i] * alpha_t


func _update_burn(dt: float) -> void:
	# 首次进入：定位火苗
	if not _fire_sprites[0].visible:
		_position_fire_sprites()
		for sp in _fire_sprites:
			sp.visible = true
		for i in range(FIRE_SPRITE_COUNT):
			_fire_base_alphas[i] = 0.525 + randf() * 0.225

	# 底层持续灼烧
	_fan_fill.color.a = 0.375 + sin(_elapsed * 3.0) * 0.075

	# 波浪层呼吸 + 边缘波动
	for i in range(WAVE_LAYERS):
		var breathe := sin(_elapsed * (2.5 + i * 0.8) + float(i) * 1.2) * 0.1125
		_wave_layers[i].color.a = _wave_base_alphas[i] + breathe
		# 边缘波动：更新多边形顶点
		var wave_t := sin(_elapsed * 2.0 + float(i) * 0.7) * 0.06
		_wave_layers[i].polygon = _compute_fan_polygon(_wave_base_scales[i] + wave_t)

	# 火苗闪烁
	for i in range(FIRE_SPRITE_COUNT):
		var flicker := 0.7 + sin(_elapsed * (4.0 + float(i) * 1.3) + float(i) * 2.1) * 0.3
		_fire_sprites[i].modulate.a = _fire_base_alphas[i] * flicker
		_fire_sprites[i].scale = Vector2.ONE * (1.0 + sin(_elapsed * (3.0 + float(i)) + float(i)) * 0.3)


func _update_damage(dt: float) -> void:
	_tick_timer += dt
	if _tick_timer >= DAMAGE_INTERVAL:
		_tick_timer = 0.0
		_tick_count += 1
		_apply_damage()
		# 伤害tick视觉脉冲
		_damage_pulse()


func _apply_damage() -> void:
	for u in _targets:
		if not (u and is_instance_valid(u) and u.get("is_alive") == true):
			continue
		# 距离检测
		var to_target: Vector2 = u.global_position - global_position
		var dist: float = to_target.length()
		if dist > FAN_RADIUS or dist < 1.0:
			continue
		# 角度检测：目标方向与扇形中心方向的夹角
		var angle_diff := absf(wrapf(to_target.angle() - rotation, -PI, PI))
		if angle_diff > FAN_HALF_ANGLE:
			continue
		# 命中
		if _signal_bus and _signal_bus.has_signal("skill_hit"):
			_signal_bus.skill_hit.emit(_caster, [u], {
				"caster": _caster, "target": u, "damage": _damage,
				"damage_type": _damage_type, "skill_id": _skill_id,
				"hit_pos": u.global_position,
			})
		_spawn_hit_spark(u.global_position)


func _damage_pulse() -> void:
	# 波浪层亮度脉冲
	for i in range(WAVE_LAYERS):
		_wave_layers[i].color.a = minf(_wave_base_alphas[i] + 0.1125, 1.0)
	# 火苗亮度脉冲
	for i in range(FIRE_SPRITE_COUNT):
		_fire_base_alphas[i] = minf(_fire_base_alphas[i] + 0.1125, 0.9)
	# 延时恢复
	var tw := create_tween()
	tw.tween_callback(_restore_pulse).set_delay(0.15)


func _restore_pulse() -> void:
	if not _active or _fading:
		return
	for i in range(WAVE_LAYERS):
		_wave_layers[i].color.a = _wave_base_alphas[i]
	for i in range(FIRE_SPRITE_COUNT):
		_fire_base_alphas[i] = 0.525 + randf() * 0.225


# ═══════════════════ 收尾 ═══════════════════

func _start_fade() -> void:
	if _fading:
		return
	_fading = true
	_ember_particles.emitting = false
	_spray_particles.emitting = false

	var ft := create_tween()
	ft.set_parallel(true)
	var dur := FADE_DURATION
	ft.tween_property(_fan_fill, "color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	for i in range(WAVE_LAYERS):
		ft.tween_property(_wave_layers[i], "color:a", 0.0, dur * (0.6 + i * 0.15)).set_ease(Tween.EASE_IN)
	for sp in _fire_sprites:
		ft.tween_property(sp, "modulate:a", 0.0, dur * 0.5).set_ease(Tween.EASE_IN)
	ft.finished.connect(_destroy)


func _destroy() -> void:
	_active = false
	visible = false
	set_process(false)
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
	_tick_count = 0
	_wave_distortion = 0.0
	_targets.clear()
	_caster = null
	_signal_bus = null
	_fan_fill.color.a = 0.0
	for i in range(WAVE_LAYERS):
		_wave_layers[i].color.a = 0.0
		_wave_layers[i].polygon = PackedVector2Array()
	for i in range(FIRE_SPRITE_COUNT):
		_fire_sprites[i].visible = false
		_fire_sprites[i].modulate.a = 0.0
		_fire_base_alphas[i] = 0.0
	_ember_particles.emitting = false
	_spray_particles.emitting = false
	_swirl_l.visible = false
	_swirl_r.visible = false
	visible = false
	set_process(false)


# ═══════════════════ 几何计算 ═══════════════════

func _compute_fan_polygon(radius_ratio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var r := FAN_RADIUS * radius_ratio
	for i in range(ARC_STEPS + 1):
		var angle := -FAN_HALF_ANGLE + (2.0 * FAN_HALF_ANGLE) * float(i) / float(ARC_STEPS)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	return pts


func _position_fire_sprites() -> void:
	for i in range(FIRE_SPRITE_COUNT):
		var angle := randf_range(-FAN_HALF_ANGLE * 0.85, FAN_HALF_ANGLE * 0.85)
		var dist := randf_range(FAN_RADIUS * 0.15, FAN_RADIUS * 0.85)
		_fire_sprites[i].position = Vector2(cos(angle), sin(angle)) * dist
		_fire_sprites[i].scale = Vector2.ONE * randf_range(0.8, 1.5)


# ═══════════════════ 视觉效果 ═══════════════════

func _spawn_hit_spark(pos: Vector2) -> void:
	var tree := get_tree()
	if not tree:
		return
	var count := randi_range(6, 12)
	for i in range(count):
		var angle := randf_range(0, TAU)
		var dir := Vector2(cos(angle), sin(angle))
		var sp := Sprite2D.new()
		sp.texture = _circle_tex()
		sp.scale = Vector2.ONE * randf_range(0.2, 0.5)
		sp.modulate = Color(1.0, randf_range(0.5, 1.0), randf_range(0.1, 0.5))
		sp.global_position = pos
		tree.root.add_child(sp)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(sp, "global_position", sp.global_position + dir * randf_range(10.0, 35.0), 0.25)
		tw.tween_property(sp, "modulate:a", 0.0, 0.2).set_delay(0.05)
		tw.tween_callback(sp.queue_free).set_delay(0.35)


# ═══════════════════ 纹理生成 ═══════════════════

func _make_fill_tex() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in range(4):
		for x in range(4):
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


func _make_fire_sprite_tex() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var cx := 16.0
	for y in range(32):
		for x in range(32):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a := exp(-d * d / 40.0)
			img.set_pixel(x, y, Color(1.0, 0.7, 0.2, a))
	return ImageTexture.create_from_image(img)


func _make_swirl_tex() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var cx := 16.0
	for y in range(32):
		for x in range(32):
			var dx := x - cx
			var dy := y - cx
			var d := sqrt(dx * dx + dy * dy)
			var angle := atan2(dy, dx)
			var spiral := sin(angle * 3.0 - d * 0.4) * 0.5 + 0.5
			var ring := clampf(1.0 - absf(d - 10.0) / 8.0, 0.0, 1.0)
			var a := spiral * ring
			img.set_pixel(x, y, Color(1.0, 0.6, 0.15, a))
	return ImageTexture.create_from_image(img)


func _spray_tex() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var cx := 8.0
	for y in range(16):
		for x in range(16):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a := 1.0 - clampf(d / cx, 0.0, 1.0)
			a = a * a  # sharper edge
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _circle_tex() -> Texture2D:
	if _circle_tex_cache:
		return _circle_tex_cache
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var cx := 4.0
	for y in range(8):
		for x in range(8):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a := 1.0 - clampf(d / cx, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_circle_tex_cache = ImageTexture.create_from_image(img)
	return _circle_tex_cache


func _make_spray_mat() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(1, 0, 0)
	m.spread = 45.0
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 400.0
	m.initial_velocity_max = 600.0
	m.scale_min = 2.0
	m.scale_max = 3.0
	var g := Gradient.new()
	g.colors = [Color(1.0, 0.9, 0.3, 0.95), Color(1.0, 0.5, 0.1, 0.8), Color(0.9, 0.2, 0.05, 0.4), Color(0.6, 0.1, 0.02, 0.0)]
	var gt := GradientTexture2D.new()
	gt.gradient = g
	m.color_ramp = gt
	return m


func _make_ember_mat() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 50.0
	m.gravity = Vector3(0, -40, 0)
	m.initial_velocity_min = 30.0
	m.initial_velocity_max = 80.0
	m.scale_min = 0.15
	m.scale_max = 0.4
	var g := Gradient.new()
	g.colors = [Color(1.0, 0.9, 0.5, 0.9), Color(1.0, 0.6, 0.2, 0.5), Color(0.8, 0.2, 0.05, 0.0)]
	var gt := GradientTexture2D.new()
	gt.gradient = g
	m.color_ramp = gt
	return m
