# comp_core_sprite.gd
# 核心精灵组件 — 管理 core/inner/hotspot/nose 四层 Sprite
class_name CompCoreSprite
extends ProjectileComponent

var _core_sprite: Sprite2D
var _inner_sprite: Sprite2D
var _hotspot_sprite: Sprite2D
var _nose_sprite: Sprite2D

var _core_texture: Texture2D
var _nose_texture: Texture2D
var _body: ProjectileVisual

var _jitter_time: float = 0.0

func create_nodes(parent: Node2D) -> void:
	_core_sprite = Sprite2D.new()
	parent.add_child(_core_sprite)
	_inner_sprite = Sprite2D.new()
	parent.add_child(_inner_sprite)
	_hotspot_sprite = Sprite2D.new()
	parent.add_child(_hotspot_sprite)
	_nose_sprite = Sprite2D.new()
	parent.add_child(_nose_sprite)


func configure(visual_def: SkillVisualDef, chain: ExecutionChain, tex_manager: VFXTextureManager) -> void:
	_body = visual_def.get_body()
	_jitter_time = 0.0

	# 加载纹理
	_core_texture = null
	_nose_texture = null
	if _body.tex_core_path != "" and ResourceLoader.exists(_body.tex_core_path):
		_core_texture = load(_body.tex_core_path)
	if _body.tex_nose_path != "" and ResourceLoader.exists(_body.tex_nose_path):
		_nose_texture = load(_body.tex_nose_path)

	var base_tex: Texture2D = _core_texture if _core_texture else tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := base_tex.get_size() if base_tex else Vector2(16, 16)

	var core_w: float = _body.core_width if _body.core_width > 0 else _body.core_radius * 2.0
	var core_h: float = _body.core_height if _body.core_height > 0 else _body.core_radius * 2.0
	var core_color: Color = _body.core_color

	# 颜色覆盖（Modifier）
	if chain.color_override != Color.WHITE:
		core_color = chain.color_override

	# 设置碰撞半径
	var core_half: float = max(core_w, core_h) * 0.5
	chain.current_radius = max(_body.core_radius, core_half * 1.5)
	chain.base_radius = _body.core_radius

	# 核心
	_core_sprite.texture = base_tex
	_core_sprite.scale = Vector2(core_w / tex_size.x, core_h / tex_size.y)
	_core_sprite.modulate = core_color
	_core_sprite.visible = true

	# 内核层
	if _body.inner_enabled and _body.inner_width > 0 and _body.inner_height > 0:
		_inner_sprite.texture = base_tex
		_inner_sprite.scale = Vector2(_body.inner_width / tex_size.x, _body.inner_height / tex_size.y)
		_inner_sprite.position = _body.inner_offset
		_inner_sprite.modulate = _body.inner_color
		_inner_sprite.visible = true
	else:
		_inner_sprite.visible = false

	# 热点层
	if _body.hotspot_enabled and _body.hotspot_width > 0 and _body.hotspot_height > 0:
		_hotspot_sprite.texture = base_tex
		_hotspot_sprite.scale = Vector2(_body.hotspot_width / tex_size.x, _body.hotspot_height / tex_size.y)
		_hotspot_sprite.position = _body.hotspot_offset
		_hotspot_sprite.modulate = _body.hotspot_color
		_hotspot_sprite.visible = true
	else:
		_hotspot_sprite.visible = false

	# 弹尖
	if _body.nose_enabled and _body.nose_length > 0 and _body.nose_width > 0:
		var nose_tex: Texture2D = _nose_texture if _nose_texture else tex_manager.get_texture(VFXTextureManager.NOSE_TRIANGLE)
		_nose_sprite.texture = nose_tex
		var nose_tex_size := nose_tex.get_size() if nose_tex else Vector2(16, 16)
		_nose_sprite.scale = Vector2(_body.nose_length / nose_tex_size.x, _body.nose_width / nose_tex_size.y)
		_nose_sprite.modulate = _body.nose_color
		_nose_sprite.visible = true
	else:
		_nose_sprite.visible = false


func update(dt: float, parent: Node2D, chain: ExecutionChain) -> void:
	if not _body:
		return

	# 抖动
	if _body.jitter_enabled:
		_jitter_time += dt
		var amp: float = _body.jitter_amplitude
		var freq_x: float = _body.jitter_freq_x
		var freq_y: float = _body.jitter_freq_y
		var offset := Vector2(
			sin(_jitter_time * freq_x * TAU) * amp,
			sin(_jitter_time * freq_y * TAU) * amp
		)
		if _core_sprite:
			_core_sprite.position = offset
		if _inner_sprite and _inner_sprite.visible:
			_inner_sprite.position = _body.inner_offset + offset
		if _hotspot_sprite and _hotspot_sprite.visible:
			_hotspot_sprite.position = _body.hotspot_offset + offset

	# 弹尖朝向
	if _nose_sprite and _nose_sprite.visible and chain.direction.length() > 0:
		_nose_sprite.rotation = chain.direction.angle()


func on_destroy(_parent: Node2D) -> void:
	# 淡出由 ProjectileNode 统一处理
	pass


func reset() -> void:
	_core_texture = null
	_nose_texture = null
	_body = null
	_jitter_time = 0.0


func is_active() -> bool:
	return _body != null


func get_all_sprites() -> Array:
	return [_core_sprite, _inner_sprite, _hotspot_sprite, _nose_sprite]
