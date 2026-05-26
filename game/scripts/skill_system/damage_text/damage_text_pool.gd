## DamageTextPool — 伤害跳字对象池
## 遵循 HitVFXPool 模式
extends Node2D

@export var pool_size: int = 20

var _node_script: GDScript

var _available: Array = []
var _active: Array = []


func _ready() -> void:
	_node_script = load("res://scripts/skill_system/damage_text/damage_text_node.gd")
	for i in pool_size:
		var node = _node_script.new()
		node.name = "DamageTextNode_%d" % i
		node.visible = false
		add_child(node)
		_available.append(node)


## 从池中获取一个跳字节点
func acquire():
	var node
	if _available.is_empty():
		node = _node_script.new()
		node.name = "DamageTextNode_overflow_%d" % _active.size()
		add_child(node)
	else:
		node = _available.pop_back()

	node.visible = true
	node.scale = Vector2.ZERO
	node.modulate = Color.WHITE
	node.rotation = 0.0
	_active.append(node)
	return node


## 释放节点回池
func release(node) -> void:
	if not node or not is_instance_valid(node):
		return
	node.reset_for_pool()
	node.visible = false
	_active.erase(node)
	_available.append(node)


## 释放所有活跃节点
func release_all() -> void:
	for node in _active:
		if is_instance_valid(node):
			node.reset_for_pool()
			node.visible = false
			_available.append(node)
	_active.clear()


## 获取池状态统计
func get_stats() -> Dictionary:
	return {
		"pool_size": pool_size,
		"available": _available.size(),
		"active": _active.size(),
		"overflow": max(0, _active.size() + _available.size() - pool_size),
	}
