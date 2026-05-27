## ProjectileNode — 单个投射物运行时节点（v4.0 Component 架构）
## 运动和命中逻辑在此，视觉效果委托给 ProjectileComponent
extends Node2D

const ProjectileHitDetectorScript = preload("res://scripts/skill_system/core/projectile_hit_detector.gd")

## 调试：显示碰撞检测框（运行时通过 execute 切换）
static var debug_show_collision: bool = false

var _chain: ExecutionChain
var _hit_area: Area2D
var _hit_shape: CollisionShape2D
var _collision_shape_type: int = 0  # 0=CIRCLE, 1=RECT, 2=CAPSULE, 3=POLYGON
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

## ── 浪头偏移（命中检测用） ──
var _crest_offset: float = 0.0


func _ready() -> void:
	VFXTextureManager._instance = null
	_setup_components()


func _setup_components() -> void:
	_comp_core = CompCoreSprite.new()
	_comp_glow = CompGlow.new()
	_comp_trail = CompTrailParticles.new()
	_comp_flame = CompFlameTrail.new()
	_comp_comet = CompCometTrail.new()
	_comp_path_dots = CompPathDots.new()
	_comp_explosion = CompExplosion.new()
	_components = [_comp_glow, _comp_core, _comp_trail, _comp_flame, _comp_comet, _comp_path_dots, _comp_explosion]
	for c in _components:
		c.create_nodes(self)


func initialize(chain: ExecutionChain, visual_def: SkillVisualDef, signal_bus: Node) -> void:
	_chain = chain
	_visual_def = visual_def
	_signal_bus = signal_bus
	_initialized = true
	_tex_manager = VFXTextureManager.get_instance()

	global_position = chain.position

	# 从 visual_def 读取轨迹类型（chain 默认为 0）
	if _visual_def.trajectory_type > 0 and chain.trajectory_type == 0:
		chain.trajectory_type = _visual_def.trajectory_type

	# 初始化曲线（随机弧线方向）
	if chain.trajectory_type > 0:
		if chain.control_point_offset == 0.0 or chain.control_point_offset == 100.0:
			chain.control_point_offset = randf_range(80.0, 200.0) * (1.0 if randi() % 2 == 0 else -1.0)
		if not chain.has_meta("bezier_forward_ratio"):
			chain.set_meta("bezier_forward_ratio", randf_range(0.4, 0.7))
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

	# 读取浪头偏移（仅对 crest 模式的技能生效）
	_crest_offset = 0.0
	var trail_def := _visual_def.get_trail()
	if trail_def and trail_def.flame and trail_def.flame.is_enabled() and trail_def.flame.crest_mode:
		_crest_offset = trail_def.flame.forward_offset + 8.0

	# 从 SkillDef 加载碰撞配置
	_setup_collision()

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

	# 命中检测（使用浪头位置）
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


## ── 碰撞体设置 ──

func _setup_collision() -> void:
	_hit_area = Area2D.new()
	_hit_area.collision_mask = 5  # 检测物理层1(敌人) + 物理层3(标靶)
	add_child(_hit_area)

	_hit_shape = CollisionShape2D.new()
	var def_path := "res://resources/skills/skill_defs/" + _chain.skill_id + ".tres"
	if ResourceLoader.exists(def_path):
		var def := load(def_path)
		_collision_shape_type = def.get("collision_shape") if "collision_shape" in def else 0
		var radius: float = def.get("collision_radius") if "collision_radius" in def else 14.0
		var w: float = def.get("collision_width") if "collision_width" in def else 16.0
		var h: float = def.get("collision_height") if "collision_height" in def else 16.0
		var poly = def.get("collision_polygon") if "collision_polygon" in def else []

		match _collision_shape_type:
			0:  # CIRCLE
				var s := CircleShape2D.new()
				s.radius = radius
				_hit_shape.shape = s
			1:  # RECT
				var s := RectangleShape2D.new()
				s.extents = Vector2(w * 0.5, h * 0.5)
				_hit_shape.shape = s
			2:  # CAPSULE
				var s := CapsuleShape2D.new()
				s.radius = minf(w, h) * 0.5
				s.height = maxf(w, h) - s.radius * 2.0
				_hit_shape.shape = s
			3:  # POLYGON
				if poly.size() >= 3:
					var s := ConcavePolygonShape2D.new()
					var segments: PackedVector2Array = []
					for i in poly.size():
						var p: Vector2 = poly[i]
						segments.append(p)
						segments.append(poly[(i + 1) % poly.size()])
					s.set_segments(segments)
					_hit_shape.shape = s
	else:
		# fallback: 圆形
		_collision_shape_type = 0
		var s := CircleShape2D.new()
		s.radius = 14.0
		_hit_shape.shape = s

	_hit_area.add_child(_hit_shape)

	# 碰撞体定位：有 crest 时放到浪头位置，否则在弹体中心
	if _crest_offset > 0.0 and _chain.direction.length() > 0:
		_hit_area.position = _chain.direction * _crest_offset


## ── 命中检测 ──

func _get_crest_pos() -> Vector2:
	if _crest_offset > 0.0 and _chain.direction.length() > 0:
		return global_position + _chain.direction * _crest_offset
	return global_position


func _check_hit() -> void:
	# 使用 Area2D 物理碰撞检测
	if _hit_area == null:
		return
	var bodies: Array = []
	bodies.append_array(_hit_area.get_overlapping_bodies())
	bodies.append_array(_hit_area.get_overlapping_areas())
	if bodies.is_empty():
		# 目标已死亡：检查是否有其他存活目标
		if _chain.target == null or not is_instance_valid(_chain.target):
			var alive_found := false
			for t in _chain.available_targets:
				if t and is_instance_valid(t) and t.get("is_alive") == true:
					alive_found = true
					break
			if alive_found:
				var new_target: Node2D = TargetSelector.find_nearest(global_position, _chain.available_targets, func(u): return u and is_instance_valid(u) and u.get("is_alive") == true)
				if new_target == null:
					for t in _chain.available_targets:
						if t and is_instance_valid(t) and t.get("is_alive") == true:
							new_target = t
							break
				if new_target:
					_chain.target = new_target
					_chain.target_pos = new_target.global_position
					_chain.direction = global_position.direction_to(new_target.global_position)
					return
			_chain.destroy()
		return

	# 找到最近的重叠体
	var closest: Node2D = null
	var closest_dist: float = INF
	for body in bodies:
		if body == _chain.caster:
			continue
		if not body.has_method("take_damage"):
			continue
		if body in _chain.hit_targets:
			continue
		var d := global_position.distance_squared_to(body.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = body

	if closest:
		_handle_hit(closest)


func _handle_hit(target: Node2D) -> void:
	if _chain.pierce_enabled:
		if target not in _chain.hit_targets:
			_chain.hit_targets.append(target)
			_emit_hit_signal(target)
			if _chain.pierce_count > 0:
				_chain.pierce_count -= 1
			if _chain.pierce_count == 0:
				_hide_all_visuals()
				_comp_flame.on_destroy(self)
				_comp_comet.on_destroy(self)
				_chain.destroy()
	else:
		_emit_hit_signal(target)
		if _chain.bounce_remaining > 0:
			var enemies: Array = _chain.enemy_query_func.call() if _chain.enemy_query_func.is_valid() else _chain.available_targets
			# Exclude hit target BEFORE selecting next bounce target
			if target not in _chain.hit_targets:
				_chain.hit_targets.append(target)
			var next: Node2D = TargetSelector.select_for_bounce(
				global_position, enemies, _chain.target_mode, _chain.hit_targets)
			if next:
				_chain.bounce_remaining -= 1
				match _chain.bounce_type:
					ExecutionChain.BounceType.REDIRECT:
						_chain.direction = global_position.direction_to(next.global_position)
						_chain.target = next
						return
					ExecutionChain.BounceType.RESPAWN:
						_bounce_respawn(target, next)
						return
		_chain.destroy()


func _emit_hit_signal(target: Node2D) -> void:
	if _signal_bus and is_instance_valid(_chain.caster):
		var damage_amount: float = _chain.damage * _chain.bounce_damage_scale
		var info: Dictionary = {
			"caster": _chain.caster,
			"target": target,
			"damage": damage_amount,
			"damage_type": _chain.damage_type,
			"skill_id": _chain.skill_id,
			"hit_aoe_radius": _chain.hit_aoe_radius,
			"hit_pos": _get_crest_pos(),
			"projectile_node": self,
			"secondary_damage_type": _chain.secondary_damage_type,
			"secondary_damage": _chain.secondary_damage,
		}
		_signal_bus.skill_hit.emit(_chain.caster, [target], info)


func _on_chain_hit(_chain_ref: ExecutionChain, _target: Node2D) -> void:
	pass


func _bounce_respawn(_hit_target: Node2D, next_target: Node2D) -> void:
	# 立即停止处理和隐藏视觉效果
	set_process(false)
	_hide_all_visuals()
	_comp_flame.on_destroy(self)
	_comp_comet.on_destroy(self)

	# 如果施法者或弹射目标已死亡，不再弹射
	if not is_instance_valid(_chain.caster) or not is_instance_valid(next_target):
		_chain.destroy()
		return

	# 先把 target 换为 next_target，避免 duplicate 复制已释放的原始 target
	_chain.target = next_target
	_chain.target_pos = next_target.global_position

	var new_chain := _chain.duplicate()
	new_chain.position = global_position
	new_chain.target = next_target
	new_chain.target_pos = next_target.global_position
	new_chain.direction = global_position.direction_to(next_target.global_position)
	new_chain.hit_targets = _chain.hit_targets.duplicate()
	new_chain.distance_traveled = 0.0
	new_chain.elapsed_time = 0.0
	new_chain.control_point_offset = randf_range(80.0, 200.0) * (1.0 if randi() % 2 == 0 else -1.0)
	new_chain.set_meta("bezier_forward_ratio", randf_range(0.4, 0.7))
	new_chain.behavior_state = "Flying"

	# 延时 0.2 秒后生成下一个弹射水浪
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self):
		return

	var pool = get_parent()
	if pool.has_method("spawn"):
		pool.spawn(new_chain, _visual_def, _signal_bus)

	_chain.destroy()


## ── 销毁 ──

func _on_chain_destroyed(_destroyed_chain: ExecutionChain) -> void:
	if _signal_bus:
		_signal_bus.behavior_complete.emit(self)

	# 统一销毁所有视觉组件
	for c in _components:
		c.on_destroy(self)

	# 清理碰撞体
	if _hit_area:
		_hit_area.queue_free()
		_hit_area = null

	# 立即隐藏所有精灵并归还池
	var pool = get_parent()
	if pool.has_method("despawn"):
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

func _draw() -> void:
	if not debug_show_collision:
		return
	if _hit_shape == null or _hit_shape.shape == null:
		return

	var color := Color(0.0, 1.0, 0.0, 0.8)  # 绿色半透明
	match _collision_shape_type:
		0:  # CIRCLE
			var circle = _hit_shape.shape as CircleShape2D
			if circle:
				var r: float = circle.radius
				draw_circle(Vector2.ZERO, r, Color.TRANSPARENT, false, 2.0)
				draw_arc(Vector2.ZERO, r, 0, TAU, 32, color, 2.0)
		1:  # RECT
			var rect_shape = _hit_shape.shape as RectangleShape2D
			if rect_shape:
				var ext: Vector2 = rect_shape.extents
				draw_rect(Rect2(-ext.x, -ext.y, ext.x * 2, ext.y * 2), color, false, 2.0)
		2:  # CAPSULE
			var cap = _hit_shape.shape as CapsuleShape2D
			if cap:
				var r: float = cap.radius
				var h: float = cap.height * 0.5
				draw_circle(Vector2(0, -h), r, Color.TRANSPARENT, false, 2.0)
				draw_circle(Vector2(0, h), r, Color.TRANSPARENT, false, 2.0)
				draw_rect(Rect2(-r, -h, r * 2, h * 2), color, false, 2.0)
		3:  # POLYGON
			if _chain and _chain.skill_id != "":
				var def_path := "res://resources/skills/skill_defs/" + _chain.skill_id + ".tres"
				if ResourceLoader.exists(def_path):
					var def := load(def_path)
					var poly = def.get("collision_polygon") if "collision_polygon" in def else []
					if poly.size() >= 3:
						var pts := PackedVector2Array()
						for p in poly:
							pts.append(p)
						draw_polyline(pts, color, 2.0)
						draw_line(pts[pts.size()-1], pts[0], color, 2.0)


func _reset_for_pool() -> void:
	for c in _components:
		c.reset()
	_initialized = false
	if _hit_area:
		_hit_area.queue_free()
		_hit_area = null
		_hit_shape = null
