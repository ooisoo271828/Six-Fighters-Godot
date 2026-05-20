class_name ExecShockwave
extends VFXExecutorBase

## 冲击波执行器 — 快速膨胀的圆形波纹 + 可选屏幕震动


func get_kind() -> StringName:
	return &"shockwave"


func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params := layer.params
	var color: Color = params.get("color", Color.WHITE)
	var radius: float = params.get("radius", 64.0)
	var duration: float = params.get("duration", 0.25)
	var width: float = params.get("width", 4.0)
	var shake_strength: float = params.get("shake_strength", 0.0)

	var tex := tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := tex.get_size() if tex else Vector2(16, 16)

	# 冲击波主体：从小到大的环
	var node: HitVFXNode
	if pool:
		node = pool.acquire()
	else:
		node = HitVFXNode.new()

	var start_scale := Vector2.ONE * width / tex_size.x
	node.setup_sprite(tex, color, start_scale, world_pos, duration)
	node.get_sprite().modulate = Color(color.r, color.g, color.b, 0.8)

	var end_scale := Vector2.ONE * radius * 2.0 / tex_size.x
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node.get_sprite(), "scale", end_scale, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(node.get_sprite(), "modulate:a", 0.0, duration).set_delay(duration * 0.1)
	tween.tween_callback(node.stop).set_delay(duration + 0.05)
	node.play()

	# 可选震屏
	if shake_strength > 0.0:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			var cam := tree.root.get_viewport().get_camera_2d()
			if cam and cam.has_method("add_trauma"):
				cam.add_trauma(shake_strength * 0.05)
