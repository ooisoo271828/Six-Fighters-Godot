## CameraAnchor — 镜头锚点
## 挂载到 Node2D 上，子节点应包含一个 Camera2D
## 接受玩家输入控制移动，Camera2D 自动跟随
## 这是游戏镜头系统的核心组件，Arena 场景和 Demo 场景共用
extends Node2D

## 锚点移动速度 (px/s)
@export var anchor_speed: float = 250.0
## 是否启用键盘输入控制（Demo 中可关闭以固定镜头）
@export var input_enabled: bool = false

func _process(dt: float) -> void:
	if not input_enabled:
		return

	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		position += dir * anchor_speed * dt
