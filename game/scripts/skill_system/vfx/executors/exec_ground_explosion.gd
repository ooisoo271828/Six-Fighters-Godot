class_name ExecGroundExplosion
extends VFXExecutorBase

## 地面爆炸片执行器 — 专为落石流星设计
## 组合效果：岩石碎片迸射 + 火焰冲击波 + 地面灼烧痕迹

func get_kind() -> StringName:
	return &"ground_explosion"

func execute(layer: VFXLayerDef, world_pos: Vector2, _pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params: Dictionary = layer.params
	var color: Color = params.get("color", Color(1.0, 0.4, 0.05, 1))
	var radius: float = params.get("radius", 60.0)
	var duration: float = params.get("duration", 0.8)
	var debris_color: Color = params.get("debris_color", Color(0.4, 0.2, 0.08, 1))

	# 1. 地面灼烧痕迹（暗色扩散圆，椭圆透视）
	var burn: HitVFXNode = HitVFXNode.new()
	burn.setup_sprite(
		tex_manager.get_texture(VFXTextureManager.SOFT_CIRCLE),
		Color(0.2, 0.08, 0.02, 0.6),
		Vector2(radius * 2.0 / 32.0 * 1.6, radius * 2.0 / 32.0),
		world_pos, duration * 1.5
	)
	var burn_tween: Tween = burn.create_tween()
	burn_tween.tween_property(burn.get_sprite(), "modulate:a", 0.0, duration * 1.2).set_delay(0.1)
	burn_tween.tween_callback(burn.stop).set_delay(duration * 1.5 + 0.1)
	burn.play()

	# 2. 火焰冲击环（椭圆扩散，带尖刺边缘）
	var ring: HitVFXNode = HitVFXNode.new()
	var ring_tex: Texture2D = tex_manager.get_texture(VFXTextureManager.RING_SPIKY)
	var tex_size: Vector2 = ring_tex.get_size() if ring_tex else Vector2(64, 64)
	ring.setup_sprite(ring_tex, Color.WHITE,
		Vector2(radius * 0.3 * 2.0 / tex_size.x * 1.6, radius * 0.3 * 2.0 / tex_size.y),
		world_pos, duration)

	# 环上色
	ring.get_sprite().modulate = color

	# 环扩散
	var ring_tween: Tween = ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring.get_sprite(), "scale",
		Vector2(radius * 2.0 / tex_size.x * 1.6, radius * 2.0 / tex_size.y),
		0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ring_tween.tween_property(ring.get_sprite(), "modulate:a", 0.0, 0.5).set_delay(0.25)
	ring_tween.tween_callback(ring.stop).set_delay(0.8)
	ring.play()

	# 3. 岩石碎片迸射
	var rock_tex: Texture2D = tex_manager.get_texture(&"rock_irregular")
	if rock_tex:
		var frag_count: int = randi_range(6, 10)
		for i in range(frag_count):
			var angle: float = float(i) / float(frag_count) * TAU + randf_range(-0.2, 0.2)
			var speed: float = randf_range(60.0, 180.0)
			var frag_scale: float = randf_range(0.15, 0.4)

			var frag: HitVFXNode = HitVFXNode.new()
			frag.setup_sprite(rock_tex, debris_color,
				Vector2.ONE * frag_scale,
				world_pos, 0.6)
			frag.get_sprite().rotation = randf_range(0.0, TAU)

			var ft: Tween = frag.create_tween()
			ft.set_parallel(true)
			var target: Vector2 = world_pos + Vector2(cos(angle), sin(angle)) * speed * 0.3
			ft.tween_property(frag.get_sprite(), "global_position", target, 0.3)
			ft.tween_property(frag.get_sprite(), "rotation", frag.get_sprite().rotation + randf_range(-3.0, 3.0), 0.3)
			ft.tween_property(frag.get_sprite(), "modulate:a", 0.0, 0.3).set_delay(0.3)
			ft.tween_callback(frag.stop).set_delay(0.7)
			frag.play()

	# 4. 火焰星点迸射
	var spark_count: int = randi_range(12, 20)
	for i in range(spark_count):
		var angle: float = float(i) / float(spark_count) * TAU + randf_range(-0.15, 0.15)
		var dist: float = randf_range(30.0, 70.0)
		var spark: HitVFXNode = HitVFXNode.new()
		var spark_tex: Texture2D = tex_manager.get_texture(VFXTextureManager.CIRCLE)
		spark.setup_sprite(spark_tex, Color(1.0, 0.6, 0.1, 1),
			Vector2.ONE * randf_range(0.2, 0.5),
			world_pos, 0.4)
		var st: Tween = spark.create_tween()
		st.set_parallel(true)
		var spark_target: Vector2 = world_pos + Vector2(cos(angle), sin(angle)) * dist
		st.tween_property(spark.get_sprite(), "global_position", spark_target, 0.2)
		st.tween_property(spark.get_sprite(), "modulate:a", 0.0, 0.2).set_delay(0.2)
		st.tween_callback(spark.stop).set_delay(0.5)
		spark.play()
