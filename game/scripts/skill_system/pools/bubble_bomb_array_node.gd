## BubbleBombArrayNode — 气泡炸弹阵运行时节点
## 管理: 紫菱水晶飞行 → 射线标记 → 气泡生长 → 依次爆炸
extends Node2D

# ── 常量 ──
const CRYSTAL_END := Vector2(-180, -200)  # 水晶悬浮位（相对椭圆中心）
const FLIGHT_DURATION: float = 0.84
const RAY_DURATION: float = 0.3
const GROW_DURATION: float = 1.5
const EXPLOSION_RADIUS: float = 45.0
const EXPLOSION_INTERVAL: float = 0.25
const BUBBLE_MAX_DIAMETER: float = 60.0
const BUBBLE_HEIGHT: float = 26.0
const BUBBLE_COUNT: int = 8
const ELLIPSE_W: float = 300.0
const ELLIPSE_H: float = 200.0
const CRYSTAL_W: int = 24
const CRYSTAL_H: int = 42

enum Phase { IDLE, CRYSTAL_FLIGHT, RAY_CAST, BUBBLE_GROW, EXPLODING, DONE }

# ── 状态 ──
var _caster: Node2D
var _ellipse_center: Vector2
var _damage: float
var _damage_type: String
var _skill_id: String
var _signal_bus: Node
var _targets: Array = []

var _phase: int = Phase.IDLE
var _phase_timer: float = 0.0
var _active: bool = false
var _bomb_positions: Array[Vector2] = []
var _explosion_order: Array[int] = []
var _explosion_idx: int = 0
var _hit_counter: Dictionary = {}
var _crystal_start: Vector2
var _crystal_hover_base_y: float

# ── 子节点 ──
var _crystal: Sprite2D
var _rays: Array[Line2D] = []
var _bubbles: Array[Sprite2D] = []


# ═══════════════════ 生命周期 ═══════════════════

func _ready() -> void:
	_build_nodes()
	_generate_textures()


func _build_nodes() -> void:
	_crystal = Sprite2D.new()
	_crystal.name = "Crystal"
	_crystal.centered = true
	_crystal.visible = false
	add_child(_crystal)

	for i in BUBBLE_COUNT:
		var ray := Line2D.new()
		ray.name = "Ray%d" % i
		ray.default_color = Color(1, 1, 1, 0)
		ray.width = 2.5
		ray.visible = false
		add_child(ray)
		_rays.append(ray)

	for i in BUBBLE_COUNT:
		var sp := Sprite2D.new()
		sp.name = "Bubble%d" % i
		sp.centered = true
		sp.visible = false
		add_child(sp)
		_bubbles.append(sp)


# ═══════════════════ 纹理 ═══════════════════

func _generate_textures() -> void:
	_make_crystal_tex()
	_make_bubble_tex()


func _make_crystal_tex() -> void:
	var img := Image.create(CRYSTAL_W, CRYSTAL_H, false, Image.FORMAT_RGBA8)
	var cx := CRYSTAL_W * 0.5
	var cy := CRYSTAL_H * 0.5
	var hw := cx - 1.0
	var hh := cy - 1.0
	for y in range(CRYSTAL_H):
		for x in range(CRYSTAL_W):
			var dx := (x - cx) / hw
			var dy := (y - cy) / hh
			if absf(dx) + absf(dy) <= 1.0:
				var dist := sqrt(dx * dx + dy * dy)
				var bright := 1.0 - dist * 0.25
				img.set_pixel(x, y, Color(0.65 * bright, 0.25 * bright, 0.85 * bright, 1.0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_crystal.texture = ImageTexture.create_from_image(img)


func _make_bubble_tex() -> void:
	var w := int(BUBBLE_MAX_DIAMETER)
	var h := int(BUBBLE_HEIGHT)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w * 0.5
	var rx := cx - 2.0
	var ry := h - 2.0
	var light_dir := Vector2(-0.7, -0.7).normalized()
	for y in range(h):
		var dy: float = (h - 1.0 - y) / ry
		if dy < 0.0:
			continue
		for x in range(w):
			var dx: float = (x - cx) / rx
			var d2: float = dx * dx + dy * dy
			if d2 > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var nd := sqrt(d2)
			var nx := dx / maxf(nd, 0.001)
			var ny := dy / maxf(nd, 0.001)
			var light: float = 0.55 + 0.45 * maxf(0.0, nx * light_dir.x + ny * light_dir.y)
			var alpha: float = 0.75 * (1.0 - nd * 0.25)
			var hl := Vector2(dx - 0.25, dy - 0.35)
			var hl_len := hl.length() / 0.3
			var spec: float = exp(-hl_len * hl_len * 5.0) * 0.6
			var r_col: float = (0.6 + spec) * light
			var g_col: float = (0.25 + spec * 0.3) * light
			var b_col: float = (0.85 + spec) * light
			img.set_pixel(x, y, Color(r_col, g_col, b_col, alpha))
	_bubble_tex = ImageTexture.create_from_image(img)
	for sp in _bubbles:
		sp.texture = _bubble_tex


var _bubble_tex: Texture2D = null


# ═══════════════════ 初始化 ═══════════════════

func initialize(
	caster: Node2D,
	ellipse_center: Vector2,
	targets: Array,
	damage: float,
	damage_type: String,
	skill_id: String,
	signal_bus: Node
) -> void:
	_caster = caster
	_ellipse_center = ellipse_center
	_damage = damage
	_damage_type = damage_type
	_skill_id = skill_id
	_signal_bus = signal_bus
	_targets = targets.duplicate()
	_hit_counter.clear()
	_phase_timer = 0.0
	_explosion_idx = 0
	_active = true

	_bomb_positions = _random_points_in_ellipse()
	_crystal_start = caster.global_position - ellipse_center
	_crystal_hover_base_y = CRYSTAL_END.y

	_start_phase_flight()


func _random_points_in_ellipse() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var hw := ELLIPSE_W * 0.5
	var hh := ELLIPSE_H * 0.5
	for i in BUBBLE_COUNT:
		while true:
			var px: float = randf_range(-hw, hw)
			var py: float = randf_range(-hh, hh)
			if (px * px) / (hw * hw) + (py * py) / (hh * hh) <= 1.0:
				pts.append(Vector2(px, py))
				break
	return pts


func _hide_all() -> void:
	_crystal.visible = false
	for r in _rays:
		r.visible = false
	for b in _bubbles:
		b.visible = false


# ═══════════════════ 阶段控制 ═══════════════════

func _start_phase_flight() -> void:
	_phase = Phase.CRYSTAL_FLIGHT
	_phase_timer = 0.0
	_crystal.position = _crystal_start
	_crystal.visible = true
	set_process(true)


func _start_phase_rays() -> void:
	_phase = Phase.RAY_CAST
	_phase_timer = 0.0
	for i in BUBBLE_COUNT:
		var ray := _rays[i]
		ray.clear_points()
		ray.add_point(_crystal.position)
		ray.add_point(_bomb_positions[i])
		ray.default_color = Color(1, 1, 1, 1.0)
		ray.visible = true


func _start_phase_grow() -> void:
	_phase = Phase.BUBBLE_GROW
	_phase_timer = 0.0
	for r in _rays:
		r.visible = false
	for i in BUBBLE_COUNT:
		var sp := _bubbles[i]
		sp.position = _bomb_positions[i]
		sp.scale = Vector2.ZERO
		sp.visible = true
		var tw := create_tween()
		tw.tween_property(sp, "scale", Vector2.ONE, GROW_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)


func _start_phase_explode() -> void:
	_phase = Phase.EXPLODING
	_phase_timer = 0.0
	_explosion_idx = 0
	_explosion_order.clear()
	for i in BUBBLE_COUNT:
		_explosion_order.append(i)
	_explosion_order.shuffle()
	_explode_next()


func _explode_next() -> void:
	if not _active:
		return
	if _explosion_idx >= BUBBLE_COUNT:
		_on_all_exploded()
		return
	var idx := _explosion_order[_explosion_idx]
	_explosion_idx += 1

	var world_pos := _ellipse_center + _bomb_positions[idx]
	_apply_explosion_damage(world_pos)
	_play_explosion_vfx(_bomb_positions[idx])
	# 气泡延迟 0.15s 后碎裂消失（爆炸特效先出来）
	get_tree().create_timer(0.15).timeout.connect(func():
		if not _active:
			return
		_shatter_bubble(_bomb_positions[idx])
		_bubbles[idx].visible = false
	)

	get_tree().create_timer(EXPLOSION_INTERVAL).timeout.connect(_explode_next)


func _shatter_bubble(local_pos: Vector2) -> void:
	for i in randi_range(8, 14):
		var frag := Sprite2D.new()
		frag.name = "Frag"
		frag.centered = true
		frag.texture = _circle_tex()
		frag.scale = Vector2.ONE * randf_range(0.12, 0.3)
		frag.modulate = Color(randf_range(0.5, 0.9), randf_range(0.15, 0.4), randf_range(0.5, 0.9), 1.0)
		frag.position = local_pos + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		frag.rotation = randf_range(0, TAU)
		add_child(frag)
		var angle := randf_range(0, TAU)
		var dist := randf_range(12, 35)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(frag, "position", frag.position + Vector2(cos(angle), sin(angle)) * dist, 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(frag, "rotation", frag.rotation + randf_range(-5, 5), 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(frag, "scale", frag.scale * 0.3, 0.3)
		tw.tween_property(frag, "modulate:a", 0.0, 0.15).set_delay(0.2)
		tw.tween_callback(frag.queue_free).set_delay(0.5)


func _apply_explosion_damage(world_pos: Vector2) -> void:
	for u in _targets:
		if not (u and is_instance_valid(u) and u.get("is_alive") == true):
			continue
		var dist: float = u.global_position.distance_to(world_pos)
		if dist <= EXPLOSION_RADIUS:
			var prev: int = _hit_counter.get(u, 0)
			var decayed: float = _damage * pow(0.7, prev)
			if _signal_bus and _signal_bus.has_signal("skill_hit"):
				_signal_bus.skill_hit.emit(_caster, [u], {
					"caster": _caster, "target": u, "damage": decayed,
					"damage_type": _damage_type, "skill_id": _skill_id,
					"hit_pos": u.global_position,
				})
			_hit_counter[u] = prev + 1


func _play_explosion_vfx(local_pos: Vector2) -> void:
	# 气泡底边中点（触地点）
	var ground_pos := local_pos + Vector2(0, BUBBLE_HEIGHT * 0.5)

	# ── 空中爆裂圆盘 ──
	var burst := Sprite2D.new()
	burst.name = "Burst"
	burst.centered = true
	burst.position = local_pos
	burst.scale = Vector2.ZERO
	burst.modulate = Color(1, 1, 1, 1)
	add_child(burst)
	_make_burst_tex_for(burst)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(burst, "scale", Vector2(2.5, 2.5), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(burst, "modulate:a", 0.0, 0.15).set_delay(0.07)
	tw.tween_callback(burst.queue_free).set_delay(0.35)

	# ── 地面椭圆扩散环（触地点为中心，椭圆化） ──
	var gnd_ring := Sprite2D.new()
	gnd_ring.name = "GndRing"
	gnd_ring.centered = true
	gnd_ring.position = ground_pos
	gnd_ring.scale = Vector2.ZERO
	gnd_ring.modulate = Color(0.85, 0.35, 0.85, 0.85)
	gnd_ring.texture = _gnd_ring_tex()
	add_child(gnd_ring)
	var tw_g := create_tween()
	tw_g.set_parallel(true)
	tw_g.tween_property(gnd_ring, "scale", Vector2(4.0, 1.8), 0.35).set_ease(Tween.EASE_OUT)
	tw_g.tween_property(gnd_ring, "modulate:a", 0.0, 0.28).set_delay(0.07)
	tw_g.tween_callback(gnd_ring.queue_free).set_delay(0.4)

	# ── 地面椭圆扩散（紫色光晕） ──
	var gnd_splash := Sprite2D.new()
	gnd_splash.name = "GndSplash"
	gnd_splash.centered = true
	gnd_splash.position = ground_pos
	gnd_splash.scale = Vector2.ZERO
	gnd_splash.modulate = Color(0.7, 0.2, 0.7, 0.75)
	gnd_splash.texture = _ground_splash_tex()
	add_child(gnd_splash)
	var tw_s := create_tween()
	tw_s.set_parallel(true)
	tw_s.tween_property(gnd_splash, "scale", Vector2(2.5, 1.4), 0.3).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(gnd_splash, "modulate:a", 0.0, 0.22).set_delay(0.08)
	tw_s.tween_callback(gnd_splash.queue_free).set_delay(0.38)

	# ── 地面绽放射线（触地点出发，Y压缩椭圆化） ──
	for i in randi_range(8, 12):
		var angle: float = randf_range(0, TAU)
		var len: float = randf_range(15, 35)
		var dir := Vector2(cos(angle), sin(angle))
		dir.y *= 0.45
		dir = dir.normalized() * len
		var ray := Line2D.new()
		ray.name = "GroundRay"
		ray.default_color = Color(0.9, 0.4, 0.9, 0.8)
		ray.width = randf_range(1.5, 3.0)
		ray.add_point(ground_pos)
		ray.add_point(ground_pos + dir)
		add_child(ray)
		var tw_ray := create_tween()
		tw_ray.tween_property(ray, "default_color", Color(0.9, 0.4, 0.9, 0.0), 0.25)
		tw_ray.tween_callback(ray.queue_free).set_delay(0.3)

	# ── 火花粒子（50个） ──
	for i in range(50):
		var a: float = randf_range(0.0, TAU)
		var dist: float = randf_range(4.0, 28.0)
		var dir := Vector2(cos(a), sin(a))
		var sp := Sprite2D.new()
		sp.name = "Spark"
		sp.texture = _circle_tex()
		sp.scale = Vector2.ONE * randf_range(0.08, 0.28)
		sp.modulate = Color(1.0, randf_range(0.35, 0.9), randf_range(0.2, 0.7))
		sp.position = local_pos
		add_child(sp)
		var tw_sp := create_tween()
		tw_sp.set_parallel(true)
		tw_sp.tween_property(sp, "position", sp.position + dir * dist, 0.3).set_ease(Tween.EASE_OUT)
		tw_sp.tween_property(sp, "modulate:a", 0.0, 0.18).set_delay(0.12)
		tw_sp.tween_callback(sp.queue_free).set_delay(0.45)

	# ── 地面向上暴涌（只显示地面以上半球） ──
	for i in randi_range(10, 16):
		var sp := Sprite2D.new()
		sp.name = "UpBurst"
		sp.texture = _circle_tex()
		sp.scale = Vector2.ONE * randf_range(0.15, 0.45)
		sp.modulate = Color(randf_range(0.6, 1.0), randf_range(0.3, 0.7), randf_range(0.5, 0.9))
		sp.position = ground_pos
		add_child(sp)
		var dx := randf_range(-1.0, 1.0)
		var dy := -randf_range(0.3, 1.0)
		var dir := Vector2(dx, dy).normalized()
		var dist: float = randf_range(8, 32)
		var tw_up := create_tween()
		tw_up.set_parallel(true)
		tw_up.tween_property(sp, "position", sp.position + dir * dist, 0.32).set_ease(Tween.EASE_OUT)
		tw_up.tween_property(sp, "scale", sp.scale * 0.2, 0.3).set_ease(Tween.EASE_IN)
		tw_up.tween_property(sp, "modulate:a", 0.0, 0.22).set_delay(0.1)
		tw_up.tween_callback(sp.queue_free).set_delay(0.45)


func _on_all_exploded() -> void:
	_phase = Phase.DONE
	_active = false
	_crystal.visible = false
	set_process(false)
	var p := get_parent()
	if p and p.has_method("despawn"):
		p.despawn(self)


# ═══════════════════ 更新循环 ═══════════════════

func _process(delta: float) -> void:
	if not _active:
		return
	_phase_timer += delta

	match _phase:
		Phase.CRYSTAL_FLIGHT:
			var t := minf(_phase_timer / FLIGHT_DURATION, 1.0)
			_crystal.position = _crystal_start.lerp(CRYSTAL_END, t)
			if t >= 1.0:
				_start_phase_rays()

		Phase.RAY_CAST:
			var t := _phase_timer / RAY_DURATION
			var alpha := 1.0 - t
			for r in _rays:
				r.default_color = Color(1, 1, 1, maxf(alpha, 0))
			if t >= 1.0:
				_start_phase_grow()

		Phase.BUBBLE_GROW:
			_crystal.position.y = _crystal_hover_base_y + sin(Time.get_ticks_msec() * 0.003) * 3.0
			if _phase_timer >= GROW_DURATION:
				_start_phase_explode()

		Phase.EXPLODING:
			_crystal.position.y = _crystal_hover_base_y + sin(Time.get_ticks_msec() * 0.003) * 3.0

		Phase.DONE:
			pass


# ═══════════════════ 池重置 ═══════════════════

func reset_for_pool() -> void:
	_active = false
	_phase = Phase.IDLE
	_phase_timer = 0.0
	_explosion_idx = 0
	_hit_counter.clear()
	_bomb_positions.clear()
	_explosion_order.clear()
	_targets.clear()
	_caster = null
	_signal_bus = null
	_hide_all()
	set_process(false)


# ═══════════════════ 工具纹理 ═══════════════════

var _circle_tex_cache: Texture2D = null

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


var _ground_splash_tex_cache: Texture2D = null

func _ground_splash_tex() -> Texture2D:
	if _ground_splash_tex_cache:
		return _ground_splash_tex_cache
	var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	var cx := 24.0
	var cy := 12.0
	var rx := 21.0
	var ry := 9.0
	for y in range(24):
		for x in range(48):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var d2 := dx * dx + dy * dy
			if d2 > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var a := (1.0 - sqrt(d2)) * 0.85
			img.set_pixel(x, y, Color(0.75, 0.25, 0.75, a))
	_ground_splash_tex_cache = ImageTexture.create_from_image(img)
	return _ground_splash_tex_cache


var _gnd_ring_tex_cache: Texture2D = null

func _gnd_ring_tex() -> Texture2D:
	if _gnd_ring_tex_cache:
		return _gnd_ring_tex_cache
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cx := s * 0.5
	for y in range(s):
		for x in range(s):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			if d >= 8.0 and d <= 14.0:
				var a := 1.0 - absf(d - 11.0) / 4.0
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * 0.9))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_gnd_ring_tex_cache = ImageTexture.create_from_image(img)
	return _gnd_ring_tex_cache


func _make_burst_tex_for(sprite: Sprite2D) -> void:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cx := s * 0.5
	var r := cx - 2.0
	for y in range(s):
		for x in range(s):
			var dx := x - cx
			var dy := y - cx
			var d2 := dx * dx + dy * dy
			if d2 > r * r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var nd := sqrt(d2) / r
			var alpha: float = (1.0 - nd) * 1.0
			if alpha < 0.01:
				continue
			var r_col: float
			var g_col: float
			var b_col: float
			if nd < 0.3:
				var t := nd / 0.3
				r_col = 1.0
				g_col = 0.95 - t * 0.35
				b_col = 0.7 - t * 0.4
			elif nd < 0.6:
				var t := (nd - 0.3) / 0.3
				r_col = 1.0
				g_col = 0.6 - t * 0.3
				b_col = 0.3 + t * 0.3
			else:
				var t := (nd - 0.6) / 0.4
				r_col = 0.9 - t * 0.4
				g_col = 0.3 - t * 0.15
				b_col = 0.6 + t * 0.3
			img.set_pixel(x, y, Color(r_col, g_col, b_col, alpha))
	sprite.texture = ImageTexture.create_from_image(img)
