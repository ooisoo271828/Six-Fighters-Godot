class_name ExecScreenShake
extends VFXExecutorBase

## 震屏执行器 — 通过 Camera2D 的 trauma 系统实现屏幕震动


func get_kind() -> StringName:
	return &"screen_shake"


func execute(layer: VFXLayerDef, world_pos: Vector2, _pool: HitVFXPool, _tex_manager: VFXTextureManager) -> void:
	var params := layer.params
	var strength: float = params.get("strength", 1.0)

	# 获取场景中的 Camera2D
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var cam := tree.root.get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(strength * 0.05)
