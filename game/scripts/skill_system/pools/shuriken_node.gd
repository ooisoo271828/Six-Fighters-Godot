## ShurikenNode — 霰弹手里剑运行时节点
## 4刃十字手里剑 + 旋转飞行 + 命中血痕 + 火花粒子
extends Node2D

const ProjectileHitDetectorScript = preload("res://scripts/skill_system/core/projectile_hit_detector.gd")

# ── 常量 ──
const SHURIKEN_SIZE: int = 84
const BLADE_LENGTH: int = 34
const BLADE_WIDTH: int = 10
const GEM_RADIUS: int = 7
const ROTATION_SPEED: float = 12.0  # rad/s (~2 rotations/sec)
const HIT_FLASH_DURATION: float = 0.1
const STUCK_DURATION: float = 0.3

enum Phase { FLYING, HIT, DONE }

var _caster: Node2D
var _target: Node2D
var _damage: float
var _damage_type: String
var _skill_id: String
var _signal_bus: Node
var _available_targets: Array = []

var _phase: int = Phase.FLYING
var _phase_timer: float = 0.0
var _direction: Vector2
var _speed: float = 592.0
var _active: bool = false
var _hit_done: bool = false

var _sprite: Sprite2D


func _ready() -> void:
	_build_nodes()
	_make_shuriken_tex()


func _build_nodes() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Shuriken"
	_sprite.centered = true
	add_child(_sprite)


func _make_shuriken_tex() -> void:
	var img := Image.create(SHURIKEN_SIZE, SHURIKEN_SIZE, false, Image.FORMAT_RGBA8)
	var cx := SHURIKEN_SIZE / 2.0
	var cy := SHURIKEN_SIZE / 2.0

	for y in range(SHURIKEN_SIZE):
		for x in range(SHURIKEN_SIZE):
			var dx := x - cx
			var dy := y - cy
			var dist := sqrt(dx * dx + dy * dy)
			var angle := atan2(dy, dx)

			img.set_pixel(x, y, _shuriken_pixel(dx, dy, dist, angle, cx))

	var tex := ImageTexture.create_from_image(img)
	_sprite.texture = tex


func _shuriken_pixel(dx: float, dy: float, dist: float, angle: float, center: float) -> Color:
	# 中心血红宝石
	if dist <= GEM_RADIUS:
		var gem_shade := 0.7 + 0.3 * (1.0 - dist / GEM_RADIUS)
		return Color(0.9 * gem_shade, 0.1, 0.15 * gem_shade, 1.0)

	# 4片刀刃（十字方向：0°, 90°, 180°, 270°）
	for i in range(4):
		var blade_angle := float(i) * PI / 2.0
		var rel_angle := wrapf(angle - blade_angle, -PI, PI)

		# 刀刃形状：楔形，从中心向外延伸
		var blade_dist := dist - GEM_RADIUS
		if blade_dist < 0 or blade_dist > BLADE_LENGTH:
			continue

		# 角度范围随距离变化（根部宽，尖端窄）
		var width_factor := 1.0 - (blade_dist / BLADE_LENGTH) * 0.7
		var max_angle := atan2(BLADE_WIDTH * width_factor * 0.5, blade_dist)

		if absf(rel_angle) > max_angle:
			continue

		# 刀刃着色：银灰色，边缘高光
		var edge_factor := absf(rel_angle) / max_angle
		var length_factor := blade_dist / BLADE_LENGTH

		var shade: float
		if edge_factor > 0.7:
			# 边缘高光
			shade = 0.9 + 0.1 * (1.0 - (edge_factor - 0.7) / 0.3)
		elif edge_factor < 0.2:
			# 中心脊线
			shade = 0.85
		else:
			# 主面
			shade = 0.65 + 0.15 * (1.0 - length_factor)

		# 尖端渐淡
		if length_factor > 0.8:
			shade *= 1.0 - (length_factor - 0.8) / 0.2 * 0.3

		return Color(shade * 0.85, shade * 0.85, shade * 0.9, 1.0)

	# 中心环（宝石与刀刃之间）
	if dist <= GEM_RADIUS + 3.0:
		var ring_shade := 0.5 + 0.2 * sin(dist * 2.0)
		return Color(ring_shade * 0.4, ring_shade * 0.4, ring_shade * 0.45, 1.0)

	return Color(0, 0, 0, 0)


func initialize(caster: Node2D, target: Node2D, damage: float, damage_type: String, skill_id: String, signal_bus: Node, direction: Vector2, available_targets: Array = []) -> void:
	_caster = caster
	_target = target
	_damage = damage
	_damage_type = damage_type
	_skill_id = skill_id
	_signal_bus = signal_bus
	_direction = direction.normalized()
	_available_targets = available_targets
	_phase = Phase.FLYING
	_phase_timer = 0.0
	_hit_done = false
	_active = true
	_sprite.modulate = Color(1, 1, 1, 1)
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(0.5, 0.5)
	set_process(true)
	visible = true


# ═══════════════════ 更新循环 ═══════════════════

func _process(dt: float) -> void:
	if not _active:
		return

	_phase_timer += dt

	match _phase:
		Phase.FLYING:
			# 旋转动画
			_sprite.rotation += ROTATION_SPEED * dt

			# 移动
			global_position += _direction * _speed * dt

			# 检查是否命中目标（检测所有敌人）
			var targets := _available_targets
			if targets.is_empty() and is_instance_valid(_target):
				targets = [_target]

			if not targets.is_empty():
				var hit_target: Node2D = ProjectileHitDetectorScript.check_collision(
					global_position, targets, 20.0
				)
				if hit_target:
					_target = hit_target  # 更新目标为实际命中的敌人
					_on_hit()

			# 超出屏幕销毁
			if _phase_timer > 3.0:
				_destroy()

		Phase.HIT:
			if _phase_timer >= STUCK_DURATION:
				_start_fade()

		Phase.DONE:
			pass


func _on_hit() -> void:
	if _hit_done or not _active:
		return
	_hit_done = true

	# 发送伤害信号
	if is_instance_valid(_caster) and is_instance_valid(_target) and _signal_bus and _signal_bus.has_signal("skill_hit"):
		_signal_bus.skill_hit.emit(_caster, [_target], {
			"caster": _caster, "target": _target, "damage": _damage,
			"damage_type": _damage_type, "skill_id": _skill_id,
			"hit_pos": global_position,
		})

	# 播放命中特效
	_play_hit_effects()

	# 进入 HIT 阶段
	_phase = Phase.HIT
	_phase_timer = 0.0
	_sprite.visible = false


func _start_fade() -> void:
	_phase = Phase.DONE
	_destroy()


func _destroy() -> void:
	_active = false
	visible = false
	set_process(false)

	var p := get_parent()
	if p and p.has_method("despawn"):
		p.despawn(self)


# ═══════════════════ 命中特效 ═══════════════════

func _play_hit_effects() -> void:
	var gp := global_position

	# 1. 交叉血红刀痕
	_create_crossed_blade_marks(gp)

	# 2. 火花粒子
	_create_spark_particles(gp)

	# 3. 中心闪光
	_create_center_flash(gp)


func _create_crossed_blade_marks(pos: Vector2) -> void:
	# 两条交叉的血红刀痕（中间宽到两边逐渐变窄变尖）
	for i in range(2):
		var mark := Line2D.new()
		mark.name = "BladeMark%d" % i
		mark.width = 8.0
		mark.default_color = Color(0.9, 0.15, 0.2, 0.9)
		mark.joint_mode = Line2D.LINE_JOINT_ROUND
		mark.begin_cap_mode = Line2D.LINE_CAP_ROUND
		mark.end_cap_mode = Line2D.LINE_CAP_ROUND

		# 宽度曲线：中间宽，两端尖
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.0))    # 起点：尖
		curve.add_point(Vector2(0.15, 0.7))   # 快速变宽
		curve.add_point(Vector2(0.5, 1.0))    # 中间：最宽
		curve.add_point(Vector2(0.85, 0.7))   # 快速变窄
		curve.add_point(Vector2(1.0, 0.0))    # 终点：尖
		mark.width_curve = curve

		var angle := float(i) * PI / 4.0 + randf_range(-0.2, 0.2)
		var length := randf_range(36.0, 56.0)
		var dir := Vector2(cos(angle), sin(angle))

		# 添加多个点以形成平滑线条
		var segments := 8
		for j in range(segments + 1):
			var t := float(j) / float(segments)
			var point := pos + dir * length * (t - 0.5)
			mark.add_point(point)

		get_parent().add_child(mark)

		# 淡出动画
		var tw := create_tween()
		tw.tween_property(mark, "default_color:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(mark.queue_free).set_delay(0.35)


func _create_spark_particles(pos: Vector2) -> void:
	# 50个火花粒子，四周绽开
	for i in range(50):
		var spark := Sprite2D.new()
		spark.name = "Spark"
		spark.texture = _circle_tex()
		spark.scale = Vector2.ONE * randf_range(0.5, 0.7)
		spark.modulate = Color(1.0, randf_range(0.4, 0.9), randf_range(0.1, 0.5))
		spark.position = pos

		get_parent().add_child(spark)

		var angle := randf_range(0, TAU)
		var dist := randf_range(12.0, 45.0)
		var target_pos := pos + Vector2(cos(angle), sin(angle)) * dist

		var duration := randf_range(0.2, 0.35)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", target_pos, duration).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, duration * 0.7).set_delay(duration * 0.3)
		tw.tween_callback(spark.queue_free).set_delay(duration + 0.05)


func _create_center_flash(pos: Vector2) -> void:
	var flash := Sprite2D.new()
	flash.name = "HitFlash"
	flash.texture = _circle_tex()
	flash.scale = Vector2.ONE * 0.5
	flash.modulate = Color(1.0, 0.9, 0.8, 0.9)
	flash.position = pos

	get_parent().add_child(flash)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector2.ONE * 1.5, HIT_FLASH_DURATION).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, HIT_FLASH_DURATION)
	tw.tween_callback(flash.queue_free).set_delay(HIT_FLASH_DURATION + 0.05)


# ═══════════════════ 池化重置 ═══════════════════

func reset_for_pool() -> void:
	_active = false
	_hit_done = false
	_phase = Phase.FLYING
	_phase_timer = 0.0
	_caster = null
	_target = null
	_signal_bus = null
	visible = false
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	_sprite.rotation = 0.0
	set_process(false)


# ═══════════════════ 工具纹理 ═══════════════════

var _circle_tex_cache: Texture2D = null

func _circle_tex() -> Texture2D:
	if _circle_tex_cache:
		return _circle_tex_cache
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var cx := 4.0
	for y in range(8):
		for x in range(8):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cx))
			var a := 1.0 - clampf(d / cx, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_circle_tex_cache = ImageTexture.create_from_image(img)
	return _circle_tex_cache
