## LaserBeamPool — 大激光术对象池
## 管理 LaserBeamNode 实例的创建/复用
## 激光柱同时存在的数量远少于投射物，池大小 8 足够
extends Node2D

const POOL_SIZE: int = 8

var _pool: Array[Node2D] = []
var _active: Array[Node2D] = []
var _initialized: bool = false


func _ready() -> void:
	print("[LaserBeamPool] Ready (call initialize() from SkillRoot)")


func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_prepopulate_pool()
	print("[LaserBeamPool] Initialized with %d beams" % POOL_SIZE)


func _prepopulate_pool() -> void:
	for i in range(POOL_SIZE):
		var node := _create_beam_node()
		node.visible = false
		_pool.append(node)
		add_child(node)


func _create_beam_node() -> Node2D:
	var node := Node2D.new()
	node.set_script(load("res://scripts/skill_system/pools/laser_beam_node.gd"))
	return node


## 从池中取出一根激光柱
func spawn(caster: Node2D, direction: Vector2, damage: float, damage_type: String, skill_id: String, signal_bus: Node) -> Node2D:
	var node: Node2D
	if _pool.is_empty():
		node = _create_beam_node()
		add_child(node)
	else:
		node = _pool.pop_back()

	node.initialize(caster, direction, damage, damage_type, skill_id, signal_bus)
	node.visible = true
	_active.append(node)
	return node


## 归还激光柱到池
func despawn(node: Node2D) -> void:
	var idx := _active.find(node)
	if idx >= 0:
		_active.remove_at(idx)
	node.visible = false
	node.set_process(false)
	if node.has_method("reset_for_pool"):
		node.reset_for_pool()
	_pool.append(node)


## 获取当前活跃的激光柱数量
func get_active_count() -> int:
	return _active.size()


## 销毁所有活跃激光柱
func clear_all() -> void:
	for node in _active.duplicate():
		despawn(node)
