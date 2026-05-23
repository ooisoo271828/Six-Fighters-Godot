class_name ArenaTileset
extends RefCounted

## 熔岩洞穴竞技场瓦片生成器 — 代码生成 32x32 瓦片并创建 TileSet

const TILE_SIZE := 32

enum Tile {
	LAVA_FLOOR,       # 0 熔岩地面（可行走）
	LAVA_FLOOR_DARK,  # 1 深色熔岩地面
	STONE_WALL,       # 2 石壁
	BOSS_FLOOR,       # 3 Boss区地面
	BOSS_FLOOR_DARK,  # 4 Boss区深色地面
	LAVA_SEA,         # 5 熔岩海
	LAVA_SEA_BRIGHT,  # 6 熔岩海高光
	BORDER_LINE,      # 7 边界线（岩浆平台边缘）
	ROCK,             # 8 碎石
	LAVA_BUBBLE,       # 9 熔岩气泡
	WALL_DECO,        # 10 石壁装饰
}

const COLORS := {
	Tile.LAVA_FLOOR: Color(0.23, 0.04, 0.04),
	Tile.LAVA_FLOOR_DARK: Color(0.16, 0.02, 0.02),
	Tile.STONE_WALL: Color(0.16, 0.16, 0.18),
	Tile.BOSS_FLOOR: Color(0.29, 0.04, 0.04),
	Tile.BOSS_FLOOR_DARK: Color(0.20, 0.03, 0.03),
	Tile.LAVA_SEA: Color(0.54, 0.10, 0.04),
	Tile.LAVA_SEA_BRIGHT: Color(0.80, 0.20, 0.02),
	Tile.BORDER_LINE: Color(0.33, 0.20, 0.13),
	Tile.ROCK: Color(0.18, 0.18, 0.18),
	Tile.LAVA_BUBBLE: Color(0.90, 0.55, 0.05),
	Tile.WALL_DECO: Color(0.13, 0.13, 0.15),
}

const ATLAS_COLS := 8
const TILE_COUNT := 11

static func generate_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var cols := ATLAS_COLS
	var rows := ceili(float(TILE_COUNT) / cols)
	var atlas_w := cols * TILE_SIZE
	var atlas_h := rows * TILE_SIZE

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
	img.fill(base_color)
	_add_texture(img, base_color, tile_type)
	return img

static func _add_texture(img: Image, base_color: Color, tile_type: int) -> void:
	match tile_type:
		Tile.LAVA_FLOOR, Tile.LAVA_FLOOR_DARK:
			# 熔岩地面：暗色裂缝
			for i in range(10):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				img.set_pixel(x, y, base_color.lightened(0.08 + randf() * 0.12))
			# 裂纹线条
			for i in range(3):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				for j in range(6):
					var px := clampi(x + j, 0, TILE_SIZE - 1)
					var py := clampi(y + (j % 3) - 1, 0, TILE_SIZE - 1)
					img.set_pixel(px, py, base_color.darkened(0.15))
			# 微小红光
			for i in range(4):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				img.set_pixel(x, y, Color(0.6, 0.1, 0.05))

		Tile.STONE_WALL, Tile.WALL_DECO:
			# 石壁：砖纹
			for x in range(TILE_SIZE):
				if x % 16 == 0:
					for y in range(TILE_SIZE):
						img.set_pixel(x, y, base_color.darkened(0.2))
			for y in range(0, TILE_SIZE, 16):
				for x in range(TILE_SIZE):
					img.set_pixel(x, y, base_color.darkened(0.2))
			if tile_type == Tile.WALL_DECO:
				for i in range(6):
					var x := randi() % TILE_SIZE
					var y := randi() % TILE_SIZE
					img.set_pixel(x, y, base_color.lightened(0.1))

		Tile.BOSS_FLOOR, Tile.BOSS_FLOOR_DARK:
			# Boss地面：熔岩地面加强版，有符文感
			for i in range(15):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				img.set_pixel(x, y, base_color.lightened(0.1 + randf() * 0.12))
			# 红色纹路
			for i in range(4):
				var x := randi() % TILE_SIZE
				var y := randi() % TILE_SIZE
				for j in range(8):
					var px := clampi(x + (j % 3) - 1, 0, TILE_SIZE - 1)
					var py := clampi(y + j / 2, 0, TILE_SIZE - 1)
					img.set_pixel(px, py, Color(0.5, 0.08, 0.06))

		Tile.LAVA_SEA:
			# 熔岩海：红色/橙色波纹
			for y in range(TILE_SIZE):
				for x in range(TILE_SIZE):
					if (x * 7 + y * 13) % 8 == 0:
						img.set_pixel(x, y, base_color.lightened(0.12))
					elif (x * 5 + y * 11) % 12 == 0:
						img.set_pixel(x, y, Color(0.7, 0.15, 0.05))

		Tile.LAVA_SEA_BRIGHT:
			# 熔岩海高光
			for y in range(TILE_SIZE):
				for x in range(TILE_SIZE):
					if (x * 3 + y * 7) % 6 == 0:
						img.set_pixel(x, y, Color(0.9, 0.3, 0.05))
					elif (x * 5 + y * 9) % 10 == 0:
						img.set_pixel(x, y, Color(1.0, 0.5, 0.05))

		Tile.BORDER_LINE:
			# 边界线：暗色岩层边缘
			for y in range(TILE_SIZE):
				for x in range(TILE_SIZE):
					if y < 3:
						img.set_pixel(x, y, Color(0.4, 0.25, 0.12))
					elif y < 6:
						if (x + y) % 3 == 0:
							img.set_pixel(x, y, base_color.lightened(0.08))
			# 横向纹理
			for x in range(TILE_SIZE):
				img.set_pixel(x, 2, Color(0.25, 0.15, 0.08))
				img.set_pixel(x, 5, Color(0.25, 0.15, 0.08))

		Tile.ROCK:
			# 碎石：灰色块状
			for y in range(8, 26):
				for x in range(6, 24):
					var dx := x - 15
					var dy := y - 17
					if dx * dx / 64.0 + dy * dy / 64.0 < 1.0:
						img.set_pixel(x, y, base_color.lightened(0.05 + randf() * 0.08))
			# 边缘暗色
			for y in range(6, 28):
				for x in range(4, 26):
					var dx := x - 15
					var dy := y - 17
					if 0.8 < dx * dx / 64.0 + dy * dy / 64.0 and dx * dx / 64.0 + dy * dy / 64.0 < 1.2:
						img.set_pixel(x, y, base_color.darkened(0.15))

		Tile.LAVA_BUBBLE:
			# 熔岩气泡：橙色圆点
			var cx := 16
			var cy := 16
			var r := 6
			for y in range(TILE_SIZE):
				for x in range(TILE_SIZE):
					var dx := x - cx
					var dy := y - cy
					var dist := sqrt(dx * dx + dy * dy)
					if dist < r:
						img.set_pixel(x, y, Color(0.9, 0.5, 0.05))
				# 亮斑
			for y in range(TILE_SIZE):
				for x in range(TILE_SIZE):
					var dx := x - 14
					var dy := y - 14
					if dx * dx + dy * dy < 4:
						img.set_pixel(x, y, Color(1.0, 0.7, 0.1))
			# 背景熔岩色周围
			var bg := Color(0.54, 0.10, 0.04)
			for y in range(TILE_SIZE):
				for x in range(TILE_SIZE):
					var dx := x - cx
					var dy := y - cy
					var dist := sqrt(dx * dx + dy * dy)
					if dist > r + 1:
						img.set_pixel(x, y, bg)
						if (x * 7 + y * 13) % 8 == 0:
							img.set_pixel(x, y, bg.lightened(0.12))
