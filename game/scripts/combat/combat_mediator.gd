## CombatMediator — 战斗循环编排器
## 由各战斗场景实例化为子节点，编排英雄/敌人的战斗循环
## 包含：目标选择、AI tick、技能施放分流（即时/投射物）、伤害结算、DOT、清理
class_name CombatMediator
extends Node

# ── 战斗常量 ──
const ATTACK_RANGE := 155.0
const ENEMY_SPEED := 95.0
const ENEMY_RANGED_RANGE := 280.0
const ENEMY_MELEE_RANGE := 80.0

# ── 信号 ──
signal all_heroes_dead
signal damage_dealt(target: Node2D, amount: float, is_crit: bool, hit_outcome: int, damage_type: int, is_player_target: bool)

# ── 配置 ──
var combat_params: CombatParams
var rng_func: Callable

# ── 单位列表 ──
var heroes: Array[Hero] = []
var enemies: Array[Enemy] = []

# ── 系统引用 ──
var skill_system: Node
var skill_signal_bus: Node

func setup(p_combat_params: CombatParams, p_rng_func: Callable) -> void:
	combat_params = p_combat_params
	rng_func = p_rng_func


func register_heroes(p_heroes: Array[Hero]) -> void:
	heroes = p_heroes


func register_enemies(p_enemies: Array[Enemy]) -> void:
	enemies = p_enemies


func set_skill_system(p_skill_system: Node) -> void:
	skill_system = p_skill_system
	skill_signal_bus = skill_system.skill_signal_bus if skill_system else null
	if skill_signal_bus:
		skill_signal_bus.skill_hit.connect(_on_projectile_hit)


# ══════════════════════════════════════════
#  主更新（由场景 _process 调用）
# ══════════════════════════════════════════

func update(delta: float) -> void:
	_update_dots(delta)
	_update_hero_combat(delta)
	_update_enemy_combat(delta)
	_cleanup_dead()


# ══════════════════════════════════════════
#  DOT / 状态效果
# ══════════════════════════════════════════

func _update_dots(dt: float) -> void:
	var dot_interval: float = combat_params.dot_tick_interval_sec
	for hero in heroes:
		if hero and is_instance_valid(hero) and hero.is_alive:
			hero.status_effects.tick(dt, dot_interval, func(dmg: float) -> void:
				hero.take_damage(dmg)
				damage_dealt.emit(hero, dmg, false, CombatResolver.HitOutcome.HIT, CombatResolver.DamageType.ELEMENTAL_POISON, true)
			)
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and enemy.is_alive:
			enemy.status_effects.tick(dt, dot_interval, func(dmg: float) -> void:
				enemy.take_damage(dmg)
				damage_dealt.emit(enemy, dmg, false, CombatResolver.HitOutcome.HIT, CombatResolver.DamageType.ELEMENTAL_POISON, false)
			)


# ══════════════════════════════════════════
#  英雄战斗循环
# ══════════════════════════════════════════

func _update_hero_combat(dt: float) -> void:
	for hero in heroes:
		if not (hero and is_instance_valid(hero) and hero.is_alive):
			continue
		if hero.status_effects.is_stunned():
			continue
		var nearest_enemy: Enemy = TargetSelector.find_nearest_alive_enemy(hero.position, enemies)
		if not nearest_enemy:
			continue
		# AI 决策仍需要一个参考目标
		var pick: RoleAI.AutonomyPick = hero.tick_ai(dt, nearest_enemy, combat_params, rng_func)
		if not pick:
			continue

		# 获取技能定义
		var skill_def: Resource = null
		if skill_system and skill_system.has_method("get_skill_def"):
			skill_def = skill_system.get_skill_def(pick.skill.skill_id)

		# 目标选择由 SkillSystem 内部根据 SkillDef 配置完成
		var alive_enemies := get_alive_enemies()
		skill_system.cast_skill(hero, pick.skill.skill_id, alive_enemies)

		# 即时伤害：用 SkillSystem 选出的目标（最近的）做结算
		var delivery: String = skill_def.delivery_type if skill_def and skill_def.get("delivery_type") else "projectile"
		if delivery == "instant":
			var cast_range: float = skill_def.cast_range if skill_def and skill_def.get("cast_range") else ATTACK_RANGE
			var instant_target: Node2D = TargetSelector.find_nearest_in_range(hero.position, alive_enemies, cast_range)
			if instant_target:
				_resolve_and_apply_damage(hero, instant_target, pick.skill)


## 即时伤害结算
func _resolve_and_apply_damage(attacker: Node2D, target: Node2D, skill_def: Resource) -> void:
	var result := CombatResolver.resolve_attack(
		attacker.stats, target.stats,
		skill_def.base_damage, skill_def.damage_type,
		skill_def.stun_chance if skill_def.stun_chance else 0.0,
		skill_def.stun_duration if skill_def.stun_duration else 0.0,
		combat_params, rng_func,
		target.status_effects.get_shock_stacks_for_resolution()
	)
	damage_dealt.emit(target, result.instant_damage, result.crit, result.hit_outcome, skill_def.damage_type, false)
	target.take_damage(result.instant_damage)
	if attacker.get("timers") and attacker.timers.get("rage") != null:
		attacker.timers.rage = minf(100.0, attacker.timers.rage + result.instant_damage * 0.15)
	target.apply_status_updates(result.status_updates, combat_params)


## 投射物命中时伤害结算（连接 skill_signal_bus.skill_hit）
func _on_projectile_hit(caster: Node2D, targets: Array, damage_info: Dictionary) -> void:
	if targets.is_empty():
		return
	var target: Node2D = targets[0]
	if not (target and is_instance_valid(target)):
		return
	if not (caster and is_instance_valid(caster)):
		return

	var damage: float = damage_info.get("damage", 0.0)
	var damage_type_str: String = damage_info.get("damage_type", "physical")
	var skill_id: String = damage_info.get("skill_id", "")

	# 读取 skill_def 中的附加参数
	var skill_def: Resource = null
	if skill_system and skill_system.has_method("get_skill_def"):
		skill_def = skill_system.get_skill_def(skill_id)

	var base_damage: float = damage
	var dmg_type: int = _string_to_damage_type(damage_type_str)
	var stun_chance: float = skill_def.stun_chance if skill_def and skill_def.get("stun_chance") else 0.0
	var stun_duration: float = skill_def.stun_duration if skill_def and skill_def.get("stun_duration") else 0.0

	var result := CombatResolver.resolve_attack(
		caster.stats, target.stats,
		base_damage, dmg_type,
		stun_chance, stun_duration,
		combat_params, rng_func,
		target.status_effects.get_shock_stacks_for_resolution()
	)
	var is_player_target := target is Hero
	damage_dealt.emit(target, result.instant_damage, result.crit, result.hit_outcome, dmg_type, is_player_target)
	target.take_damage(result.instant_damage)
	if caster.get("timers") and caster.timers.get("rage") != null:
		caster.timers.rage = minf(100.0, caster.timers.rage + result.instant_damage * 0.15)
	target.apply_status_updates(result.status_updates, combat_params)

	# AOE on hit
	var aoe_radius: float = damage_info.get("hit_aoe_radius", 0.0)
	if aoe_radius > 0.0:
		var hit_pos: Vector2 = damage_info.get("hit_pos", target.global_position)
		_apply_aoe_damage(hit_pos, aoe_radius, caster, target, base_damage, dmg_type, stun_chance, stun_duration)

	# 混合伤害：副伤害类型（如 50% 物理 + 50% 火焰）
	var sec_type: int = damage_info.get("secondary_damage_type", -1)
	if sec_type >= 0:
		var sec_damage: float = damage_info.get("secondary_damage", 0.0)
		if sec_damage > 0.0:
			var sec_result := CombatResolver.resolve_attack(
				caster.stats, target.stats,
				sec_damage, sec_type,
				stun_chance, stun_duration,
				combat_params, rng_func,
				target.status_effects.get_shock_stacks_for_resolution()
			)
			var is_player_target_sec := target is Hero
			damage_dealt.emit(target, sec_result.instant_damage, sec_result.crit, sec_result.hit_outcome, sec_type, is_player_target_sec)
			target.take_damage(sec_result.instant_damage)
			target.apply_status_updates(sec_result.status_updates, combat_params)

			# AOE 也应用副伤害
			if aoe_radius > 0.0:
				var hit_pos_sec: Vector2 = damage_info.get("hit_pos", target.global_position)
				for enemy in enemies:
					if not (enemy and is_instance_valid(enemy) and enemy.is_alive):
						continue
					if enemy == target:
						continue
					var dist: float = hit_pos_sec.distance_to(enemy.position)
					if dist > aoe_radius:
						continue
					var sec_aoe_result := CombatResolver.resolve_attack(
						caster.stats, enemy.stats,
						sec_damage, sec_type,
						stun_chance, stun_duration,
						combat_params, rng_func,
						enemy.status_effects.get_shock_stacks_for_resolution()
					)
					damage_dealt.emit(enemy, sec_aoe_result.instant_damage, sec_aoe_result.crit, sec_aoe_result.hit_outcome, sec_type, false)
					enemy.take_damage(sec_aoe_result.instant_damage)
					enemy.apply_status_updates(sec_aoe_result.status_updates, combat_params)


## AOE damage on projectile hit (excludes the primary target)
func _apply_aoe_damage(hit_pos: Vector2, radius: float, caster: Node2D, primary_target: Node2D, base_damage: float, dmg_type: int, stun_chance: float, stun_duration: float) -> void:
	for enemy in enemies:
		if not (enemy and is_instance_valid(enemy) and enemy.is_alive):
			continue
		if enemy == primary_target:
			continue
		var dist: float = hit_pos.distance_to(enemy.position)
		if dist > radius:
			continue
		var result := CombatResolver.resolve_attack(
			caster.stats, enemy.stats,
			base_damage, dmg_type,
			stun_chance, stun_duration,
			combat_params, rng_func,
			enemy.status_effects.get_shock_stacks_for_resolution()
		)
		damage_dealt.emit(enemy, result.instant_damage, result.crit, result.hit_outcome, dmg_type, false)
		enemy.take_damage(result.instant_damage)
		enemy.apply_status_updates(result.status_updates, combat_params)


func _string_to_damage_type(dt_str: String) -> int:
	match dt_str:
		"physical": return CombatResolver.DamageType.PHYSICAL
		"elemental_fire": return CombatResolver.DamageType.ELEMENTAL_FIRE
		"elemental_ice": return CombatResolver.DamageType.ELEMENTAL_ICE
		"elemental_lightning": return CombatResolver.DamageType.ELEMENTAL_LIGHTNING
		"elemental_poison": return CombatResolver.DamageType.ELEMENTAL_POISON
	return CombatResolver.DamageType.PHYSICAL


# ══════════════════════════════════════════
#  敌人战斗循环
# ══════════════════════════════════════════

func _update_enemy_combat(dt: float) -> void:
	for enemy in enemies:
		if not (enemy and is_instance_valid(enemy) and enemy.is_alive):
			continue
		var target: Hero = TargetSelector.find_nearest_alive_hero(enemy.position, heroes)
		if not target:
			continue
		var skill_id: String = enemy.get_meta("skill_id", "")
		var attack_range: float = enemy.get_meta("attack_range", ENEMY_MELEE_RANGE)
		var dist: float = enemy.position.distance_to(target.position)
		if dist > attack_range:
			var dir := (target.position - enemy.position).normalized()
			enemy.position += dir * ENEMY_SPEED * dt
			continue
		if enemy.tick_ai(dt, target):
			if skill_id != "" and skill_system and skill_system.has_method("cast_skill"):
				var alive_heroes := get_alive_heroes()
				skill_system.cast_skill(enemy, skill_id, alive_heroes)
			else:
				# 旧版回退：无 skill_id 的敌人走即时伤害
				var result := CombatResolver.resolve_attack(
					enemy.stats, target.stats,
					enemy.base_attack, CombatResolver.DamageType.PHYSICAL,
					0.0, 0.0, combat_params, rng_func,
					target.status_effects.get_shock_stacks_for_resolution()
				)
				damage_dealt.emit(target, result.instant_damage, result.crit, result.hit_outcome, CombatResolver.DamageType.PHYSICAL, true)
				target.take_damage(result.instant_damage)


# ══════════════════════════════════════════
#  清理死亡单位
# ══════════════════════════════════════════

func _cleanup_dead() -> void:
	heroes = heroes.filter(func(h): return h and is_instance_valid(h) and h.is_alive)
	enemies = enemies.filter(func(e): return e and is_instance_valid(e) and e.is_alive)
	if heroes.is_empty():
		all_heroes_dead.emit()


# ══════════════════════════════════════════
#  公共查询接口
# ══════════════════════════════════════════

func get_alive_enemies() -> Array:
	return enemies.filter(func(e): return e and is_instance_valid(e) and e.is_alive)


func get_alive_heroes() -> Array:
	return heroes.filter(func(h): return h and is_instance_valid(h) and h.is_alive)
