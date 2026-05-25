# comp_flame_trail.gd
# 向前前缘火焰粒子组件
class_name CompFlameTrail
extends ProjectileComponent

var _particles: GPUParticles2D
var _config: FlameTrailConfig
var _flame_texture: Texture2D
var _crest_sprites: Array[Sprite2D] = []
var _crest_sprite_tex: Texture2D

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

	if _config.crest_mode:
		_setup_crest_mode(chain)
	else:
		_setup_forward_spray(chain)


func _setup_forward_spray(chain: ExecutionChain) -> void:
	_particles.amount = _config.count * 3
	_particles.lifetime = _config.life_max
	_particles.one_shot = false
	_particles.explosiveness = 0.0
	_particles.randomness = 0.7
	_particles.local_coords = false

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


func _setup_crest_mode(chain: ExecutionChain) -> void:
	# 浪头模式：Sprite 沿横向弧线排列在弹体前沿
	_clear_crest_sprites()
	_particles.emitting = false
	_particles.visible = false

	_crest_sprite_tex = _flame_texture if _flame_texture else null
	if not _crest_sprite_tex:
		var tm = VFXTextureManager.get_instance()
		_crest_sprite_tex = tm.get_texture(VFXTextureManager.SOFT_CIRCLE)

	var parent = _particles.get_parent()
	var count: int = _config.count
	var _half_w: float = _config.crest_width * 0.5
	var fwd = chain.direction if chain.direction.length() > 0 else Vector2.RIGHT
	var perp = Vector2(-fwd.y, fwd.x)
	var offset = fwd * _config.forward_offset

	for i in range(count):
		var t := float(i) / float(count - 1) - 0.5  # -0.5 to 0.5
		var s := Sprite2D.new()
		s.texture = _crest_sprite_tex
		var dot_scale: float = _config.particle_scale_min + (_config.particle_scale_max - _config.particle_scale_min) * (0.3 + 0.7 * (1.0 - abs(t)))
		s.scale = Vector2.ONE * dot_scale
		s.modulate = _config.color_1
		# 弧形排列：沿横向分布，中间向前弯曲（1-t² 让中心凸出最多）
		var arc_push: float = 1.0 - t * t
		s.position = offset + perp * t * _config.crest_width + fwd * arc_push * 8.0
		parent.add_child(s)
		_crest_sprites.append(s)


func update(_dt: float, _parent: Node2D, chain: ExecutionChain) -> void:
	if not _config or not _config.is_enabled():
		return
	var fwd = chain.direction if chain.direction.length() > 0 else Vector2.RIGHT
	if _config.crest_mode:
		if _crest_sprites.size() > 0:
			var perp = Vector2(-fwd.y, fwd.x)
			var offset = fwd * _config.forward_offset
			for i in range(_crest_sprites.size()):
				var s = _crest_sprites[i]
				if not s:
					continue
				var t := float(i) / float(_crest_sprites.size() - 1) - 0.5
				var arc_push: float = 1.0 - t * t
				s.position = offset + perp * t * _config.crest_width + fwd * arc_push * 8.0
	else:
		if _config.forward_offset != 0.0:
			_particles.position = fwd * _config.forward_offset


func on_destroy(_parent: Node2D) -> void:
	if _particles:
		_particles.emitting = false
	_clear_crest_sprites()


func reset() -> void:
	_flame_texture = null
	_config = null
	_clear_crest_sprites()


func _clear_crest_sprites() -> void:
	for s in _crest_sprites:
		if s and is_instance_valid(s):
			s.queue_free()
	_crest_sprites.clear()


func is_active() -> bool:
	return _config != null and _config.is_enabled()
