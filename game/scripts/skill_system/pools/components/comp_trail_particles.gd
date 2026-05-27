# comp_trail_particles.gd
# 向后散射粒子拖尾组件
class_name CompTrailParticles
extends ProjectileComponent

var _particles: GPUParticles2D
var _config: ParticleTrailConfig
var _trail_texture: Texture2D

func create_nodes(parent: Node2D) -> void:
	_particles = GPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = false
	_particles.amount = 1
	var default_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	default_mat.direction = Vector3(1, 0, 0)
	default_mat.spread = 0
	_particles.process_material = default_mat
	parent.add_child(_particles)


func configure(visual_def: SkillVisualDef, chain: ExecutionChain, tex_manager: VFXTextureManager) -> void:
	var trail: TrailDef = visual_def.get_trail()
	_config = trail.particles
	if not _config or not _config.is_enabled():
		_particles.emitting = false
		_particles.visible = false
		return

	# 加载纹理
	_trail_texture = null
	if _config.texture_path != "" and ResourceLoader.exists(_config.texture_path):
		_trail_texture = load(_config.texture_path)

	_particles.texture = _trail_texture if _trail_texture else tex_manager.get_texture(VFXTextureManager.SOFT_CIRCLE)

	var life_max: float = _config.life_max if _config.life_max > 0 else _config.lifetime * 1.5
	_particles.amount = _config.count * 4
	_particles.lifetime = life_max
	_particles.one_shot = false
	_particles.explosiveness = 0.0
	_particles.randomness = 0.5
	_particles.local_coords = false

	# 粒子材质
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	var dir = -chain.direction if chain.direction.length() > 0 else Vector2.UP
	mat.direction = Vector3(dir.x * 50, dir.y * 50, 0)
	mat.spread = (_config.spread_min + _config.spread_max) / 2.0
	mat.initial_velocity_min = _config.back_dist_min
	mat.initial_velocity_max = _config.back_dist_max
	mat.scale_min = _config.radius_min
	mat.scale_max = _config.radius_max

	# 缩放曲线
	if _config.scale_curve:
		var curve_tex: CurveTexture = CurveTexture.new()
		curve_tex.curve = _config.scale_curve
		mat.scale_curve = curve_tex
	else:
		# 默认衰减曲线
		var trail_curve: Curve = Curve.new()
		trail_curve.add_point(Vector2(0.0, 1.0))
		trail_curve.add_point(Vector2(0.15, 0.95))
		trail_curve.add_point(Vector2(0.35, 0.7))
		trail_curve.add_point(Vector2(0.6, 0.3))
		trail_curve.add_point(Vector2(1.0, 0.0))
		var trail_curve_tex: CurveTexture = CurveTexture.new()
		trail_curve_tex.curve = trail_curve
		mat.scale_curve = trail_curve_tex

	# 颜色渐变：仅在无自定义纹理时应用
	if not _trail_texture:
		var tc1: Color = _config.color_1
		var tc2: Color = _config.color_2 if _config.color_2 != Color.WHITE else tc1
		var tc3: Color = _config.color_3 if _config.color_3 != Color.WHITE else tc2
		var trail_grad: Gradient = Gradient.new()
		trail_grad.add_point(0.0, Color(tc1.r, tc1.g, tc1.b, 0.9))
		trail_grad.add_point(0.4, Color(tc2.r, tc2.g, tc2.b, 0.6))
		trail_grad.add_point(1.0, Color(tc3.r, tc3.g, tc3.b, 0.0))
		var trail_grad_tex: GradientTexture1D = GradientTexture1D.new()
		trail_grad_tex.gradient = trail_grad
		mat.color_initial_ramp = trail_grad_tex

	# λ���ƣ�������ŵĻ���β����
	if _config.position_offset != Vector2.ZERO:
		_particles.position = _config.position_offset
	else:
		_particles.position = Vector2.ZERO

	_particles.process_material = mat
	_particles.emitting = true
	_particles.visible = true


func update(_dt: float, _parent: Node2D, chain: ExecutionChain) -> void:
	# 动态跟随弹体尾部：每帧将粒子发射点定位到弹体最后端
	if _config and _config.position_offset != Vector2.ZERO and chain.direction.length() > 0:
		_particles.position = -chain.direction * absf(_config.position_offset.x)


func on_destroy(_parent: Node2D) -> void:
	if _particles:
		_particles.emitting = false


func reset() -> void:
	_trail_texture = null
	_config = null


func is_active() -> bool:
	return _config != null and _config.is_enabled()
