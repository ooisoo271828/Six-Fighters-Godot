## DamageTextNode — 单个伤害跳字节点
## 包含 Label + Tween 驱动的弹出/上浮/淡出动画
extends Node2D

var _label: Label
var _tween: Tween


func _init() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(_label)


## 初始化文本和样式
func setup(text: String, color: Color, font_size: int, pixel_font = null) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	if pixel_font:
		_label.add_theme_font_override("font", pixel_font)
	_label.add_theme_font_size_override("font_size", font_size)
	scale = Vector2.ZERO
	modulate = Color.WHITE


## 怪物跳字 — 跳跃动感
func play_monster_animation(release_cb: Callable) -> void:
	var start_y := position.y
	var start_x := position.x

	_tween = create_tween()

	# 相位 1：弹出 overshoot
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "position:x", start_x + randf_range(-15.0, 15.0), 0.15).set_ease(Tween.EASE_OUT)

	# 相位 2：上浮 + 旋转摆动
	_tween.tween_property(self, "position:y", start_y - 80.0, 0.5).set_delay(0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(self, "rotation", randf_range(-0.1, 0.1), 0.2).set_delay(0.1).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", 0.0, 0.2).set_delay(0.3).set_ease(Tween.EASE_IN_OUT)

	# 相位 3：淡出
	_tween.tween_property(_label, "modulate:a", 0.0, 0.3).set_delay(0.5)

	# 完成回调
	_tween.set_parallel(false)
	_tween.tween_callback(release_cb)


## 玩家跳字 — 轻量
func play_player_animation(release_cb: Callable) -> void:
	var start_y := position.y

	_tween = create_tween()

	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", start_y - 40.0, 0.3).set_delay(0.08).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.2).set_delay(0.3)

	_tween.set_parallel(false)
	_tween.tween_callback(release_cb)


## 治疗跳字 — 轻量偏右
func play_heal_animation(release_cb: Callable) -> void:
	var start_y := position.y
	var start_x := position.x

	_tween = create_tween()

	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", start_y - 40.0, 0.4).set_delay(0.08).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:x", start_x + 20.0, 0.4).set_delay(0.08).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.2).set_delay(0.35)

	_tween.set_parallel(false)
	_tween.tween_callback(release_cb)


## 池复用清理
func reset_for_pool() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	_label.text = ""
	_label.modulate.a = 1.0
	scale = Vector2.ONE
	rotation = 0.0
	position = Vector2.ZERO
