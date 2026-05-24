# comp_path_dots.gd
# 路径光点组件 — 沿飞行路径间隔生成离散光点
class_name CompPathDots
extends ProjectileComponent

var _config: PathDotConfig
var _timer: float = 0.0
var _tex_manager: VFXTextureManager

func configure(visual_def: SkillVisualDef, _chain: ExecutionChain, tex_manager: VFXTextureManager) -> void:
	var trail := visual_def.get_trail()
	_config = trail.path_dots
	_tex_manager = tex_manager
	_timer = 0.0
	if not _config or not _config.is_enabled():
		_config = null


func update(dt: float, parent: Node2D, _chain: ExecutionChain) -> void:
	if not _config:
		return
	_timer += dt
	if _timer < _config.interval:
		return
	_timer -= _config.interval

	# 使用池化的 HitVFXNode 或直接 Sprite（简化实现）
	var tex := _tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := tex.get_size() if tex else Vector2(16, 16)
	var scale_val := Vector2.ONE * _config.size / (tex_size.x / 16.0)

	var dot := Sprite2D.new()
	dot.texture = tex
	dot.scale = scale_val
	dot.modulate = _config.color
	dot.global_position = parent.global_position
	parent.get_tree().root.add_child(dot)

	var tw := parent.create_tween()
	tw.tween_property(dot, "modulate:a", 0.0, _config.lifetime)
	tw.tween_callback(dot.queue_free).set_delay(_config.lifetime + 0.05)


func reset() -> void:
	_config = null
	_timer = 0.0


func is_active() -> bool:
	return _config != null and _config.is_enabled()
