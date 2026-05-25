## SkillSystem 场景根节点
extends Node

## 职责：
## - 初始化所有子系统节点
## - 提供统一的 cast_skill() 对外接口
## - 管理 SkillSystem 的启用/禁用

@onready var skill_registry: Node = $SkillRegistry
@onready var modifier_registry: Node = $ModifierRegistry
@onready var modifier_processor: Node = $ModifierProcessor
@onready var skill_signal_bus: Node = $SkillSignalBus
@onready var projectile_pool: Node2D = $ProjectilePool
@onready var executor_pool: Node = $ExecutorPool
@onready var skill_vfx_manager: Node = $SkillVFXManager
@onready var laser_beam_pool: Node2D = $LaserBeamPool

var _chain_id_counter: int = 0

func _ready() -> void:
	_initialize_subsystems()
	_connect_signal_bus()
	print("[SkillSystem] Ready")

func _initialize_subsystems() -> void:
	skill_registry.initialize()
	modifier_registry.initialize()
	projectile_pool.initialize()
	executor_pool.initialize()
	skill_vfx_manager.initialize()
	laser_beam_pool.initialize()

func _connect_signal_bus() -> void:
	# VFX 监听伤害信号
	skill_signal_bus.skill_hit.connect(skill_vfx_manager._on_skill_hit)
	skill_signal_bus.behavior_spawned.connect(skill_vfx_manager._on_behavior_spawned)
	skill_signal_bus.behavior_complete.connect(skill_vfx_manager._on_behavior_complete)
	skill_signal_bus.telegraph_started.connect(skill_vfx_manager._on_telegraph_started)

## ── 对外 API ──

## 施放技能的入口
## available_targets: 场上所有可用目标（由调用方提供，如 CombatMediator 的 alive_enemies）
## extra_modifiers: 外部注入的 Modifier 列表（来自装备、天赋、光环等），可选
func cast_skill(caster: Node2D, skill_id: String, available_targets: Array, extra_modifiers: Array[SkillModifier] = []) -> void:
	if not skill_registry.is_ready():
		push_warning("[SkillSystem] Registry not ready, skip cast: " + skill_id)
		return

	var skill_def: Resource = skill_registry.get_skill(skill_id)
	if not skill_def:
		push_warning("[SkillSystem] Skill not found: " + skill_id)
		return

	# ── 目标选择 ──
	var target_mode: int = skill_def.target_mode if skill_def.get("target_mode") != null else 0
	var cast_range: float = skill_def.cast_range if skill_def.get("cast_range") else 300.0
	var target: Node2D = TargetSelector.select_target(caster.position, available_targets, target_mode, cast_range)
	if not target:
		return

	var visual_def: SkillVisualDef = skill_registry.get_skill_visual(skill_id)

	# 获取该技能的基础 Modifier（从 SkillDef 读取）
	var entity_modifier_ids: Array[String] = []
	if skill_def.get("base_modifier_ids"):
		entity_modifier_ids = skill_def.base_modifier_ids

	# 获取完整的 Modifier 实例列表
	var modifiers: Array[SkillModifier] = modifier_registry.get_entity_modifiers(entity_modifier_ids)
	# 合并外部注入的 Modifier（装备、天赋、光环等）
	modifiers.append_array(extra_modifiers)

	# 构建执行上下文
	var context: SkillEffect.SkillExecutionContext = SkillEffect.SkillExecutionContext.new()
	context.caster = caster
	context.target = target
	context.target_pos = target.global_position if target else caster.global_position
	context.direction = caster.global_position.direction_to(context.target_pos)
	context.damage = skill_def.base_damage
	context.damage_type = _int_to_damage_type_string(skill_def.damage_type)
	context.skill_id = skill_id
	context.visual_def = visual_def
	context.delivery_type = skill_def.delivery_type if skill_def.get("delivery_type") else "projectile"
	context.tracking_enabled = skill_def.tracking_enabled if skill_def.get("tracking_enabled") else false
	context.turn_rate = skill_def.turn_rate if skill_def.get("turn_rate") else 0.0
	context.hit_precision_radius = skill_def.hit_precision_radius if skill_def.get("hit_precision_radius") else 0.0
	context.pierce_enabled = skill_def.pierce_enabled if skill_def.get("pierce_enabled") else false
	context.pierce_count = skill_def.pierce_count if skill_def.get("pierce_count") != null else 0
	context.bounce_remaining = skill_def.bounce_remaining if skill_def.get("bounce_remaining") != null else 0
	context.bounce_type = skill_def.bounce_type if skill_def.get("bounce_type") != null else 0
	context.bounce_damage_scale = skill_def.bounce_damage_scale if skill_def.get("bounce_damage_scale") else 1.0
	context.hit_aoe_radius = skill_def.hit_aoe_radius if skill_def.get("hit_aoe_radius") else 0.0
	context.secondary_damage_type = skill_def.secondary_damage_type if skill_def.get("secondary_damage_type") != null else -1
	context.secondary_damage_ratio = skill_def.secondary_damage_ratio if skill_def.get("secondary_damage_ratio") != null else 0.0
	context.available_targets = available_targets
	context.target_mode = target_mode
	context.cast_range = cast_range

	skill_signal_bus.skill_cast_requested.emit(caster, skill_id, target)

	# 创建 Effect 实例
	var effect: SkillEffect = skill_registry.create_effect_instance(skill_def.effect_type)

	# ModifierProcessor 解析执行链
	var chains: Array[ExecutionChain] = modifier_processor.resolve(effect, modifiers, context)
	if chains.is_empty():
		return

	skill_signal_bus.skill_cast_started.emit(caster, skill_id, context.target_pos)

	# 获取执行器并执行
	for chain in chains:
		if chain.behavior_state == "Destroyed":
			continue
		_execute_chain(chain, skill_def, visual_def)

## 执行单条叶子链
func _execute_chain(chain: ExecutionChain, skill_def: SkillDef, visual_def: SkillVisualDef) -> void:
	# 激光柱直接走 LaserBeamPool
	if chain.effect_id == "emit_laser_beam":
		laser_beam_pool.spawn(
			chain.caster,
			chain.direction,
			chain.damage,
			chain.damage_type,
			chain.skill_id,
			skill_signal_bus
		)
		skill_signal_bus.skill_cast_finished.emit(chain.caster, skill_def.skill_id if skill_def else "")
		return

	var executor = executor_pool.acquire()
	if not executor:
		push_warning("[SkillSystem] No available executor")
		return

	executor.execute(chain, skill_def, visual_def, skill_signal_bus)

## 生成唯一链 ID（供 Projectile 使用）
func generate_chain_id() -> int:
	_chain_id_counter += 1
	return _chain_id_counter

## ── 查询 API ──

## 获取所有已注册的技能 ID
func get_all_skill_ids() -> Array[String]:
	return skill_registry.get_all_skill_ids()

## 获取技能定义
func get_skill_def(skill_id: String) -> Resource:
	return skill_registry.get_skill(skill_id)

## 检查技能是否存在
func has_skill(skill_id: String) -> bool:
	return skill_registry.has_skill(skill_id)

## 将 int damage_type 转换为字符串
static func _int_to_damage_type_string(dt: int) -> String:
	match dt:
		0: return "physical"
		1: return "elemental_fire"
		2: return "elemental_ice"
		3: return "elemental_lightning"
		4: return "elemental_poison"
	return "physical"
