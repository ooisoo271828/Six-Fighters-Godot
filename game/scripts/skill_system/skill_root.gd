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

func _connect_signal_bus() -> void:
	# VFX 监听伤害信号
	skill_signal_bus.skill_hit.connect(skill_vfx_manager._on_skill_hit)
	skill_signal_bus.behavior_spawned.connect(skill_vfx_manager._on_behavior_spawned)
	skill_signal_bus.behavior_complete.connect(skill_vfx_manager._on_behavior_complete)
	skill_signal_bus.telegraph_started.connect(skill_vfx_manager._on_telegraph_started)

## ── 对外 API ──

## 施放技能的入口
func cast_skill(caster: Node2D, skill_id: String, target: Node2D) -> void:
	if not skill_registry.is_ready():
		push_warning("[SkillSystem] Registry not ready, skip cast: " + skill_id)
		return

	var skill_def: Resource = skill_registry.get_skill(skill_id)
	if not skill_def:
		push_warning("[SkillSystem] Skill not found: " + skill_id)
		return

	var visual_def: Resource = skill_registry.get_skill_visual(skill_id) as Resource

	# 获取该技能的基础 Modifier（从 SkillDef 读取）
	var entity_modifier_ids: Array[String] = []
	if skill_def.get("base_modifier_ids"):
		entity_modifier_ids = skill_def.base_modifier_ids

	# 获取完整的 Modifier 实例列表
	var modifiers: Array[SkillModifier] = modifier_registry.get_entity_modifiers(entity_modifier_ids)

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
func _execute_chain(chain: ExecutionChain, skill_def, visual_def) -> void:
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
