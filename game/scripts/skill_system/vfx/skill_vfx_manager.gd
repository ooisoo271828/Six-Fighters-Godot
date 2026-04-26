## SkillVFXManager — VFX 总控
## 监听 SkillSignalBus 信号，驱动所有视觉特效
extends Node

var _initialized: bool = false

## ── 粒子池 ──
@warning_ignore("unused_private_class_variable")
var _particle_pools: Dictionary = {}  # effect_id → Array[CPUParticles2D]

func _ready() -> void:
	print("[SkillVFXManager] Ready (call initialize() from SkillRoot)")

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	# 预创建常用粒子效果
	_setup_default_effects()
	print("[SkillVFXManager] Initialized")

func _setup_default_effects() -> void:
	# 可以在这里预创建各种粒子预设
	pass

## ── 信号处理 ──

func _on_skill_hit(_caster: Node2D, targets: Array, info: Dictionary) -> void:
	var impact_level: String = info.get("impact_level", "medium")
	for t in targets:
		if is_instance_valid(t):
			spawn_hit_effect(t.global_position, info.get("damage_type", "physical"), impact_level)

func _on_behavior_spawned(_projectile: Node2D, _behavior_type: String, _chain_data: Dictionary) -> void:
	# projectile 节点自带视觉，这里可以补充额外的 VFX
	pass

func _on_behavior_complete(_projectile: Node2D) -> void:
	# 投射物消失时的视觉（已被 ProjectileNode 处理）
	pass

func _on_telegraph_started(_caster: Node2D, target_pos: Vector2, shape: String, duration: float) -> void:
	spawn_telegraph(target_pos, shape, duration)

## ── VFX 生成 ──

## 命中效果
func spawn_hit_effect(world_pos: Vector2, damage_type: String, impact_level: String) -> void:
	var effect := _create_hit_effect_node()
	effect.global_position = world_pos
	_configure_hit_effect(effect, damage_type, impact_level)
	get_tree().root.add_child(effect)
	effect.emitting = true
	await get_tree().create_timer(0.5).timeout
	effect.queue_free()

## 预警圈效果
func spawn_telegraph(world_pos: Vector2, shape: String, duration: float) -> void:
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

## ── 辅助 ──

func _create_hit_effect_node() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 20
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 0.8
	return p

func _configure_hit_effect(p: CPUParticles2D, damage_type: String, impact_level: String) -> void:
	match damage_type:
		"physical":
			p.modulate = Color(0.9, 0.85, 0.7)
		"elemental_fire":
			p.modulate = Color(1.0, 0.4, 0.1)
		"elemental_ice":
			p.modulate = Color(0.5, 0.85, 1.0)
		"elemental_poison":
			p.modulate = Color(0.3, 0.8, 0.3)
		"elemental_lightning":
			p.modulate = Color(0.8, 0.8, 1.0)
		_:
			p.modulate = Color.WHITE

	match impact_level:
		"strong":
			p.amount = 40
			p.scale_amount_max = 8.0
		"weak":
			p.amount = 10
			p.scale_amount_max = 3.0
		_:
			p.amount = 20
			p.scale_amount_max = 5.0

	p.initial_velocity_max = p.scale_amount_max * 100.0
