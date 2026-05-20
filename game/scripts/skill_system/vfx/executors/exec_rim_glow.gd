class_name ExecRimGlow
extends VFXExecutorBase

## 边缘发光执行器 — 命中后目标边缘短暂发光


func get_kind() -> StringName:
	return &"rim_glow"


func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params := layer.params
	var color: Color = params.get("color", Color(1.0, 0.8, 0.3, 1.0))
	var strength: float = params.get("strength", 1.0)
	var duration: float = params.get("duration", 0.3)

	# 获取场景树中 world_pos 附近的目标节点
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	# 创建一个全屏 ColorRect 来模拟边缘发光
	# 实际项目中应找到目标 Unit 并对其 _body 应用 shader
	# 这里用一个简化的闪光节点替代
	var tex := tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := tex.get_size() if tex else Vector2(16, 16)
	var radius: float = params.get("radius", 24.0)
	var scale_val := Vector2.ONE * radius * 2.0 / tex_size.x

	var node: HitVFXNode
	if pool:
		node = pool.acquire()
	else:
		node = HitVFXNode.new()

	node.setup_sprite(tex, Color(color.r, color.g, color.b, 0.5 * strength), scale_val, world_pos, duration)
	node.play()

	var tween := node.create_tween()
	tween.tween_property(node.get_sprite(), "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(node.stop).set_delay(duration + 0.05)
