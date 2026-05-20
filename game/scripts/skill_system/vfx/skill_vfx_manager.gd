## SkillVFXManager — VFX 总控（v0.5 策略模式版）
## 监听 SkillSignalBus 信号，通过 VFXTierRegistry 解析层级配置并执行
extends Node

var _initialized: bool = false
var _tier_registry: VFXTierRegistry

## 纹理管理器引用
var _tex_manager: VFXTextureManager

## VFXLayer 注册（场景树引用）
var _vfx_layer: Node2D
var _hit_vfx_pool: HitVFXPool

## 执行器注册器
var _executor_registry: VFXExecutorRegistry


func initialize() -> void:
	if _initialized:
		return
	_initialized = true

	# 初始化纹理管理器
	_tex_manager = VFXTextureManager.get_instance()

	# 初始化层级注册表
	_tier_registry = VFXTierRegistry.new()
	add_child(_tier_registry)
	_tier_registry.initialize()

	# 初始化执行器注册器
	_executor_registry = VFXExecutorRegistry.new()
	_register_executors()

	print("[VFXManager] Initialized (v0.5 executor strategy, kinds: %s)" % str(_executor_registry.get_registered_kinds()))


func _register_executors() -> void:
	_executor_registry.register(ExecParticleBurst.new())
	_executor_registry.register(ExecScreenShake.new())
	_executor_registry.register(ExecFlash.new())
	_executor_registry.register(ExecRing.new())
	_executor_registry.register(ExecSpriteBurst.new())
	_executor_registry.register(ExecShockwave.new())
	_executor_registry.register(ExecAfterimage.new())
	_executor_registry.register(ExecRimGlow.new())


## 注册 VFXLayer（由 ArenaScene 在 _ready 时调用）
func register_vfx_layer(vfx_layer: Node2D) -> void:
	_vfx_layer = vfx_layer
	# 查找或创建 HitVFXPool
	_hit_vfx_pool = _vfx_layer.get_node_or_null("HitVFXPool") as HitVFXPool
	if _hit_vfx_pool == null:
		_hit_vfx_pool = HitVFXPool.new()
		_hit_vfx_pool.name = "HitVFXPool"
		_vfx_layer.add_child(_hit_vfx_pool)
	print("[VFXManager] VFXLayer registered, pool size: ", _hit_vfx_pool.pool_size)


## 注销 VFXLayer（场景切换时调用）
func unregister_vfx_layer() -> void:
	if _hit_vfx_pool:
		_hit_vfx_pool.release_all()
	_vfx_layer = null
	_hit_vfx_pool = null


## 获取命中特效的挂载父节点
func _get_vfx_parent() -> Node:
	if _vfx_layer and is_instance_valid(_vfx_layer):
		return _vfx_layer
	# fallback：当前场景（而非 scene.root）
	return get_tree().current_scene if get_tree().current_scene else get_tree().root


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

## kind int → StringName 映射（兼容旧 .tres 的 int kind）
const KIND_MAP: Dictionary = {
	0: &"particle_burst",
	1: &"sprite_burst",
	2: &"screen_shake",
	3: &"flash",
	4: &"ring",
	5: &"shockwave",
	6: &"afterimage",
	7: &"rim_glow",
}

func _execute_layers(layers: Array[VFXLayerDef], world_pos: Vector2) -> void:
	for layer in layers:
		if layer == null:
			continue
		# 将 int kind 转换为 StringName
		var kind_name: StringName = KIND_MAP.get(layer.kind, &"")
		if kind_name == &"":
			push_warning("VFXManager: unknown kind int '%s'" % layer.kind)
			continue
		_executor_registry.dispatch(kind_name, layer, world_pos, _hit_vfx_pool, _tex_manager)


## ── 辅助 ──

func _spawn_telegraph(world_pos: Vector2, shape: String, duration: float) -> void:
	# 创建预警视觉节点
	var telegraph := Node2D.new()
	telegraph.global_position = world_pos

	# 使用 ColorRect + telegraph_shader 渲染预警区域
	var rect := ColorRect.new()
	var radius := 60.0
	rect.size = Vector2(radius * 2.0, radius * 2.0)
	rect.position = -rect.size / 2.0

	# 加载并应用 telegraph shader
	var shader_path := "res://scripts/skill_system/vfx/shaders/telegraph_shader.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader := load(shader_path)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("fill_color", Color(1.0, 0.2, 0.2, 0.25))
		mat.set_shader_parameter("border_color", Color(1.0, 0.3, 0.3, 0.7))
		mat.set_shader_parameter("pulse_speed", 3.0)
		rect.material = mat

		# 动画：progress 从 0 → 1
		var tween := telegraph.create_tween()
		tween.tween_method(
			func(val: float): mat.set_shader_parameter("progress", val),
			0.0, 0.8, duration
		)
	else:
		# fallback：无 shader 时用半透明红色
		rect.color = Color(1.0, 0.2, 0.2, 0.2)

	telegraph.add_child(rect)

	# 可选：添加碰撞形状用于 gameplay 检测
	if shape == "CIRCLE":
		var cs := CircleShape2D.new()
		cs.radius = radius
		var col := CollisionShape2D.new()
		col.shape = cs
		telegraph.add_child(col)

	get_tree().root.add_child(telegraph)

	# 等待持续时间后移除
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(telegraph):
		telegraph.queue_free()
