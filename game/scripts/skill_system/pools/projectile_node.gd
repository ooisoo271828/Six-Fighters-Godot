## ProjectileNode — 单个投射物运行时节点
## 挂载到 ProjectilePool 下，在世界坐标系中移动和渲染
## 支持 Sprite2D 纹理 + GPUParticles2D 拖尾/爆炸
extends Node2D

var _chain: ExecutionChain
var _visual_def: Resource
var _signal_bus: Node
var _initialized: bool = false

## ── 视觉组件 ──
var _core_sprite: Sprite2D
var _glow_sprite: Sprite2D           # 外发光层
var _trail_particles: GPUParticles2D  # 粒子拖尾
var _glow_texture: CompressedTexture2D
var _explosion_texture: CompressedTexture2D
var _trail_texture: CompressedTexture2D

## ── 运动状态 ──
var _elapsed: float = 0.0
var _distance: float = 0.0
var _target_reached: bool = false

## ── 曲线运动参数 ──
var _bezier_start: Vector2
var _bezier_control: Vector2
var _bezier_end: Vector2

## ── 拖尾粒子发射偏移（始终在身后）──
var _last_trail_pos: Vector2
const TRAIL_EMIT_INTERVAL: float = 0.016  # ~60fps

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

	set_process(true)

## ── 加载纹理资源 ──

func _load_textures() -> void:
	if _visual_def == null:
		return
	var core_path: String = _visual_def.core_texture_path if "core_texture_path" in _visual_def else ""
	if not core_path.is_empty() and ResourceLoader.exists(core_path):
		_glow_texture = load(core_path)

	var exp_path: String = _visual_def.explosion_texture_path if "explosion_texture_path" in _visual_def else ""
	if not exp_path.is_empty() and ResourceLoader.exists(exp_path):
		_explosion_texture = load(exp_path)

	var trail_path: String = _visual_def.trail_texture_path if "trail_texture_path" in _visual_def else ""
	if not trail_path.is_empty() and ResourceLoader.exists(trail_path):
		_trail_texture = load(trail_path)
	elif _glow_texture:
		_trail_texture = _glow_texture

## ── 设置视觉节点 ──

func _setup_visuals() -> void:
	# 核心精灵
	_core_sprite = Sprite2D.new()
	add_child(_core_sprite)

	# 外发光层（略大，Additive 混合）
	_glow_sprite = Sprite2D.new()
	_glow_sprite.modulate = Color(1.0, 1.0, 1.0, 0.4)
	add_child(_glow_sprite)

	# 粒子拖尾
	_trail_particles = GPUParticles2D.new()
	_trail_particles.emitting = false
	_trail_particles.one_shot = false
	_trail_particles.amount = 1  # 按需在 _configure_trail_particles 中设置实际数量
	# 创建默认的粒子材质
	var default_mat := ParticleProcessMaterial.new()
	default_mat.direction = Vector3(1, 0, 0)
	default_mat.spread = 0
	_trail_particles.process_material = default_mat
	add_child(_trail_particles)

## ── 应用视觉配置 ──

func _apply_visual() -> void:
	if _visual_def == null:
		return

	var core_radius: float = _visual_def.core_radius if "core_radius" in _visual_def else 4.0
	_chain.current_radius = core_radius
	_chain.base_radius = core_radius

	# ── 核心精灵 ──
	if _glow_texture:
		_core_sprite.texture = _glow_texture
		_glow_sprite.texture = _glow_texture
		# 核心缩放：让纹理适配 core_radius
		var tex_size = _glow_texture.get_size() if _glow_texture else Vector2(64, 64)
		_core_sprite.scale = Vector2.ONE * (core_radius * 2.0) / tex_size.x
		_glow_sprite.scale = Vector2.ONE * (core_radius * 3.5) / tex_size.x
		_glow_sprite.modulate = Color(1, 1, 1, 0.35)
	else:
		# 无纹理：降级为纯色
		var core_color: Color = _visual_def.core_color if "core_color" in _visual_def else Color.WHITE
		_core_sprite.modulate = core_color

	# ── 发光混合模式 ──
	var glow_enabled: bool = _visual_def.glow_enabled if "glow_enabled" in _visual_def else true
	if glow_enabled:
		_core_sprite.modulate.a = 1.0

	# ── 颜色覆盖（Modifier 可能设置）──
	if _chain.color_override != Color.WHITE:
		_core_sprite.modulate = _chain.color_override

	# ── 粒子拖尾 ──
	var trail_enabled: bool = _visual_def.trail_particle_enabled if "trail_particle_enabled" in _visual_def else false
	if trail_enabled and _trail_texture:
		var particle_count: int = _visual_def.trail_particle_count if "trail_particle_count" in _visual_def else 8
		var lifetime: float = _visual_def.trail_particle_lifetime if "trail_particle_lifetime" in _visual_def else 0.15
		_configure_trail_particles(particle_count, lifetime)

## ── 配置拖尾粒子 ──

func _configure_trail_particles(count: int, lifetime: float) -> void:
	_trail_particles.texture = _trail_texture
	_trail_particles.amount = count * 4  # GPUParticles2D 需要足够数量
	_trail_particles.lifetime = lifetime
	_trail_particles.one_shot = false
	_trail_particles.explosiveness = 0.0
	_trail_particles.randomness = 0.3
	_trail_particles.local_coords = false  # 跟随父节点世界坐标

	# 创建粒子材质并设置方向（在 ProcessMaterial 中配置）
	var mat := ParticleProcessMaterial.new()
	# 发射方向：向后（-direction），转换为 Vector3
	var dir = -_chain.direction if _chain.direction.length() > 0 else Vector2.UP
	mat.direction = Vector3(dir.x * 50, dir.y * 50, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 40.0
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	_trail_particles.process_material = mat
	_trail_particles.emitting = true

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

	# 更新拖尾粒子
	_update_trail_emitter(dt)

	# 检查命中目标
	_check_hit()

	# 发出行为更新信号
	if _signal_bus:
		_signal_bus.behavior_update.emit(self, _chain.behavior_state, global_position)

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
	_bezier_control = _bezier_start + _chain.direction * (_bezier_start.distance_to(_bezier_end) / 2.0) + perpendicular * _chain.control_point_offset

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
			chain.destroy()
	else:
		_chain.destroy()

func _on_chain_destroyed(_destroyed_chain: ExecutionChain) -> void:
	if _signal_bus:
		_signal_bus.behavior_complete.emit(self)

	# 停止拖尾粒子
	if _trail_particles:
		_trail_particles.emitting = false

	# 触发爆炸视觉
	_spawn_explosion()

	# 归还池
	var pool = get_parent()
	if pool.has_method("despawn"):
		# 延迟归还，等待爆炸粒子播放
		await get_tree().create_timer(0.5).timeout
		pool.despawn(self)

## ── 爆炸粒子效果 ──

func _spawn_explosion() -> void:
	if _visual_def == null:
		return

	# 创建爆炸粒子节点
	var explosion := GPUParticles2D.new()
	explosion.global_position = global_position

	# 设置纹理
	if _explosion_texture:
		explosion.texture = _explosion_texture
	elif _glow_texture:
		explosion.texture = _glow_texture

	# 配置爆炸参数
	var particle_count: int = _visual_def.explosion_particle_count if "explosion_particle_count" in _visual_def else 20
	var lifetime: float = _visual_def.explosion_lifetime if "explosion_lifetime" in _visual_def else 0.4
	var radius_mult: float = _visual_def.explosion_radius_mult if "explosion_radius_mult" in _visual_def else 2.0

	explosion.amount = particle_count
	explosion.lifetime = lifetime
	explosion.one_shot = true
	explosion.explosiveness = 0.9
	explosion.randomness = 0.2

	# 颜色
	var base_color: Color = _visual_def.core_color if "core_color" in _visual_def else Color.WHITE
	explosion.modulate = base_color

	# 创建粒子材质（方向在 ProcessMaterial 中配置）
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)  # 从中心向四周
	mat.spread = 180.0
	mat.initial_velocity_min = _chain.current_radius * radius_mult * 60.0
	mat.initial_velocity_max = _chain.current_radius * radius_mult * 120.0
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.gravity = Vector3(0, 50, 0)  # 轻微下落
	explosion.process_material = mat

	# 加入场景
	get_tree().root.add_child(explosion)
	explosion.emitting = true

	# 自动释放
	await get_tree().create_timer(lifetime + 0.2).timeout
	if is_instance_valid(explosion):
		explosion.queue_free()
