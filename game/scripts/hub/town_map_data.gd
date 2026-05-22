class_name TownMapData
extends RefCounted

## 小镇地图布局数据 — 定义建筑、道路、装饰物、传送门位置
## 坐标系：瓦片坐标 (tile_x, tile_y)，原点在地图左上角
## 地图尺寸：30 x 40 瓦片（960 x 1280 像素）

const MAP_WIDTH := 30   # 瓦片数
const MAP_HEIGHT := 40  # 瓦片数

# ── 传送门位置（世界坐标） ──
const PORTAL_TILE := Vector2i(15, 20)
const PORTAL_POSITION := Vector2(15 * 32 + 16, 20 * 32 + 16)  # 瓦片中心的世界坐标
const PORTAL_INTERACT_RADIUS := 64.0

# ── 英雄出生点（世界坐标） ──
const HERO_SPAWN := Vector2(15 * 32, 22 * 32)

# ── 建筑定义 ──
# 每个建筑：{ "name": String, "rect": Rect2i (瓦片坐标), "roof_color": int }
# rect = Rect2i(tile_x, tile_y, width_in_tiles, height_in_tiles)

const BUILDINGS := [
	{
		"name": "英雄大厅",
		"rect": Rect2i(10, 4, 10, 7),   # x=10, y=4, w=10, h=7
		"wall_tile": TownTileset.Tile.STONE_WALL,
		"floor_tile": TownTileset.Tile.WOOD_FLOOR,
		"roof_tile": TownTileset.Tile.ROOF_RED,
		"door_pos": Vector2i(15, 10),     # 门口位置
	},
	{
		"name": "西商店",
		"rect": Rect2i(2, 16, 5, 4),
		"wall_tile": TownTileset.Tile.STONE_WALL,
		"floor_tile": TownTileset.Tile.WOOD_FLOOR,
		"roof_tile": TownTileset.Tile.ROOF_BROWN,
		"door_pos": Vector2i(4, 19),
	},
	{
		"name": "东商店",
		"rect": Rect2i(23, 16, 5, 4),
		"wall_tile": TownTileset.Tile.STONE_WALL,
		"floor_tile": TownTileset.Tile.WOOD_FLOOR,
		"roof_tile": TownTileset.Tile.ROOF_BROWN,
		"door_pos": Vector2i(25, 19),
	},
	{
		"name": "训练场",
		"rect": Rect2i(3, 28, 6, 5),
		"wall_tile": TownTileset.Tile.STONE_WALL,
		"floor_tile": TownTileset.Tile.PLANK,
		"roof_tile": TownTileset.Tile.ROOF_BROWN,
		"door_pos": Vector2i(6, 32),
	},
	{
		"name": "仓库",
		"rect": Rect2i(21, 28, 6, 5),
		"wall_tile": TownTileset.Tile.STONE_WALL,
		"floor_tile": TownTileset.Tile.WOOD_FLOOR,
		"roof_tile": TownTileset.Tile.ROOF_BROWN,
		"door_pos": Vector2i(24, 32),
	},
]

# ── 道路定义 ──
# 每条道路是一系列连续的瓦片坐标段
# 格式：[起点, 终点]（水平或垂直）

const ROAD_SEGMENTS := [
	# 中央南北大道
	{"from": Vector2i(14, 11), "to": Vector2i(16, 35)},
	# 英雄大厅到西商店
	{"from": Vector2i(7, 18), "to": Vector2i(14, 18)},
	# 英雄大厅到东商店
	{"from": Vector2i(16, 18), "to": Vector2i(23, 18)},
	# 中央东西横路
	{"from": Vector2i(7, 20), "to": Vector2i(23, 20)},
	# 通往训练场
	{"from": Vector2i(9, 20), "to": Vector2i(9, 30)},
	# 通往仓库
	{"from": Vector2i(21, 20), "to": Vector2i(21, 30)},
]

# ── 装饰物定义 ──
# 格式：{ "pos": Vector2i, "tile": TownTileset.Tile }

const DECORATIONS := [
	# 城镇边缘树木（围挡）
	# 北墙
	{"pos": Vector2i(0, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(1, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(2, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(3, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(4, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(5, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(6, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(7, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(8, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(9, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(20, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(21, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(22, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(23, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(24, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(25, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(26, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(27, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(28, 0), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 0), "tile": TownTileset.Tile.TREE_CROWN},
	# 南墙
	{"pos": Vector2i(0, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(1, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(2, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(3, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(4, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(5, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(6, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(7, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(8, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(9, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(10, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(11, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(12, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(13, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(14, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(15, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(16, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(17, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(18, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(19, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(20, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(21, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(22, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(23, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(24, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(25, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(26, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(27, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(28, 39), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 39), "tile": TownTileset.Tile.TREE_CROWN},
	# 西墙
	{"pos": Vector2i(0, 1), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 2), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 3), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 4), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 5), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 6), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 7), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 8), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 9), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 10), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 11), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 12), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 13), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 14), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 15), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 16), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 17), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 18), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 19), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 20), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 21), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 22), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 23), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 24), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 25), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 26), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 27), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 28), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 29), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 30), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 31), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 32), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 33), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 34), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 35), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 36), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 37), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(0, 38), "tile": TownTileset.Tile.TREE_CROWN},
	# 东墙
	{"pos": Vector2i(29, 1), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 2), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 3), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 4), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 5), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 6), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 7), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 8), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 9), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 10), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 11), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 12), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 13), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 14), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 15), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 16), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 17), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 18), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 19), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 20), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 21), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 22), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 23), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 24), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 25), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 26), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 27), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 28), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 29), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 30), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 31), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 32), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 33), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 34), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 35), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 36), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 37), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(29, 38), "tile": TownTileset.Tile.TREE_CROWN},

	# 内部装饰：花丛、木桶等
	{"pos": Vector2i(8, 5), "tile": TownTileset.Tile.FLOWER},
	{"pos": Vector2i(21, 5), "tile": TownTileset.Tile.FLOWER},
	{"pos": Vector2i(5, 14), "tile": TownTileset.Tile.FLOWER},
	{"pos": Vector2i(24, 14), "tile": TownTileset.Tile.FLOWER},
	{"pos": Vector2i(12, 24), "tile": TownTileset.Tile.FLOWER},
	{"pos": Vector2i(18, 24), "tile": TownTileset.Tile.FLOWER},
	{"pos": Vector2i(5, 35), "tile": TownTileset.Tile.FLOWER},
	{"pos": Vector2i(25, 35), "tile": TownTileset.Tile.FLOWER},

	# 内部点缀树木
	{"pos": Vector2i(2, 12), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(27, 12), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(2, 24), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(27, 24), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(12, 36), "tile": TownTileset.Tile.TREE_CROWN},
	{"pos": Vector2i(18, 36), "tile": TownTileset.Tile.TREE_CROWN},
]

# ── 碰撞体定义（建筑墙壁，不含门口） ──
# 返回每个建筑需要生成的碰撞矩形列表
# 每个碰撞矩形为 { "position": Vector2 (世界坐标中心), "size": Vector2 (世界尺寸) }

static func get_building_colliders() -> Array:
	var colliders := []
	for building in BUILDINGS:
		var rect: Rect2i = building["rect"]
		var door: Vector2i = building["door_pos"]
		# 门宽 2 瓦片，将墙壁分为上下两段
		var door_x := door.x
		# 上墙（门以上）
		var top_h := door.y - rect.position.y
		if top_h > 0:
			var pos := Vector2(
				(rect.position.x + rect.size.x / 2.0) * TownTileset.TILE_SIZE,
				(rect.position.y + top_h / 2.0) * TownTileset.TILE_SIZE
			)
			var size := Vector2(rect.size.x * TownTileset.TILE_SIZE, top_h * TownTileset.TILE_SIZE)
			colliders.append({"position": pos, "size": size})
		# 下墙左段
		var left_w := door_x - rect.position.x
		if left_w > 0:
			var wall_h := rect.size.y - top_h
			var pos := Vector2(
				(rect.position.x + left_w / 2.0) * TownTileset.TILE_SIZE,
				(door.y + wall_h / 2.0) * TownTileset.TILE_SIZE
			)
			var size := Vector2(left_w * TownTileset.TILE_SIZE, wall_h * TownTileset.TILE_SIZE)
			colliders.append({"position": pos, "size": size})
		# 下墙右段
		var right_x := door_x + 2
		var right_w := rect.position.x + rect.size.x - right_x
		if right_w > 0:
			var wall_h := rect.size.y - top_h
			var pos := Vector2(
				(right_x + right_w / 2.0) * TownTileset.TILE_SIZE,
				(door.y + wall_h / 2.0) * TownTileset.TILE_SIZE
			)
			var size := Vector2(right_w * TownTileset.TILE_SIZE, wall_h * TownTileset.TILE_SIZE)
			colliders.append({"position": pos, "size": size})
	return colliders
