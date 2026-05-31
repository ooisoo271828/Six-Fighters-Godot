class_name PortraitGenerator
extends RefCounted

## 占位头像生成器
## 程序生成带颜色和首字的头像，后续替换为正式立绘

# 英雄配色方案（与角色modulate颜色一致）
const HERO_COLORS := {
	"ironwall": Color(0.44, 0.44, 0.88),  # 蓝色 - 前排
	"ember": Color(1.0, 0.63, 0.31),      # 橙色 - 输出
	"moss": Color(0.31, 0.75, 0.38),      # 绿色 - 辅助
}

# 英雄首字
const HERO_INITIALS := {
	"ironwall": "铁",
	"ember": "烬",
	"moss": "苔",
}

## 生成占位头像 ImageTexture
static func generate(hero_id: String, size: int = 80) -> ImageTexture:
	var color: Color = HERO_COLORS.get(hero_id, Color(0.5, 0.5, 0.5))
	var initial: String = HERO_INITIALS.get(hero_id, "?")

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)

	# 填充背景色
	img.fill(color)

	# 绘制边框（深色描边）
	var border_color := color.darkened(0.3)
	for x in range(size):
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, size - 1, border_color)
	for y in range(size):
		img.set_pixel(0, y, border_color)
		img.set_pixel(size - 1, y, border_color)

	# 绘制内圈高光（模拟圆形头像感）
	var center := Vector2(size / 2, size / 2)
	var radius := size / 2 - 2
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			if dist < radius:
				var t := dist / radius
				var highlight := color.lightened(0.15 * (1.0 - t))
				img.set_pixel(x, y, highlight)

	return ImageTexture.create_from_image(img)

## 生成带文字的头像（需要Font资源）
## 暂不使用，因为需要加载字体
static func generate_with_text(hero_id: String, font: Font, size: int = 80) -> ImageTexture:
	var base_img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var color: Color = HERO_COLORS.get(hero_id, Color(0.5, 0.5, 0.5))
	base_img.fill(color)

	# 使用 Image 绘制文字比较复杂，这里先返回纯色头像
	# 文字绘制留给 UI 层的 Label 叠加
	return ImageTexture.create_from_image(base_img)
