## SkillModifier — 技能修改器基类
## 所有 Modifier 继承此类，通过 apply() 方法修改 ExecutionChain
class_name SkillModifier
extends RefCounted

## ── 属性 ──
var modifier_id: String = ""
var modifier_type: int = 0  # ModifierType.TRAJECTORY 等常量
var priority: int = 100        # 越小越先执行
var trigger_timing: int = 0     # TriggerTiming.ON_CAST 等常量
var _suppressed: bool = false
var condition_tag: String = ""  # 条件标签，空=无条件

# ═══════════════════════════════════════════════════════════
# TRAJECTORY: 散射
# ═══════════════════════════════════════════════════════════
var num_projectiles: int = 5
var fan_angle_deg: float = 60.0

# ═══════════════════════════════════════════════════════════
# TRAJECTORY: 曲线路径
# ═══════════════════════════════════════════════════════════
var curve_type: int = 0  # CurveType.BEZIER_QUAD 等常量
var control_point_offset: float = 100.0
var travel_time_multiplier: float = 1.0

# ═══════════════════════════════════════════════════════════
# LIFETIME: 弹射
# ═══════════════════════════════════════════════════════════
var max_bounces: int = 2

# ═══════════════════════════════════════════════════════════
# LIFETIME: 分裂
# ═══════════════════════════════════════════════════════════
var half_life_distance: float = 150.0
var split_count: int = 2
var scale_factor: float = 0.7
var damage_factor: float = 0.6
var split_angle_spread_deg: float = 30.0

# ═══════════════════════════════════════════════════════════
# APPEARANCE: 膨胀
# ═══════════════════════════════════════════════════════════
var size_growth_per_distance: float = 0.02
var max_scale: float = 3.0

# ═══════════════════════════════════════════════════════════
# LIFETIME: 投射物 HP
# ═══════════════════════════════════════════════════════════
var projectile_hp: float = 100.0
var destroy_on_hp_zero: bool = true

# ═══════════════════════════════════════════════════════════
# BEHAVIOR: 命中减速
# ═══════════════════════════════════════════════════════════
var slow_factor: float = 0.5
var slow_duration: float = 2.0

# ═══════════════════════════════════════════════════════════
# CONDITIONAL: 条件压制
# ═══════════════════════════════════════════════════════════
var suppressed_modifier_ids: Array[String] = []

## ── 核心接口 ──
## apply() 是 Modifier 的核心方法
## 返回新产生的子链列表（无新链时返回空数组）
func apply(_chain: ExecutionChain) -> Array[ExecutionChain]:
	return []

## ── 激活检查 ──
func is_active(caster: Node2D) -> bool:
	if _suppressed:
		return false
	if condition_tag == "":
		return true
	return ConditionEvaluator.evaluate(condition_tag, caster)

## ── 压制指定 Modifier ──
func suppress(_modifier_id_to_suppress: String) -> void:
	_suppressed = true

## ── 工具函数 ──

## 获取触发时机字符串
func get_trigger_timing_string() -> String:
	match trigger_timing:
		0: return "ON_CAST"
		1: return "ON_HIT"
		2: return "TIME_ELAPSED"
		3: return "DISTANCE_TRAVELED"
		4: return "ON_EXPLODE"
	return "ON_CAST"

## 获取 Modifier 类型字符串
func get_modifier_type_string() -> String:
	match modifier_type:
		0: return "TRAJECTORY"
		1: return "LIFETIME"
		2: return "APPEARANCE"
		3: return "BEHAVIOR"
		4: return "CONDITIONAL"
	return "TRAJECTORY"

## 移除栈中的某个 Modifier 类型（防止重复）
func _remove_modifier_from_stack(stack: Array[SkillModifier], mod_id: String) -> Array[SkillModifier]:
	var result: Array[SkillModifier]
	for m in stack:
		if m.modifier_id != mod_id:
			result.append(m)
	return result

## ── Chain ID 生成器（全局） ──
var _chain_id_counter: int = 0
func _generate_chain_id() -> int:
	_chain_id_counter += 1
	return _chain_id_counter
