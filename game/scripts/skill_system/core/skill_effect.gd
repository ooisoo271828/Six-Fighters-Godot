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
	var visual_def: SkillVisualDef

	var delivery_type: String = "projectile"
	var tracking_enabled: bool = false
	var turn_rate: float = 0.0
	var hit_precision_radius: float = 0.0
	var pierce_enabled: bool = false
	var pierce_count: int = 0
	var bounce_remaining: int = 0
	var bounce_type: int = 0            # 0=REDIRECT, 1=RESPAWN
	var bounce_damage_scale: float = 1.0
	var hit_aoe_radius: float = 0.0
	var available_targets: Array = []  # for multi-target seeking
	var target_mode: int = 0            # 0=NEAREST, 1=FARTHEST, 2=LOWEST_HP, 3=HIGHEST_HP, 4=RANDOM
	var cast_range: float = 300.0       # 技能射程（px）

	# ── 混合伤害参数 ──
	var secondary_damage_type: int = -1
	var secondary_damage_ratio: float = 0.0

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
	chain.skill_id = context.skill_id
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
	chain.tracking_enabled = context.tracking_enabled
	chain.turn_rate = context.turn_rate
	chain.hit_precision_radius = context.hit_precision_radius
	chain.pierce_enabled = context.pierce_enabled
	chain.pierce_count = context.pierce_count
	chain.bounce_remaining = context.bounce_remaining
	chain.bounce_type = context.bounce_type
	chain.bounce_damage_scale = context.bounce_damage_scale
	chain.hit_aoe_radius = context.hit_aoe_radius
	chain.target_mode = context.target_mode
	chain.secondary_damage_type = context.secondary_damage_type
	chain.secondary_damage = context.damage * context.secondary_damage_ratio
	chain.secondary_damage_ratio = context.secondary_damage_ratio
	chain.available_targets = context.available_targets
	return chain
