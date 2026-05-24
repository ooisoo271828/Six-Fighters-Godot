class_name ExecEllipseRing
extends VFXExecutorBase

## 椭圆冲击环执行器 — 从命中点向外扩散一个椭圆形的冲击环
## 用于模拟斜45度视角的地面爆炸片

func get_kind() -> StringName:
	return &"ellipse_ring"

func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params: Dictionary = layer.params
	var color: Color = params.get("color", Color(1.0, 0.5, 0.1, 1))
	var radius_start: float = params.get("radius_start", 8.0)
	var radius_end: float = params.get("radius_end", 48.0)
	var duration: float = params.get("duration", 0.8)
	var scale_x: float = params.get("scale_x", 1.5)

	# 使用带尖刺的程序化纹理
	var tex: Texture2D = tex_manager.get_texture(VFXTextureManager.RING_SPIKY)
	var tex_size: Vector2 = tex.get_size() if tex else Vector2(64, 64)

	var node: HitVFXNode
	if pool:
		node = pool.acquire()
	else:
		node = HitVFXNode.new()

	# 初始缩放：环形，水平拉伸为椭圆
	var start_scale: Vector2 = Vector2(
		radius_start * 2.0 / tex_size.x * scale_x,
		radius_start * 2.0 / tex_size.y
	)
	node.setup_sprite(tex, Color.WHITE, start_scale, world_pos, duration)

	# 应用溶解着色器
	var dissolve_shader_path: String = "res://scripts/skill_system/vfx/shaders/dissolve_shader.gdshader"
	if ResourceLoader.exists(dissolve_shader_path):
		var noise_tex: Texture2D = tex_manager.get_texture(VFXTextureManager.NOISE_PERLIN)
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = load(dissolve_shader_path)
		mat.set_shader_parameter("noise_texture", noise_tex)
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("base_color", Color(color.r, color.g, color.b, 0.85))
		mat.set_shader_parameter("dissolve_color", Color(color.r * 1.3, color.g * 0.8, color.b * 0.3, 1.0))
		mat.set_shader_parameter("edge_width", 0.15)
		mat.set_shader_parameter("dissolve_mode", 1)
		mat.set_shader_parameter("center", Vector2(0.5, 0.5))
		node.get_sprite().material = mat

	# 扩散：快速完成（~0.3s）
	var expand_dur: float = 0.3
	var end_scale: Vector2 = Vector2(
		radius_end * 2.0 / tex_size.x * scale_x,
		radius_end * 2.0 / tex_size.y
	)
	var tween: Tween = node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node.get_sprite(), "scale", end_scale, expand_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 溶解
	var dissolve_dur: float = duration
	tween.tween_method(_set_dissolve.bind(node.get_sprite()), 0.0, 1.0, dissolve_dur).set_delay(expand_dur)
	tween.tween_callback(node.stop).set_delay(expand_dur + dissolve_dur + 0.05)
	node.play()


static func _set_dissolve(value: float, sprite: Sprite2D) -> void:
	if sprite and sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("dissolve_amount", value)
