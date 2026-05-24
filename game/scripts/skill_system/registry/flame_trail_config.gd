# flame_trail_config.gd
# 向前前缘火焰粒子配置
class_name FlameTrailConfig
extends Resource

@export var enabled: bool = false
@export var count: int = 12
@export var inner_min: float = 1.2
@export var inner_max: float = 5.5
@export var outer_min: float = 5.5
@export var outer_max: float = 14.0
@export var color_1: Color = Color.WHITE
@export var color_2: Color = Color.WHITE
@export var life_min: float = 0.1
@export var life_max: float = 0.195
## 自定义纹理路径。留空 = 使用程序化 CIRCLE
@export var texture_path: String = ""

func is_enabled() -> bool:
	return enabled

static func get_default() -> FlameTrailConfig:
	return FlameTrailConfig.new()
