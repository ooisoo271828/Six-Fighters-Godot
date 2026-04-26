## SkillEffect — 技能执行树节点基类
## 所有 Effect 节点（发射、区域伤害、状态等）继承此类
class_name SkillEffect
extends RefCounted

## ── 执行上下文 ──
class SkillExecutionContext:
	extends RefCounted

	var caster: Node2D
	var target: Node2D
	var target_pos: Vector2
	var direction: Vector2
	var damage: float
	var damage_type: String
	var skill_id: String
	var visual_def: Resource  # SkillVisualDef

	func _to_string() -> String:
		return "Context[skill=%s caster=%s target=%s damage=%.1f]" % [skill_id, caster, target, damage]

## ── Effect 类型枚举 ──
enum EffectType {
	EMIT_PROJECTILE,    # 发射抛射物（最常用）
	AREA_DAMAGE,         # 区域伤害（瞬发）
	APPLY_STATUS,        # 施加状态
	EMIT_BURST,          # 爆发效果（视觉）
}

## ── 属性 ──
var effect_id: String = "base_effect"
var effect_type: EffectType = EffectType.EMIT_PROJECTILE

## ── 核心接口 ──
## 执行此 Effect，返回 0 个或多个叶子 ExecutionChain
func execute(_context: SkillExecutionContext) -> Array[ExecutionChain]:
	return []

## 获取 Effect 的唯一标识
func get_effect_id() -> String:
	return effect_id

## ── 工具函数 ──

## 创建一条基础叶子链（所有叶子 Effect 共用）
func _create_chain(context: SkillExecutionContext) -> ExecutionChain:
	var chain := ExecutionChain.new()
	chain.effect = self
	chain.effect_id = effect_id
	chain.caster = context.caster
	chain.target = context.target
	chain.target_pos = context.target_pos
	chain.direction = context.direction
	chain.position = context.caster.global_position
	chain.damage = context.damage
	chain.damage_type = context.damage_type
	chain.base_damage = context.damage
	chain.current_radius = 4.0
	chain.base_radius = 4.0
	chain.scale = 1.0
	chain.projectile_hp = 0.0
	chain.can_be_targeted = false
	chain.speed = 300.0
	chain.behavior_state = "Flying"
	chain.travel_time_multiplier = 1.0
	return chain
