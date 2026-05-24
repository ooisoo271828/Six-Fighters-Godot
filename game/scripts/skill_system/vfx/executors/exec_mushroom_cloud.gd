class_name ExecMushroomCloud
extends VFXExecutorBase

## 蘑菇云执行器 — 从命中点向上升腾的帧动画蘑菇云
## 使用 VFXTextureManager 预生成的 8 帧程序化纹理

func get_kind() -> StringName:
	return &"mushroom_cloud"

func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	var params := layer.params
	var rise_height: float = params.get("rise_height", 120.0)
	var rise_duration: float = params.get("rise_duration", 1.5)
	var fade_duration: float = params.get("fade_duration", 0.6)
	var scale_val: float = params.get("scale", 2.5)
	var color: Color = params.get("color", Color(1.0, 0.5, 0.15, 0.95))

	# 创建 Sprite 节点（主蘑菇云）
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex_manager.get_texture(&"mushroom_cloud_frame_0")
	sprite.modulate = color
	sprite.scale = Vector2.ONE * scale_val
	sprite.global_position = world_pos
	sprite.centered = true

	# 添加第二个外层光晕（增加体积感）
	var glow: Sprite2D = Sprite2D.new()
	glow.texture = tex_manager.get_texture(VFXTextureManager.SOFT_CIRCLE)
	glow.modulate = Color(1.0, 0.3, 0.05, 0.3)
	glow.scale = Vector2.ONE * scale_val * 1.5
	glow.global_position = world_pos
	glow.centered = true

	# 添加到 VFX 层
	var parent: Node = _get_vfx_parent(pool)
	if parent:
		parent.add_child(sprite)
		parent.add_child(glow)

	# 帧动画参数
	var frame_count: int = 8
	var frame_duration: float = rise_duration / float(frame_count)

	# 主 Tween：驱动帧切换 + 升腾 + 淡出
	var tween: Tween = sprite.create_tween()
	tween.set_parallel(true)

	# 上升运动加一点缓动
	var rise_target: Vector2 = world_pos + Vector2(0.0, -rise_height)
	tween.tween_property(sprite, "global_position", rise_target, rise_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 逐帧切换纹理
	for f in range(1, frame_count):
		var frame_key: StringName = StringName("mushroom_cloud_frame_%d" % f)
		var frame_tex: Texture2D = tex_manager.get_texture(frame_key)
		var frame_time: float = frame_duration * float(f)
		if frame_tex:
			tween.tween_callback(_set_texture.bind(sprite, frame_tex)).set_delay(frame_time)

	# 最后一段淡出
	tween.tween_method(_set_alpha.bind(sprite), 1.0, 0.0, fade_duration).set_delay(rise_duration)
	tween.tween_callback(_set_visible.bind(sprite, false)).set_delay(rise_duration + fade_duration + 0.05)

	# 外层光晕动画：先变大再消失
	var glow_tween: Tween = glow.create_tween()
	glow_tween.set_parallel(true)
	glow_tween.tween_property(glow, "scale", Vector2.ONE * scale_val * 2.5, rise_duration).set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(glow, "modulate:a", 0.0, rise_duration).set_delay(rise_duration * 0.2)
	glow_tween.tween_callback(_cleanup.bind(glow)).set_delay(rise_duration + 0.3)


static func _set_texture(sprite: Sprite2D, tex: Texture2D) -> void:
	if sprite and is_instance_valid(sprite):
		sprite.texture = tex


static func _set_alpha(value: float, sprite: Sprite2D) -> void:
	if sprite and is_instance_valid(sprite):
		sprite.modulate.a = value


static func _set_visible(sprite: Sprite2D, vis: bool) -> void:
	if sprite and is_instance_valid(sprite):
		sprite.visible = vis


static func _cleanup(sprite: Sprite2D) -> void:
	if sprite and is_instance_valid(sprite):
		sprite.queue_free()


## 获取 VFX 挂载父节点
func _get_vfx_parent(pool: HitVFXPool) -> Node:
	if pool and is_instance_valid(pool):
		return pool.get_parent()
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree and scene_tree.current_scene:
		return scene_tree.current_scene
	return null
