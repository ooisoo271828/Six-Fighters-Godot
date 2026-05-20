class_name HitVFXPool
extends Node2D

## 命中特效对象池 — 管理 HitVFXNode 的 acquire/release
## 挂载在场景树的 VFXLayer 下，场景切换时随父节点一起清理

@export var pool_size: int = 80

var _available: Array[HitVFXNode] = []
var _active: Array[HitVFXNode] = []


func _ready() -> void:
	# 预分配池节点
	for i in range(pool_size):
		var node := HitVFXNode.new()
		node.set_pool(self)
		node.visible = false
		add_child(node)
		_available.append(node)


## 从池中获取一个节点
func acquire() -> HitVFXNode:
	var node: HitVFXNode
	if _available.size() > 0:
		node = _available.pop_back()
	else:
		# 溢出：创建新节点
		node = HitVFXNode.new()
		node.set_pool(self)
		add_child(node)
	node.visible = true
	_active.append(node)
	return node


## 归还节点到池
func release(node: HitVFXNode) -> void:
	if node in _active:
		_active.erase(node)
	node.visible = false
	node._hide_all()
	_available.append(node)


## 归还所有活跃节点（场景切换时调用）
func release_all() -> void:
	for node in _active.duplicate():
		release(node)


## 获取当前活跃节点数
func get_active_count() -> int:
	return _active.size()


## 获取池状态
func get_stats() -> Dictionary:
	return {
		"total": pool_size,
		"available": _available.size(),
		"active": _active.size(),
		"overflow": _active.size() - (pool_size - _available.size()) if _active.size() > pool_size - _available.size() else 0
	}
