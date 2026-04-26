## ConditionEvaluator — 条件评估器
## 所有 Modifier 的激活条件由此类统一评估
class_name ConditionEvaluator
extends Node

## 条件标签 → 评估函数 的映射
## 可在运行时动态注册新条件
var _condition_map: Dictionary = {
	"always": _eval_always,
	"never": _eval_never,
}

func _ready() -> void:
	# 注册内置条件
	register_condition("always", _eval_always)
	register_condition("never", _eval_never)
	# TODO: 注册游戏特定条件
	# register_condition("in_boss_aura", _eval_in_boss_aura)
	# register_condition("hp_below_50", _eval_hp_below_50)

## 注册新条件（供其他系统调用）
func register_condition(tag: String, eval_func: Callable) -> void:
	_condition_map[tag] = eval_func

## 评估条件标签
static func evaluate(tag: String, caster: Node2D) -> bool:
	# 使用单例评估（如果已初始化）
	var eval := _get_singleton()
	if eval and eval._condition_map.has(tag):
		return eval._condition_map[tag].call(caster)
	return false

## 获取评估器单例
static func _get_singleton() -> ConditionEvaluator:
	var root = Engine.get_main_loop().root
	if root.has_node("/root/ConditionEvaluator"):
		return root.get_node("/root/ConditionEvaluator")
	# 临时创建
	var e := ConditionEvaluator.new()
	e.name = "ConditionEvaluator"
	root.add_child(e)
	return e

## ── 内置条件 ──

static func _eval_always(_caster: Node2D) -> bool:
	return true

static func _eval_never(_caster: Node2D) -> bool:
	return false

## ── 示例：可扩展的游戏特定条件 ──

static func _eval_in_boss_aura(_caster: Node2D) -> bool:
	# 需要 AuraManager 支持
	# return AuraManager.is_caster_in_aura(caster, "boss_suppression")
	return false

static func _eval_hp_below_50(caster: Node2D) -> bool:
	if caster and caster.has_method("get_hp_ratio"):
		return caster.get_hp_ratio() < 0.5
	return false
