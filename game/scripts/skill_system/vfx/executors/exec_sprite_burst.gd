class_name ExecSpriteBurst
extends VFXExecutorBase

## 精灵碎片爆发执行器 — 从命中点发射自定义纹理碎片


func get_kind() -> StringName:
	return &"sprite_burst"


func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params: Dictionary = layer.params
	var texture_key: String = params.get("texture_key", "circle")
	var count: int = params.get("count", 6)
	var speed_min: float = params.get("speed_min", 30.0)
	var speed_max: float = params.get("speed_max", 70.0)
	var size_min: float = params.get("size_min", 0.2)
	var size_max: float = params.get("size_max", 0.5)
	var color: Color = params.get("color", Color.WHITE)
	var lifetime: float = params.get("lifetime", 0.4)
	var angular_spread: float = params.get("angular_spread", 6.2832)

	var tex := tex_manager.get_texture(texture_key)
	var tex_size: Vector2 = tex.get_size() if tex else Vector2(16, 16)

	var base_angle: float = params.get("base_angle", -PI / 2.0)

	for i in range(count):
		var angle: float
		if angular_spread >= TAU:
			angle = float(i) / float(count) * TAU + randf_range(-0.15, 0.15)
		else:
			angle = base_angle + randf_range(-angular_spread / 2.0, angular_spread / 2.0)

		var dir := Vector2(cos(angle), sin(angle))
		var speed := randf_range(speed_min, speed_max)
		var scale_val := Vector2.ONE * randf_range(size_min, size_max) / (tex_size.x / 16.0)

		var node: HitVFXNode
		if pool:
			node = pool.acquire()
		else:
			node = HitVFXNode.new()

		node.setup_sprite(tex, color, scale_val, world_pos, lifetime)

		var tween := node.create_tween()
		tween.set_parallel(true)
		var target := world_pos + dir * speed * 0.3
		tween.tween_property(node.get_sprite(), "global_position", target, lifetime)
		tween.tween_property(node.get_sprite(), "modulate:a", 0.0, lifetime).set_delay(lifetime * 0.3)
		# 旋转
		var rot_speed := randf_range(-3.0, 3.0)
		tween.tween_property(node.get_sprite(), "rotation", rot_speed, lifetime)
		tween.tween_callback(node.stop).set_delay(lifetime + 0.1)
		node.play()
