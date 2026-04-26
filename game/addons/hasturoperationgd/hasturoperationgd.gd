@tool
extends EditorPlugin


var _dock: Control
var _backend: ExecutorBackend


func _enable_plugin() -> void:
	pass


func _disable_plugin() -> void:
	pass


func _enter_tree() -> void:
	print("[HasturPlugin] _enter_tree called")
	HasturOperationGDPluginSettings.register_settings()

	_backend = ExecutorBackend.new()
	add_child(_backend)
	_backend.initialize(self)
	print("[HasturPlugin] Backend initialized")

	# 创建 Dock 面板 - 使用场景文件
	print("[HasturPlugin] Loading dock scene...")
	var dock_scene = preload("res://addons/hasturoperationgd/executor_dock.tscn")
	_dock = dock_scene.instantiate()
	_dock.initialize(_backend)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	print("[HasturPlugin] Dock added to RIGHT_UL")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _backend:
		remove_child(_backend)
		_backend.queue_free()
		_backend = null
