class_name SkillIcon
extends Control

## 技能图标组件
## 显示技能图标 + 扇形CD遮罩

const ICON_SIZE := 20

var _icon_texture: TextureRect
var _cd_label: Label
var _cd_ratio: float = 0.0  # 0.0 = 可用, 1.0 = 完全冷却中
var _is_ultimate: bool = false
var _is_available: bool = true

func _init() -> void:
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	size = Vector2(ICON_SIZE, ICON_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	# 图标纹理
	_icon_texture = TextureRect.new()
	_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_texture.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_texture.size = Vector2(ICON_SIZE, ICON_SIZE)
	add_child(_icon_texture)

	# CD数字标签（居中）
	_cd_label = Label.new()
	_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cd_label.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_cd_label.size = Vector2(ICON_SIZE, ICON_SIZE)
	_cd_label.add_theme_font_size_override("font_size", 9)
	_cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_cd_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_cd_label.add_theme_constant_override("shadow_offset_x", 1)
	_cd_label.add_theme_constant_override("shadow_offset_y", 1)
	_cd_label.visible = false
	add_child(_cd_label)

## 设置技能图标纹理
func set_icon(texture: Texture2D) -> void:
	if _icon_texture:
		_icon_texture.texture = texture

## 设置是否为大招
func set_ultimate(ultimate: bool) -> void:
	_is_ultimate = ultimate

## 更新CD状态
## ratio: 0.0=可用, 1.0=完全冷却中
## remaining_sec: 剩余秒数（用于显示数字）
func update_cd(ratio: float, remaining_sec: float = 0.0) -> void:
	var was_available := _is_available
	_cd_ratio = clampf(ratio, 0.0, 1.0)
	_is_available = ratio <= 0.0

	# CD数字显示
	if _is_available:
		_cd_label.visible = false
	else:
		_cd_label.visible = true
		if remaining_sec > 0:
			_cd_label.text = "%.1f" % remaining_sec if remaining_sec < 10 else "%d" % ceili(remaining_sec)
		else:
			_cd_label.text = ""

	queue_redraw()

func _draw() -> void:
	if _cd_ratio <= 0.0:
		# 可用状态 - 大招加金色光晕
		if _is_ultimate:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.85, 0, 0.15))
		return

	# 绘制扇形CD遮罩
	var center := size / 2.0
	var radius := ICON_SIZE / 2.0

	var points := PackedVector2Array()
	points.append(center)

	# 从12点钟方向顺时针
	var segments := 32
	var sweep_angle := _cd_ratio * TAU
	for i in range(segments + 1):
		var angle := -PI / 2.0 + (float(i) / segments) * sweep_angle
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	# 半透明黑色遮罩
	draw_colored_polygon(points, Color(0, 0, 0, 0.55))

	# 边框指示CD进度
	var border_color := Color(0.3, 0.3, 0.3, 0.8) if not _is_ultimate else Color(0.8, 0.6, 0.0, 0.8)
	var arc_points := PackedVector2Array()
	for i in range(segments + 1):
		var angle := -PI / 2.0 + (float(i) / segments) * sweep_angle
		arc_points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if arc_points.size() >= 2:
		draw_polyline(arc_points, border_color, 1.5)
