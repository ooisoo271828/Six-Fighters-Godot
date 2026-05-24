# comp_flame_trail.gd
# 向前前缘火焰粒子组件
class_name CompFlameTrail
extends ProjectileComponent

var _particles: GPUParticles2D
var _config: FlameTrailConfig
var _flame_texture: Texture2D

func create_nodes(parent: Node2D) -> void:
	_particles = GPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = false
	_particles.amount = 1
	var default_mat := ParticleProcessMaterial.new()
	default_mat.direction = Vector3(0, 0, 0)
	default_mat.spread = 180.0
	_particles.process_material = default_mat
	parent.add_child(_particles)


func configure(visual_def: SkillVisualDef, chain: ExecutionChain, tex_manager: VFXTextureManager) -> void:
	var trail := visual_def.get_trail()
	_config = trail.flame
	if not _config or not _config.is_enabled():
		_particles.emitting = false
		_particles.visible = false
		return

	# 加载纹理
	_flame_texture = null
	if _config.texture_path != "" and ResourceLoader.exists(_config.texture_path):
		_flame_texture = load(_config.texture_path)
	_particles.texture = _flame_texture if _flame_texture else tex_manager.get_texture(VFXTextureManager.CIRCLE)

	_particles.amount = _config.count * 3
	_particles.lifetime = _config.life_max
	_particles.one_shot = false
	_particles.explosiveness = 0.0
	_particles.randomness = 0.7
	_particles.local_coords = false

	# 粒子材质
	var mat := ParticleProcessMaterial.new()
	var fwd = chain.direction if chain.direction.length() > 0 else Vector2.RIGHT
	mat.direction = Vector3(fwd.x, fwd.y, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = _config.inner_min
	mat.initial_velocity_max = _config.outer_max
	mat.scale_min = 0.2
	mat.scale_max = 0.6
	mat.gravity = Vector3.ZERO
	_particles.process_material = mat
	_particles.emitting = true
	_particles.visible = true


func update(_dt: float, _parent: Node2D, _chain: ExecutionChain) -> void:
	pass  # 粒子自驱动


func on_destroy(_parent: Node2D) -> void:
	if _particles:
		_particles.emitting = false


func reset() -> void:
	_flame_texture = null
	_config = null


func is_active() -> bool:
	return _config != null and _config.is_enabled()
