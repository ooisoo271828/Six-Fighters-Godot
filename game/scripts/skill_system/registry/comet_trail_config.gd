# comet_trail_config.gd
# Line2D 三层实线彗星拖尾配置
class_name CometTrailConfig
extends Resource

@export var enabled: bool = false
@export var max_samples: int = 28
## 蛇形摆动频率
@export var sway_freq: float = 0.7
## 蛇形摆动幅度
@export var sway_amplitude: float = 1.1
## 沿长度方向的宽度曲线。留空 = 使用默认锥形衰减
@export var width_curve: Curve

# ── 外层 ──
@export_group("Outer Layer")
@export var outer_width: float = 6.0
@export var outer_color: Color = Color.WHITE
@export var outer_alpha: float = 0.35

# ── 中层 ──
@export_group("Mid Layer")
@export var mid_width: float = 3.4
@export var mid_color: Color = Color.WHITE
@export var mid_alpha: float = 0.62

# ── 内层 ──
@export_group("Inner Layer")
@export var inner_width: float = 1.8
@export var inner_color: Color = Color.WHITE
@export var inner_alpha: float = 0.96

func is_enabled() -> bool:
	return enabled

## 获取默认宽度曲线（锥形衰减）
static func build_default_width_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.1, 0.98))
	curve.add_point(Vector2(0.25, 0.85))
	curve.add_point(Vector2(0.40, 0.65))
	curve.add_point(Vector2(0.55, 0.45))
	curve.add_point(Vector2(0.70, 0.25))
	curve.add_point(Vector2(0.82, 0.12))
	curve.add_point(Vector2(0.92, 0.04))
	curve.add_point(Vector2(1.0, 0.0))
	return curve

static func get_default() -> CometTrailConfig:
	return CometTrailConfig.new()
