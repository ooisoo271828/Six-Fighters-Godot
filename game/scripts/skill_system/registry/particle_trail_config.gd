# particle_trail_config.gd
# 向后散射粒子拖尾配置
class_name ParticleTrailConfig
extends Resource

@export var enabled: bool = false
@export var count: int = 8
@export var lifetime: float = 0.15
@export var back_dist_min: float = 20.0
@export var back_dist_max: float = 80.0
@export var spread_min: float = 28.0
@export var spread_max: float = 46.0
@export var radius_min: float = 0.3
@export var radius_max: float = 0.8
@export var color_1: Color = Color.WHITE
@export var color_2: Color = Color.WHITE
@export var color_3: Color = Color.WHITE
@export var life_min: float = 0.18
@export var life_max: float = 0.45
## 自定义粒子纹理路径。留空 = 使用程序化 SOFT_CIRCLE + color_ramp 着色
@export var texture_path: String = ""
## 缩放曲线（粒子生命周期内的大小变化）。留空 = 使用默认衰减曲线
@export var scale_curve: Curve

func is_enabled() -> bool:
	return enabled

static func get_default() -> ParticleTrailConfig:
	return ParticleTrailConfig.new()
