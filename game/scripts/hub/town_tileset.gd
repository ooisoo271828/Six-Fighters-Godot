class_name TownTileset
extends RefCounted

## 小镇瓦片纹理生成器 — 代码生成 32x32 瓦片并创建 TileSet

const TILE_SIZE := 32

# 瓦片类型枚举
enum Tile {
	GRASS,
	GRASS_DARK,
	DIRT_ROAD,
	STONE_WALL,
	WOOD_FLOOR,
	TREE_TRUNK,
	TREE_CROWN,
	FLOWER,
	WATER,
	ROOF_BROWN,
	ROOF_RED,
	DOOR,
	PLANK,
}

# 颜色定义
const COLORS := {
	Tile.GRASS: Color(0.22, 0.35, 0.18),
	Tile.GRASS_DARK: Color(0.18, 0.28, 0.15),
	Tile.DIRT_ROAD: Color(0.42, 0.36, 0.28),
	Tile.STONE_WALL: Color(0.45, 0.42, 0.40),
	Tile.WOOD_FLOOR: Color(0.50, 0.38, 0.25),
	Tile.TREE_TRUNK: Color(0.40, 0.30, 0.20),
	Tile.TREE_CROWN: Color(0.15, 0.40, 0.15),
	Tile.FLOWER: Color(0.85, 0.45, 0.55),
	Tile.WATER: Color(0.25, 0.40, 0.65),
	Tile.ROOF_BROWN: Color(0.45, 0.30, 0.18),
	Tile.ROOF_RED: Color(0.55, 0.22, 0.18),
	Tile.DOOR: Color(0.35, 0.25, 0.15),
	Tile.PLANK: Color(0.55, 0.42, 0.28),
}

# atlas 中瓦片的排列：每行 8 个瓦片
const ATLAS_COLS := 8
const TILE_COUNT := 13  # Tile 枚举数量

static func generate_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# 计算 atlas 尺寸
	var cols := ATLAS_COLS
	var rows := ceili(float(TILE_COUNT) / cols)
	var atlas_w := cols * TILE_SIZE
	var atlas_h := rows * TILE_SIZE

	# 创建 atlas 图片
	var atlas_img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)

	for tile_type in range(TILE_COUNT):
		var col := tile_type % cols
		var row := tile_type / cols
		var origin := Vector2i(col * TILE_SIZE, row * TILE_SIZE)
		var tile_img := _generate_tile(tile_type)
		atlas_img.blit_rect(tile_img, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), origin)

	var texture := ImageTexture.create_from_image(atlas_img)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# 为每个瓦片创建 atlas 坐标
	for tile_type in range(TILE_COUNT):
		var col := tile_type % cols
		var row := tile_type / cols
		var atlas_coords := Vector2i(col, row)
		source.create_tile(atlas_coords)

	ts.add_source(source, 0)

	return ts

static func _generate_tile(tile_type: int) -> Image:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base_color: Color = COLORS.get(tile_type, Color.MAGENTA)

	# 填充基础色
	img.fill(base_color)

	# 添加细微噪点/纹理变化
	_add_noise(img, base_color, tile_type)

	return img

static func _add_noise(img: Image, base_color: Color, tile_type: int) -> void:
	# 根据瓦片类型添加不同的纹理效果
	match tile_type:
		Tile.GRASS, Tile.GRASS_DARK:
			# 草地：添加随机深色小点模拟草叶
			for i in range(12):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				var shade := base_color.darkened(0.15 + randf() * 0.15)
				img.set_pixel(x, y, shade)
			# 添加几根亮色草叶
			for i in range(5):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				img.set_pixel(x, y, base_color.lightened(0.1))

		Tile.DIRT_ROAD:
			# 泥土路：添加小石子纹理
			for i in range(8):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				img.set_pixel(x, y, base_color.lightened(0.08 + randf() * 0.1))

		Tile.STONE_WALL:
			# 石墙：添加砖缝线条
			for x in range(TILE_SIZE):
				if x % 16 == 0:
					for y in range(TILE_SIZE):
						img.set_pixel(x, y, base_color.darkened(0.2))
			for y in range(0, TILE_SIZE, 16):
				for x in range(TILE_SIZE):
					img.set_pixel(x, y, base_color.darkened(0.2))

		Tile.WOOD_FLOOR, Tile.PLANK:
			# 木地板：添加木纹横线
			for y in range(0, TILE_SIZE, 8):
				for x in range(TILE_SIZE):
					var shade := base_color.darkened(0.08) if y % 16 == 0 else base_color
					img.set_pixel(x, y, shade)

		Tile.TREE_CROWN:
			# 树冠：添加深色纹理
			for i in range(20):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				img.set_pixel(x, y, base_color.darkened(0.2 + randf() * 0.15))

		Tile.ROOF_BROWN, Tile.ROOF_RED:
			# 屋顶：添加瓦片纹理线条
			for y in range(0, TILE_SIZE, 8):
				for x in range(TILE_SIZE):
					img.set_pixel(x, y, base_color.darkened(0.15))
			for x in range(0, TILE_SIZE, 16):
				for y in range(TILE_SIZE):
					img.set_pixel(x, y, base_color.darkened(0.1))

		Tile.FLOWER:
			# 花朵：基础草地上添加彩色点
			img.fill(COLORS[Tile.GRASS])
			for i in range(4):
				var x := 8 + randi() % 16
				var y := 8 + randi() % 16
				var flower_colors := [Color(0.9, 0.3, 0.3), Color(0.9, 0.8, 0.2), Color(0.8, 0.4, 0.8)]
				img.set_pixel(x, y, flower_colors[randi() % flower_colors.size()])

		Tile.WATER:
			# 水面：添加波纹
			for y in range(TILE_SIZE):
				for x in range(TILE_SIZE):
					if (x + y * 3) % 12 == 0:
						img.set_pixel(x, y, base_color.lightened(0.12))

		Tile.DOOR:
			# 门：添加木板纹理
			for y in range(0, TILE_SIZE, 6):
				for x in range(TILE_SIZE):
					img.set_pixel(x, y, base_color.darkened(0.15))
			# 门把手
			img.set_pixel(22, 16, Color(0.7, 0.6, 0.2))
			img.set_pixel(23, 16, Color(0.7, 0.6, 0.2))
