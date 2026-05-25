## EvilEyePool — 魔眼激光对象池
## 管理 EvilEyeNode 实例的创建/复用
extends Node2D

const POOL_SIZE: int = 4

var _pool: Array[Node2D] = []
var _active: Array[Node2D] = []
var _initialized: bool = false


func _ready() -> void:
	print("[EvilEyePool] Ready (call initialize() from SkillRoot)")


func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_prepopulate_pool()
	print("[EvilEyePool] Initialized with %d eyes" % POOL_SIZE)


func _prepopulate_pool() -> void:
	var script_res = preload("res://scripts/skill_system/pools/evil_eye_node.gd")
	for i in range(POOL_SIZE):
		var node := script_res.new() as Node2D
		node.visible = false
		_pool.append(node)
		add_child(node)


## 从池中取出一颗魔眼
func spawn(
	caster: Node2D,
	path_origin: Vector2,
	path_angle: float,
	path_def: LaserPathDef,
	damage: float,
	damage_type: String,
	skill_id: String,
	signal_bus: Node,
	available_targets: Array
) -> Node2D:
	var node: Node2D
	if _pool.is_empty():
		var script_res = preload("res://scripts/skill_system/pools/evil_eye_node.gd")
		node = script_res.new() as Node2D
		add_child(node)
	else:
		node = _pool.pop_back()

	# 眼球在轨迹中心上方
	var eye_pos: Vector2 = path_origin + Vector2(0, -180.0)
	node.global_position = eye_pos
	node.initialize(caster, path_origin, path_angle, path_def, damage, damage_type, skill_id, signal_bus, available_targets)
	node.visible = true
	_active.append(node)
	return node


## 归还魔眼到池
func despawn(node: Node2D) -> void:
	var idx := _active.find(node)
	if idx >= 0:
		_active.remove_at(idx)
	node.visible = false
	node.set_process(false)
	if node.has_method("reset_for_pool"):
		node.reset_for_pool()
	_pool.append(node)


## 获取当前活跃的魔眼数量
func get_active_count() -> int:
	return _active.size()


## 销毁所有活跃魔眼
func clear_all() -> void:
	for node in _active.duplicate():
		despawn(node)
