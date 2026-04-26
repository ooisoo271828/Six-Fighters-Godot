## SkillExecutor — 技能施法执行器
## 持有单次技能施放的所有运行时状态
extends Node

var _chain: ExecutionChain
var _skill_def: Resource
var _visual_def: Resource
var _signal_bus: Node
var _completed: bool = false
var _skill_root: Node

func _ready() -> void:
	pass

## 执行单条叶子链
func execute(chain: ExecutionChain, skill_def: Resource, visual_def: Resource, signal_bus: Node) -> void:
	_chain = chain
	_skill_def = skill_def
	_visual_def = visual_def
	_signal_bus = signal_bus
	_skill_root = get_tree().root.get_node_or_null("SkillSystem")
	if not _skill_root:
		_skill_root = get_parent().get_parent()
	_completed = false

	# 实例化 Effect
	var effect: SkillEffect
	var effect_type: String = skill_def.get("effect_type") if skill_def else ""
	if not effect_type.is_empty() and _skill_root:
		effect = _skill_root.skill_registry.create_effect_instance(effect_type)
	else:
		effect = EmitProjectileEffect.new()

	if effect == null:
		effect = EmitProjectileEffect.new()

	# 立即执行 Effect（通常是发射投射物）
	var chains := effect.execute(_build_context())
	for child_chain in chains:
		_spawn_chain(child_chain)

	_signal_bus.skill_cast_finished.emit(_chain.caster, _skill_def.skill_id if _skill_def else "")

	# 归还执行器
	var pool := get_parent()
	if pool.has_method("release"):
		pool.release(self)

func _build_context() -> SkillEffect.SkillExecutionContext:
	var ctx := SkillEffect.SkillExecutionContext.new()
	ctx.caster = _chain.caster
	ctx.target = _chain.target
	ctx.target_pos = _chain.target_pos
	ctx.direction = _chain.direction
	ctx.damage = _chain.damage
	ctx.damage_type = _chain.damage_type
	ctx.skill_id = _skill_def.skill_id if _skill_def else ""
	ctx.visual_def = _visual_def
	return ctx

func _spawn_chain(chain: ExecutionChain) -> void:
	# 通过 ProjectilePool 生成投射物节点
	var pool: Node2D = _skill_root.projectile_pool if _skill_root else null
	if pool and pool.has_method("spawn"):
		pool.spawn(chain, _visual_def, _signal_bus)
