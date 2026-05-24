## EmitMeteorEffect — 流星坠落 Effect
## 从屏幕外右上方向目标位置发射一颗流星，命中后触发 AOE 伤害
## v1.0
class_name EmitMeteorEffect
extends SkillEffect

## 坠落持续时间（秒）
const FALL_DURATION := 1.2

func _init():
	effect_id = "emit_meteor"
	effect_type = EffectType.EMIT_PROJECTILE

func execute(context: SkillEffect.SkillExecutionContext) -> Array[ExecutionChain]:
	# 计算流星起点：目标位置右上方的屏幕外
	var target_pos := context.target_pos
	var fall_dist_h := context.hit_aoe_radius * 6.0  # 水平偏移
	var fall_dist_v := context.hit_aoe_radius * 4.5  # 垂直偏移
	var spawn_pos := Vector2(
		target_pos.x + fall_dist_h,
		target_pos.y - fall_dist_v
	)

	# 方向向量：起点 → 目标
	var direction := spawn_pos.direction_to(target_pos)

	# 速度：在 FALL_DURATION 秒内到达目标
	var travel_dist := spawn_pos.distance_to(target_pos)
	var speed_val := travel_dist / FALL_DURATION

	var chain := _create_chain(context)

	# 重写起点、方向、速度
	chain.position = spawn_pos
	chain.direction = direction
	chain.speed = speed_val

	# 取消追踪，使用直线轨迹
	chain.tracking_enabled = false
	chain.trajectory_type = 0  # LINEAR

	# 命中精度
	chain.hit_precision_radius = 20.0

	# 只有一个流星
	chain.scale = 1.0
	chain.current_radius = 24.0
	chain.base_radius = 24.0

	# 可选：调整伤害，略微上浮以符合范围技能定位
	chain.damage = context.damage

	return [chain]
