class_name ExecParticleBurst
extends VFXExecutorBase

## 粒子爆发执行器 — 从命中点向四周发射精灵碎片


func get_kind() -> StringName:
	return &"particle_burst"


func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params := layer.params
	var count: int = params.get("count", 8)
	var speed_min: float = params.get("speed_min", 40.0)
	var speed_max: float = params.get("speed_max", 80.0)
	var size_min: float = params.get("size_min", 0.3)
	var size_max: float = params.get("size_max", 0.7)
	var color: Color = params.get("color", Color.WHITE)
	var lifetime: float = params.get("lifetime", 0.3)

	var tex := tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := tex.get_size() if tex else Vector2(16, 16)

	for i in range(count):
		var angle := float(i) / float(count) * TAU + randf_range(-0.15, 0.15)
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
		tween.tween_callback(node.stop).set_delay(lifetime + 0.1)
		node.play()
