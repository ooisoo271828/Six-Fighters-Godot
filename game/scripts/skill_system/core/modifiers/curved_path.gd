## CurvedPathModifier — 曲线路径修改器
## 抛射物走贝塞尔曲线/正弦波等路径，而非直线
class_name CurvedPathModifier
extends SkillModifier

const CURVE_BEZIER_QUAD: int = 0
const CURVE_BEZIER_CUBIC: int = 1
const CURVE_SINE_WAVE: int = 2
const CURVE_SPIRAL: int = 3

var wave_amplitude: float = 30.0          # 正弦振幅（子类独有）
var wave_frequency: float = 2.0           # 正弦频率（子类独有）

func _init():
	modifier_id = "curved_path"
	modifier_type = 0  # TRAJECTORY
	priority = 20
	trigger_timing = 0  # ON_CAST
	# 设置默认值
	curve_type = 0  # CURVE_BEZIER_QUAD
	control_point_offset = 100.0
	travel_time_multiplier = 1.5

func apply(chain: ExecutionChain) -> Array[ExecutionChain]:
	chain.trajectory_type = curve_type
	chain.control_point_offset = control_point_offset
	chain.travel_time_multiplier = travel_time_multiplier
	# 不产生新链，只修改母链的运动算法
	return []
