## SkillVFXManager — VFX 总控（v0.3 层级池版）
## 监听 SkillSignalBus 信号，通过 VFXTierRegistry 解析层级配置并执行
extends Node

var _initialized: bool = false
var _tier_registry: VFXTierRegistry

## 共享程序化纹理缓存
static var _shared_circle_tex: Texture2D


func initialize() -> void:
	if _initialized:
		return
	_initialized = true

	# 初始化层级注册表
	_tier_registry = VFXTierRegistry.new()
	add_child(_tier_registry)
	_tier_registry.initialize()

	print("[VFXManager] Initialized (tier pool system v0.3)")


## ── 信号处理 ──

func _on_skill_hit(_caster: Node2D, targets: Array, info: Dictionary) -> void:
	var skill_id: String = info.get("skill_id", "")
	if skill_id == "":
		return

	var visual_def := _load_visual_def(skill_id)
	if visual_def == null:
		return

	# 检查技能是否接入了层级池系统
	if not _has_tier_config(visual_def):
		return

	# 解析所有层级的 Layer
	var layers: Array[VFXLayerDef] = []
	for tier_id in ["A", "B", "C"]:
		var layer := _resolve_tier_layer(visual_def, tier_id)
		if layer:
			layers.append(layer)

	# 技能自定义 Layer
	if "custom_hit_layers" in visual_def:
		for custom in visual_def.custom_hit_layers:
			if custom is VFXLayerDef:
				layers.append(custom)

	if layers.is_empty():
		return

	for t in targets:
		if is_instance_valid(t):
			_execute_layers(layers, t.global_position)


func _on_behavior_spawned(_projectile: Node2D, _behavior_type: String, _chain_data: Dictionary) -> void:
	pass


func _on_behavior_complete(_projectile: Node2D) -> void:
	pass


func _on_telegraph_started(_caster: Node2D, target_pos: Vector2, shape: String, duration: float) -> void:
	_spawn_telegraph(target_pos, shape, duration)


## ── 层级解析 ──

func _has_tier_config(vis: Resource) -> bool:
	for key in ["hit_vfx_tier_A", "hit_vfx_tier_B", "hit_vfx_tier_C"]:
		if key in vis and vis.get(key) != "":
			return true
	if "custom_hit_layers" in vis and vis.custom_hit_layers.size() > 0:
		return true
	return false


func _resolve_tier_layer(vis: Resource, tier_id: String) -> VFXLayerDef:
	var key := "hit_vfx_tier_" + tier_id
	if key in vis:
		var effect_id: String = vis.get(key)
		if effect_id != "":
			var layer := _tier_registry.resolve(tier_id, effect_id)
			if layer:
				return layer
	return _tier_registry.get_default(tier_id)


func _load_visual_def(skill_id: String) -> Resource:
	var path := "res://resources/skills/skill_visual_defs/" + skill_id + ".tres"
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path)
	return null


## ── VFX 执行器 ──

func _execute_layers(layers: Array[VFXLayerDef], world_pos: Vector2) -> void:
	for layer in layers:
		if layer == null:
			continue
		match layer.kind:
			0:
				_exec_particle_burst(layer.params, world_pos)
			1:
				_exec_sprite_burst(layer.params, world_pos)
			2:
				_exec_screen_shake(layer.params)
			3:
				_exec_flash(layer.params, world_pos)
			4:
				_exec_ring(layer.params, world_pos)


func _exec_particle_burst(params: Dictionary, pos: Vector2) -> void:
	var count: int = params.get("count", 8)
	var speed_min: float = params.get("speed_min", 40.0)
	var speed_max: float = params.get("speed_max", 80.0)
	var size_min: float = params.get("size_min", 0.3)
	var size_max: float = params.get("size_max", 0.7)
	var color: Color = params.get("color", Color.WHITE)
	var lifetime: float = params.get("lifetime", 0.3)

	var tex := _get_circle_texture()
	var tex_size := tex.get_size() if tex else Vector2(16, 16)

	for i in range(count):
		var angle := float(i) / float(count) * TAU + randf_range(-0.15, 0.15)
		var dir := Vector2(cos(angle), sin(angle))
		var speed := randf_range(speed_min, speed_max)

		var spark := Sprite2D.new()
		spark.texture = tex
		spark.scale = Vector2.ONE * randf_range(size_min, size_max) / (tex_size.x / 16.0)
		spark.modulate = color
		spark.global_position = pos
		get_tree().root.add_child(spark)

		var tween := create_tween()
		tween.set_parallel(true)
		var target := spark.global_position + dir * speed * 0.3
		tween.tween_property(spark, "global_position", target, lifetime)
		tween.tween_property(spark, "modulate:a", 0.0, lifetime).set_delay(lifetime * 0.3)
		tween.tween_callback(spark.queue_free).set_delay(lifetime + 0.1)


func _exec_flash(params: Dictionary, pos: Vector2) -> void:
	var color: Color = params.get("color", Color.WHITE)
	var duration: float = params.get("duration", 0.1)
	var radius: float = params.get("radius", 16.0)

	var flash := Sprite2D.new()
	flash.texture = _get_circle_texture()
	var tex_size := flash.texture.get_size() if flash.texture else Vector2(16, 16)
	flash.scale = Vector2.ONE * radius * 2.0 / tex_size.x
	flash.modulate = color
	flash.global_position = pos
	get_tree().root.add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.tween_callback(flash.queue_free).set_delay(duration + 0.05)


func _exec_screen_shake(params: Dictionary) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		var strength: float = params.get("strength", 1.0)
		cam.add_trauma(strength * 0.05)


func _exec_sprite_burst(_params: Dictionary, _pos: Vector2) -> void:
	pass


func _exec_ring(_params: Dictionary, _pos: Vector2) -> void:
	pass


## ── 辅助 ──

func _spawn_telegraph(world_pos: Vector2, _shape: String, duration: float) -> void:
	var circle := Node2D.new()
	circle.global_position = world_pos
	var cs := CircleShape2D.new()
	cs.radius = 30.0
	var col := CollisionShape2D.new()
	col.shape = cs
	circle.add_child(col)
	get_tree().root.add_child(circle)
	await get_tree().create_timer(duration).timeout
	circle.queue_free()


func _get_circle_texture() -> Texture2D:
	if _shared_circle_tex != null:
		return _shared_circle_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for x in range(16):
		for y in range(16):
			var dx := float(x) - 7.5
			var dy := float(y) - 7.5
			if dx * dx + dy * dy <= 49.0:
				img.set_pixel(x, y, Color.WHITE)
	_shared_circle_tex = ImageTexture.create_from_image(img)
	return _shared_circle_tex
