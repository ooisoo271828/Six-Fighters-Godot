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
## 粒子系统在弹体上的前向偏移（用于将粒子定位到弹尖）
@export var forward_offset: float = 0.0
## 浪头火花模式：在弹体前沿生成一排静止的弧形粒子，模拟浪花
@export var crest_mode: bool = false
## 浪头火花的横向宽度
@export var crest_width: float = 30.0
## 粒子缩放范围（浪头模式使用）
@export var particle_scale_min: float = 1.0
@export var particle_scale_max: float = 3.0

func is_enabled() -> bool:
	return enabled

static func get_default() -> FlameTrailConfig:
	return FlameTrailConfig.new()
