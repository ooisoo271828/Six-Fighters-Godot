# path_dot_config.gd
# 路径光点配置 — 沿飞行路径间隔生成的离散光点
class_name PathDotConfig
extends Resource

@export var enabled: bool = false
@export var interval: float = 0.04
@export var lifetime: float = 0.3
@export var color: Color = Color(1, 0.8, 0.4, 0.6)
@export var size: float = 0.25

func is_enabled() -> bool:
	return enabled

static func get_default() -> PathDotConfig:
	return PathDotConfig.new()
