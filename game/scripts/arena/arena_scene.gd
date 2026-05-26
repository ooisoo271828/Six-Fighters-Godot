extends Node2D

## Arena 战斗场景 — 熔岩洞穴竞技场
## 走廊阶段：位置触发刷怪 → Boss阶段：5秒倒计时 → 5波推怪

# ── 镜头/跟随参数 ──
const FORMATION_Y_BIAS := 120.0
const SOFT_FOLLOW_RADIUS := 350.0
const HARD_FOLLOW_RADIUS := 480.0
const FOLLOW_LERP_NORMAL := 3.0
const FOLLOW_LERP_URGENT := 8.0

# ── Boss 战参数 ──
const BOSS_WAVE_COUNTS: Array[int] = [8, 9, 10, 15, 23]
const BOSS_WAVE_TIMEOUT := 30.0
const BOSS_WAVE_DEATH_RATIO := 0.9
const BOSS_SPAWN_INTERVAL := 1.5
const COUNTDOWN_SEC := 5.0
const ELITE_HP_MULTIPLIER := 2.5
const ELITE_ATTACK_MULTIPLIER := 1.8

# ── 阶段枚举 ──
enum Phase {
	CORRIDOR,
	BOSS_COUNTDOWN,
	BOSS_ACTIVE,
	VICTORY,
	DEFEAT,
}

# ── 引用 ──
@onready var camera_anchor: Node2D = $CameraAnchor
@onready var camera_2d: Camera2D = $CameraAnchor/Camera2D
@onready var y_sort_container: Node2D = $YSortContainer
@onready var projectiles_container: Node2D = $Projectiles
@onready var vfx_container: Node2D = $VFX
@onready var damage_text_layer: CanvasLayer = $DamageTextLayer
@onready var hud_layer: CanvasLayer = $HUDLayer

# ── 地图系统 ──
var _arena_map: ArenaMapData
var _ground_tilemap: TileMapLayer

# ── 战斗编排 ──
var combat_mediator: CombatMediator

# ── 跳字系统 ──
var damage_floater

# ── 运行时状态（战斗） ──
var combat_params: CombatParams
var arena_config: ArenaConfig
var rng_seed: int = 0
var rng_func: Callable
var heroes: Array[Hero] = []
var hero_slot_indices: Array[int] = []
var enemies: Array[Enemy] = []
var hero_registry: HeroRegistry
var skill_registry: SkillRegistry
var skill_system: Node
var joystick: VirtualJoystick


# ── 运行时状态（阶段） ──
var phase: int = Phase.CORRIDOR
var wave_label: Label
var result_label: Label
var countdown_label: Label
var _exit_dialog: PanelContainer

# 走廊阶段
var _corridor_wave_idx := 0
var _corridor_wave_config: Array[Dictionary] = []

# Boss
var _countdown_timer := 0.0
var _wave_spawner: WaveSpawner
var _boss_wave_index := 0
var _boss_wave_time := 0.0
var _boss_wave_initial_count := 0

# ═════════════════
#  初始化
# ═════════════════

func _ready() -> void:
	_initialize()
	_create_tilemap()
	_create_hud()
	_setup_joystick()
	_start_combat()

func _initialize() -> void:
	rng_seed = Time.get_ticks_msec() & 0xFFFF ^ (randi() % 1000000000)
	rng_func = func() -> float:
		rng_seed = (rng_seed * 1103515245 + 12345) & 0x7FFFFFFF
		return float(rng_seed % 1000000) / 1000000.0

	combat_params = GameManager.combat_params
	arena_config = ArenaConfig.create_default()

	_arena_map = ArenaMapData.new()
	_corridor_wave_config = _arena_map.get_corridor_waves()

	var skill_system_scene: PackedScene = load("res://scenes/skill_system/skill_system.tscn")
	skill_system = skill_system_scene.instantiate()
	add_child(skill_system)
	skill_registry = skill_system.skill_registry
	GameManager.skill_registry = skill_registry

	# Register VFX layer with the skill VFX manager
	var vfx_manager = skill_system.get_node_or_null("SkillVFXManager")
	if vfx_manager:
		vfx_manager.register_vfx_layer(vfx_container)

	hero_registry = HeroRegistry.new()
	add_child(hero_registry)

	combat_mediator = CombatMediator.new()
	add_child(combat_mediator)
	combat_mediator.setup(combat_params, rng_func)
	combat_mediator.all_heroes_dead.connect(_trigger_defeat)

	var entry := _arena_map.get_entry_world_position()
	camera_anchor.position = Vector2(entry.x, entry.y - FORMATION_Y_BIAS)
	camera_2d.reset_smoothing()

	camera_2d.limit_left = 0
	camera_2d.limit_right = ArenaMapData.MAP_WIDTH * ArenaMapData.TILE_SIZE
	camera_2d.limit_top = 0
	camera_2d.limit_bottom = ArenaMapData.MAP_HEIGHT * ArenaMapData.TILE_SIZE

	_wave_spawner = WaveSpawner.new()
	add_child(_wave_spawner)

	# 初始化伤害跳字系统
	damage_floater = load("res://scripts/skill_system/damage_text/damage_floater.gd").new()
	damage_floater.name = "DamageFloater"
	damage_text_layer.add_child(damage_floater)

func _create_tilemap() -> void:
	_ground_tilemap = TileMapLayer.new()
	_ground_tilemap.name = "GroundTileMap"
	_ground_tilemap.tile_set = ArenaTileset.generate_tileset()
	_ground_tilemap.z_index = -1
	add_child(_ground_tilemap)
	move_child(_ground_tilemap, 0)

	for ty in range(ArenaMapData.MAP_HEIGHT):
		for tx in range(ArenaMapData.MAP_WIDTH):
			var tile_type := _arena_map.get_tile_type(tx, ty)
			if tile_type >= 0:
				var atlas_coords := Vector2i(tile_type % ArenaTileset.ATLAS_COLS, tile_type / ArenaTileset.ATLAS_COLS)
				_ground_tilemap.set_cell(Vector2i(tx, ty), 0, atlas_coords)

func _create_hud() -> void:
	wave_label = Label.new()
	wave_label.text = ""
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.position = Vector2(0, 20)
	wave_label.size = Vector2(540, 30)
	wave_label.add_theme_font_size_override("font_size", 18)
	hud_layer.add_child(wave_label)

	countdown_label = Label.new()
	countdown_label.text = ""
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.position = Vector2(0, 380)
	countdown_label.size = Vector2(540, 200)
	countdown_label.add_theme_font_size_override("font_size", 96)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	countdown_label.visible = false
	hud_layer.add_child(countdown_label)

	result_label = Label.new()
	result_label.text = ""
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.position = Vector2(0, 360)
	result_label.size = Vector2(540, 240)
	result_label.add_theme_font_size_override("font_size", 56)
	result_label.visible = false
	hud_layer.add_child(result_label)

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

# ═════════════════
#  战斗启动
# ═════════════════

func _start_combat() -> void:
	var result := GameManager.spawn_squad(y_sort_container, _get_spawn_center(), {
		"hero_registry": hero_registry,
		"skill_registry": skill_registry,
		"max_hp": 420.0,
		"add_shadow": true,
	})
	heroes = result["heroes"]
	hero_slot_indices = result["slot_indices"]

	combat_mediator.register_heroes(heroes)
	combat_mediator.register_enemies(enemies)
	combat_mediator.set_skill_system(skill_system)
	combat_mediator.set_enemy_attack_callbacks(_spawn_enemy_shuriken, _spawn_enemy_slash)
	combat_mediator.damage_dealt.connect(_on_damage_dealt)
	EventBus.emit_combat_started()

func _get_spawn_center() -> Vector2:
	return camera_anchor.position + Vector2(0, FORMATION_Y_BIAS)

# ═════════════════
#  主循环
# ═════════════════

func _process(delta: float) -> void:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return

	_update_hero_follow(delta)
	_clamp_positions()
	if combat_mediator:
		combat_mediator.update(delta)
	_update_phase_logic(delta)
	_check_end_conditions()
	_update_ui()

func _clamp_positions() -> void:
	camera_anchor.position = _arena_map.clamp_to_walkable(camera_anchor.position)
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			enemy.position = _arena_map.clamp_to_walkable(enemy.position)

# ═════════════════
#  英雄跟随
# ═════════════════

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
			hero.position = target
		elif dist > SOFT_FOLLOW_RADIUS:
			hero.position = hero.position.lerp(target, FOLLOW_LERP_URGENT * dt)
		else:
			hero.position = hero.position.lerp(target, FOLLOW_LERP_NORMAL * dt)

func _update_phase_logic(dt: float) -> void:
	match phase:
		Phase.CORRIDOR:
			_update_corridor(dt)
		Phase.BOSS_COUNTDOWN:
			_update_countdown(dt)
		Phase.BOSS_ACTIVE:
			_update_boss_wave(dt)

# ── 走廊阶段 ──

func _update_corridor(_dt: float) -> void:
	# 检查 Boss 触发
	if _arena_map.is_in_boss_trigger(camera_anchor.position):
		_start_boss_countdown()
		return

	# 检查走廊波次触发
	if _corridor_wave_idx < _corridor_wave_config.size():
		var config := _corridor_wave_config[_corridor_wave_idx]
		if camera_anchor.position.y < config["y_trigger"] * ArenaMapData.TILE_SIZE:
			_spawn_corridor_wave(config)
			_corridor_wave_idx += 1

func _spawn_corridor_wave(cfg: Dictionary) -> void:
	var zone_center := Vector2(camera_anchor.position.x, camera_anchor.position.y - 200.0)
	var zone_size := Vector2(500.0, 160.0)
	var rect_zone := SpawnZone.rect(zone_center, zone_size)
	var walkable_zone := SpawnZone.validated(rect_zone, func(p): return _arena_map.is_walkable(p.x, p.y))

	var wave := WaveConfig.new(cfg["count"], 4.0)
	wave.add_zone(walkable_zone)
	wave.elite_count = 1 if cfg.get("has_elite", false) else 0
	_wave_spawner.start_wave(wave, rng_func, _on_wave_spawn)

func _on_wave_spawn(pos: Vector2, _config: WaveConfig, is_elite: bool) -> void:
	var enemy := Enemy.new()
	enemy.name = "Minion_%d" % enemies.size()
	enemy.position = _arena_map.clamp_to_walkable(pos)
	y_sort_container.add_child(enemy)

	if is_elite:
		enemy.setup_enemy(false,
			arena_config.minion_base_hp * ELITE_HP_MULTIPLIER * _config.hp_multiplier,
			arena_config.minion_base_attack * ELITE_ATTACK_MULTIPLIER * _config.attack_multiplier, 1.2)
		enemy.modulate = Color(0.9, 0.4, 0.1)
	else:
		enemy.setup_enemy(false,
			arena_config.minion_base_hp * _config.hp_multiplier,
			arena_config.minion_base_attack * _config.attack_multiplier, 0.9)

	var skill_type := "shuriken" if rng_func.call() < 0.5 else "slash"
	enemy.set_meta("skill_type", skill_type)

	# åºç¨ WaveConfig æ©å±æ ç­¾
	for key in _config.tags:
		enemy.set_meta(key, _config.tags[key])

	_add_unit_shadow(enemy)
	enemies.append(enemy)
	combat_mediator.register_enemies(enemies)

func _start_boss_countdown() -> void:
	phase = Phase.BOSS_COUNTDOWN
	_countdown_timer = COUNTDOWN_SEC
	countdown_label.visible = true
	countdown_label.text = str(ceili(_countdown_timer))
	wave_label.text = "⚔ BOSS AREA ⚔"
	# 锁定摇杆，限制镜头移动
	camera_anchor.clear_joystick_input()
	camera_anchor.set("joystick_enabled", false)

func _update_countdown(dt: float) -> void:
	_countdown_timer -= dt
	countdown_label.text = str(maxi(1, ceili(_countdown_timer)))

	if _countdown_timer <= 0:
		countdown_label.visible = false
		camera_anchor.set("joystick_enabled", true)
		_start_boss_wave_sequence()

# ── Boss 战波次 ──

func _start_boss_wave_sequence() -> void:
	phase = Phase.BOSS_ACTIVE
	_boss_wave_index = 0
	_begin_boss_wave()

func _begin_boss_wave() -> void:
	var count := BOSS_WAVE_COUNTS[_boss_wave_index]
	_boss_wave_initial_count = count
	_boss_wave_time = 0.0

	var boss_center := _arena_map.get_boss_center_world()
	var zone := SpawnZone.validated(
		SpawnZone.circle(boss_center, 450.0),
		func(p): return _arena_map.is_walkable(p.x, p.y)
	)

	var wave := WaveConfig.new(count, 4.0)
	wave.add_zone(zone)
	wave.set_tag("boss_wave", _boss_wave_index)
	wave_label.text = "Boss Wave %d / %d" % [_boss_wave_index + 1, BOSS_WAVE_COUNTS.size()]
	EventBus.emit_wave_started(_boss_wave_index)
	_wave_spawner.start_wave(wave, rng_func, _on_wave_spawn)

func _update_boss_wave(dt: float) -> void:
	_boss_wave_time += dt
	if _wave_spawner.is_active:
		return
	# æåä¸æ³¢ï¼æäººå¨é¨æ­»äº¡ â èå©
	if _boss_wave_index >= BOSS_WAVE_COUNTS.size() - 1:
		for e in enemies:
			if e and is_instance_valid(e) and e.is_alive:
				return
		_trigger_victory()
		return
	if _should_advance_boss_wave():
		_advance_boss_wave()

func _should_advance_boss_wave() -> bool:
	if _boss_wave_index >= BOSS_WAVE_COUNTS.size() - 1:
		return false
	if _wave_spawner.is_active:
		return false
	if _boss_wave_time >= BOSS_WAVE_TIMEOUT:
		return true

	# ç»è®¡å½åæ³¢æ¬¡æå¤å°æäººè¿å¨å­æ´»
	var alive_from_current := 0
	for e in enemies:
		if e and is_instance_valid(e) and e.is_alive:
			if e.get_meta("boss_wave", -1) == _boss_wave_index:
				alive_from_current += 1

	var total := _boss_wave_initial_count
	var dead := total - alive_from_current
	if total > 0 and float(dead) / float(total) >= BOSS_WAVE_DEATH_RATIO:
		return true

	return false

func _advance_boss_wave() -> void:
	_boss_wave_index += 1
	if _boss_wave_index >= BOSS_WAVE_COUNTS.size():
		# 所有波次完成 → 胜利
		_trigger_victory()
	else:
		_begin_boss_wave()

# ══════════════════════════════════════════
#  敌人 & 视觉
# ══════════════════════════════════════════

func _add_unit_shadow(unit: CharacterBody2D) -> void:
	var shadow := ColorRect.new()
	shadow.name = "Shadow"
	shadow.size = Vector2(20, 8)
	shadow.position = Vector2(-10, 14)
	shadow.color = Color(0, 0, 0, 0.3)
	unit.add_child(shadow)

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

# ══════════════════════════════════════════
#  清理 / 结算
# ══════════════════════════════════════════



## Route damage events to floating text
func _on_damage_dealt(target: Node2D, amount: float, is_crit: bool, hit_outcome: int, damage_type: int, is_player_target: bool) -> void:
	if not damage_floater or not is_instance_valid(damage_floater):
		return
	if is_player_target:
		damage_floater.show_player_damage(target.global_position, amount, is_crit, hit_outcome, damage_type)
	else:
		damage_floater.show_monster_damage(target.global_position, amount, is_crit, hit_outcome, damage_type)



func _check_end_conditions() -> void:
	pass  # hero death handled by CombatMediator.all_heroes_dead signal

func _save_hub_return_position() -> void:
	# 传送门下方 3 个角色身位
	const PORTAL_POS := Vector2(15 * 32 + 16, 20 * 32 + 16)
	const SPOT_OFFSET := Vector2(0, 3 * 60)
	GameManager.hub_camera_position = PORTAL_POS + SPOT_OFFSET

func _trigger_victory() -> void:
	phase = Phase.VICTORY
	result_label.text = "VICTORY"
	result_label.visible = true
	EventBus.emit_victory()
	_save_hub_return_position()

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/hub/main.tscn")

func _trigger_defeat() -> void:
	phase = Phase.DEFEAT
	result_label.text = "DEFEAT"
	result_label.visible = true
	EventBus.emit_defeat()
	_save_hub_return_position()

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/hub/main.tscn")

# ══════════════════════════════════════════
#  退出确认
# ══════════════════════════════════════════

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

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(backdrop)
	backdrop.visible = false
	_exit_dialog.set_meta("backdrop", backdrop)
	hud_layer.add_child(_exit_dialog)

func _on_exit_pressed() -> void:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return
	_exit_dialog.visible = true
	var backdrop: ColorRect = _exit_dialog.get_meta("backdrop")
	if backdrop:
		backdrop.visible = true

func _on_exit_confirmed() -> void:
	_save_hub_return_position()
	get_tree().change_scene_to_file("res://scenes/hub/main.tscn")

func _on_exit_cancelled() -> void:
	_exit_dialog.visible = false
	var backdrop: ColorRect = _exit_dialog.get_meta("backdrop")
	if backdrop:
		backdrop.visible = false

func _update_ui() -> void:
	pass
