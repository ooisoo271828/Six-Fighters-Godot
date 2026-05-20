# impact_visual.gd
# 命中爆发子 Resource — 火花、震屏、命中特效
class_name ImpactVisual
extends Resource

# ── 命中火花 ──
@export_group("Spark Burst")
@export var spark_count_min: int = 10
@export var spark_count_max: int = 14
@export var spark_speed_min: float = 24.0
@export var spark_speed_max: float = 72.0
@export var spark_life_min: float = 0.12
@export var spark_life_max: float = 0.22
@export var spark_color: Color = Color.WHITE
@export var spark_particle_count: int = 20
@export var spark_lifetime: float = 0.4
@export var spark_radius_mult: float = 2.0

# ── 震屏 ──
@export_group("Screen Effects")
@export var shake_strength: float = 0.0
@export var shake_duration: float = 0.0

# ── 命中特效类型 ──
@export var impact_effect_kind: String = "spark"
