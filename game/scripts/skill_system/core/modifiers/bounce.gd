## BounceModifier — 弹射修改器
## 命中目标后转向最近敌人继续飞行
class_name BounceModifier
extends SkillModifier

func _init():
	modifier_id = "bounce"
	modifier_type = 1  # LIFETIME
	priority = 60
	trigger_timing = 1  # ON_HIT
	max_bounces = 2

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
	chain.bounce_remaining = max_bounces
	# Projectile 在命中时会调用 chain.on_hit()，那里处理弹射逻辑
	# 这里只注册触发器（由 ProjectileNode 在命中时调用）
	return []
