# trail_def.gd
# 拖尾系统复合容器 — 持有各类型拖尾的可选子配置
# 每种子配置为 null 或 is_enabled()=false 表示不启用
class_name TrailDef
extends Resource

## 向后散射粒子（火球碎片、冰晶散射等）
@export var particles: ParticleTrailConfig

## 向前前缘火焰（火球头部燃烧）
@export var flame: FlameTrailConfig

## Line2D 三层实线彗星拖尾（冰箭流光、魔法尾迹）
@export var comet: CometTrailConfig

## 路径光点（毒雾轨迹、奥术印记）
@export var path_dots: PathDotConfig


func has_any_trail() -> bool:
	if particles and particles.is_enabled():
		return true
	if flame and flame.is_enabled():
		return true
	if comet and comet.is_enabled():
		return true
	if path_dots and path_dots.is_enabled():
		return true
	return false


static func get_default() -> TrailDef:
	return TrailDef.new()
