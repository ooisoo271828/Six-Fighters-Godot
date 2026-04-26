extends Node2D

## Arena 战斗场景

const ATTACK_RANGE := 155.0
const MOVE_SPEED := 180.0
const ENEMY_SPEED := 95.0

var combat_params: CombatParams
var arena_config: ArenaConfig
var rng_seed: int = 0
var rng_func: Callable

var squad_position: Vector2 = Vector2(180, 420)
var move_vector: Vector2 = Vector2.ZERO

var heroes: Array[Hero] = []
var enemies: Array[Enemy] = []

var wave_index: int = 0
var spawn_queue: int = 0
var spawn_timer: float = 0.0
var wave_break_timer: float = 0.0
var wave_phase: String = "spawning"

var hero_registry: HeroRegistry
var skill_registry: SkillRegistry
var joystick: VirtualJoystick

var wave_label: Label
var result_label: Label

func _ready() -> void:
	_initialize()
	_create_ui()
	_setup_joystick()
	_start_combat()

func _initialize() -> void:
	rng_seed = Time.get_ticks_msec() & 0xFFFF ^ (randi() % 1000000000)
	rng_func = func() -> float:
		rng_seed = (rng_seed * 1103515245 + 12345) & 0x7FFFFFFF
		return float(rng_seed % 1000000) / 1000000.0
	
	arena_config = ArenaConfig.create_default()
	combat_params = GameManager.combat_params
	
	hero_registry = HeroRegistry.new()
	add_child(hero_registry)
	skill_registry = SkillRegistry.new()
	add_child(skill_registry)
	GameManager.skill_registry = skill_registry
	
	squad_position = Vector2(180, 420)

func _create_ui() -> void:
	# 背景 - 全屏覆盖，在最底层
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(540, 960)
	add_child(bg)
	
	# 波次标签
	wave_label = Label.new()
	wave_label.text = "Wave 1 / 3"
	wave_label.position = Vector2(200, 20)
	wave_label.add_theme_font_size_override("font_size", 20)
	add_child(wave_label)
	
	# 结果标签
	result_label = Label.new()
	result_label.text = ""
	result_label.position = Vector2(170, 400)
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.visible = false
	add_child(result_label)

func _setup_joystick() -> void:
	# 创建虚拟摇杆 - 直接作为子节点，用 _input 全局监听
	joystick = VirtualJoystick.new()
	add_child(joystick)
	
	# 连接信号
	joystick.joystick_input.connect(_on_joystick_input)
	joystick.joystick_stopped.connect(_on_joystick_stopped)

func _on_joystick_input(dx: float, dy: float) -> void:
	move_vector = Vector2(dx, dy)

func _on_joystick_stopped() -> void:
	move_vector = Vector2.ZERO

func _start_combat() -> void:
	var roster: Array[String] = GameManager.get_roster()
	if roster.is_empty():
		roster = ["ironwall", "ember", "moss"]
	
	_spawn_heroes(roster)
	
	wave_index = 0
	spawn_queue = arena_config.wave_enemy_counts[0] if wave_index < arena_config.wave_enemy_counts.size() else 4
	spawn_timer = 0.5  # 首个敌人0.5秒后生成
	wave_phase = "spawning"
	
	EventBus.emit_combat_started()
	EventBus.emit_wave_started(wave_index)

func _spawn_heroes(roster: Array[String]) -> void:
	var offsets := [-56, 0, 56]
	var i := 0
	
	for hero_id in roster:
		var hero_def: HeroDef = hero_registry.get_hero(hero_id)
		if not hero_def:
			continue
		
		var hero := Hero.new()
		hero.name = "Hero_%s" % hero_id
		hero.position = squad_position + Vector2(offsets[i % 3], 0)
		add_child(hero)
		
		var max_hp := 420.0
		hero.setup_hero(hero_def, max_hp, skill_registry)
		
		heroes.append(hero)
		i += 1

func _process(delta: float) -> void:
	if wave_phase == "win" or wave_phase == "lose":
		return
	
	_update_player_movement(delta)
	_update_hero_positions()
	_update_dots(delta)
	_update_combat(delta)
	_update_waves(delta)
	_cleanup_dead_units()
	_check_end_conditions()
	_update_ui()

func _update_player_movement(dt: float) -> void:
	var bounds := get_viewport_rect().size
	
	# 键盘输入
	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kb.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kb.y += 1.0
	
	if kb != Vector2.ZERO:
		move_vector = kb.normalized()
	
	squad_position.x = clampf(squad_position.x + move_vector.x * MOVE_SPEED * dt, 40, bounds.x - 40)
	squad_position.y = clampf(squad_position.y + move_vector.y * MOVE_SPEED * dt, 120, bounds.y - 100)

func _update_hero_positions() -> void:
	var offsets := [-56, 0, 56]
	for i in range(heroes.size()):
		var hero: Hero = heroes[i]
		if hero and is_instance_valid(hero):
			hero.position = squad_position + Vector2(offsets[i % 3], 0)

func _update_dots(dt: float) -> void:
	var dot_interval: float = combat_params.dot_tick_interval_sec
	
	for hero in heroes:
		if hero and is_instance_valid(hero) and hero.is_alive:
			hero.status_effects.tick(dt, dot_interval, func(dmg): hero.take_damage(dmg))
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and enemy.is_alive:
			enemy.status_effects.tick(dt, dot_interval, func(dmg): enemy.take_damage(dmg))

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
		# 英雄攻击范围与敌人接近范围一致（ATTACK_RANGE + 20）
		if dist > ATTACK_RANGE + 20:
			continue
		
		var pick: RoleAI.AutonomyPick = hero.tick_ai(dt, target, combat_params, rng_func)
		if not pick:
			continue
		
		var result := CombatResolver.resolve_attack(
			hero.stats,
			target.stats,
			pick.skill.base_damage,
			pick.skill.damage_type,
			pick.skill.stun_chance if pick.skill.stun_chance else 0.0,
			pick.skill.stun_duration_base_sec if pick.skill.stun_duration_base_sec else 0.0,
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
		
		var dist := enemy.position.distance_to(target.position)
		if dist > ATTACK_RANGE + 20:
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
	
	# 检查是否还有小兵存活
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

func _spawn_minion() -> void:
	var viewport := get_viewport_rect().size
	var x := 80.0 + (rng_func.call() as float) * (viewport.x - 160)
	var y := 140.0 + (rng_func.call() as float) * 120
	
	var enemy := Enemy.new()
	enemy.name = "Minion_%d" % enemies.size()
	enemy.position = Vector2(x, y)
	add_child(enemy)
	
	enemy.setup_enemy(false, arena_config.minion_base_hp, arena_config.minion_base_attack, 0.9)
	enemies.append(enemy)

func _spawn_boss() -> void:
	var viewport := get_viewport_rect().size
	var x := viewport.x / 2
	var y := 160.0
	
	var enemy := Enemy.new()
	enemy.name = "Boss"
	enemy.position = Vector2(x, y)
	add_child(enemy)
	
	enemy.setup_enemy(true, arena_config.boss_base_hp, arena_config.boss_base_attack, arena_config.boss_pattern_cooldown_sec)
	enemies.append(enemy)

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

func _update_ui() -> void:
	if wave_label:
		wave_label.text = "Wave %d / %d" % [wave_index + 1, arena_config.wave_count]
