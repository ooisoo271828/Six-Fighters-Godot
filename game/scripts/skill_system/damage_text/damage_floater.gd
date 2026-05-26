## DamageFloater — 伤害跳字协调器
## 管理怪物/玩家两个对象池，将伤害事件转换为屏幕上的跳字
extends Node

## 伤害类型 → 颜色映射
const DAMAGE_COLORS := {
	CombatResolver.DamageType.PHYSICAL: Color.WHITE,
	CombatResolver.DamageType.ELEMENTAL_FIRE: Color(1.0, 0.27, 0.27),
	CombatResolver.DamageType.ELEMENTAL_ICE: Color(0.27, 0.53, 1.0),
	CombatResolver.DamageType.ELEMENTAL_LIGHTNING: Color(1.0, 0.84, 0.0),
	CombatResolver.DamageType.ELEMENTAL_POISON: Color(0.27, 1.0, 0.27),
}

const COLOR_CRIT := Color(1.0, 0.4, 0.0)
const COLOR_MISS := Color(0.53, 0.53, 0.53)
const COLOR_HEAL := Color(0.27, 0.87, 0.27)

const FONT_SIZE_MONSTER := 24
const FONT_SIZE_MONSTER_CRIT := 32
const FONT_SIZE_PLAYER := 18
const FONT_SIZE_PLAYER_CRIT := 24
const FONT_SIZE_DOT := 16
const FONT_SIZE_HEAL := 20
const FONT_SIZE_MISS := 20

## 单位头顶偏移（世界坐标）
const HEAD_OFFSET_Y: float = 35.0
var _pixel_font = null

func _get_pixel_font():
	if not _pixel_font:
		_pixel_font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	return _pixel_font

var _pool_script: GDScript
var monster_pool
var player_pool


func _init() -> void:
	_pool_script = load("res://scripts/skill_system/damage_text/damage_text_pool.gd")
	monster_pool = _pool_script.new()
	monster_pool.name = "MonsterDamageTextPool"
	add_child(monster_pool)

	player_pool = _pool_script.new()
	player_pool.name = "PlayerDamageTextPool"
	add_child(player_pool)


## 显示怪物伤害跳字（世界坐标）
func show_monster_damage(world_pos: Vector2, amount: float, is_crit: bool, hit_outcome: int, damage_type: int) -> void:
	if hit_outcome == CombatResolver.HitOutcome.MISS:
		_show_text(world_pos, "MISS", COLOR_MISS, FONT_SIZE_MISS, monster_pool, false, false, _get_pixel_font())
		return

	var color: Color = COLOR_CRIT if is_crit else DAMAGE_COLORS.get(damage_type, Color.WHITE)
	var font_size: int = FONT_SIZE_MONSTER_CRIT if is_crit else FONT_SIZE_MONSTER
	var text := "%d!" % amount if is_crit else "%d" % amount

	_show_text(world_pos, text, color, font_size, monster_pool, true, false, _get_pixel_font())


## 显示玩家伤害跳字（世界坐标）
func show_player_damage(world_pos: Vector2, amount: float, is_crit: bool, hit_outcome: int, damage_type: int) -> void:
	if hit_outcome == CombatResolver.HitOutcome.MISS:
		_show_text(world_pos, "MISS", COLOR_MISS, FONT_SIZE_MISS, player_pool, false, false)
		return

	var color: Color = COLOR_CRIT if is_crit else DAMAGE_COLORS.get(damage_type, Color.WHITE)
	var font_size: int = FONT_SIZE_PLAYER_CRIT if is_crit else FONT_SIZE_PLAYER

	_show_text(world_pos, "%d" % amount, color, font_size, player_pool, false, false)


## 显示 DOT 伤害跳字（世界坐标，使用怪物池，小字号）
func show_dot_damage(world_pos: Vector2, amount: float) -> void:
	_show_text(world_pos, "%d" % amount, DAMAGE_COLORS[CombatResolver.DamageType.ELEMENTAL_POISON], FONT_SIZE_DOT, monster_pool, false, false, _get_pixel_font())


## 显示治疗跳字（世界坐标）
func show_heal(world_pos: Vector2, amount: float, is_player: bool) -> void:
	var pool = player_pool if is_player else monster_pool
	_show_text(world_pos, "+%d" % amount, COLOR_HEAL, FONT_SIZE_HEAL, pool, false, true)


## 显示 MISS 跳字（世界坐标）
func show_miss(world_pos: Vector2, is_player: bool) -> void:
	var pool = player_pool if is_player else monster_pool
	_show_text(world_pos, "MISS", COLOR_MISS, FONT_SIZE_MISS, pool, false, false)


## 核心方法：坐标转换 → 池获取 → 播放动画
func _show_text(world_pos: Vector2, text: String, color: Color, font_size: int,
		pool, is_monster_bounce: bool, is_heal: bool, pixel_font = null) -> void:

	var camera := get_viewport().get_camera_2d()
	if not camera:
		return

	var head_pos := world_pos - Vector2(0, HEAD_OFFSET_Y)
	var screen_pos := camera.get_canvas_transform() * head_pos
	if screen_pos.y < -50 or screen_pos.y > 1050 or screen_pos.x < -100 or screen_pos.x > 700:
		return  # 屏幕外裁剪

	var node = pool.acquire()
	node.position = screen_pos
	node.setup(text, color, font_size, pixel_font)

	var release := func(): pool.release(node)

	if is_heal:
		node.play_heal_animation(release)
	elif is_monster_bounce:
		node.play_monster_animation(release)
	else:
		node.play_player_animation(release)


## 清空所有跳字
func clear_all() -> void:
	monster_pool.release_all()
	player_pool.release_all()
