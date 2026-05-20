class_name ExecFlash
extends VFXExecutorBase

## 闪光执行器 — 命中时在目标位置生成短暂闪光


func get_kind() -> StringName:
	return &"flash"


func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params := layer.params
	var color: Color = params.get("color", Color.WHITE)
	var duration: float = params.get("duration", 0.1)
	var radius: float = params.get("radius", 16.0)

	var tex := tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := tex.get_size() if tex else Vector2(16, 16)
	var scale_val := Vector2.ONE * radius * 2.0 / tex_size.x

	var node: HitVFXNode
	if pool:
		node = pool.acquire()
	else:
		node = HitVFXNode.new()

	node.setup_sprite(tex, color, scale_val, world_pos, duration)
	node.play()

	var tween := node.create_tween()
	tween.tween_property(node.get_sprite(), "modulate:a", 0.0, duration)
	tween.tween_callback(node.stop).set_delay(duration + 0.05)
