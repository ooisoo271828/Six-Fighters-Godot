## SkillSignalBus — 技能信号总线
## 所有技能事件的信号集中定义点
extends Node

## ── 施放相关 ──
@warning_ignore("unused_signal")
signal skill_cast_requested(caster: Node2D, skill_id: String, target: Node2D)
@warning_ignore("unused_signal")
signal skill_cast_started(caster: Node2D, skill_id: String, target_pos: Vector2)
@warning_ignore("unused_signal")
signal skill_cast_finished(caster: Node2D, skill_id: String)

## ── 命中相关 ──
@warning_ignore("unused_signal")
signal skill_hit(caster: Node2D, targets: Array, damage_info: Dictionary)
@warning_ignore("unused_signal")
signal skill_missed(caster: Node2D, target: Node2D)

## ── 投射物行为相关 ──
@warning_ignore("unused_signal")
signal behavior_spawned(projectile: Node2D, behavior_type: String, chain_data: Dictionary)
@warning_ignore("unused_signal")
signal behavior_update(projectile: Node2D, state: String, position: Vector2)
@warning_ignore("unused_signal")
signal behavior_complete(projectile: Node2D)
@warning_ignore("unused_signal")
signal behavior_interrupted(projectile: Node2D)

## ── 预警相关 ──
@warning_ignore("unused_signal")
signal telegraph_started(caster: Node2D, target_pos: Vector2, shape: String, duration: float)
@warning_ignore("unused_signal")
signal telegraph_finished(caster: Node2D, target_pos: Vector2)

## ── VFX 相关 ──
@warning_ignore("unused_signal")
signal vfx_request(effect_id: String, world_pos: Vector2, params: Dictionary)
@warning_ignore("unused_signal")
signal impact_effect(target: Node2D, impact_level: String)
@warning_ignore("unused_signal")
signal projectile_hit_damaged(projectile: Node2D, damage: float, remaining_hp: float)

func _ready() -> void:
	print("[SkillSignalBus] Ready")
