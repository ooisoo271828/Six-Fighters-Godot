## ExecutorPool — 技能执行器对象池
## 管理 SkillExecutor 实例的复用
extends Node

const POOL_SIZE: int = 20

var _pool: Array[Node] = []
var _active: Array[Node] = []
var _prefab_scene: PackedScene
var _initialized: bool = false

func _ready() -> void:
	print("[ExecutorPool] Ready (call initialize() from SkillRoot)")

func initialize() -> void:
	if _initialized:
		return
	_initialized = true

	var prefab_path := "res://scenes/skill_system/nodes/executor.tscn"
	if ResourceLoader.exists(prefab_path):
		_prefab_scene = load(prefab_path)

	for i in POOL_SIZE:
		var ex := _create_executor()
		_pool.append(ex)
		add_child(ex)

	print("[ExecutorPool] Initialized with %d executors" % POOL_SIZE)

func _create_executor() -> Node:
	if _prefab_scene:
		return _prefab_scene.instantiate()
	var ex := Node.new()
	ex.set_script(load("res://scripts/skill_system/core/skill_executor.gd"))
	return ex

## 获取空闲执行器
func acquire() -> Node:
	var ex: Node
	if _pool.is_empty():
		ex = _create_executor()
		add_child(ex)
	else:
		ex = _pool.pop_back()

	ex.set_process(true)
	_active.append(ex)
	return ex

## 归还执行器
func release(executor: Node) -> void:
	var idx := _active.find(executor)
	if idx >= 0:
		_active.remove_at(idx)
	executor.set_process(false)
	_pool.append(executor)

func get_pool_size() -> int:
	return _pool.size()

func get_active_count() -> int:
	return _active.size()
