# modifier_def.gd
# Modifier 数据定义（资源 C）
# 包含所有 Modifier 的配置参数

class_name ModifierDef
extends Resource

# ── 标识 ──
@export var modifier_id: String = ""
@export var display_name: String = ""

# ── 类型分类 ──
@export_enum("TRAJECTORY:0", "LIFETIME:1", "APPEARANCE:2", "BEHAVIOR:3", "CONDITIONAL:4")
var modifier_type: int = 0
@export_enum("ON_CAST:0", "ON_HIT:1", "TIME_ELAPSED:2", "DISTANCE_TRAVELED:3", "ON_EXPLODE:4")
var trigger_timing: int = 0
@export var priority: int = 100     # 越小越先执行

# ── 条件 ──
@export var condition_tag: String = ""  # 空 = 无条件激活

# ═══════════════════════════════════════════════════════════
# TRAJECTORY: 散射
# ═══════════════════════════════════════════════════════════
@export_group("Scatter (TRAJECTORY)")
@export var num_projectiles: int = 5
@export var fan_angle_deg: float = 60.0

# ═══════════════════════════════════════════════════════════
# TRAJECTORY: 曲线路径
# ═══════════════════════════════════════════════════════════
@export_group("CurvedPath (TRAJECTORY)")
@export_enum("BEZIER_QUAD:0", "BEZIER_CUBIC:1", "SINE_WAVE:2", "SPIRAL:3")
var curve_type: int = 0
@export var control_point_offset: float = 100.0
@export var travel_time_multiplier: float = 1.0

# ═══════════════════════════════════════════════════════════
# LIFETIME: 弹射
# ═══════════════════════════════════════════════════════════
@export_group("Bounce (LIFETIME)")
@export var max_bounces: int = 2

# ═══════════════════════════════════════════════════════════
# LIFETIME: 分裂
# ═══════════════════════════════════════════════════════════
@export_group("Fission (LIFETIME)")
@export var half_life_distance: float = 150.0
@export var split_count: int = 2
@export var scale_factor: float = 0.7
@export var damage_factor: float = 0.6
@export var split_angle_spread_deg: float = 30.0

# ═══════════════════════════════════════════════════════════
# APPEARANCE: 膨胀
# ═══════════════════════════════════════════════════════════
@export_group("Expansion (APPEARANCE)")
@export var size_growth_per_distance: float = 0.02
@export var max_scale: float = 3.0

# ═══════════════════════════════════════════════════════════
# LIFETIME: 投射物 HP
# ═══════════════════════════════════════════════════════════
@export_group("ProjectileHP (LIFETIME)")
@export var projectile_hp: float = 100.0
@export var destroy_on_hp_zero: bool = true

# ═══════════════════════════════════════════════════════════
# BEHAVIOR: 命中减速
# ═══════════════════════════════════════════════════════════
@export_group("SlowOnHit (BEHAVIOR)")
@export var slow_factor: float = 0.5
@export var slow_duration: float = 2.0

# ═══════════════════════════════════════════════════════════
# CONDITIONAL: 条件压制
# ═══════════════════════════════════════════════════════════
@export_group("ConditionalSuppress (CONDITIONAL)")
@export var suppressed_modifier_ids: Array[String] = []

# ── 验证 ──
func is_valid() -> bool:
	return modifier_id != ""

# ── 辅助方法 ──
func get_modifier_type_name() -> String:
	match modifier_type:
		0: return "TRAJECTORY"
		1: return "LIFETIME"
		2: return "APPEARANCE"
		3: return "BEHAVIOR"
		4: return "CONDITIONAL"
	return "UNKNOWN"

func get_trigger_timing_name() -> String:
	match trigger_timing:
		0: return "ON_CAST"
		1: return "ON_HIT"
		2: return "TIME_ELAPSED"
		3: return "DISTANCE_TRAVELED"
		4: return "ON_EXPLODE"
	return "ON_CAST"

func get_priority_description() -> String:
	if priority <= 0:
		return "FIRST (ConditionalSuppress)"
	elif priority < 20:
		return "EARLY (Scatter, CurvedPath)"
	elif priority < 60:
		return "MIDDLE (Fission, Bounce)"
	elif priority < 90:
		return "LATE (Expansion)"
	else:
		return "LAST (ProjectileHP)"
