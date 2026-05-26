## FlyingSwordPool — 飞剑风暴对象池
extends Node2D

const POOL_SIZE: int = 15

var _pool: Array[Node2D] = []
var _active: Array[Node2D] = []
var _initialized: bool = false


func _ready() -> void:
	print("[FlyingSwordPool] Ready (call initialize() from SkillRoot)")


func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_prepopulate_pool()
	print("[FlyingSwordPool] Initialized with %d nodes" % POOL_SIZE)


func _prepopulate_pool() -> void:
	var script_res = preload("res://scripts/skill_system/pools/flying_sword_node.gd")
	for i in range(POOL_SIZE):
		var node := script_res.new() as Node2D
		node.visible = false
		_pool.append(node)
		add_child(node)


func spawn(caster: Node2D, target: Node2D, damage: float, damage_type: String, skill_id: String, signal_bus: Node) -> Node2D:
	var node: Node2D
	if _pool.is_empty():
		var script_res = preload("res://scripts/skill_system/pools/flying_sword_node.gd")
		node = script_res.new() as Node2D
		add_child(node)
	else:
		node = _pool.pop_back()

	node.global_position = caster.global_position
	node.initialize(caster, target, damage, damage_type, skill_id, signal_bus)
	node.visible = true
	_active.append(node)
	return node


func despawn(node: Node2D) -> void:
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
