## ExecutionChain — 技能执行链（状态载体）
## 每条叶子链代表一个抛射物路径，承载该路径的所有运行时状态
class_name ExecutionChain
extends RefCounted

## ── 基础信息 ──
var chain_id: int = 0
var effect: SkillEffect
var effect_id: String = ""

## ── 角色信息 ──
var caster: Node2D
var target: Node2D
var target_pos: Vector2

## ── 运动参数 ──
var position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var distance_traveled: float = 0.0
var travel_time_multiplier: float = 1.0
var spawn_delay: float = 0.0          # 发射延迟（实现子弹 staggered launch）

## 轨迹类型（CurvedPath 决定）
var trajectory_type: int = 0  # 0=直线，1+=曲线类型枚举
var control_point_offset: float = 100.0

## ── 伤害参数 ──
var damage: float = 0.0
var damage_type: String = "physical"
var base_damage: float = 0.0  # 用于计算分裂后伤害比例
var skill_id: String = ""

## ── 外观参数 ──
var scale: float = 1.0
var base_scale: float = 1.0
var current_radius: float = 4.0
var base_radius: float = 4.0
var color_override: Color = Color.WHITE

## ── 抛射物生命值 ──
var projectile_hp: float = 0.0  # 0 = 不可破坏
var can_be_targeted: bool = false

## ── 膨胀参数（ExpansionModifier 设置，ProjectileNode 每帧读取） ──
var expansion_growth_rate: float = 0.0  # 0 = 无膨胀
var expansion_max_scale: float = 3.0

## ── 正弦波参数（CurvedPathModifier 设置） ──
var wave_amplitude: float = 0.0
var wave_frequency: float = 2.0

## ── Modifier 栈 ──
var modifier_stack: Array[SkillModifier]
var modifier_index: int = 0  # 已处理到第几个 Modifier

## ── 子链（Modifier 可能添加） ──
var child_chains: Array[ExecutionChain]
var parent_chain: ExecutionChain  # 父链引用

## ── 行为状态 ──
## Flying / Hit / Exploded / Fading / Destroyed
var behavior_state: String = "Flying"

## ── 触发器 ──
var _time_triggers: Array[Dictionary]
var _distance_triggers: Array[Dictionary]
var _hit_triggers: Array[Dictionary]

## ── 追踪参数 ──
var tracking_enabled: bool = false
var turn_rate: float = 0.0              # rad/s，方向修正最大角速度
var hit_precision_radius: float = 0.0   # 命中精准范围，0 = 精确碰撞

## ── 穿透参数 ──
var pierce_enabled: bool = false
var pierce_count: int = 0               # -1 = 无限穿透
var hit_targets: Array[Node2D] = []     # 已命中目标列表（穿透模式防重复）

## ── 弹射参数 ──
var bounce_damage_scale: float = 1.0

## AOE on hit
var hit_aoe_radius: float = 0.0    # 弹射伤害系数

## ── 伤害上下文（命中时供 CombatMediator 使用） ──
var skill_def_ref: Resource             # 引用 SkillDef
var enemy_query_func: Callable
var available_targets: Array = []  # for multi-target seeking          # () -> Array[Node2D]，弹射目标查询回调

## ── 临时状态（在 ProjectileNode 中使用） ──
var elapsed_time: float = 0.0
var hit_count: int = 0
var bounce_remaining: int = 0

## ── 信号 ──
signal chain_hit(chain: ExecutionChain, hit_target: Node2D)
signal chain_destroyed(chain: ExecutionChain)

## ── 触发器注册 API ──

func add_time_trigger(time_sec: float, callback: Callable) -> void:
	_time_triggers.append({"time": time_sec, "callback": callback, "triggered": false})

func add_distance_trigger(dist: float, callback: Callable) -> void:
	_distance_triggers.append({"dist": dist, "callback": callback, "triggered": false})

func add_hit_trigger(callback: Callable) -> void:
	_hit_triggers.append({"callback": callback})

## ── 触发器检查（在 ProjectileNode._process 中调用） ──

func check_triggers(dt: float) -> void:
	elapsed_time += dt

	# 时间触发
	for t in _time_triggers:
		if not t.get("triggered", false) and elapsed_time >= t["time"]:
			t["triggered"] = true
			t["callback"].call(self)

	# 距离触发
	for d in _distance_triggers:
		if not d.get("triggered", false) and distance_traveled >= d["dist"]:
			d["triggered"] = true
			d["callback"].call(self)

## ── 命中处理 ──

func on_hit(_hit_target: Node2D) -> void:
	hit_count += 1
	chain_hit.emit(self, _hit_target)
	for t in _hit_triggers:
		t["callback"].call(self, _hit_target)

## ── 链操作 API ──

func duplicate() -> ExecutionChain:
	var c := ExecutionChain.new()
	c.chain_id = 0  # 由 SkillRoot 分配
	c.effect = effect
	c.effect_id = effect_id
	c.caster = caster
	c.target = target
	c.target_pos = target_pos
	c.position = position
	c.direction = direction
	c.speed = speed
	c.distance_traveled = 0.0
	c.travel_time_multiplier = travel_time_multiplier
	c.spawn_delay = spawn_delay
	c.trajectory_type = trajectory_type
	c.control_point_offset = control_point_offset
	c.damage = damage
	c.damage_type = damage_type
	c.base_damage = base_damage
	c.skill_id = skill_id
	c.scale = scale
	c.base_scale = base_scale
	c.current_radius = current_radius
	c.base_radius = base_radius
	c.color_override = color_override
	c.projectile_hp = projectile_hp
	c.can_be_targeted = can_be_targeted
	c.expansion_growth_rate = expansion_growth_rate
	c.expansion_max_scale = expansion_max_scale
	c.wave_amplitude = wave_amplitude
	c.wave_frequency = wave_frequency
	c.modifier_stack = modifier_stack.duplicate()
	c.modifier_index = modifier_index
	c.parent_chain = self
	c.tracking_enabled = tracking_enabled
	c.turn_rate = turn_rate
	c.hit_precision_radius = hit_precision_radius
	c.pierce_enabled = pierce_enabled
	c.pierce_count = pierce_count
	c.bounce_damage_scale = bounce_damage_scale
	c.hit_aoe_radius = hit_aoe_radius
	c.skill_def_ref = skill_def_ref
	c.enemy_query_func = enemy_query_func
	c.available_targets = available_targets
	return c

func add_child(new_chain: ExecutionChain) -> void:
	child_chains.append(new_chain)

func suppress_modifier(modifier_id: String) -> void:
	for mod in modifier_stack:
		if mod.modifier_id == modifier_id:
			mod._suppressed = true

func keep_alive() -> void:
	behavior_state = "Flying"

func destroy() -> void:
	if behavior_state == "Destroyed":
		return
	behavior_state = "Destroyed"
	chain_destroyed.emit(self)

func explode() -> void:
	behavior_state = "Exploded"
	chain_destroyed.emit(self)

## ── 弹射 ──

func reroute_to_nearest_enemy(exclude: Node2D) -> bool:
	var enemies: Array = enemy_query_func.call() if enemy_query_func.is_valid() else []
	if enemies.is_empty():
		return false
	var next: Node2D = TargetSelector.find_nearest_excluding(position, enemies, exclude)
	if next:
		direction = position.direction_to(next.global_position)
		target = next
		target_pos = next.global_position
		return true
	return false

## ── 辅助 ──

func _to_string() -> String:
	return "Chain[%d/%s state=%s pos=%s speed=%.0f]" % [chain_id, effect_id, behavior_state, position, speed]
