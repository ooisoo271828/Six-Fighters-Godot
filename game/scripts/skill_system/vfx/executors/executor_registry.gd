class_name VFXExecutorRegistry
extends RefCounted

## VFX 执行器注册器 — 根据 kind 分发到对应执行器

var _executors: Dictionary = {}  # StringName -> VFXExecutorBase


## 注册执行器
func register(executor: VFXExecutorBase) -> void:
	_executors[executor.get_kind()] = executor


## 分发执行
func dispatch(kind: StringName, layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	if kind in _executors:
		_executors[kind].execute(layer, world_pos, pool, tex_manager)
	else:
		push_warning("VFXExecutorRegistry: no executor for kind '%s'" % kind)


## 获取所有已注册的 kind
func get_registered_kinds() -> Array[StringName]:
	return Array(_executors.keys(), TYPE_STRING_NAME, &"", null)
