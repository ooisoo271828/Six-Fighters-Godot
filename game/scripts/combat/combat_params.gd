class_name CombatParams
extends Resource

## 战斗参数 - 对应 Web 版本的 CombatParams 类型

# 命中判定参数
var hit_chance_min: float
var hit_chance_max: float
var hit_chance_slope: float
var hit_chance_bias: float
var glancing_min: float
var glancing_max: float
var deflect_mult: float

# 命中圆桌
var hit_roundtable_softmax_k: float
var hit_roundtable_min_prob: float
var hit_roundtable_min_outcomes: float

# 暴击参数
var crit_chance_min: float
var crit_chance_max: float
var crit_chance_base: float
var crit_chance_rate_scale: float
var crit_multiplier_min: float
var crit_multiplier_max: float
var crit_multiplier_base: float
var crit_multiplier_power: float

# 元素抗性
var element_damage_multiplier_min: float
var element_damage_multiplier_max: float
var element_damage_multiplier_base: float
var element_damage_multiplier_scale: float

# DOT 参数
var dot_tick_interval_sec: float

# Burn
var burn_duration_base: float
var burn_duration_per_stack: float
var burn_stack_max: int
var burn_dot_ratio_base: float
var burn_dot_ratio_per_stack: float

# Frost
var frost_duration_base: float
var frost_duration_per_stack: float
var frost_stack_max: int
var frost_dot_ratio_base: float
var frost_dot_ratio_per_stack: float
var frost_cc_slow_per_stack: float
var frost_cc_slow_max: float

# Poison
var poison_duration_base: float
var poison_duration_per_stack: float
var poison_stack_max: int
var poison_dot_ratio_base: float
var poison_dot_ratio_per_stack: float

# Shock
var shock_duration_base: float
var shock_duration_per_stack: float
var shock_stack_max: int
var shock_damage_taken_min: float
var shock_damage_taken_max: float
var shock_damage_taken_base: float
var shock_damage_taken_per_stack: float

# Stun
var stun_resistance_offset: float
var stun_duration_multiplier_base: float
var stun_duration_multiplier_scale: float
var stun_duration_multiplier_min: float
var stun_duration_multiplier_max: float
var stun_duration_min_sec: float
var stun_duration_max_sec: float
