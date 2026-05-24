# projectile_component.gd
# 弹体视觉组件基类 — 每种视觉效果由独立组件驱动
class_name ProjectileComponent
extends RefCounted

## 创建视觉节点（在 ProjectileNode._setup_visuals 时调用一次）
func create_nodes(_parent: Node2D) -> void:
	pass

## 从 VisualDef 配置（每次 initialize 时调用）
func configure(_visual_def: SkillVisualDef, _chain: ExecutionChain, _tex_manager: VFXTextureManager) -> void:
	pass

## 每帧更新
func update(_dt: float, _parent: Node2D, _chain: ExecutionChain) -> void:
	pass

## 销毁时清理（Tween 淡出等）
func on_destroy(_parent: Node2D) -> void:
	pass

## 池复用重置
func reset() -> void:
	pass

## 是否启用
func is_active() -> bool:
	return false
