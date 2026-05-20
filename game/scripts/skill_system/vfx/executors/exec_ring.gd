class_name ExecRing
extends VFXExecutorBase

## 冲击环执行器 — 从命中点向外扩散一个环形波纹


func get_kind() -> StringName:
	return &"ring"


func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params := layer.params
	var color: Color = params.get("color", Color.WHITE)
	var radius_start: float = params.get("radius_start", 8.0)
	var radius_end: float = params.get("radius_end", 48.0)
	var width: float = params.get("width", 3.0)
	var duration: float = params.get("duration", 0.35)

	var tex := tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := tex.get_size() if tex else Vector2(16, 16)

	var node: HitVFXNode
	if pool:
		node = pool.acquire()
	else:
		node = HitVFXNode.new()

	# 初始缩放 = 小环
	var start_scale := Vector2.ONE * radius_start * 2.0 / tex_size.x
	node.setup_sprite(tex, color, start_scale, world_pos, duration)
	node.get_sprite().modulate = Color(color.r, color.g, color.b, 0.6)

	# Tween: 环扩大 + 淡出
	var end_scale := Vector2.ONE * radius_end * 2.0 / tex_size.x
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node.get_sprite(), "scale", end_scale, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node.get_sprite(), "modulate:a", 0.0, duration).set_delay(duration * 0.2)
	tween.tween_callback(node.stop).set_delay(duration + 0.05)
	node.play()
