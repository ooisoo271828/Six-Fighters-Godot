extends Node2D

## Arena 战斗场景 — 基于锚点-跟随镜头系统

# ── 战斗常量 ──
const ATTACK_RANGE := 155.0
const ENEMY_SPEED := 95.0
const ENEMY_RANGED_RANGE := 280.0
const ENEMY_MELEE_RANGE := 80.0

# ── 镜头/跟随参数 ──
const FORMATION_Y_BIAS := 120.0      # 阵型中心向下偏移（英雄在画面偏下）
const SOFT_FOLLOW_RADIUS := 350.0     # 英雄自由活动半径
const HARD_FOLLOW_RADIUS := 480.0     # 超出则强制传送
const FOLLOW_LERP_NORMAL := 3.0       # 正常跟随速度
const FOLLOW_LERP_URGENT := 8.0       # 紧急追赶速度

# 阵型偏移由 GameManager.FORMATION_OFFSETS 统一管理

# ── 引用（.tscn 声明式节点） ──
@onready var camera_anchor: Node2D = $CameraAnchor
@onready var camera_2d: Camera2D = $CameraAnchor/Camera2D
@onready var y_sort_container: Node2D = $YSortContainer
@onready var projectiles_container: Node2D = $Projectiles
@onready var vfx_container: Node2D = $VFX
@onready var damage_text_layer: CanvasLayer = $DamageTextLayer
@onready var hud_layer: CanvasLayer = $HUDLayer

# ── 运行时状态 ──
var combat_params: CombatParams
var arena_config: ArenaConfig
var rng_seed: int = 0
var rng_func: Callable

var heroes: Array[Hero] = []
var hero_slot_indices: Array[int] = []  # 每个英雄对应的阵型槽位索引
var enemies: Array[Enemy] = []

var wave_index: int = 0
var spawn_queue: int = 0
var spawn_timer: float = 0.0
var wave_break_timer: float = 0.0
var wave_phase: String = "spawning"

var hero_registry: HeroRegistry
var skill_registry: SkillRegistry
var skill_system: Node
var joystick: VirtualJoystick

var wave_label: Label
var result_label: Label
var _exit_dialog: PanelContainer

# ── 初始化 ──

func _ready() -> void:
	_initialize()
	_create_ground()
	_create_hud()
	_setup_joystick()
	_start_combat()

func _initialize() -> void:
	rng_seed = Time.get_ticks_msec() & 0xFFFF ^ (randi() % 1000000000)
	rng_func = func() -> float:
		rng_seed = (rng_seed * 1103515245 + 12345) & 0x7FFFFFFF
		return float(rng_seed % 1000000) / 1000000.0

	arena_config = ArenaConfig.create_default()
	combat_params = GameManager.combat_params

	# SkillSystem — 加载完整的技能系统（投射物池、特效、信号总线）
	var skill_system_scene: PackedScene = load("res://scenes/skill_system/skill_system.tscn")
	skill_system = skill_system_scene.instantiate()
	add_child(skill_system)
	skill_registry = skill_system.skill_registry
	GameManager.skill_registry = skill_registry

	# HeroRegistry — 在 SkillSystem 之后加载，确保技能已注册
	hero_registry = HeroRegistry.new()
	add_child(hero_registry)

	# 锚点起始位置（世界坐标原点附近）
	camera_anchor.position = Vector2(270, 480)

func _create_ground() -> void:
	# 网格地面 — 提供空间参照
	var ground := Node2D.new()
	ground.name = "Ground"
	ground.set_script(preload("res://scripts/arena/battle_ground.gd"))
	ground.z_index = 0
	add_child(ground)
	move_child(ground, 0)  # 确保在最底层

func _create_hud() -> void:
	# 波次标签 — 在 HUD CanvasLayer 中
	wave_label = Label.new()
	wave_label.text = "Wave 1 / 3"
	wave_label.position = Vector2(200, 20)
	wave_label.add_theme_font_size_override("font_size", 20)
	hud_layer.add_child(wave_label)

	# 结果标签 — 在 HUD CanvasLayer 中
	result_label = Label.new()
	result_label.text = ""
	result_label.position = Vector2(170, 400)
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.visible = false
	hud_layer.add_child(result_label)

	# 退出副本按钮 — 右上角
	var exit_btn := Button.new()
	exit_btn.text = "退出副本"
	exit_btn.custom_minimum_size = Vector2(80, 32)
	exit_btn.add_theme_font_size_override("font_size", 12)
	exit_btn.anchor_left = 1.0
	exit_btn.anchor_right = 1.0
	exit_btn.offset_left = -90
	exit_btn.offset_right = -10
	exit_btn.offset_top = 10
	exit_btn.offset_bottom = 42
	exit_btn.pressed.connect(_on_exit_pressed)
	hud_layer.add_child(exit_btn)

	_setup_exit_dialog()

func _setup_joystick() -> void:
	joystick = VirtualJoystick.new()
	hud_layer.add_child(joystick)

	joystick.joystick_input.connect(_on_joystick_input)
	joystick.joystick_stopped.connect(_on_joystick_stopped)

func _on_joystick_input(dx: float, dy: float) -> void:
	camera_anchor.set_joystick_input(dx, dy)

func _on_joystick_stopped() -> void:
	camera_anchor.clear_joystick_input()

# ── 战斗启动 ──

func _start_combat() -> void:
	var result := GameManager.spawn_squad(y_sort_container, _get_spawn_center(), {
		"hero_registry": hero_registry,
		"skill_registry": skill_registry,
		"max_hp": 420.0,
		"add_shadow": true,
	})
	heroes = result["heroes"]
	hero_slot_indices = result["slot_indices"]

	wave_index = 0
	spawn_queue = arena_config.wave_enemy_counts[0] if wave_index < arena_config.wave_enemy_counts.size() else 4
	spawn_timer = 0.5
	wave_phase = "spawning"

	EventBus.emit_combat_started()
	EventBus.emit_wave_started(wave_index)

func _get_spawn_center() -> Vector2:
	return camera_anchor.position + Vector2(0, FORMATION_Y_BIAS)

# ── 主循环 ──

func _process(delta: float) -> void:
	if wave_phase == "win" or wave_phase == "lose":
		return

	_update_hero_follow(delta)
	_update_dots(delta)
	_update_combat(delta)
	_update_waves(delta)
	_cleanup_dead_units()
	_check_end_conditions()
	_update_ui()

# ── 英雄跟随系统 ──

func _get_formation_target(slot_index: int) -> Vector2:
	return _get_spawn_center() + GameManager.get_formation_offset(slot_index)

func _update_hero_follow(dt: float) -> void:
	for i in range(heroes.size()):
		var hero: Hero = heroes[i]
		if not (hero and is_instance_valid(hero) and hero.is_alive):
			continue

		var target := _get_formation_target(hero_slot_indices[i])
		var dist := hero.position.distance_to(target)

		if dist > HARD_FOLLOW_RADIUS:
			# 强制传送
			hero.position = target
		elif dist > SOFT_FOLLOW_RADIUS:
			# 紧急追赶
			hero.position = hero.position.lerp(target, FOLLOW_LERP_URGENT * dt)
		else:
			# 正常跟随
			hero.position = hero.position.lerp(target, FOLLOW_LERP_NORMAL * dt)

# ── DoT / 状态效果 ──

func _update_dots(dt: float) -> void:
	var dot_interval: float = combat_params.dot_tick_interval_sec

	for hero in heroes:
		if hero and is_instance_valid(hero) and hero.is_alive:
			hero.status_effects.tick(dt, dot_interval, func(dmg): hero.take_damage(dmg))

	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and enemy.is_alive:
			enemy.status_effects.tick(dt, dot_interval, func(dmg): enemy.take_damage(dmg))

# ── 战斗逻辑 ──

func _update_combat(dt: float) -> void:
	for hero in heroes:
		if not (hero and is_instance_valid(hero) and hero.is_alive):
			continue
		if hero.status_effects.is_stunned():
			continue

		var target := _find_nearest_enemy(hero.position)
		if not target:
			continue

		var dist := hero.position.distance_to(target.position)
		if dist > ATTACK_RANGE + 20:
			continue

		var pick: RoleAI.AutonomyPick = hero.tick_ai(dt, target, combat_params, rng_func)
		if not pick:
			continue

		# 触发视觉投射物
		skill_system.cast_skill(hero, pick.skill.skill_id, target)

		var result := CombatResolver.resolve_attack(
			hero.stats,
			target.stats,
			pick.skill.base_damage,
			pick.skill.damage_type,
			pick.skill.stun_chance if pick.skill.stun_chance else 0.0,
			pick.skill.stun_duration if pick.skill.stun_duration else 0.0,
			combat_params,
			rng_func,
			target.status_effects.get_shock_stacks_for_resolution()
		)

		target.take_damage(result.instant_damage)
		hero.timers.rage = minf(100.0, hero.timers.rage + result.instant_damage * 0.15)

		for update in result.status_updates:
			target.apply_status_updates([update], combat_params)

	for enemy in enemies:
		if not (enemy and is_instance_valid(enemy) and enemy.is_alive):
			continue

		var target := _find_nearest_hero(enemy.position)
		if not target:
			continue

		var skill_type: String = enemy.get_meta("skill_type", "slash")
		var is_ranged := skill_type == "shuriken"
		var attack_range := ENEMY_RANGED_RANGE if is_ranged else ENEMY_MELEE_RANGE

		var dist := enemy.position.distance_to(target.position)
		if dist > attack_range:
			var dir := (target.position - enemy.position).normalized()
			enemy.position += dir * ENEMY_SPEED * dt
			continue

		if enemy.tick_ai(dt, target):
			var result := CombatResolver.resolve_attack(
				enemy.stats,
				target.stats,
				enemy.base_attack,
				CombatResolver.DamageType.PHYSICAL,
				0.0, 0.0,
				combat_params,
				rng_func,
				target.status_effects.get_shock_stacks_for_resolution()
			)

			if is_ranged:
				_spawn_enemy_shuriken(enemy, target, result.instant_damage)
			else:
				_spawn_enemy_slash(enemy, target)
				target.take_damage(result.instant_damage)

	for enemy in enemies:
		if enemy and enemy.is_boss and is_instance_valid(enemy):
			enemy.update_boss_phases(dt, arena_config)

func _find_nearest_enemy(pos: Vector2) -> Enemy:
	var nearest: Enemy = null
	var nearest_dist := INF
	for enemy in enemies:
		if not (enemy and is_instance_valid(enemy) and enemy.is_alive):
			continue
		var dist := pos.distance_to(enemy.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _find_nearest_hero(pos: Vector2) -> Hero:
	var nearest: Hero = null
	var nearest_dist := INF
	for hero in heroes:
		if not (hero and is_instance_valid(hero) and hero.is_alive):
			continue
		var dist := pos.distance_to(hero.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = hero
	return nearest

# ── 波次系统 ──

func _update_waves(dt: float) -> void:
	match wave_phase:
		"boss":
			_check_boss_phase()
		"spawning":
			_update_spawning(dt)
		"break":
			_update_break(dt)

func _check_boss_phase() -> void:
	var boss_alive := false
	for e in enemies:
		if e and is_instance_valid(e) and e.is_alive and e.is_boss:
			boss_alive = true
			break
	if not boss_alive:
		_trigger_victory()

func _update_spawning(dt: float) -> void:
	if spawn_queue > 0:
		spawn_timer -= dt
		if spawn_timer <= 0:
			_spawn_minion()
			spawn_queue -= 1
			spawn_timer = arena_config.spawn_interval_sec
		return

	var minions_alive := false
	for e in enemies:
		if e and is_instance_valid(e) and e.is_alive and not e.is_boss:
			minions_alive = true
			break
	if minions_alive:
		return

	wave_phase = "break"
	wave_break_timer = arena_config.wave_break_sec

func _update_break(dt: float) -> void:
	wave_break_timer -= dt
	if wave_break_timer > 0:
		return

	if wave_index < arena_config.wave_count - 1:
		wave_index += 1
		spawn_queue = arena_config.wave_enemy_counts[wave_index] if wave_index < arena_config.wave_enemy_counts.size() else 4
		spawn_timer = 0.0
		wave_phase = "spawning"
		EventBus.emit_wave_started(wave_index)
	else:
		_spawn_boss()
		wave_phase = "boss"

# ── 敌人生成（基于锚点的世界坐标） ──

func _add_unit_shadow(unit: CharacterBody2D) -> void:
	var shadow := ColorRect.new()
	shadow.name = "Shadow"
	shadow.size = Vector2(20, 8)
	shadow.position = Vector2(-10, 14)
	shadow.color = Color(0, 0, 0, 0.3)
	unit.add_child(shadow)

func _spawn_minion() -> void:
	# 敌人在锚点上方区域生成
	var anchor_pos := camera_anchor.position
	var x := anchor_pos.x - 200.0 + (rng_func.call() as float) * 400.0
	var y := anchor_pos.y - 300.0 + (rng_func.call() as float) * 120.0

	var enemy := Enemy.new()
	enemy.name = "Minion_%d" % enemies.size()
	enemy.position = Vector2(x, y)
	y_sort_container.add_child(enemy)

	enemy.setup_enemy(false, arena_config.minion_base_hp, arena_config.minion_base_attack, 0.9)

	# 随机分配攻击类型：飞镖 or 刀光
	var skill_type := "shuriken" if rng_func.call() < 0.5 else "slash"
	enemy.set_meta("skill_type", skill_type)

	_add_unit_shadow(enemy)
	enemies.append(enemy)

func _spawn_boss() -> void:
	var anchor_pos := camera_anchor.position
	var x := anchor_pos.x
	var y := anchor_pos.y - 280.0

	var enemy := Enemy.new()
	enemy.name = "Boss"
	enemy.position = Vector2(x, y)
	y_sort_container.add_child(enemy)

	enemy.setup_enemy(true, arena_config.boss_base_hp, arena_config.boss_base_attack, arena_config.boss_pattern_cooldown_sec)
	_add_unit_shadow(enemy)
	enemies.append(enemy)

# ── 敌人技能特效 ──

func _spawn_enemy_shuriken(enemy: Node2D, target: Node2D, damage: float) -> void:
	var shuriken: Node2D = Node2D.new()
	shuriken.set_script(preload("res://scripts/arena/enemy_shuriken.gd"))
	shuriken.global_position = enemy.global_position
	add_child(shuriken)
	shuriken.setup(target, damage, func(dmg): target.take_damage(dmg))

func _spawn_enemy_slash(enemy: Node2D, target: Node2D) -> void:
	var slash: Node2D = Node2D.new()
	slash.set_script(preload("res://scripts/arena/enemy_slash.gd"))
	slash.global_position = enemy.global_position
	add_child(slash)
	slash.setup(target)

# ── 清理 / 结算 ──

func _cleanup_dead_units() -> void:
	heroes = heroes.filter(func(h): return h and is_instance_valid(h) and h.is_alive)
	enemies = enemies.filter(func(e): return e and is_instance_valid(e) and e.is_alive)

func _check_end_conditions() -> void:
	if heroes.is_empty() and wave_phase != "lose":
		_trigger_defeat()

func _trigger_victory() -> void:
	wave_phase = "win"
	result_label.text = "VICTORY"
	result_label.visible = true
	EventBus.emit_victory()

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/hub/main.tscn")

func _trigger_defeat() -> void:
	wave_phase = "lose"
	result_label.text = "DEFEAT"
	result_label.visible = true
	EventBus.emit_defeat()

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/hub/main.tscn")

# ── 退出副本确认 ──

func _setup_exit_dialog() -> void:
	_exit_dialog = PanelContainer.new()
	_exit_dialog.visible = false
	_exit_dialog.anchor_left = 0.5
	_exit_dialog.anchor_top = 0.5
	_exit_dialog.anchor_right = 0.5
	_exit_dialog.anchor_bottom = 0.5
	_exit_dialog.offset_left = -140
	_exit_dialog.offset_right = 140
	_exit_dialog.offset_top = -70
	_exit_dialog.offset_bottom = 90

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.6, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_exit_dialog.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "确认退出副本？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "退出后关卡进度将不保留"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 12)
	info.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(info)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var confirm_btn := Button.new()
	confirm_btn.text = "确认退出"
	confirm_btn.custom_minimum_size = Vector2(90, 36)
	confirm_btn.pressed.connect(_on_exit_confirmed)
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "继续战斗"
	cancel_btn.custom_minimum_size = Vector2(90, 36)
	cancel_btn.pressed.connect(_on_exit_cancelled)
	btn_row.add_child(cancel_btn)

	vbox.add_child(btn_row)
	_exit_dialog.add_child(vbox)

	# 全屏背景遮罩
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(backdrop)
	backdrop.visible = false
	_exit_dialog.set_meta("backdrop", backdrop)

	hud_layer.add_child(_exit_dialog)

func _on_exit_pressed() -> void:
	if wave_phase == "win" or wave_phase == "lose":
		return
	_exit_dialog.visible = true
	var backdrop: ColorRect = _exit_dialog.get_meta("backdrop")
	if backdrop:
		backdrop.visible = true

func _on_exit_confirmed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/main.tscn")

func _on_exit_cancelled() -> void:
	_exit_dialog.visible = false
	var backdrop: ColorRect = _exit_dialog.get_meta("backdrop")
	if backdrop:
		backdrop.visible = false

func _update_ui() -> void:
	if wave_label:
		wave_label.text = "Wave %d / %d" % [wave_index + 1, arena_config.wave_count]
