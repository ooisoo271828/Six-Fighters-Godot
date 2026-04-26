## ProjectilePool — 投射物对象池
## 管理 ProjectileNode 实例的创建/复用
extends Node2D

const POOL_SIZE: int = 100

var _pool: Array[Node2D] = []
var _active: Array[Node2D] = []
var _prefab_scene: PackedScene
var _initialized: bool = false

@onready var skill_signal_bus: Node = $"../SkillSignalBus"

func _ready() -> void:
	print("[ProjectilePool] Ready (call initialize() from SkillRoot)")

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	# 尝试加载预制场景
	var prefab_path := "res://scenes/skill_system/nodes/projectile.tscn"
	if ResourceLoader.exists(prefab_path):
		_prefab_scene = load(prefab_path)
	_prepopulate_pool()
	print("[ProjectilePool] Initialized with %d projectiles" % POOL_SIZE)

## 预创建对象
func _prepopulate_pool() -> void:
	for i in POOL_SIZE:
		var node := _create_projectile_node()
		node.visible = false
		_pool.append(node)
		add_child(node)

func _create_projectile_node() -> Node2D:
	if _prefab_scene:
		return _prefab_scene.instantiate()
	# Fallback：程序化创建
	var node := Node2D.new()
	node.set_script(load("res://scripts/skill_system/pools/projectile_node.gd"))
	return node

## 从池中取出一个投射物
func spawn(chain: ExecutionChain, visual_def: Resource, signal_bus: Node) -> Node2D:
	var node: Node2D
	if _pool.is_empty():
		node = _create_projectile_node()
		add_child(node)
	else:
		node = _pool.pop_back()

	node.initialize(chain, visual_def, signal_bus)
	node.visible = true
	_active.append(node)
	skill_signal_bus.behavior_spawned.emit(node, chain.effect_id, _chain_to_dict(chain))
	return node

## 归还投射物到池中
func despawn(node: Node2D) -> void:
	var idx := _active.find(node)
	if idx >= 0:
		_active.remove_at(idx)
	node.visible = false
	node.set_process(false)
	_pool.append(node)

## 获取当前活跃的投射物数量
func get_active_count() -> int:
	return _active.size()

## 销毁所有活跃投射物
func clear_all() -> void:
	for node in _active.duplicate():
		despawn(node)

## 将 chain 数据转为 Dictionary（供信号使用）
func _chain_to_dict(chain: ExecutionChain) -> Dictionary:
	return {
		"chain_id": chain.chain_id,
		"effect_id": chain.effect_id,
		"skill_id": chain.skill_id,
		"speed": chain.speed,
		"scale": chain.scale,
		"current_radius": chain.current_radius,
		"color": chain.color_override,
		"trajectory_type": chain.trajectory_type,
		"travel_time_multiplier": chain.travel_time_multiplier,
	}
