class_name ExecAfterimage
extends VFXExecutorBase

## 残影执行器 — 在命中点生成快速消散的残影效果


func get_kind() -> StringName:
	return &"afterimage"


func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params := layer.params
	var color: Color = params.get("color", Color(0.5, 0.5, 1.0, 0.6))
	var count: int = params.get("count", 3)
	var offset: float = params.get("offset", 6.0)
	var lifetime: float = params.get("lifetime", 0.25)
	var scale_factor: float = params.get("scale_factor", 1.0)

	var tex := tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := tex.get_size() if tex else Vector2(16, 16)
	var base_scale := Vector2.ONE * scale_factor * 2.0 / (tex_size.x / 16.0)

	for i in range(count):
		var delay: float = float(i) * lifetime / float(count) * 0.5
		var drift := Vector2(randf_range(-offset, offset), randf_range(-offset, offset))

		var node: HitVFXNode
		if pool:
			node = pool.acquire()
		else:
			node = HitVFXNode.new()

		var spawn_pos := world_pos + drift
		var alpha := color.a * (1.0 - float(i) / float(count) * 0.5)
		var fade_color := Color(color.r, color.g, color.b, alpha)
		node.setup_sprite(tex, fade_color, base_scale * (1.0 - float(i) * 0.15), spawn_pos, lifetime)

		# 延迟后淡出
		var tween := node.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(node.get_sprite(), "modulate:a", 0.0, lifetime - delay)
		tween.tween_callback(node.stop).set_delay(lifetime - delay + 0.05)
		node.play()
