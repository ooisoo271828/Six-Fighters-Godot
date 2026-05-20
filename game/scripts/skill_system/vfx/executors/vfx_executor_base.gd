class_name VFXExecutorBase
extends RefCounted

## VFX 执行器基类 — 策略模式
## 子类必须实现 get_kind() 和 execute()

## 返回此执行器处理的 kind（StringName）
func get_kind() -> StringName:
	return &""


## 执行特效
## layer: VFXLayerDef — 特效参数
## world_pos: Vector2 — 世界坐标
## pool: HitVFXPool — 命中特效对象池（可为 null）
## tex_manager: VFXTextureManager — 纹理管理器
func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool, tex_manager: VFXTextureManager) -> void:
	pass
