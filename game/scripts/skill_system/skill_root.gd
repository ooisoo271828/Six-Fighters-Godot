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
@onready var evil_eye_pool: Node2D = $EvilEyePool
@onready var small_laser_beam_pool: Node2D = $SmallLaserBeamPool
@onready var bubble_bomb_array_pool: Node2D = $BubbleBombArrayPool
@onready var flying_sword_pool: Node2D = $FlyingSwordPool
@onready var shuriken_pool: Node2D = $ShurikenPool
@onready var burning_hands_pool: Node2D = $BurningHandsPool

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
	evil_eye_pool.initialize()
	small_laser_beam_pool.initialize()
	bubble_bomb_array_pool.initialize()
	flying_sword_pool.initialize()
	shuriken_pool.initialize()
	burning_hands_pool.initialize()

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

	# MAX_COVERAGE 模式：计算最优角度，不需要单个目标
	if target_mode == 6:  # MAX_COVERAGE
		if skill_def.get("effect_type") == "emit_evil_eye_laser":
			_cast_evil_eye_laser(caster, skill_def, skill_id, available_targets, extra_modifiers)
			return

		if skill_def.get("effect_type") == "emit_small_laser_beam":
			_cast_small_laser_beam(caster, skill_def, skill_id, available_targets, extra_modifiers)
			return

		if skill_def.get("effect_type") == "emit_bubble_bomb_array":
			_cast_bubble_bomb_array(caster, skill_def, skill_id, available_targets, extra_modifiers)
			return

		if skill_def.get("effect_type") == "emit_flying_sword_storm":
			_cast_flying_sword_storm(caster, skill_def, skill_id, available_targets, extra_modifiers)
			return

		if skill_def.get("effect_type") == "emit_burning_hands":
			_cast_burning_hands(caster, skill_def, skill_id, available_targets, extra_modifiers)
			return

	# 特殊 Effect 直接走专用方法
	if skill_def.get("effect_type") == "emit_scatter_shuriken":
		_cast_scatter_shuriken(caster, skill_def, skill_id, available_targets, extra_modifiers)
		return

		var beam_width: float = 90.0   # laser_beam.gd 中的 BEAM_WIDTH
		var beam_length: float = 900.0 # laser_beam.gd 中的 BEAM_LENGTH
		var optimal_angle: float = TargetSelector.find_max_coverage_angle(
			caster.position, available_targets, beam_width, beam_length, cast_range
		)
		if optimal_angle == INF:
			return  # 没有合法目标

		var visual_def_ml: SkillVisualDef = skill_registry.get_skill_visual(skill_id)
		var entity_modifier_ids_ml: Array[String] = []
		if skill_def.get("base_modifier_ids"):
			entity_modifier_ids_ml = skill_def.base_modifier_ids
		var modifiers_ml: Array[SkillModifier] = modifier_registry.get_entity_modifiers(entity_modifier_ids_ml)
		modifiers_ml.append_array(extra_modifiers)

		var context_ml: SkillEffect.SkillExecutionContext = SkillEffect.SkillExecutionContext.new()
		context_ml.caster = caster
		context_ml.target = null
		context_ml.target_pos = caster.global_position + Vector2(cos(optimal_angle), sin(optimal_angle)) * cast_range
		context_ml.direction = Vector2(cos(optimal_angle), sin(optimal_angle))
		context_ml.damage = skill_def.base_damage
		context_ml.damage_type = _int_to_damage_type_string(skill_def.damage_type)
		context_ml.skill_id = skill_id
		context_ml.visual_def = visual_def_ml
		context_ml.delivery_type = skill_def.delivery_type if skill_def.get("delivery_type") else "projectile"
		context_ml.tracking_enabled = false
		context_ml.turn_rate = 0.0
		context_ml.hit_precision_radius = 0.0
		context_ml.pierce_enabled = false
		context_ml.pierce_count = 0
		context_ml.bounce_remaining = 0
		context_ml.bounce_type = 0
		context_ml.bounce_damage_scale = 1.0
		context_ml.hit_aoe_radius = 0.0
		context_ml.secondary_damage_type = skill_def.secondary_damage_type if skill_def.get("secondary_damage_type") != null else -1
		context_ml.secondary_damage_ratio = skill_def.secondary_damage_ratio if skill_def.get("secondary_damage_ratio") != null else 0.0
		context_ml.available_targets = available_targets
		context_ml.target_mode = target_mode
		context_ml.cast_range = cast_range

		skill_signal_bus.skill_cast_requested.emit(caster, skill_id, null)
		var effect_ml: SkillEffect = skill_registry.create_effect_instance(skill_def.effect_type)
		var chains_ml: Array[ExecutionChain] = modifier_processor.resolve(effect_ml, modifiers_ml, context_ml)
		if chains_ml.is_empty():
			return
		skill_signal_bus.skill_cast_started.emit(caster, skill_id, context_ml.target_pos)
		for chain in chains_ml:
			if chain.behavior_state == "Destroyed":
				continue
			_execute_chain(chain, skill_def, visual_def_ml)
		return

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

## 魔眼激光施放
func _cast_evil_eye_laser(caster: Node2D, skill_def, skill_id: String, available_targets: Array, _extra_modifiers: Array = []) -> void:
	var path_def := load('res://resources/skills/path_defs/evil_eye_path_s.tres') as LaserPathDef
	if not path_def:
		push_warning('[SkillSystem] Failed to load path def for evil_eye_laser')
		return

	var result := TargetSelector.find_optimal_laser_path(
		caster.position, available_targets, skill_def.cast_range, path_def, 40.0, 15.0
	)
	if result.get('covered_count', 0) == 0:
		return  # 没有合法目标

	skill_signal_bus.skill_cast_requested.emit(caster, skill_id, null)
	skill_signal_bus.skill_cast_started.emit(caster, skill_id, result.path_origin)

	evil_eye_pool.spawn(
		caster,
		result.path_origin,
		result.path_angle,
		path_def,
		skill_def.base_damage,
		_int_to_damage_type_string(skill_def.damage_type),
		skill_id,
		skill_signal_bus,
		available_targets
	)

	skill_signal_bus.skill_cast_finished.emit(caster, skill_id)


## 小激光术：120度扇区 + 5道激光柱
func _cast_small_laser_beam(caster: Node2D, skill_def, skill_id: String, available_targets: Array, _extra_modifiers: Array = []) -> void:
	var cone_angle := TargetSelector.find_best_cone_angle(caster.position, available_targets, 120.0, skill_def.cast_range)
	if cone_angle == INF:
		return

	var half_cone := 60.0
	var cone_dir := Vector2.RIGHT.rotated(deg_to_rad(cone_angle))
	var cone_targets: Array = []
	for u in available_targets:
		if not (u and is_instance_valid(u) and u.get("is_alive") == true):
			continue
		var to_u: Vector2 = u.position - caster.position
		if to_u.length() > skill_def.cast_range or to_u.length() < 1.0:
			continue
		var angle_diff := rad_to_deg(absf(to_u.angle_to(cone_dir)))
		if angle_diff <= half_cone:
			cone_targets.append(u)

	if cone_targets.is_empty():
		return

	var shuffled := cone_targets.duplicate()
	shuffled.shuffle()
	var pick: Array = []
	for i in range(min(5, shuffled.size())):
		pick.append(shuffled[i])
	while pick.size() < 5:
		pick.append(cone_targets[randi() % cone_targets.size()])

	skill_signal_bus.skill_cast_requested.emit(caster, skill_id, null)
	skill_signal_bus.skill_cast_started.emit(caster, skill_id, pick[0].global_position)

	for i in range(5):
		var target = pick[i]
		var dir: Vector2 = (target.global_position - caster.global_position).normalized()
		get_tree().create_timer(i * 0.3).timeout.connect(func():
			small_laser_beam_pool.spawn(caster, dir, skill_def.base_damage, _int_to_damage_type_string(skill_def.damage_type), skill_id, skill_signal_bus)
		)

	skill_signal_bus.skill_cast_finished.emit(caster, skill_id)


## 气泡炸弹阵：椭圆覆盖 + 多阶段爆炸
func _cast_bubble_bomb_array(caster: Node2D, skill_def, skill_id: String, available_targets: Array, _extra_modifiers: Array = []) -> void:
	var ellipse_result := TargetSelector.find_optimal_ellipse(
		caster.position, available_targets, skill_def.cast_range
	)
	if ellipse_result.get("covered_count", 0) == 0:
		return

	var ellipse_center := ellipse_result.ellipse_center as Vector2

	skill_signal_bus.skill_cast_requested.emit(caster, skill_id, null)
	skill_signal_bus.skill_cast_started.emit(caster, skill_id, ellipse_center)

	bubble_bomb_array_pool.spawn(
		caster,
		ellipse_center,
		available_targets,
		skill_def.base_damage,
		_int_to_damage_type_string(skill_def.damage_type),
		skill_id,
		skill_signal_bus
	)

	skill_signal_bus.skill_cast_finished.emit(caster, skill_id)


## 飞剑风暴：椭圆选域 + 分散索敌 + 竖直下插
func _cast_flying_sword_storm(caster: Node2D, skill_def, skill_id: String, available_targets: Array, _extra_modifiers: Array = []) -> void:
	var ellipse_center := TargetSelector.find_optimal_ellipse(
		caster.position, available_targets, 800.0,
		350.0, 125.0
	).get("ellipse_center", caster.position) as Vector2

	var valid: Array = []
	var hw := 175.0
	var hh := 62.5
	for u in available_targets:
		if u and is_instance_valid(u) and u.get("is_alive") == true:
			var dx := absf(u.position.x - ellipse_center.x)
			var dy := absf(u.position.y - ellipse_center.y)
			if (dx * dx) / (hw * hw) + (dy * dy) / (hh * hh) <= 1.0:
				valid.append(u)

	if valid.is_empty():
		return

	var assigned: Array = []
	var already: Array = []
	var count := mini(10, maxi(1, valid.size() * 2))
	for i in range(count):
		var pick: Node2D = null
		var unassigned: Array = []
		for u in valid:
			if not already.has(u):
				unassigned.append(u)
		if not unassigned.is_empty():
			pick = unassigned[randi() % unassigned.size()]
		else:
			pick = valid[randi() % valid.size()]
		assigned.append(pick)
		already.append(pick)

	skill_signal_bus.skill_cast_requested.emit(caster, skill_id, null)
	skill_signal_bus.skill_cast_started.emit(caster, skill_id, ellipse_center)

	for target in assigned:
		flying_sword_pool.spawn(
			caster, target, skill_def.base_damage,
			_int_to_damage_type_string(skill_def.damage_type),
			skill_id, skill_signal_bus, valid
		)

	skill_signal_bus.skill_cast_finished.emit(caster, skill_id)


## 火焰之手：扇形 AOE + 持续灼烧
func _cast_burning_hands(caster: Node2D, skill_def, skill_id: String, available_targets: Array, _extra_modifiers: Array = []) -> void:
	# 筛选有效目标
	var valid: Array = []
	for u in available_targets:
		if u and is_instance_valid(u) and u.get("is_alive") == true:
			var dist := caster.position.distance_to(u.position)
			if dist <= skill_def.cast_range and dist > 1.0:
				valid.append(u)

	if valid.is_empty():
		return

	# 计算扇形中心方向（朝向最近目标的质心）
	var centroid := Vector2.ZERO
	for u in valid:
		centroid += u.position
	centroid /= valid.size()
	var direction := caster.position.direction_to(centroid)

	skill_signal_bus.skill_cast_requested.emit(caster, skill_id, null)
	skill_signal_bus.skill_cast_started.emit(caster, skill_id, centroid)

	burning_hands_pool.spawn(
		caster, direction, skill_def.base_damage,
		_int_to_damage_type_string(skill_def.damage_type),
		skill_id, skill_signal_bus, valid
	)

	skill_signal_bus.skill_cast_finished.emit(caster, skill_id)


## 霰弹手里剑：90度扇形选域 + 9发连射 + 间隔递减
func _cast_scatter_shuriken(caster: Node2D, skill_def, skill_id: String, available_targets: Array, _extra_modifiers: Array = []) -> void:
	const SHOT_COUNT: int = 9
	const FAN_ANGLE_DEG: float = 90.0
	# 间隔递减：0.35 → 0.1
	const INTERVALS: Array[float] = [0.35, 0.32, 0.29, 0.26, 0.23, 0.20, 0.17, 0.14, 0.11]

	# 筛选有效目标
	var valid: Array = []
	for u in available_targets:
		if u and is_instance_valid(u) and u.get("is_alive") == true:
			var dist := caster.position.distance_to(u.position)
			if dist <= skill_def.cast_range and dist > 1.0:
				valid.append(u)

	if valid.is_empty():
		return

	# 计算扇形中心方向（朝向最近目标或质心）
	var center_dir: Vector2
	var nearest := TargetSelector.find_nearest_in_range(caster.position, valid, skill_def.cast_range)
	if nearest:
		center_dir = caster.position.direction_to(nearest.position)
	else:
		var centroid := Vector2.ZERO
		for u in valid:
			centroid += u.position
		centroid /= valid.size()
		center_dir = caster.position.direction_to(centroid)

	# 筛选90度扇形内目标
	var half_fan := deg_to_rad(FAN_ANGLE_DEG * 0.5)
	var fan_targets: Array = []
	for u in valid:
		var to_u := caster.position.direction_to(u.position)
		var angle_diff := absf(center_dir.angle_to(to_u))
		if angle_diff <= half_fan:
			fan_targets.append(u)

	# 回退：扇形内无目标则用全部有效目标
	if fan_targets.is_empty():
		fan_targets = valid

	# 按距离排序
	fan_targets.sort_custom(func(a, b): return caster.position.distance_to(a.position) < caster.position.distance_to(b.position))

	skill_signal_bus.skill_cast_requested.emit(caster, skill_id, null)
	skill_signal_bus.skill_cast_started.emit(caster, skill_id, fan_targets[0].global_position)

	# 选择9个目标（优先不同目标）
	var assigned: Array = []
	var last_target: Node2D = null
	for i in range(SHOT_COUNT):
		var pick: Node2D = null
		# 优先选择不同于上次的目标
		if last_target != null and fan_targets.size() > 1:
			var different: Array = []
			for t in fan_targets:
				if t != last_target:
					different.append(t)
			if not different.is_empty():
				pick = different[randi() % different.size()]
		if pick == null:
			pick = fan_targets[randi() % fan_targets.size()]
		assigned.append(pick)
		last_target = pick

	# 计算累积延迟并发射
	var accumulated_delay: float = 0.0
	for i in range(SHOT_COUNT):
		var target: Node2D = assigned[i]
		var delay: float = accumulated_delay
		accumulated_delay += INTERVALS[i]

		# 伤害微调 +/-10%
		var damage: float = skill_def.base_damage * randf_range(0.9, 1.1)
		damage = maxf(1.0, damage)

		# 方向
		var dir: Vector2 = caster.position.direction_to(target.global_position)

		get_tree().create_timer(delay).timeout.connect(func():
			shuriken_pool.spawn(
				caster, target, damage,
				_int_to_damage_type_string(skill_def.damage_type),
				skill_id, skill_signal_bus, dir, valid
			)
		)

	skill_signal_bus.skill_cast_finished.emit(caster, skill_id)


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
