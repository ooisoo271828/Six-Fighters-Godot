## ProjectileNode — 单个投射物运行时节点
## 挂载到 ProjectilePool 下，在世界坐标系中移动和渲染
## v2.0：支持多层核心、抖动、前缘火焰、增强拖尾和爆炸
extends Node2D

var _chain: ExecutionChain
var _visual_def: Resource
var _signal_bus: Node
var _initialized: bool = false

## ── 视觉组件：多层核心 ──
var _core_sprite: Sprite2D
var _inner_sprite: Sprite2D          # 内核层
var _hotspot_sprite: Sprite2D        # 热点层
var _nose_sprite: Sprite2D           # 弹尖
var _glow_sprite: Sprite2D           # 摩擦光晕层

var _glow2_sprite: Sprite2D          # 外层辉光层
var _ray_sprite: Sprite2D            # 辐射射线层
## ── 视觉组件：粒子系统 ──
var _trail_particles: GPUParticles2D     # 拖尾粒子
var _front_flame_particles: GPUParticles2D  # 前缘火焰粒子

## ── 纹理缓存 ──
var _core_texture: Texture2D
var _glow_texture: Texture2D
var _trail_texture: Texture2D
var _explosion_texture: Texture2D
var _front_flame_texture: Texture2D
var _nose_texture: Texture2D

## ── 运动状态 ──
var _elapsed: float = 0.0
var _distance: float = 0.0
var _target_reached: bool = false
var _spawn_timer: float = 0.0         # 发射延迟计时器
var _spawned: bool = false            # 是否已到延迟开始运动

## ── 曲线运动参数 ──
var _bezier_start: Vector2
var _bezier_control: Vector2
var _bezier_end: Vector2

## ── 抖动状态 ──
var _jitter_time: float = 0.0

## ── 拖尾粒子发射偏移 ──
var _last_trail_pos: Vector2
const TRAIL_EMIT_INTERVAL: float = 0.016  # ~60fps

## ── 彗星拖尾（Line2D 三层绘制）──
var _comet_line_outer: Line2D
var _comet_line_mid: Line2D
var _comet_line_inner: Line2D
var _trail_offsets: Array[Vector2] = []   # 局部偏移量（相对子弹当前位置）
var _last_global_pos: Vector2              # 上一帧全局位置，用于计算移动补偿
const MAX_TRAIL_POINTS := 28

## ── 程序化纹理缓存（所有 ProjectileNode 共享）──
static var _shared_circle_tex: Texture2D
static var _shared_nose_tex: Texture2D

static var _shared_ray_tex: Texture2D

func _ready() -> void:
	_setup_visuals()


func initialize(chain: ExecutionChain, visual_def: Resource, signal_bus: Node) -> void:
	_chain = chain
	_visual_def = visual_def
	_signal_bus = signal_bus
	_initialized = true

	# 加载纹理
	_load_textures()

	# 初始化位置
	global_position = chain.position
	_last_trail_pos = chain.position

	# 初始化曲线
	if chain.trajectory_type > 0:
		_init_bezier()

	# 初始化视觉
	_apply_visual()

	# 连接销毁信号
	_chain.chain_destroyed.connect(_on_chain_destroyed)
	_chain.chain_hit.connect(_on_chain_hit)

	# 重置状态
	_elapsed = 0.0
	_distance = 0.0
	_target_reached = false
	_jitter_time = 0.0
	_spawn_timer = 0.0
	_spawned = _chain.spawn_delay <= 0.0

	set_process(true)


## ── 获取或创建共享的程序化纹理 ──

static func _get_shared_circle_texture() -> Texture2D:
	if _shared_circle_tex != null:
		return _shared_circle_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for x in range(16):
		for y in range(16):
			var dx := float(x) - 7.5
			var dy := float(y) - 7.5
			if dx * dx + dy * dy <= 49.0:
				img.set_pixel(x, y, Color.WHITE)
	_shared_circle_tex = ImageTexture.create_from_image(img)
	return _shared_circle_tex


static func _get_shared_nose_texture() -> Texture2D:
	if _shared_nose_tex != null:
		return _shared_nose_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	# 右指三角形：尖端在右侧
	for y in range(16):
		var half_h: float = 8.0 - abs(float(y) - 7.5)
		if half_h <= 0.0:
			continue
		for x in range(16):
			var progress: float = float(x) / 15.0
			var max_half: float = half_h * (1.0 - progress * 0.7)
			var dy: float = abs(float(y) - 7.5)
			if dy <= max_half and x >= 4:
				img.set_pixel(x, y, Color.WHITE)
	_shared_nose_tex = ImageTexture.create_from_image(img)
	return _shared_nose_tex


static func _get_shared_ray_texture() -> Texture2D:
	if _shared_ray_tex != null:
		return _shared_ray_tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	# 绘制辐射射线：从中心向外发散的12条光纹
	var cx := 15.5
	var cy := 15.5
	# 核心光晕（中心亮斑）
	for x in range(32):
		for y in range(32):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx*dx + dy*dy)
			# 中心实心圆（半径5）
			if dist <= 4.5:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			# 中心到半透明的渐变（半径5~12）
			elif dist <= 11.5:
				var a := 1.0 - (dist - 4.5) / 7.0
				img.set_pixel(x, y, Color(1, 1, 1, a * 0.6))
	# 辐射射线（12条）
	for r in range(12):
		var angle := float(r) / 12.0 * TAU
		var sin_a := sin(angle)
		var cos_a := cos(angle)
		for d in range(3, 18):
			var px := int(cx + cos_a * float(d) + 0.5)
			var py := int(cy + sin_a * float(d) + 0.5)
			if px >= 0 and px < 32 and py >= 0 and py < 32:
				# 射线渐变透明
				var a := 1.0 - float(d - 3) / 15.0
				# 射线宽度3像素（画3条相邻线）
				for w in range(-1, 2):
					var wx := int(cx + cos_a * float(d) + sin_a * float(w) * 0.5 + 0.5)
					var wy := int(cy + sin_a * float(d) - cos_a * float(w) * 0.5 + 0.5)
					if wx >= 0 and wx < 32 and wy >= 0 and wy < 32:
						var existing := img.get_pixel(wx, wy)
						var new_a := maxf(existing.a, a * 0.35)
						img.set_pixel(wx, wy, Color(1, 1, 1, new_a))
	_shared_ray_tex = ImageTexture.create_from_image(img)
	return _shared_ray_tex

## ── 加载纹理资源 ──

func _load_textures() -> void:
	if _visual_def == null:
		return

	# 核心纹理（优先用新字段 tex_core_path）
	var core_path: String = _get_visual_str("tex_core_path", "core_texture_path", "")
	if not core_path.is_empty() and ResourceLoader.exists(core_path):
		_core_texture = load(core_path)

	# 光晕纹理
	var glow_path: String = _get_visual_str("tex_glow_path", "", "")
	if not glow_path.is_empty() and ResourceLoader.exists(glow_path):
		_glow_texture = load(glow_path)
	elif _core_texture:
		_glow_texture = _core_texture

	# 拖尾纹理
	var trail_path: String = _get_visual_str("tex_trail_path", "trail_texture_path", "")
	if not trail_path.is_empty() and ResourceLoader.exists(trail_path):
		_trail_texture = load(trail_path)
	elif _core_texture:
		_trail_texture = _core_texture

	# 爆炸纹理
	var exp_path: String = _get_visual_str("tex_explosion_path", "explosion_texture_path", "")
	if not exp_path.is_empty() and ResourceLoader.exists(exp_path):
		_explosion_texture = load(exp_path)
	elif _core_texture:
		_explosion_texture = _core_texture

	# 前缘火焰纹理
	var flame_path: String = _get_visual_str("tex_front_flame_path", "", "")
	if not flame_path.is_empty() and ResourceLoader.exists(flame_path):
		_front_flame_texture = load(flame_path)
	elif _core_texture:
		_front_flame_texture = _core_texture

	# 弹尖纹理
	var nose_path: String = _get_visual_str("tex_nose_path", "", "")
	if not nose_path.is_empty() and ResourceLoader.exists(nose_path):
		_nose_texture = load(nose_path)


## 辅助：获取视觉定义字段，优先新字段名，回退旧字段名
func _get_visual_str(new_key: String, old_key: String, default: String) -> String:
	if new_key in _visual_def:
		var v = _visual_def.get(new_key)
		if v is String and not v.is_empty():
			return v
	if old_key != "" and old_key in _visual_def:
		var v = _visual_def.get(old_key)
		if v is String and not v.is_empty():
			return v
	return default


## ── 设置视觉节点 ──

func _setup_visuals() -> void:
	# 摩擦光晕（最底层，最先添加）
	_glow_sprite = Sprite2D.new()
	add_child(_glow_sprite)

	# 外层辉光
	_glow2_sprite = Sprite2D.new()
	add_child(_glow2_sprite)

	# 辐射射线
	_ray_sprite = Sprite2D.new()
	add_child(_ray_sprite)

	# 核心精灵
	_core_sprite = Sprite2D.new()
	add_child(_core_sprite)

	# 内核层
	_inner_sprite = Sprite2D.new()
	add_child(_inner_sprite)

	# 热点层
	_hotspot_sprite = Sprite2D.new()
	add_child(_hotspot_sprite)

	# 弹尖
	_nose_sprite = Sprite2D.new()
	add_child(_nose_sprite)

	# 拖尾粒子
	_trail_particles = GPUParticles2D.new()
	_trail_particles.emitting = false
	_trail_particles.one_shot = false
	_trail_particles.amount = 1
	var default_mat := ParticleProcessMaterial.new()
	default_mat.direction = Vector3(1, 0, 0)
	default_mat.spread = 0
	_trail_particles.process_material = default_mat
	add_child(_trail_particles)

	# 前缘火焰粒子
	_front_flame_particles = GPUParticles2D.new()
	_front_flame_particles.emitting = false
	_front_flame_particles.one_shot = false
	_front_flame_particles.amount = 1
	var flame_mat := ParticleProcessMaterial.new()
	flame_mat.direction = Vector3(0, 0, 0)
	flame_mat.spread = 180.0
	_front_flame_particles.process_material = flame_mat
	add_child(_front_flame_particles)

	# 彗星拖尾 Line2D（3 层）
	_comet_line_outer = Line2D.new()
	_comet_line_outer.antialiased = true
	add_child(_comet_line_outer)

	_comet_line_mid = Line2D.new()
	_comet_line_mid.antialiased = true
	add_child(_comet_line_mid)

	_comet_line_inner = Line2D.new()
	_comet_line_inner.antialiased = true
	add_child(_comet_line_inner)


## ── 应用视觉配置 ──

func _apply_visual() -> void:
	if _visual_def == null:
		return

	var core_radius: float = _visual_def.core_radius if "core_radius" in _visual_def else 4.0

	# ── 确定核心尺寸（先声明，命中检测要用）──
	var core_w: float = _visual_def.core_width if "core_width" in _visual_def and _visual_def.core_width > 0 else core_radius * 2.0
	var core_h: float = _visual_def.core_height if "core_height" in _visual_def and _visual_def.core_height > 0 else core_radius * 2.0

	# 命中检测半径：使用核心视觉尺寸的 1.5 倍（中层区域触发）
	var core_half: float = max(core_w, core_h) * 0.5
	_chain.current_radius = max(core_radius, core_half * 1.5)
	_chain.base_radius = core_radius
	if "speed" in _visual_def:
		_chain.speed = _visual_def.speed
	var core_color: Color = _visual_def.core_color if "core_color" in _visual_def else Color.WHITE

	# ── 确定基础纹理 ──
	var base_tex: Texture2D = _core_texture if _core_texture else _get_shared_circle_texture()
	var tex_size := base_tex.get_size() if base_tex else Vector2(16, 16)

	# ── 颜色覆盖（Modifier 可能设置）──
	if _chain.color_override != Color.WHITE:
		core_color = _chain.color_override

	# ── 1. 摩擦光晕 ──
	var glow_radius: float = _visual_def.core_glow_radius if "core_glow_radius" in _visual_def else 0.0
	if glow_radius > 0.0:
		var glow_color: Color = _visual_def.core_glow_color if "core_glow_color" in _visual_def else Color.WHITE
		var glow_alpha: float = _visual_def.core_glow_alpha if "core_glow_alpha" in _visual_def else 0.48
		_glow_sprite.texture = _glow_texture if _glow_texture else _get_shared_circle_texture()
		var glow_tex_size := _glow_sprite.texture.get_size() if _glow_sprite.texture else Vector2(16, 16)
		_glow_sprite.scale = Vector2(glow_radius * 2.0 / glow_tex_size.x, glow_radius * 2.0 / glow_tex_size.y)
		_glow_sprite.modulate = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
		_glow_sprite.visible = true
	else:
		# 旧参数兼容：glow_enabled
		var glow_enabled: bool = _visual_def.glow_enabled if "glow_enabled" in _visual_def else true
		if glow_enabled and base_tex:
			_glow_sprite.texture = _glow_texture if _glow_texture else base_tex
			var glow_tex_size := _glow_sprite.texture.get_size() if _glow_sprite.texture else tex_size
			_glow_sprite.scale = Vector2.ONE * (core_radius * 3.5) / glow_tex_size.x
			_glow_sprite.modulate = Color(core_color.r, core_color.g, core_color.b, 0.35)
			_glow_sprite.visible = true
		else:
			_glow_sprite.visible = false

	# ── 1b. 外层辉光（glow2）──
	var glow2_radius: float = _visual_def.core_glow2_radius if "core_glow2_radius" in _visual_def else 0.0
	if glow2_radius > 0.0:
		var glow2_color: Color = _visual_def.core_glow2_color if "core_glow2_color" in _visual_def else Color.WHITE
		var glow2_alpha: float = _visual_def.core_glow2_alpha if "core_glow2_alpha" in _visual_def else 0.25
		_glow2_sprite.texture = _glow_texture if _glow_texture else _get_shared_circle_texture()
		var g2_tex_size := _glow2_sprite.texture.get_size() if _glow2_sprite.texture else Vector2(16, 16)
		_glow2_sprite.scale = Vector2(glow2_radius * 2.0 / g2_tex_size.x, glow2_radius * 2.0 / g2_tex_size.y)
		_glow2_sprite.modulate = Color(glow2_color.r, glow2_color.g, glow2_color.b, glow2_alpha)
		_glow2_sprite.visible = true
	else:
		_glow2_sprite.visible = false

	# ── 1c. 辐射射线层 ──
	var ray_enabled: bool = glow_radius > 0.0
	if ray_enabled:
		_ray_sprite.texture = _get_shared_ray_texture()
		var ray_tex_size := _ray_sprite.texture.get_size() if _ray_sprite.texture else Vector2(32, 32)
		_ray_sprite.scale = Vector2.ONE * (glow_radius * 2.2 / ray_tex_size.x)
		var glow_color: Color = _visual_def.core_glow_color if "core_glow_color" in _visual_def else Color.WHITE
		_ray_sprite.modulate = Color(glow_color.r, glow_color.g, glow_color.b, 0.25)
		_ray_sprite.visible = true
	else:
		_ray_sprite.visible = false

	# ── 2. 核心精灵 ──
	_core_sprite.texture = base_tex
	_core_sprite.scale = Vector2(core_w / tex_size.x, core_h / tex_size.y)
	_core_sprite.modulate = core_color
	_core_sprite.visible = true

	# ── 3. 内核层 ──
	var inner_enabled: bool = _visual_def.core_inner_enabled if "core_inner_enabled" in _visual_def else false
	if inner_enabled:
		var inner_color: Color = _visual_def.core_inner_color if "core_inner_color" in _visual_def else Color.WHITE
		var inner_w: float = _visual_def.core_inner_width if "core_inner_width" in _visual_def else 0.0
		var inner_h: float = _visual_def.core_inner_height if "core_inner_height" in _visual_def else 0.0
		var inner_offset: Vector2 = _visual_def.core_inner_offset if "core_inner_offset" in _visual_def else Vector2.ZERO
		if inner_w > 0.0 and inner_h > 0.0:
			_inner_sprite.texture = base_tex
			_inner_sprite.scale = Vector2(inner_w / tex_size.x, inner_h / tex_size.y)
			_inner_sprite.position = inner_offset
			_inner_sprite.modulate = inner_color
			_inner_sprite.visible = true
		else:
			_inner_sprite.visible = false
	else:
		_inner_sprite.visible = false

	# ── 4. 热点层 ──
	var hotspot_enabled: bool = _visual_def.core_hotspot_enabled if "core_hotspot_enabled" in _visual_def else false
	if hotspot_enabled:
		var hotspot_color: Color = _visual_def.core_hotspot_color if "core_hotspot_color" in _visual_def else Color.WHITE
		var hotspot_w: float = _visual_def.core_hotspot_width if "core_hotspot_width" in _visual_def else 0.0
		var hotspot_h: float = _visual_def.core_hotspot_height if "core_hotspot_height" in _visual_def else 0.0
		var hotspot_offset: Vector2 = _visual_def.core_hotspot_offset if "core_hotspot_offset" in _visual_def else Vector2.ZERO
		if hotspot_w > 0.0 and hotspot_h > 0.0:
			_hotspot_sprite.texture = base_tex
			_hotspot_sprite.scale = Vector2(hotspot_w / tex_size.x, hotspot_h / tex_size.y)
			_hotspot_sprite.position = hotspot_offset
			_hotspot_sprite.modulate = hotspot_color
			_hotspot_sprite.visible = true
		else:
			_hotspot_sprite.visible = false
	else:
		_hotspot_sprite.visible = false

	# ── 5. 弹尖 ──
	var nose_enabled: bool = _visual_def.core_nose_enabled if "core_nose_enabled" in _visual_def else false
	if nose_enabled:
		var nose_color: Color = _visual_def.core_nose_color if "core_nose_color" in _visual_def else Color.WHITE
		var nose_length: float = _visual_def.core_nose_length if "core_nose_length" in _visual_def else 0.0
		var nose_width: float = _visual_def.core_nose_width if "core_nose_width" in _visual_def else 0.0
		if nose_length > 0.0 and nose_width > 0.0:
			var nose_tex: Texture2D = _nose_texture if _nose_texture else _get_shared_nose_texture()
			_nose_sprite.texture = nose_tex
			var nose_tex_size := nose_tex.get_size() if nose_tex else Vector2(16, 16)
			_nose_sprite.scale = Vector2(nose_length / nose_tex_size.x, nose_width / nose_tex_size.y)
			_nose_sprite.modulate = nose_color
			_nose_sprite.visible = true
		else:
			_nose_sprite.visible = false
	else:
		_nose_sprite.visible = false

	# ── 6. 拖尾粒子 ──
	var trail_enabled: bool = _visual_def.trail_particle_enabled if "trail_particle_enabled" in _visual_def else false
	if trail_enabled and _trail_texture:
		_configure_trail_particles()

	# ── 7. 前缘火焰粒子 ──
	var flame_enabled: bool = _visual_def.front_flame_enabled if "front_flame_enabled" in _visual_def else false
	if flame_enabled:
		_configure_front_flame()

	# ── 8. 彗星拖尾 Line2D ──
	# Godot 4.6 bool 属性有缓存 bug，fallback 用 outer_width > 0 判定
	var comet_on: bool = false
	if "comet_enabled" in _visual_def:
		comet_on = _visual_def.comet_enabled
		if not comet_on and _visual_def.comet_outer_width > 0:
			comet_on = true
	if comet_on:
		_configure_comet_trail()

	# ── 投射物整体缩放 ──
	var proj_scale: float = _visual_def.projectile_scale if "projectile_scale" in _visual_def else 1.0
	if proj_scale != 1.0:
		scale = Vector2.ONE * proj_scale


## ── 配置拖尾粒子（增强版） ──

func _configure_trail_particles() -> void:
	_trail_particles.texture = _trail_texture
	var particle_count: int = _visual_def.trail_particle_count if "trail_particle_count" in _visual_def else 8
	var lifetime: float = _visual_def.trail_particle_lifetime if "trail_particle_lifetime" in _visual_def else 0.15

	# 增强参数
	var back_min: float = _visual_def.trail_back_dist_min if "trail_back_dist_min" in _visual_def else 20.0
	var back_max: float = _visual_def.trail_back_dist_max if "trail_back_dist_max" in _visual_def else 80.0
	var spread_min: float = _visual_def.trail_spread_min if "trail_spread_min" in _visual_def else 28.0
	var spread_max: float = _visual_def.trail_spread_max if "trail_spread_max" in _visual_def else 46.0
	var radius_min: float = _visual_def.trail_radius_min if "trail_radius_min" in _visual_def else 0.3
	var radius_max: float = _visual_def.trail_radius_max if "trail_radius_max" in _visual_def else 0.8
	var _life_min: float = _visual_def.trail_life_min if "trail_life_min" in _visual_def else lifetime * 0.8
	var life_max: float = _visual_def.trail_life_max if "trail_life_max" in _visual_def else lifetime * 1.5

	_trail_particles.amount = particle_count * 4
	_trail_particles.lifetime = life_max
	_trail_particles.one_shot = false
	_trail_particles.explosiveness = 0.0
	_trail_particles.randomness = 0.5
	_trail_particles.local_coords = false

	# 创建粒子材质
	var mat := ParticleProcessMaterial.new()
	var dir = -_chain.direction if _chain.direction.length() > 0 else Vector2.UP
	mat.direction = Vector3(dir.x * 50, dir.y * 50, 0)
	mat.spread = (spread_min + spread_max) / 2.0
	mat.initial_velocity_min = back_min
	mat.initial_velocity_max = back_max
	mat.scale_min = radius_min
	mat.scale_max = radius_max

	# 拖尾粒子缩放曲线：刚离开火球时保持较大，中段开始衰减，尾部稀疏
	var trail_curve := Curve.new()
	trail_curve.add_point(Vector2(0.0, 1.0))
	trail_curve.add_point(Vector2(0.15, 0.95))
	trail_curve.add_point(Vector2(0.35, 0.7))
	trail_curve.add_point(Vector2(0.6, 0.3))
	trail_curve.add_point(Vector2(1.0, 0.0))
	var trail_curve_tex := CurveTexture.new()
	trail_curve_tex.curve = trail_curve
	mat.scale_curve = trail_curve_tex
	_trail_particles.process_material = mat
	_trail_particles.emitting = true


## ── 配置前缘火焰粒子 ──

func _configure_front_flame() -> void:
	var flame_tex: Texture2D = _front_flame_texture if _front_flame_texture else _trail_texture
	if flame_tex:
		_front_flame_particles.texture = flame_tex
	else:
		_front_flame_particles.texture = _get_shared_circle_texture()

	var count: int = _visual_def.front_flame_count if "front_flame_count" in _visual_def else 12
	var inner_min: float = _visual_def.front_flame_inner_min if "front_flame_inner_min" in _visual_def else 1.2
	var _inner_max: float = _visual_def.front_flame_inner_max if "front_flame_inner_max" in _visual_def else 5.5
	var _outer_min: float = _visual_def.front_flame_outer_min if "front_flame_outer_min" in _visual_def else 5.5
	var outer_max: float = _visual_def.front_flame_outer_max if "front_flame_outer_max" in _visual_def else 14.0
	var _life_min: float = _visual_def.front_flame_life_min if "front_flame_life_min" in _visual_def else 0.1
	var life_max: float = _visual_def.front_flame_life_max if "front_flame_life_max" in _visual_def else 0.195

	_front_flame_particles.amount = count * 3
	_front_flame_particles.lifetime = life_max
	_front_flame_particles.one_shot = false
	_front_flame_particles.explosiveness = 0.0
	_front_flame_particles.randomness = 0.7
	_front_flame_particles.local_coords = false

	# 前缘粒子：方向朝飞行方向的前方
	var mat := ParticleProcessMaterial.new()
	var fwd = _chain.direction if _chain.direction.length() > 0 else Vector2.RIGHT
	mat.direction = Vector3(fwd.x, fwd.y, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = inner_min
	mat.initial_velocity_max = outer_max
	mat.scale_min = 0.2
	mat.scale_max = 0.6
	mat.gravity = Vector3.ZERO
	_front_flame_particles.process_material = mat
	_front_flame_particles.emitting = true


## ── 配置彗星拖尾 Line2D ──

func _configure_comet_trail() -> void:
	var outer_w: float = _visual_def.comet_outer_width if "comet_outer_width" in _visual_def else 6.0
	var outer_c: Color = _visual_def.comet_outer_color if "comet_outer_color" in _visual_def else Color.WHITE
	var outer_a: float = _visual_def.comet_outer_alpha if "comet_outer_alpha" in _visual_def else 0.35
	var mid_w: float = _visual_def.comet_mid_width if "comet_mid_width" in _visual_def else 3.4
	var mid_c: Color = _visual_def.comet_mid_color if "comet_mid_color" in _visual_def else Color.WHITE
	var mid_a: float = _visual_def.comet_mid_alpha if "comet_mid_alpha" in _visual_def else 0.62
	var inner_w: float = _visual_def.comet_inner_width if "comet_inner_width" in _visual_def else 1.8
	var inner_c: Color = _visual_def.comet_inner_color if "comet_inner_color" in _visual_def else Color.WHITE
	var inner_a: float = _visual_def.comet_inner_alpha if "comet_inner_alpha" in _visual_def else 0.96

	_comet_line_outer.width = outer_w
	_comet_line_outer.default_color = Color(outer_c.r, outer_c.g, outer_c.b, outer_a)
	_comet_line_mid.width = mid_w
	_comet_line_mid.default_color = Color(mid_c.r, mid_c.g, mid_c.b, mid_a)
	_comet_line_inner.width = inner_w
	_comet_line_inner.default_color = Color(inner_c.r, inner_c.g, inner_c.b, inner_a)

	# 宽度渐变曲线：从前端到后端逐渐变细，带波动变化
	var _setup_width_curve := func(line: Line2D, _base_w: float):
		var curve := Curve.new()
		# 前段保持宽度（0~0.3）
		curve.add_point(Vector2(0.0, 1.0))
		# 中段开始收缩（0.3~0.6），带轻微凹凸
		curve.add_point(Vector2(0.1, 0.98))
		curve.add_point(Vector2(0.25, 0.85))
		curve.add_point(Vector2(0.40, 0.65))
		# 后段快速变细（0.6~1.0），带波动
		curve.add_point(Vector2(0.55, 0.45))
		curve.add_point(Vector2(0.70, 0.25))
		curve.add_point(Vector2(0.82, 0.12))
		curve.add_point(Vector2(0.92, 0.04))
		curve.add_point(Vector2(1.0, 0.0))
		line.width_curve = curve

	_setup_width_curve.call(_comet_line_outer, outer_w)
	_setup_width_curve.call(_comet_line_mid, mid_w)
	_setup_width_curve.call(_comet_line_inner, inner_w)

	var _max_pts: int = _visual_def.comet_max_samples if "comet_max_samples" in _visual_def else 28
	_trail_offsets.clear()
	_trail_offsets.push_front(Vector2.ZERO)
	_last_global_pos = global_position


## ── 每帧更新 ──

func _process(dt: float) -> void:
	if not _initialized:
		return

	if _chain.behavior_state == "Destroyed" or _chain.behavior_state == "Exploded":

		set_process(false)
		return

	_elapsed += dt
	_chain.elapsed_time = _elapsed

	# 检查触发器
	_chain.check_triggers(dt)

	# --- 错峰发射：延迟期间只计时，不移动 ---
	if not _spawned:
		_spawn_timer += dt
		if _spawn_timer >= _chain.spawn_delay:
			_spawned = true
			# 延迟结束，初始化贝塞尔曲线（使用当前global_position作为实际起点）
			if _chain.trajectory_type > 0:
				_init_bezier()
		else:
			# 延迟期间：透明渐变显现
			var alpha := clampf(_spawn_timer / maxf(_chain.spawn_delay, 0.01), 0.2, 1.0)
			var all_sprites := [_glow_sprite, _glow2_sprite, _ray_sprite, _core_sprite, _inner_sprite, _hotspot_sprite, _nose_sprite]
			for s in all_sprites:
				if s and is_instance_valid(s):
					s.modulate.a = alpha
			return

	# 根据轨迹类型更新位置
	match _chain.trajectory_type:
		0:
			_update_linear(dt)
		1:  # BEZIER_QUAD
			_update_bezier_quad(dt)
		2:  # SINE_WAVE
			_update_sine_wave(dt)
		_:
			_update_linear(dt)

	# 更新核心抖动
	_update_jitter(dt)

	# 更新弹尖朝向
	_update_nose_rotation()

	# 更新拖尾粒子
	_update_trail_emitter(dt)

	# 更新彗星拖尾 Line2D
	# Godot 4.6 bool 缓存 bug fallback
	var _comet_active: bool = false
	if "comet_enabled" in _visual_def:
		_comet_active = _visual_def.comet_enabled
		if not _comet_active and _visual_def.comet_outer_width > 0:
			_comet_active = true
	if _comet_line_outer != null and _comet_active:
		_update_comet_trail()

	# 检查命中目标
	_check_hit()

	# 发出行为更新信号
	if _signal_bus:
		_signal_bus.behavior_update.emit(self, _chain.behavior_state, global_position)


## ── 核心抖动更新 ──

func _update_jitter(dt: float) -> void:
	var jitter_on: bool = _visual_def.jitter_enabled if "jitter_enabled" in _visual_def else false
	if not jitter_on:
		return

	_jitter_time += dt
	var amp: float = _visual_def.jitter_amplitude if "jitter_amplitude" in _visual_def else 0.9
	var freq_x: float = _visual_def.jitter_freq_x if "jitter_freq_x" in _visual_def else 2.3
	var freq_y: float = _visual_def.jitter_freq_y if "jitter_freq_y" in _visual_def else 2.1

	var offset := Vector2(
		sin(_jitter_time * freq_x * TAU) * amp,
		sin(_jitter_time * freq_y * TAU) * amp
	)
	# 对核心层和内层应用抖动
	if _core_sprite:
		_core_sprite.position = offset
	if _inner_sprite and _inner_sprite.visible:
		var base_offset: Vector2 = _visual_def.core_inner_offset if "core_inner_offset" in _visual_def else Vector2.ZERO
		_inner_sprite.position = base_offset + offset
	if _hotspot_sprite and _hotspot_sprite.visible:
		var base_offset: Vector2 = _visual_def.core_hotspot_offset if "core_hotspot_offset" in _visual_def else Vector2.ZERO
		_hotspot_sprite.position = base_offset + offset

	# 射线层缓慢旋转
	if _ray_sprite and _ray_sprite.visible:
		_ray_sprite.rotation = _jitter_time * 0.4


## ── 更新弹尖朝向（跟随飞行方向）──

func _update_nose_rotation() -> void:
	if _nose_sprite and _nose_sprite.visible and _chain.direction.length() > 0:
		_nose_sprite.rotation = _chain.direction.angle()


## ── 直线运动 ──

func _update_linear(dt: float) -> void:
	var move: float = _chain.speed * dt * _chain.travel_time_multiplier
	var delta := _chain.direction * move
	global_position += delta
	_chain.position = global_position
	_distance += move
	_chain.distance_traveled = _distance


## ── 二次贝塞尔曲线 ──

func _init_bezier() -> void:
	_bezier_start = _chain.position
	_bezier_end = _chain.target_pos
	var perpendicular := _chain.direction.rotated(PI / 2.0)
	_bezier_control = _bezier_start + _chain.direction * (_bezier_start.distance_to(_bezier_end) * _chain.get_meta("bezier_forward_ratio", 0.5)) + perpendicular * _chain.control_point_offset


func _update_bezier_quad(dt: float) -> void:
	var move := _chain.speed * dt * _chain.travel_time_multiplier
	var total_dist := _bezier_start.distance_to(_bezier_end)
	_distance += move
	var t := clampf(_distance / total_dist, 0.0, 1.0)

	var mt: float = 1.0 - t
	global_position = mt * mt * _bezier_start + 2.0 * mt * t * _bezier_control + t * t * _bezier_end
	_chain.position = global_position
	_chain.distance_traveled = _distance

	# 更新方向为曲线的切线方向
	var next_t := minf(t + 0.01, 1.0)
	var mt2: float = 1.0 - next_t
	var next_pos := mt2 * mt2 * _bezier_start + 2.0 * mt2 * next_t * _bezier_control + next_t * next_t * _bezier_end
	_chain.direction = (next_pos - global_position).normalized()


## ── 正弦波动 ──

func _update_sine_wave(dt: float) -> void:
	_update_linear(dt)
	var perpendicular := _chain.direction.rotated(PI / 2.0)
	var wave_offset: float = sin(_distance * 0.05 * (_chain.wave_frequency if "wave_frequency" in _chain else 2.0)) * _chain.wave_amplitude
	global_position += perpendicular * wave_offset * dt * 10.0


## ── 拖尾粒子发射器跟随 ──

func _update_trail_emitter(_dt: float) -> void:
	# 粒子节点跟随父节点，无需额外操作
	pass


## ── 彗星拖尾更新 ──

func _update_comet_trail() -> void:
	# 计算本帧子弹移动量
	var current_pos := global_position
	var movement := current_pos - _last_global_pos
	_last_global_pos = current_pos

	# 反向补偿已有 trail 点：Line2D 随子弹移动了，偏移量要抵消这个移动
	# 保证 trail 点留在世界空间中的正确位置
	for i in range(_trail_offsets.size()):
		_trail_offsets[i] -= movement

	# 当前子弹位置 = 局部偏移 0
	_trail_offsets.push_front(Vector2.ZERO)

	# 裁剪到最大点数
	var _max_pts: int = _visual_def.comet_max_samples if "comet_max_samples" in _visual_def else 28
	while _trail_offsets.size() > _max_pts:
		_trail_offsets.pop_back()

	# 应用蛇形摆动（在局部坐标系中，不影响子弹本身位置）
	var sway_freq: float = _visual_def.comet_sway_freq if "comet_sway_freq" in _visual_def else 0.7
	var sway_amp: float = _visual_def.comet_sway_amplitude if "comet_sway_amplitude" in _visual_def else 1.1
	var swayed := _trail_offsets.duplicate()
	var fwd := _chain.direction if _chain.direction.length() > 0 else Vector2.RIGHT
	var perp := fwd.rotated(PI / 2.0)
	for i in range(swayed.size()):
		var t := float(i) / float(max(1, swayed.size()))
		var offset := sin(t * TAU * sway_freq + _elapsed * 2.0) * sway_amp * t
		swayed[i] += perp * offset

	# 更新 3 层 Line2D
	_comet_line_outer.points = PackedVector2Array(swayed)
	_comet_line_mid.points = PackedVector2Array(swayed)
	_comet_line_inner.points = PackedVector2Array(swayed)


## ── 命中检测 ──

func _check_hit() -> void:
	if _chain.target == null or not is_instance_valid(_chain.target):
		return

	var dist := global_position.distance_to(_chain.target.global_position)
	if dist < _chain.current_radius + 10.0:
		_chain.on_hit(_chain.target)


## ── 信号处理 ──

func _on_chain_hit(chain: ExecutionChain, target: Node2D) -> void:
	if _signal_bus:
		var info := {
			"caster": chain.caster,
			"target": target,
			"damage": chain.damage,
			"damage_type": chain.damage_type,
			"skill_id": chain.skill_id,
		}
		_signal_bus.skill_hit.emit(chain.caster, [target], info)

	if chain.bounce_remaining > 0:
		var next := chain._find_nearest_enemy_excluding(target)
		if next:
			chain.bounce_remaining -= 1
			chain.direction = global_position.direction_to(next.global_position)
			chain.target = next
		else:
			_chain.destroy()
	else:
		_chain.destroy()


func _on_chain_destroyed(_destroyed_chain: ExecutionChain) -> void:
	if _signal_bus:
		_signal_bus.behavior_complete.emit(self)

	# 立即停止粒子发射
	if _trail_particles:
		_trail_particles.emitting = false
	if _front_flame_particles:
		_front_flame_particles.emitting = false

	# 清除彗星拖尾 Line2D
	if _comet_line_outer != null:
		_comet_line_outer.points = []
	if _comet_line_mid != null:
		_comet_line_mid.points = []
	if _comet_line_inner != null:
		_comet_line_inner.points = []
	_trail_offsets.clear()

	# 火球体快速淡出（300ms）
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	var all_sprites := [_glow_sprite, _glow2_sprite, _ray_sprite, _core_sprite, _inner_sprite, _hotspot_sprite, _nose_sprite]
	for s in all_sprites:
		if s and is_instance_valid(s) and s.visible:
			fade_tween.tween_property(s, "modulate:a", 0.0, 0.3)

	# 触发爆炸视觉（与淡出同时）
	_spawn_explosion()

	# 等待淡出完成 + 爆炸粒子播放，然后归还池
	var pool = get_parent()
	if pool.has_method("despawn"):
		await get_tree().create_timer(0.6).timeout
		for s in all_sprites:
			if s and is_instance_valid(s):
				s.visible = false
		pool.despawn(self)


## ── 爆炸粒子效果（增强版） ──

func _spawn_explosion() -> void:
	if _visual_def == null:
		return

	var impact_color: Color = Color(1, 0.9, 0.73, 1)
	var spark_count: int = 16

	# 精灵粒子爆发（替代 GPUParticles2D，完全可控的方向）
	for i in range(spark_count):
		var angle := float(i) / float(spark_count) * TAU
		angle += randf_range(-0.15, 0.15)  # 每颗粒子小幅度随机偏移
		var dir := Vector2(cos(angle), sin(angle))
		var speed := randf_range(100.0, 200.0)

		var spark := Sprite2D.new()
		spark.texture = _core_texture if _core_texture else _get_shared_circle_texture()
		var tex_size := spark.texture.get_size() if spark.texture else Vector2(16, 16)
		spark.scale = Vector2.ONE * randf_range(0.3, 0.8) / (tex_size.x / 16.0)
		spark.modulate = impact_color
		spark.global_position = global_position
		get_tree().root.add_child(spark)

		# 飞行动画
		var tween := create_tween()
		tween.set_parallel(true)
		var target_pos := spark.global_position + dir * randf_range(40.0, 80.0)
		tween.tween_property(spark, "global_position", target_pos, randf_range(0.15, 0.3))
		tween.tween_property(spark, "modulate:a", 0.0, randf_range(0.15, 0.3)).set_delay(0.05)

		# 清理
		tween.tween_callback(spark.queue_free).set_delay(0.35)

	# 屏幕震动
	if "impact_shake_strength" in _visual_def and _visual_def.impact_shake_strength > 0:
		var shake_strength: float = _visual_def.impact_shake_strength
		var camera = get_viewport().get_camera_2d()
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(shake_strength * 0.1)
