## SmallLaserBeamPool — 小激光术对象池
extends Node2D

const POOL_SIZE: int = 10

var _pool: Array = []
var _active: Array = []
var _initialized: bool = false


func _ready() -> void:
	pass


func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_prepopulate_pool()


func _prepopulate_pool() -> void:
	for i in range(POOL_SIZE):
		var node = _create_beam_node()
		node.visible = false
		_pool.append(node)
		add_child(node)


func _create_beam_node():
	var node := Node2D.new()
	node.set_script(load("res://scripts/skill_system/pools/small_laser_beam_node.gd"))
	return node


func spawn(caster: Node2D, direction: Vector2, damage: float, damage_type: String, skill_id: String, signal_bus: Node, targets: Array = []) -> Node2D:
	var node
	if _pool.is_empty():
		node = _create_beam_node()
		add_child(node)
	else:
		node = _pool.pop_back()

	node.initialize(caster, direction, damage, damage_type, skill_id, signal_bus)
	if targets.size() > 0 and node.has_method("set_targets"):
		node.set_targets(targets)
	node.visible = true
	_active.append(node)
	return node


func despawn(node) -> void:
	var idx := _active.find(node)
	if idx >= 0:
		_active.remove_at(idx)
	node.visible = false
	node.set_process(false)
	if node.has_method("reset_for_pool"):
		node.reset_for_pool()
	_pool.append(node)


func get_active_count() -> int:
	return _active.size()


func clear_all() -> void:
	for node in _active.duplicate():
		despawn(node)
