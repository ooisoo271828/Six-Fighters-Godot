## ProjectileHPModifier — 抛射物生命值修改器
## 抛射物有血量，可被敌对伤害打爆
class_name ProjectileHPModifier
extends SkillModifier

func _init():
	modifier_id = "projectile_hp"
	modifier_type = 1  # LIFETIME
	priority = 100
	trigger_timing = 0  # ON_CAST
	# 设置默认值（使用父类的 projectile_hp）
	projectile_hp = 100.0
	destroy_on_hp_zero = true

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
	chain.projectile_hp = projectile_hp
	chain.can_be_targeted = true
	return []
