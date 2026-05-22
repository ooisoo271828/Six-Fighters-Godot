extends Node2D

## 基地小镇主场景 — 可玩的和平场景，英雄自由移动、传送门、工具栏

# ── 跟随参数（复用竞技场） ──
const FORMATION_Y_BIAS := 120.0
const SOFT_FOLLOW_RADIUS := 350.0
const HARD_FOLLOW_RADIUS := 480.0
const FOLLOW_LERP_NORMAL := 3.0
const FOLLOW_LERP_URGENT := 8.0

# 阵型偏移由 GameManager.FORMATION_OFFSETS 统一管理

# ── 节点引用 ──
@onready var ground_layer: TileMapLayer = $Ground
@onready var decor_layer: TileMapLayer = $GroundDecor
@onready var building_colliders: Node2D = $BuildingColliders
@onready var camera_anchor = $CameraAnchor
@onready var camera_2d: Camera2D = $CameraAnchor/Camera2D
@onready var y_sort_container: Node2D = $YSortContainer
@onready var ui_layer: CanvasLayer = $UILayer

# ── 运行时状态 ──
var _heroes: Array[Hero] = []  # 实际存在的英雄（不含空位）
var _hero_slot_indices: Array[int] = []  # 每个英雄对应的阵型槽位索引
var _hero_registry: HeroRegistry
var _joystick: VirtualJoystick
var _portal: Node2D
var _portal_dialog: PanelContainer
var _toolbar: PanelContainer

var _is_near_portal := false
var _squad_editor_open := false

func _ready() -> void:
	_init_tileset()
	_init_map()
	_init_building_colliders()
	_spawn_heroes()
	_setup_camera()
	_setup_joystick()
	_setup_portal()
	_setup_toolbar()
	_setup_portal_dialog()

# ── 瓦片地图初始化 ──

func _init_tileset() -> void:
	var ts := TownTileset.generate_tileset()
	ground_layer.tile_set = ts
	decor_layer.tile_set = ts

func _init_map() -> void:
	# 填充底层地形：草地
	for x in range(TownMapData.MAP_WIDTH):
		for y in range(TownMapData.MAP_HEIGHT):
			var tile_type := TownTileset.Tile.GRASS
			# 交替深浅草地增加层次
			if (x + y) % 3 == 0:
				tile_type = TownTileset.Tile.GRASS_DARK
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(tile_type % 8, tile_type / 8))

	# 铺设道路
	for segment in TownMapData.ROAD_SEGMENTS:
		var from: Vector2i = segment["from"]
		var to: Vector2i = segment["to"]
		if from.x == to.x:
			# 垂直道路
			for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
				ground_layer.set_cell(Vector2i(from.x, y), 0, Vector2i(TownTileset.Tile.DIRT_ROAD % 8, TownTileset.Tile.DIRT_ROAD / 8))
		else:
			# 水平道路
			for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
				ground_layer.set_cell(Vector2i(x, from.y), 0, Vector2i(TownTileset.Tile.DIRT_ROAD % 8, TownTileset.Tile.DIRT_ROAD / 8))

	# 绘制建筑（墙壁 + 屋顶）
	for building in TownMapData.BUILDINGS:
		var rect: Rect2i = building["rect"]
		var wall_coord := Vector2i(building["wall_tile"] % 8, building["wall_tile"] / 8)
		var roof_coord := Vector2i(building["roof_tile"] % 8, building["roof_tile"] / 8)
		var floor_coord := Vector2i(building["floor_tile"] % 8, building["floor_tile"] / 8)
		var door: Vector2i = building["door_pos"]

		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				if Vector2i(x, y) == door or Vector2i(x, y) == door + Vector2i(1, 0):
					# 门口
					ground_layer.set_cell(Vector2i(x, y), 0, floor_coord)
				elif x == rect.position.x or x == rect.position.x + rect.size.x - 1 or y == rect.position.y or y == rect.position.y + rect.size.y - 1:
					# 墙壁边缘
					ground_layer.set_cell(Vector2i(x, y), 0, wall_coord)
				else:
					# 内部地板
					ground_layer.set_cell(Vector2i(x, y), 0, floor_coord)

		# 屋顶（装饰层，覆盖在建筑上方）
		var roof_margin := 1
		for x in range(rect.position.x - roof_margin, rect.position.x + rect.size.x + roof_margin):
			for y in range(rect.position.y - roof_margin, rect.position.y + 1):
				decor_layer.set_cell(Vector2i(x, y), 0, roof_coord)

	# 装饰物（花丛、树木等放装饰层）
	for deco in TownMapData.DECORATIONS:
		var coord := Vector2i(deco["tile"] % 8, deco["tile"] / 8)
		decor_layer.set_cell(deco["pos"], 0, coord)

	# 传送门平台标记（地面特殊颜色）
	var portal_coord := Vector2i(TownTileset.Tile.STONE_WALL % 8, TownTileset.Tile.STONE_WALL / 8)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			ground_layer.set_cell(TownMapData.PORTAL_TILE + Vector2i(dx, dy), 0, portal_coord)

# ── 建筑碰撞体 ──

func _init_building_colliders() -> void:
	var colliders := TownMapData.get_building_colliders()
	for col_data in colliders:
		var body := StaticBody2D.new()
		body.position = col_data["position"]
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = col_data["size"]
		shape.shape = rect_shape
		body.add_child(shape)
		building_colliders.add_child(body)

# ── 英雄生成（调用 GameManager 标准接口） ──

var _spawn_config: Dictionary  # 缓存生成配置，供 _spawn_heroes / _refresh_heroes 共用

func _spawn_heroes() -> void:
	_hero_registry = HeroRegistry.new()
	add_child(_hero_registry)

	# 默认阵容（首次进入时）
	var roster := GameManager.get_roster()
	var has_any := false
	for h in roster:
		if h != "":
			has_any = true
			break
	if not has_any:
		GameManager.set_roster(["ironwall", "ember", "moss", "", "", ""])

	_spawn_config = {
		"hero_registry": _hero_registry,
		"skill_registry": null,
		"max_hp": 420.0,
		"add_collision_to_first": true,
		"add_shadow": true,
		"hide_hp_bar": true,
	}

	var result := GameManager.spawn_squad(y_sort_container, _get_spawn_center(), _spawn_config)
	_heroes = result["heroes"]
	_hero_slot_indices = result["slot_indices"]

func _refresh_heroes() -> void:
	for hero in _heroes:
		if hero and is_instance_valid(hero):
			hero.queue_free()
	_heroes.clear()
	_hero_slot_indices.clear()

	var result := GameManager.spawn_squad(y_sort_container, _get_spawn_center(), _spawn_config)
	_heroes = result["heroes"]
	_hero_slot_indices = result["slot_indices"]

func _get_spawn_center() -> Vector2:
	return camera_anchor.position + Vector2(0, FORMATION_Y_BIAS)

# ── 相机设置 ──

func _setup_camera() -> void:
	camera_anchor.set("input_enabled", true)
	camera_anchor.set("joystick_enabled", true)
	if not _heroes.is_empty():
		camera_anchor.position = _heroes[0].position - Vector2(0, FORMATION_Y_BIAS)
	# 设置相机边界
	camera_2d.limit_left = 0
	camera_2d.limit_right = TownMapData.MAP_WIDTH * TownTileset.TILE_SIZE
	camera_2d.limit_top = 0
	camera_2d.limit_bottom = TownMapData.MAP_HEIGHT * TownTileset.TILE_SIZE

# ── 摇杆设置 ──

func _setup_joystick() -> void:
	_joystick = VirtualJoystick.new()
	ui_layer.add_child(_joystick)
	_joystick.joystick_input.connect(_on_joystick_input)
	_joystick.joystick_stopped.connect(_on_joystick_stopped)

func _on_joystick_input(dx: float, dy: float) -> void:
	camera_anchor.set_joystick_input(dx, dy)

func _on_joystick_stopped() -> void:
	camera_anchor.clear_joystick_input()

# ── 传送门 ──

func _setup_portal() -> void:
	_portal = Node2D.new()
	_portal.set_script(preload("res://scripts/hub/portal.gd"))
	_portal.position = TownMapData.PORTAL_POSITION
	y_sort_container.add_child(_portal)

func _setup_portal_dialog() -> void:
	_portal_dialog = PanelContainer.new()
	_portal_dialog.visible = false
	# 手动设置锚点到屏幕中央（不依赖 anchors_preset）
	_portal_dialog.anchor_left = 0.5
	_portal_dialog.anchor_top = 0.5
	_portal_dialog.anchor_right = 0.5
	_portal_dialog.anchor_bottom = 0.5
	# 偏移：宽 300, 高 200，整体略偏下方便手机操作
	_portal_dialog.offset_left = -150
	_portal_dialog.offset_right = 150
	_portal_dialog.offset_top = -80
	_portal_dialog.offset_bottom = 120

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_portal_dialog.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "进入竞技场？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "确认后将传送至竞技场开始战斗"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 12)
	info.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(info)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var yes_btn := Button.new()
	yes_btn.text = "确认进入"
	yes_btn.custom_minimum_size = Vector2(100, 40)
	yes_btn.pressed.connect(_on_dialog_yes)
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "返回"
	no_btn.custom_minimum_size = Vector2(80, 40)
	no_btn.pressed.connect(_on_dialog_no)
	btn_row.add_child(no_btn)

	vbox.add_child(btn_row)
	_portal_dialog.add_child(vbox)

	# 全屏背景遮罩
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(backdrop)
	backdrop.visible = false
	_portal_dialog.set_meta("backdrop", backdrop)

	ui_layer.add_child(_portal_dialog)

# ── 工具栏 ──

func _setup_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.anchors_preset = Control.PRESET_TOP_RIGHT
	_toolbar.anchor_left = 1.0
	_toolbar.anchor_right = 1.0
	_toolbar.offset_left = -120
	_toolbar.offset_top = 10
	_toolbar.offset_right = -10
	_toolbar.offset_bottom = 130

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.8)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	_toolbar.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# 小队编辑按钮
	var squad_btn := Button.new()
	squad_btn.text = "小队编辑"
	squad_btn.custom_minimum_size = Vector2(100, 32)
	squad_btn.add_theme_font_size_override("font_size", 12)
	squad_btn.pressed.connect(_on_squad_editor_pressed)
	vbox.add_child(squad_btn)

	# 技能演示按钮
	var skill_btn := Button.new()
	skill_btn.text = "技能演示"
	skill_btn.custom_minimum_size = Vector2(100, 32)
	skill_btn.add_theme_font_size_override("font_size", 12)
	skill_btn.pressed.connect(_on_skill_demo_pressed)
	vbox.add_child(skill_btn)

	# 角色查看按钮
	var hero_btn := Button.new()
	hero_btn.text = "角色查看"
	hero_btn.custom_minimum_size = Vector2(100, 32)
	hero_btn.add_theme_font_size_override("font_size", 12)
	hero_btn.pressed.connect(_on_hero_viewer_pressed)
	vbox.add_child(hero_btn)

	_toolbar.add_child(vbox)
	ui_layer.add_child(_toolbar)

# ── 主循环 ──

func _process(delta: float) -> void:
	_update_hero_follow(delta)
	_update_portal_proximity()

# ── 英雄队形跟随 ──

func _get_formation_target(slot_index: int) -> Vector2:
	var anchor_pos: Vector2 = camera_anchor.position
	var offset := GameManager.get_formation_offset(slot_index)
	return anchor_pos + Vector2(0, FORMATION_Y_BIAS) + offset

func _update_hero_follow(dt: float) -> void:
	for i in range(_heroes.size()):
		var hero: Hero = _heroes[i]
		if not (hero and is_instance_valid(hero) and hero.is_alive):
			continue

		var slot_index: int = _hero_slot_indices[i]
		var target := _get_formation_target(slot_index)
		var dist := hero.position.distance_to(target)

		if dist > HARD_FOLLOW_RADIUS:
			hero.position = target
		elif dist > SOFT_FOLLOW_RADIUS:
			hero.position = hero.position.lerp(target, FOLLOW_LERP_URGENT * dt)
		else:
			hero.position = hero.position.lerp(target, FOLLOW_LERP_NORMAL * dt)

# ── 传送门交互 ──

func _update_portal_proximity() -> void:
	if _heroes.is_empty():
		return

	var lead_pos: Vector2 = _heroes[0].position
	var dist := lead_pos.distance_to(TownMapData.PORTAL_POSITION)
	var was_near := _is_near_portal
	_is_near_portal = dist < TownMapData.PORTAL_INTERACT_RADIUS

	if _is_near_portal != was_near:
		if _portal.has_method("set_highlighted"):
			_portal.set_highlighted(_is_near_portal)
		# 靠近传送门时直接弹出确认窗口
		if _is_near_portal and not _portal_dialog.visible:
			_show_portal_dialog()
		elif not _is_near_portal and _portal_dialog.visible:
			_hide_portal_dialog()

func _show_portal_dialog() -> void:
	_portal_dialog.visible = true
	var backdrop: ColorRect = _portal_dialog.get_meta("backdrop")
	if backdrop:
		backdrop.visible = true

func _hide_portal_dialog() -> void:
	_portal_dialog.visible = false
	var backdrop: ColorRect = _portal_dialog.get_meta("backdrop")
	if backdrop:
		backdrop.visible = false

func _on_dialog_yes() -> void:
	GameManager.set_roster(GameManager.get_roster())
	get_tree().change_scene_to_file("res://scenes/arena/battle.tscn")

func _on_dialog_no() -> void:
	_hide_portal_dialog()

# ── 工具栏按钮 ──

func _on_squad_editor_pressed() -> void:
	if _squad_editor_open:
		return
	_squad_editor_open = true

	var editor := SquadEditor.new()
	editor.name = "SquadEditor"
	ui_layer.add_child(editor)

	editor.applied.connect(func(_roster):
		_squad_editor_open = false
		_refresh_heroes()
	)
	editor.closed.connect(func():
		_squad_editor_open = false
		_refresh_heroes()
	)

func _on_skill_demo_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/dev/skill_demo.tscn")

func _on_hero_viewer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/viewer/hero_viewer.tscn")
