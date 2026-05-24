# comp_glow.gd
# 光晕组件 — 管理 glow/glow2/ray 三层光晕效果
class_name CompGlow
extends ProjectileComponent

var _glow_sprite: Sprite2D
var _glow2_sprite: Sprite2D
var _ray_sprite: Sprite2D

var _glow_texture: Texture2D
var _body: ProjectileVisual
var _tex_manager: VFXTextureManager

var _glow_shader: Shader
var _glow_forward_offset: float = 0.0

func create_nodes(parent: Node2D) -> void:
	_glow_sprite = Sprite2D.new()
	parent.add_child(_glow_sprite)
	_glow2_sprite = Sprite2D.new()
	parent.add_child(_glow2_sprite)
	_ray_sprite = Sprite2D.new()
	parent.add_child(_ray_sprite)
	# 加载 shader（静态共享）
	if _glow_shader == null:
		_glow_shader = load("res://scripts/skill_system/vfx/shaders/glow_shader.gdshader")


func configure(visual_def: SkillVisualDef, _chain: ExecutionChain, tex_manager: VFXTextureManager) -> void:
	_body = visual_def.get_body()
	_tex_manager = tex_manager
	_glow_forward_offset = _body.glow_offset_forward

	# 加载光晕纹理
	_glow_texture = null
	if _body.tex_glow_path != "":
		if _body.tex_glow_path.begins_with("vfx://"):
			var key: StringName = StringName(_body.tex_glow_path.trim_prefix("vfx://"))
			_glow_texture = tex_manager.get_texture(key)
		elif ResourceLoader.exists(_body.tex_glow_path):
			_glow_texture = load(_body.tex_glow_path)

	var glow_radius: float = _body.glow_radius
	var soft_circle: Texture2D = tex_manager.get_texture(VFXTextureManager.SOFT_CIRCLE)

	# ── 主光晕 ──
	if glow_radius > 0.0:
		var glow_color: Color = _body.glow_color
		var glow_alpha: float = _body.glow_alpha
		_glow_sprite.texture = _glow_texture if _glow_texture else soft_circle
		var glow_tex_size: Vector2 = _glow_sprite.texture.get_size()
		_glow_sprite.scale = Vector2(glow_radius * 2.0 / glow_tex_size.x, glow_radius * 2.0 / glow_tex_size.y)
		if _glow_shader:
			var mat: ShaderMaterial = tex_manager.get_shared_material(
				"res://scripts/skill_system/vfx/shaders/glow_shader.gdshader",
				{"glow_color": glow_color, "glow_strength": 1.5, "glow_radius": glow_radius}
			)
			_glow_sprite.material = mat
			_glow_sprite.modulate = Color(1, 1, 1, 1)
		else:
			_glow_sprite.modulate = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
		_glow_sprite.visible = true
	elif _body.glow_enabled:
		# 兼容旧参数
		var base_tex: Texture2D = _glow_texture if _glow_texture else tex_manager.get_texture(VFXTextureManager.CIRCLE)
		_glow_sprite.texture = base_tex
		var base_tex_size: Vector2 = base_tex.get_size()
		_glow_sprite.scale = Vector2.ONE * (_body.core_radius * 3.5) / base_tex_size.x
		if _glow_shader:
			var mat := tex_manager.get_shared_material(
				"res://scripts/skill_system/vfx/shaders/glow_shader.gdshader",
				{"glow_color": _body.core_color, "glow_strength": 1.2, "glow_radius": _body.core_radius * 3.5}
			)
			_glow_sprite.material = mat
			_glow_sprite.modulate = Color(1, 1, 1, 1)
		else:
			_glow_sprite.modulate = Color(_body.core_color.r, _body.core_color.g, _body.core_color.b, 0.35)
		_glow_sprite.visible = true
	else:
		_glow_sprite.visible = false

	# ── 外层辉光 ──
	var glow2_radius: float = _body.glow2_radius
	if glow2_radius > 0.0:
		var glow2_color: Color = _body.glow2_color
		_glow2_sprite.texture = _glow_texture if _glow_texture else soft_circle
		var g2_tex_size: Vector2 = _glow2_sprite.texture.get_size()
		_glow2_sprite.scale = Vector2(glow2_radius * 2.0 / g2_tex_size.x, glow2_radius * 2.0 / g2_tex_size.y)
		if _glow_shader:
			var mat := tex_manager.get_shared_material(
				"res://scripts/skill_system/vfx/shaders/glow_shader.gdshader",
				{"glow_color": glow2_color, "glow_strength": 0.8, "glow_radius": glow2_radius}
			)
			_glow2_sprite.material = mat
			_glow2_sprite.modulate = Color(1, 1, 1, 1)
		else:
			_glow2_sprite.modulate = Color(glow2_color.r, glow2_color.g, glow2_color.b, _body.glow2_alpha)
		_glow2_sprite.visible = true
	else:
		_glow2_sprite.visible = false

	# ── 辐射射线 ──
	if glow_radius > 0.0:
		_ray_sprite.texture = tex_manager.get_texture(VFXTextureManager.RAY_STARBURST)
		var ray_tex_size: Vector2 = _ray_sprite.texture.get_size()
		_ray_sprite.scale = Vector2.ONE * (glow_radius * 2.2 / ray_tex_size.x)
		var gc: Color = _body.glow_color
		_ray_sprite.modulate = Color(gc.r, gc.g, gc.b, 0.25)
		_ray_sprite.visible = true
	else:
		_ray_sprite.visible = false

	# 初始偏移
	# ��ʼƫ�ƣ�֧�ָ���ֵ����ֵ=����ƫ�ƣ�
	_glow_sprite.position = Vector2.ZERO
	_glow2_sprite.position = Vector2.ZERO
	_ray_sprite.position = Vector2.ZERO


func update(_dt: float, _parent: Node2D, chain: ExecutionChain) -> void:
	# ���ƫ�ƣ�֧�ָ���ֵ����ֵ=���
	if _glow_forward_offset != 0.0 and chain.direction.length() > 0.0:
		var glow_pos: Vector2 = chain.direction * _glow_forward_offset
		_glow_sprite.position = glow_pos
		_glow2_sprite.position = glow_pos
		_ray_sprite.position = glow_pos
	
	# ���ᳯ�򣨷ֱ��涯���ķ���
		if chain.direction.length() > 0.0:
			var dir_angle: float = chain.direction.angle()
			_glow_sprite.rotation = dir_angle
			_glow2_sprite.rotation = dir_angle

	# 射线层缓慢旋转
	if _ray_sprite and _ray_sprite.visible:
		_ray_sprite.rotation += _dt * 0.4


func on_destroy(_parent: Node2D) -> void:
	pass


func reset() -> void:
	_glow_texture = null
	_body = null


func is_active() -> bool:
	return _body != null


func get_all_sprites() -> Array:
	return [_glow_sprite, _glow2_sprite, _ray_sprite]
