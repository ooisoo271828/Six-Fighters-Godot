class_name ArenaMapData
extends RefCounted

## 熔岩洞穴竞技场地图布局数据
## 坐标系：瓦片坐标 (tx, ty)，原点在地图左上角
## y 增加方向为向下（Godot 标准），玩家从底部入口向上行进

const TILE_SIZE := 32

# 地图尺寸（瓦片数）
const MAP_WIDTH := 60
const MAP_HEIGHT := 270

# 走廊半宽（瓦片数），全宽约 30 瓦片 = 960px ≈ 1.78 屏幕宽度
const CORRIDOR_HALF_WIDTH := 15

# Boss 区参数（瓦片坐标）
const BOSS_CENTER := Vector2i(30, 32)
const BOSS_RADIUS := 30  # 瓦片数，直径 60 = 1920px = 2×屏幕高度

# ── 蛇形走廊路径点（瓦片坐标） ──
# 玩家从底部 (ty=MAP_HEIGHT-5) 进入，沿路径向上走到 Boss 区
const CORRIDOR_WAYPOINTS: Array[Vector2i] = [
	Vector2i(30, 265),  # 入口
	Vector2i(30, 235),  # 直上
	Vector2i(18, 210),  # 左弯
	Vector2i(18, 180),  # 直上
	Vector2i(38, 155),  # 右弯
	Vector2i(38, 125),  # 直上
	Vector2i(20, 100),  # 左弯
	Vector2i(20, 70),   # 直上
	Vector2i(35, 52),   # 右弯进入 Boss 区
	Vector2i(30, 47),   # Boss区入口过渡
]

# ── 走廊波次配置 ──
# [{ "y_trigger": int, "count": int, "has_elite": bool }]
const CORRIDOR_WAVES: Array[Dictionary] = [
	{ "y_trigger": 205, "count": 3, "has_elite": false },
	{ "y_trigger": 125, "count": 4, "has_elite": false },
	{ "y_trigger": 75,  "count": 5, "has_elite": false },
	{ "y_trigger": 55,  "count": 6, "has_elite": true  },
]

# Boss 战参数
const BOSS_TRIGGER_DIST := 250.0    # 玩家距 Boss 区中心多远触发（世界坐标）
const BOSS_COUNTDOWN_SEC := 5.0     # 倒计时秒数
const BOSS_WAVE_BASE_COUNT := 8     # 第一波 Boss 战基础数量
const BOSS_WAVE_TIMEOUT := 30.0     # 每波超时时间（秒）
const BOSS_WAVE_DEATH_RATIO := 0.9  # 前一波死亡比例触发条件

# ── 运行时：可通行区域网格 ──
# 0 = 不可通行（熔岩/墙壁），1 = 可通行（走廊/Boss地面）
var _grid: PackedByteArray
var _grid_initialized := false

# ── 边噪点偏移缓存（每行一个，用于不规则边缘） ──
var _edge_noise: Dictionary  # ty → { "left_offset": int, "right_offset": int }

func _init() -> void:
	_build_grid()

# ══════════════════════════════════════════
#  公开接口
# ══════════════════════════════════════════

## 检查世界坐标是否可通行
func is_walkable(world_x: float, world_y: float) -> bool:
	var tx := int(floorf(world_x / TILE_SIZE))
	var ty := int(floorf(world_y / TILE_SIZE))
	return _is_tile_walkable(tx, ty)

## 将世界坐标限制到最近的可通行区域
func clamp_to_walkable(pos: Vector2) -> Vector2:
	if is_walkable(pos.x, pos.y):
		return pos

	# 螺旋搜索最近的可通行瓦片
	var tx := int(floorf(pos.x / TILE_SIZE))
	var ty := int(floorf(pos.y / TILE_SIZE))

	for radius in range(1, 20):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) == radius or abs(dy) == radius:
					var nx: int = tx + dx
					var ny: int = ty + dy
					if _is_tile_walkable(nx, ny):
						return Vector2(
							nx * TILE_SIZE + TILE_SIZE / 2.0,
							ny * TILE_SIZE + TILE_SIZE / 2.0
						)
	return pos

## 获取入口世界坐标
func get_entry_world_position() -> Vector2:
	var wp := CORRIDOR_WAYPOINTS[0]
	return Vector2(wp.x * TILE_SIZE + TILE_SIZE / 2.0, wp.y * TILE_SIZE + TILE_SIZE / 2.0)

## 获取 Boss 区中心世界坐标
func get_boss_center_world() -> Vector2:
	return Vector2(
		BOSS_CENTER.x * TILE_SIZE + TILE_SIZE / 2.0,
		BOSS_CENTER.y * TILE_SIZE + TILE_SIZE / 2.0
	)

## 检查玩家坐标是否在 Boss 触发区域
func is_in_boss_trigger(world_pos: Vector2) -> bool:
	var boss_center := get_boss_center_world()
	return world_pos.distance_to(boss_center) < BOSS_TRIGGER_DIST

## 获取走廊波次配置的只读副本
func get_corridor_waves() -> Array[Dictionary]:
	return CORRIDOR_WAVES.duplicate(true)

## 检查某瓦片是否属于 Boss 区域
func is_boss_area(tx: int, ty: int) -> bool:
	var dx := tx - BOSS_CENTER.x
	var dy := ty - BOSS_CENTER.y
	return dx * dx + dy * dy <= BOSS_RADIUS * BOSS_RADIUS

## 获取指定瓦片应使用的纹理类型（用于 TileMap 渲染）
func get_tile_type(tx: int, ty: int) -> int:
	if not _within_bounds(tx, ty):
		return -1

	var idx := ty * MAP_WIDTH + tx
	if idx < 0 or idx >= _grid.size():
		return -1

	if _grid[idx] == 0:
		# 不可通行区域：熔岩海 / 墙壁
		if tx <= 2 or tx >= MAP_WIDTH - 3 or ty <= 2 or ty >= MAP_HEIGHT - 3:
			return ArenaTileset.Tile.STONE_WALL
		# 随机放置装饰物
		var hash_val := (tx * 31 + ty * 17) % 100
		if hash_val < 3:
			return ArenaTileset.Tile.ROCK
		elif hash_val < 6:
			return ArenaTileset.Tile.LAVA_BUBBLE
		elif hash_val < 10:
			return ArenaTileset.Tile.LAVA_SEA_BRIGHT
		return ArenaTileset.Tile.LAVA_SEA

	# 可通行区域
	var is_border := _is_border_tile(tx, ty)
	if is_border:
		return ArenaTileset.Tile.BORDER_LINE

	if is_boss_area(tx, ty):
		if (tx + ty) % 3 == 0:
			return ArenaTileset.Tile.BOSS_FLOOR_DARK
		return ArenaTileset.Tile.BOSS_FLOOR

	# 走廊地面
	if (tx + ty) % 4 == 0:
		return ArenaTileset.Tile.LAVA_FLOOR_DARK
	return ArenaTileset.Tile.LAVA_FLOOR

## 预计算的地图数据批量填充
## 返回 Array[Dictionary] 每项: { "tile": int, "coords": Vector2i }
func get_all_tile_placements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ty in range(MAP_HEIGHT):
		for tx in range(MAP_WIDTH):
			var tile_type := get_tile_type(tx, ty)
			if tile_type >= 0:
				result.append({ "tile": tile_type, "coords": Vector2i(tx, ty) })
	return result

# ══════════════════════════════════════════
#  内部：可通行网格构建
# ══════════════════════════════════════════

func _build_grid() -> void:
	_grid = PackedByteArray()
	_grid.resize(MAP_WIDTH * MAP_HEIGHT)
	_grid.fill(0)

	# 1. 沿路径点构建走廊
	_build_corridor()

	# 2. 构建 Boss 区
	_build_boss_area()

	# 3. 走廊到 Boss 区连接过渡
	_build_transition()

	_grid_initialized = true

func _build_corridor() -> void:
	for seg_idx in range(CORRIDOR_WAYPOINTS.size() - 1):
		var a := CORRIDOR_WAYPOINTS[seg_idx]
		var b := CORRIDOR_WAYPOINTS[seg_idx + 1]
		_draw_thick_line(a, b, CORRIDOR_HALF_WIDTH)

func _draw_thick_line(from: Vector2i, to: Vector2i, half_w: int) -> void:
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx - dy

	var cx := from.x
	var cy := from.y

	while true:
		# 在此位置绘制宽度为 half_w 的水平线段
		var noise_offset := _get_edge_noise(cy)
		var actual_hw := half_w + noise_offset
		for wx in range(-actual_hw, actual_hw + 1):
			_set_walkable(cx + wx, cy)

		if cx == to.x and cy == to.y:
			break

		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			cx += sx
		if e2 < dx:
			err += dx
			cy += sy

## 每行边缘不规则偏移（-3 到 +3 瓦片）
func _get_edge_noise(ty: int) -> int:
	if _edge_noise.has(ty):
		return _edge_noise[ty]
	# 用伪随机产生每行的不规则偏移，同一 ty 值结果一致
	var h := ty * 374761393 + 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var offset := (h % 7) - 3  # -3 ~ +3
	_edge_noise[ty] = offset
	return offset

func _build_boss_area() -> void:
	var cx := BOSS_CENTER.x
	var cy := BOSS_CENTER.y
	var base_r := BOSS_RADIUS

	for ty in range(cy - base_r - 5, cy + base_r + 6):
		for tx in range(cx - base_r - 5, cx + base_r + 6):
			if not _within_bounds(tx, ty):
				continue
			var dx := tx - cx
			var dy := ty - cy
			var dist := sqrt(float(dx * dx + dy * dy))

			# 角度相关的不规则偏移
			var angle := atan2(float(dy), float(dx))
			var angle_hash := int(angle * 10) % 7 - 3  # -3 ~ +3
			var effective_r := base_r + angle_hash * 2

			if dist < effective_r:
				_set_walkable(tx, ty)
			elif dist < effective_r + 2:
				if _is_near_walkable(tx, ty):
					_set_walkable(tx, ty)

func _build_transition() -> void:
	# 在走廊末端与 Boss 区底部之间填充过渡区域
	var last_wp := CORRIDOR_WAYPOINTS[CORRIDOR_WAYPOINTS.size() - 1]
	var boss_top := BOSS_CENTER.y - BOSS_RADIUS

	for ty in range(last_wp.y, maxi(boss_top, 0)):
		for tx in range(maxi(0, last_wp.x - CORRIDOR_HALF_WIDTH - 2), mini(MAP_WIDTH, last_wp.x + CORRIDOR_HALF_WIDTH + 3)):
			if _within_bounds(tx, ty) and _is_tile_walkable(tx, ty) == false:
				if _is_near_walkable(tx, ty) or _is_near_boss(tx, ty):
					_set_walkable(tx, ty)

## 检查某瓦片相邻是否有人可通行瓦片
func _is_near_walkable(tx: int, ty: int) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = tx + dx
			var ny: int = ty + dy
			if _within_bounds(nx, ny) and _is_tile_walkable(nx, ny):
				return true
	return false

func _is_near_boss(tx: int, ty: int) -> bool:
	var dx := tx - BOSS_CENTER.x
	var dy := ty - BOSS_CENTER.y
	return sqrt(float(dx * dx + dy * dy)) <= BOSS_RADIUS + 3

func _is_border_tile(tx: int, ty: int) -> bool:
	# 检查该可通行瓦片是否处于可通行区域的边缘（相邻有不可通行瓦片）
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = tx + dx
			var ny: int = ty + dy
			if not _within_bounds(nx, ny):
				return true
			if not _is_tile_walkable(nx, ny):
				return true
	return false

func _is_tile_walkable(tx: int, ty: int) -> bool:
	if not _within_bounds(tx, ty):
		return false
	var idx := ty * MAP_WIDTH + tx
	return _grid[idx] == 1

func _set_walkable(tx: int, ty: int) -> void:
	if not _within_bounds(tx, ty):
		return
	var idx := ty * MAP_WIDTH + tx
	_grid[idx] = 1

func _within_bounds(tx: int, ty: int) -> bool:
	return tx >= 0 and tx < MAP_WIDTH and ty >= 0 and ty < MAP_HEIGHT
