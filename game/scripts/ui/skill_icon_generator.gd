class_name SkillIconGenerator
extends RefCounted

## 占位技能图标生成器
## 根据技能伤害类型生成不同颜色和形状的图标

# 伤害类型对应颜色
const DAMAGE_TYPE_COLORS := {
	0: Color(0.7, 0.7, 0.7),   # PHYSICAL - 灰色
	1: Color(1.0, 0.4, 0.1),   # ELEMENTAL_FIRE - 橙红
	2: Color(0.3, 0.6, 1.0),   # ELEMENTAL_ICE - 蓝色
	3: Color(0.9, 0.9, 0.2),   # ELEMENTAL_LIGHTNING - 黄色
	4: Color(0.4, 0.8, 0.2),   # ELEMENTAL_POISON - 绿色
}

# 大招特殊颜色
const ULTIMATE_COLOR := Color(1.0, 0.85, 0.0)  # 金色

## 生成技能图标 ImageTexture
static func generate(skill_def: SkillDef, is_ultimate: bool = false, size: int = 40) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # 透明背景

	var color: Color
	if is_ultimate:
		color = ULTIMATE_COLOR
	else:
		color = DAMAGE_TYPE_COLORS.get(skill_def.damage_type, Color(0.5, 0.5, 0.5))

	var center := Vector2(size / 2, size / 2)
	var radius := size / 2 - 2

	if is_ultimate:
		_draw_star(img, center, radius, color)
	else:
		match skill_def.damage_type:
			1:  # FIRE - 圆形
				_draw_circle(img, center, radius, color)
			2:  # ICE - 菱形
				_draw_diamond(img, center, radius, color)
			_:  # 其他 - 圆角方块
				_draw_rounded_rect(img, center, radius, color)

	# 绘制边框
	_draw_border(img, size, color.darkened(0.3))

	return ImageTexture.create_from_image(img)

## 生成大招图标（带怒气进度）
static func generate_ultimate(skill_def: SkillDef, size: int = 40) -> ImageTexture:
	return generate(skill_def, true, size)

# ── 绘制工具方法 ──

static func _draw_circle(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var size := img.get_width()
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius:
				var t := dist / radius
				var pixel_color := color.lightened(0.2 * (1.0 - t))
				pixel_color.a = 1.0
				img.set_pixel(x, y, pixel_color)

static func _draw_diamond(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var size := img.get_width()
	for y in range(size):
		for x in range(size):
			var dx := absf(x - center.x)
			var dy := absf(y - center.y)
			if dx + dy <= radius:
				var t := (dx + dy) / radius
				var pixel_color := color.lightened(0.2 * (1.0 - t))
				pixel_color.a = 1.0
				img.set_pixel(x, y, pixel_color)

static func _draw_rounded_rect(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var size := img.get_width()
	var half := radius * 0.8
	var corner_r := radius * 0.3
	for y in range(size):
		for x in range(size):
			var dx := absf(x - center.x)
			var dy := absf(y - center.y)
			var inside := false
			if dx <= half and dy <= half:
				inside = true
			elif dx > half and dy > half:
				var corner_dist := Vector2(dx - half, dy - half).length()
				inside = corner_dist <= corner_r
			elif dx > half:
				inside = dx <= half + corner_r
			else:
				inside = dy <= half + corner_r
			if inside:
				var t := maxf(dx, dy) / radius
				var pixel_color := color.lightened(0.2 * (1.0 - t))
				pixel_color.a = 1.0
				img.set_pixel(x, y, pixel_color)

static func _draw_star(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var size := img.get_width()
	var inner_radius := radius * 0.45
	var points := 5
	for y in range(size):
		for x in range(size):
			var pos := Vector2(x, y) - center
			var dist := pos.length()
			if dist > radius:
				continue
			var angle := atan2(pos.y, pos.x)
			# 计算星形边界
			var segment := fmod(angle + PI, TAU) / TAU * points
			var segment_angle := fmod(segment, 1.0) * TAU / points
			var star_radius := lerpf(radius, inner_radius, absf(segment_angle - PI / points) / (PI / points))
			if dist <= star_radius:
				var t := dist / star_radius
				var pixel_color := color.lightened(0.3 * (1.0 - t))
				pixel_color.a = 1.0
				img.set_pixel(x, y, pixel_color)

static func _draw_border(img: Image, size: int, color: Color) -> void:
	for x in range(size):
		if img.get_pixel(x, 0).a > 0.1:
			img.set_pixel(x, 0, color)
		if img.get_pixel(x, size - 1).a > 0.1:
			img.set_pixel(x, size - 1, color)
	for y in range(size):
		if img.get_pixel(0, y).a > 0.1:
			img.set_pixel(0, y, color)
		if img.get_pixel(size - 1, y).a > 0.1:
			img.set_pixel(size - 1, y, color)
