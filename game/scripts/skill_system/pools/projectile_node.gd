## ProjectileNode — 单个投射物运行时节点（v4.0 Component 架构）
## 运动和命中逻辑在此，视觉效果委托给 ProjectileComponent
extends Node2D

var _chain: ExecutionChain
var _visual_def: SkillVisualDef
var _signal_bus: Node
var _initialized: bool = false

## ── 视觉组件 ──
var _comp_core: CompCoreSprite
var _comp_glow: CompGlow
var _comp_trail: CompTrailParticles
var _comp_flame: CompFlameTrail
var _comp_comet: CompCometTrail
var _comp_path_dots: CompPathDots
var _comp_explosion: CompExplosion
var _components: Array[ProjectileComponent] = []

## ── 运动状态 ──
var _elapsed: float = 0.0
var _distance: float = 0.0
var _target_reached: bool = false
var _spawn_timer: float = 0.0
var _spawned: bool = false

## ── 曲线运动参数 ──
var _bezier_start: Vector2
var _bezier_control: Vector2
var _bezier_end: Vector2

## ── 纹理管理器 ──
var _tex_manager: VFXTextureManager


func _ready() -> void:
	_tex_manager = VFXTextureManager.get_instance()
	_setup_components()


func _setup_components() -> void:
	_comp_core = CompCoreSprite.new()
	_comp_glow = CompGlow.new()
	_comp_trail = CompTrailParticles.new()
	_comp_flame = CompFlameTrail.new()
	_comp_comet = CompCometTrail.new()
	_comp_path_dots = CompPathDots.new()
	_comp_explosion = CompExplosion.new()
	_components = [_comp_core, _comp_glow, _comp_trail, _comp_flame, _comp_comet, _comp_path_dots, _comp_explosion]
	for c in _components:
		c.create_nodes(self)


func initialize(chain: ExecutionChain, visual_def: SkillVisualDef, signal_bus: Node) -> void:
	_chain = chain
	_visual_def = visual_def
	_signal_bus = signal_bus
	_initialized = true

	global_position = chain.position

	# 初始化曲线
	if chain.trajectory_type > 0:
		_init_bezier()

	# 配置所有组件
	for c in _components:
		c.configure(visual_def, chain, _tex_manager)

	# 连接信号
	_chain.chain_destroyed.connect(_on_chain_destroyed)
	_chain.chain_hit.connect(_on_chain_hit)

	# 重置状态
	_elapsed = 0.0
	_distance = 0.0
	_target_reached = false
	_spawn_timer = 0.0
	_spawned = _chain.spawn_delay <= 0.0
	if not _spawned:
		_hide_all_visuals()

	# 设置速度（从 visual_def）
	_chain.speed = _visual_def.speed

	set_process(true)


## ── 每帧更新 ──

func _process(dt: float) -> void:
	if not _initialized:
		return

	if _chain.behavior_state == "Destroyed" or _chain.behavior_state == "Exploded":
		set_process(false)
		return

	_elapsed += dt
	_chain.elapsed_time = _elapsed

	# 安全网
	if _elapsed > 5.0:
		_chain.destroy()
		return

	# 检查触发器
	_chain.check_triggers(dt)

	# 错峰发射
	if not _spawned:
		_spawn_timer += dt
		if _spawn_timer >= _chain.spawn_delay:
			_spawned = true
			_show_all_visuals()
			if _chain.trajectory_type > 0:
				_init_bezier()
		else:
			_hide_all_visuals()
			return

	# 运动更新
	if _chain.tracking_enabled:
		_update_homing(dt)
	else:
		match _chain.trajectory_type:
			0: _update_linear(dt)
			1: _update_bezier_quad(dt)
			2: _update_sine_wave(dt)
			_: _update_linear(dt)

	# 膨胀
	_update_expansion()

	# 组件更新
	for c in _components:
		if c.is_active():
			c.update(dt, self, _chain)

	# 命中检测
	_check_hit()

	# 行为更新信号
	if _signal_bus:
		_signal_bus.behavior_update.emit(self, _chain.behavior_state, global_position)


## ── 运动模式 ──

func _update_linear(dt: float) -> void:
	var move: float = _chain.speed * dt * _chain.travel_time_multiplier
	var delta := _chain.direction * move
	global_position += delta
	_chain.position = global_position
	_distance += move
	_chain.distance_traveled = _distance


func _init_bezier() -> void:
	_bezier_start = _chain.position
	_bezier_end = _chain.target_pos
	var perpendicular := _chain.direction.rotated(PI / 2.0)
	_bezier_control = _bezier_start + _chain.direction * (_bezier_start.distance_to(_bezier_end) * _chain.get_meta("bezier_forward_ratio", 0.5)) + perpendicular * _chain.control_point_offset


func _update_bezier_quad(dt: float) -> void:
	var move := _chain.speed * dt * _chain.travel_time_multiplier
	var total_dist := _bezier_start.distance_to(_bezier_end)
	_distance += move
	var t := clampf(_distance / total_dist, 0.0, 1.0)
	var mt: float = 1.0 - t
	global_position = mt * mt * _bezier_start + 2.0 * mt * t * _bezier_control + t * t * _bezier_end
	_chain.position = global_position
	_chain.distance_traveled = _distance
	var next_t := minf(t + 0.01, 1.0)
	var mt2: float = 1.0 - next_t
	var next_pos := mt2 * mt2 * _bezier_start + 2.0 * mt2 * next_t * _bezier_control + next_t * next_t * _bezier_end
	_chain.direction = (next_pos - global_position).normalized()


func _update_sine_wave(dt: float) -> void:
	_update_linear(dt)
	var perpendicular := _chain.direction.rotated(PI / 2.0)
	var wave_offset: float = sin(_distance * 0.05 * _chain.wave_frequency) * _chain.wave_amplitude
	global_position += perpendicular * wave_offset * dt * 10.0


func _update_homing(dt: float) -> void:
	var target: Node2D = _chain.target
	if not target or not is_instance_valid(target):
		_chain.destroy()
		return
	var ideal_dir := global_position.direction_to(target.global_position)
	var current_angle := _chain.direction.angle()
	var target_angle := ideal_dir.angle()
	var angle_diff := atan2(sin(target_angle - current_angle), cos(target_angle - current_angle))
	var max_turn := _chain.turn_rate * dt
	var actual_turn := clampf(angle_diff, -max_turn, max_turn)
	_chain.direction = _chain.direction.rotated(actual_turn)
	var move := _chain.speed * dt * _chain.travel_time_multiplier
	global_position += _chain.direction * move
	_chain.position = global_position
	_distance += move
	_chain.distance_traveled = _distance


func _update_expansion() -> void:
	if _chain.expansion_growth_rate <= 0.0:
		return
	var new_scale: float = _chain.base_scale + _chain.distance_traveled * _chain.expansion_growth_rate
	_chain.scale = minf(new_scale, _chain.expansion_max_scale)
	_chain.current_radius = _chain.base_radius * _chain.scale
	scale = Vector2.ONE * _chain.scale


## ── 命中检测 ──

func _check_hit() -> void:
	if _chain.target == null or not is_instance_valid(_chain.target):
		_chain.destroy()
		return
	var hit_radius := _chain.hit_precision_radius + _chain.current_radius if _chain.tracking_enabled else _chain.current_radius + 10.0
	var dist := global_position.distance_to(_chain.target.global_position)
	if dist < hit_radius:
		_handle_hit(_chain.target)


func _handle_hit(target: Node2D) -> void:
	if _chain.pierce_enabled:
		if target not in _chain.hit_targets:
			_chain.hit_targets.append(target)
			_emit_hit_signal(target)
			if _chain.pierce_count > 0:
				_chain.pierce_count -= 1
			if _chain.pierce_count == 0:
				_chain.destroy()
	else:
		_emit_hit_signal(target)
		if _chain.bounce_remaining > 0:
			var enemies: Array = _chain.enemy_query_func.call() if _chain.enemy_query_func.is_valid() else []
			var next: Node2D = TargetSelector.find_nearest_excluding(global_position, enemies, target) if not enemies.is_empty() else null
			if next:
				_chain.bounce_remaining -= 1
				_chain.direction = global_position.direction_to(next.global_position)
				_chain.target = next
				return
		_chain.destroy()


func _emit_hit_signal(target: Node2D) -> void:
	if _signal_bus:
		var damage_amount: float = _chain.damage * _chain.bounce_damage_scale
		var info: Dictionary = {
			"caster": _chain.caster,
			"target": target,
			"damage": damage_amount,
			"damage_type": _chain.damage_type,
			"skill_id": _chain.skill_id,
			"hit_aoe_radius": _chain.hit_aoe_radius,
			"hit_pos": global_position,
			"projectile_node": self,
		}
		_signal_bus.skill_hit.emit(_chain.caster, [target], info)


func _on_chain_hit(_chain_ref: ExecutionChain, _target: Node2D) -> void:
	pass


## ── 销毁 ──

func _on_chain_destroyed(_destroyed_chain: ExecutionChain) -> void:
	if _signal_bus:
		_signal_bus.behavior_complete.emit(self)

	# 通知组件销毁
	for c in _components:
		c.on_destroy(self)

	# 收集所有 Sprite 用于淡出
	var all_sprites: Array = []
	all_sprites.append_array(_comp_core.get_all_sprites())
	all_sprites.append_array(_comp_glow.get_all_sprites())

	# 淡出（300ms）
	var fade_tween: Tween = create_tween()
	fade_tween.set_parallel(true)
	for s in all_sprites:
		if s and is_instance_valid(s) and s.visible:
			fade_tween.tween_property(s, "modulate:a", 0.0, 0.3)

	# 等待淡出后归还池
	var pool = get_parent()
	if pool.has_method("despawn"):
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(self):
			return
		for s in all_sprites:
			if s and is_instance_valid(s):
				s.visible = false
		pool.despawn(self)


## ── 可见性控制 ──

func _hide_all_visuals() -> void:
	var all_sprites: Array = []
	all_sprites.append_array(_comp_core.get_all_sprites())
	all_sprites.append_array(_comp_glow.get_all_sprites())
	for s in all_sprites:
		if s and is_instance_valid(s):
			s.visible = false


func _show_all_visuals() -> void:
	var all_sprites: Array = []
	all_sprites.append_array(_comp_core.get_all_sprites())
	all_sprites.append_array(_comp_glow.get_all_sprites())
	for s in all_sprites:
		if s and is_instance_valid(s):
			s.visible = true


## ── 池复用重置 ──

func _reset_for_pool() -> void:
	for c in _components:
		c.reset()
	_initialized = false
