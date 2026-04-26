extends Control
class_name VirtualJoystick

## 虚拟摇杆 - 使用 _input 全局捕获鼠标/触摸事件

signal joystick_input(dx: float, dy: float)
signal joystick_stopped

var base_circle: ColorRect
var handle_circle: ColorRect

var base_pos: Vector2
var current_pos: Vector2
var max_radius: float = 40.0
var is_active: bool = false

func _ready() -> void:
	# 底座
	base_circle = ColorRect.new()
	base_circle.size = Vector2(120, 120)
	base_circle.color = Color(0.5, 0.5, 0.5, 0.3)
	base_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base_circle)
	
	# 手柄
	handle_circle = ColorRect.new()
	handle_circle.size = Vector2(60, 60)
	handle_circle.color = Color(0.9, 0.9, 0.9, 0.6)
	handle_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(handle_circle)
	
	# 设置位置 - 屏幕底部居中
	var vp := get_viewport_rect().size
	base_pos = Vector2(vp.x / 2.0, vp.y - 120.0)
	current_pos = base_pos
	
	base_circle.position = base_pos - Vector2(60, 60)
	handle_circle.position = base_pos - Vector2(30, 30)
	
	# 自身不拦截鼠标，用 _input 全局监听
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	# 鼠标左键按下
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 检查是否点击在摇杆区域附近
				var dist: float = event.global_position.distance_to(base_pos)
				if dist <= 80.0:
					is_active = true
					current_pos = event.global_position
					_update_handle()
					# 消费事件，防止穿透
					get_viewport().set_input_as_handled()
			else:
				if is_active:
					_release()
					get_viewport().set_input_as_handled()
	
	# 鼠标移动
	elif event is InputEventMouseMotion:
		if is_active:
			current_pos = event.global_position
			_update_handle()
			get_viewport().set_input_as_handled()
	
	# 触摸按下
	elif event is InputEventScreenTouch:
		if event.pressed:
			var dist: float = event.global_position.distance_to(base_pos)
			if dist <= 80.0:
				is_active = true
				current_pos = event.global_position
				_update_handle()
				get_viewport().set_input_as_handled()
		else:
			if is_active:
				_release()
				get_viewport().set_input_as_handled()
	
	# 触摸拖拽
	elif event is InputEventScreenDrag:
		if is_active:
			current_pos = event.global_position
			_update_handle()
			get_viewport().set_input_as_handled()

func _release() -> void:
	is_active = false
	current_pos = base_pos
	_update_handle()
	joystick_stopped.emit()

func _update_handle() -> void:
	if not handle_circle:
		return
	
	var offset: Vector2 = current_pos - base_pos
	var dist: float = offset.length()
	
	if dist > max_radius:
		offset = offset.normalized() * max_radius
		current_pos = base_pos + offset
	
	handle_circle.position = current_pos - Vector2(30, 30)
	
	if is_active:
		var norm_x: float = offset.x / max_radius
		var norm_y: float = offset.y / max_radius
		joystick_input.emit(norm_x, norm_y)
	else:
		joystick_input.emit(0.0, 0.0)
