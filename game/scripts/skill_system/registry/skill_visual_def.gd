# skill_visual_def.gd
# 技能视觉数据定义基类
# 包含所有视觉和表现参数，与战斗数据分离
# v2.0：增强多层核心、抖动、前缘火焰、增强拖尾和爆炸参数

class_name SkillVisualDef
extends Resource

# ── 视觉标识 ──
@export var skill_id: String = ""

# ── 投射物类型 ──
@export_enum(
	"MECHANICAL_BULLET:0",
	"FIREBALL:1",
	"GHOST_FIRE_SKULL:2",
	"MISSILE_STORM:3",
	"ICE_CYCLONE:4",
	"CHAIN_LIGHTNING:5",
	"BURNING_HANDS:6",
	"ICE_RING:7",
	"PLASMA_BEAM:8"
)
var projectile_kind: int = 0

# ── 轨迹类型（映射 Web 版的 behavior） ──
@export_enum(
	"LINEAR:0",
	"HOMING:1",
	"BEZIER_QUAD:2",
	"BEZIER_CUBIC:3",
	"SINE_WAVE:4",
	"SPIRAL:5"
)
var trajectory_type: int = 0

# ── 时序参数 ──
@export var telegraph_ms: int = 350     # 预警显示时间（毫秒）
@export var travel_ms: int = 700       # 飞行持续时间（毫秒）

# ── 形状参数 ──
@export_enum("CIRCLE:0", "RECT:1", "FAN:2")
var telegraph_shape: int = 0
@export_enum("LIGHT:0", "MEDIUM:1", "STRONG:2", "CLIMAX:3")
var impact_level: int = 1

# ── 投射物外观 ──
@export var projectile_scale: float = 1.0
@export var projectile_color: Color = Color.WHITE
@export var trail_enabled: bool = true
@export var trail_color: Color = Color.WHITE
@export var trail_width: float = 2.0

# ── 命中特效 ──
@export var impact_effect_kind: String = "spark"

# ── 速度参数 ──
@export var speed: float = 300.0  # 投射物速度（像素/秒）

# ── 多弹道参数 ──
@export var projectile_count_min: int = 1
@export var projectile_count_max: int = 1
@export var projectile_stagger_sec: float = 0.0  # 每枚导弹的延迟间隔

# ═══════════════════════════════════════════
# ── 多层弹体核心 ──
# ═══════════════════════════════════════════
@export_group("Core Layers", "core_")

## 核心颜色
@export var core_color: Color = Color.WHITE
## 核心宽度（px），0 = 用 core_radius * 2
@export var core_width: float = 0.0
## 核心高度（px），0 = 用 core_radius * 2
@export var core_height: float = 0.0
## 核心半径（旧参数，向后兼容）
@export var core_radius: float = 4.0

# ── 内核层 ──
@export var core_inner_enabled: bool = false
@export var core_inner_color: Color = Color.WHITE
@export var core_inner_width: float = 0.0
@export var core_inner_height: float = 0.0
@export var core_inner_offset: Vector2 = Vector2.ZERO

# ── 热点层 ──
@export var core_hotspot_enabled: bool = false
@export var core_hotspot_color: Color = Color.WHITE
@export var core_hotspot_width: float = 0.0
@export var core_hotspot_height: float = 0.0
@export var core_hotspot_offset: Vector2 = Vector2.ZERO

# ── 弹尖 ──
@export var core_nose_enabled: bool = false
@export var core_nose_color: Color = Color.WHITE
@export var core_nose_length: float = 0.0
@export var core_nose_width: float = 0.0

# ── 摩擦光晕 ──
@export var core_glow_radius: float = 0.0  # 0 = 禁用
@export var core_glow_color: Color = Color.WHITE
@export var core_glow_alpha: float = 0.48

# ── 外层辉光（第二层光晕） ──
@export var core_glow2_radius: float = 0.0  # 0 = 禁用
@export var core_glow2_color: Color = Color.WHITE
@export var core_glow2_alpha: float = 0.25

# ═══════════════════════════════════════════
# ── 核心抖动 ──
# ═══════════════════════════════════════════
@export_group("Core Jitter", "jitter_")

@export var jitter_enabled: bool = false
@export var jitter_amplitude: float = 0.9
@export var jitter_freq_x: float = 2.3
@export var jitter_freq_y: float = 2.1

# ═══════════════════════════════════════════
# ── 纹理参数 ──
# ═══════════════════════════════════════════
@export_group("Textures", "tex_")

## 核心精灵纹理路径（留空则用纯色圆）
@export var tex_core_path: String = ""
## 发光层纹理路径
@export var tex_glow_path: String = ""
## 拖尾粒子纹理路径
@export var tex_trail_path: String = ""
## 爆炸粒子纹理路径
@export var tex_explosion_path: String = ""
## 前缘火焰纹理路径
@export var tex_front_flame_path: String = ""
## 弹尖纹理路径
@export var tex_nose_path: String = ""

# ═══════════════════════════════════════════
# ── 前缘火焰粒子 ──
# ═══════════════════════════════════════════
@export_group("Front Flame", "front_flame_")

@export var front_flame_enabled: bool = false
@export var front_flame_count: int = 12
@export var front_flame_inner_min: float = 1.2
@export var front_flame_inner_max: float = 5.5
@export var front_flame_outer_min: float = 5.5
@export var front_flame_outer_max: float = 14.0
@export var front_flame_color_1: Color = Color.WHITE
@export var front_flame_color_2: Color = Color.WHITE
@export var front_flame_life_min: float = 0.1
@export var front_flame_life_max: float = 0.195

# ═══════════════════════════════════════════
# ── 增强拖尾粒子 ──
# ═══════════════════════════════════════════
@export_group("Trail Particles", "trail_")

## 是否启用粒子拖尾
@export var trail_particle_enabled: bool = false
@export var trail_particle_count: int = 8
@export var trail_particle_lifetime: float = 0.15
@export var trail_back_dist_min: float = 20.0
@export var trail_back_dist_max: float = 80.0
@export var trail_spread_min: float = 28.0
@export var trail_spread_max: float = 46.0
@export var trail_radius_min: float = 1.2
@export var trail_radius_max: float = 6.4
@export var trail_color_1: Color = Color.WHITE
@export var trail_color_2: Color = Color.WHITE
@export var trail_color_3: Color = Color.WHITE
@export var trail_life_min: float = 0.18
@export var trail_life_max: float = 0.45
## 旧参数兼容
@export var trail_texture_path: String = ""

# ═══════════════════════════════════════════
# ── 彗星拖尾（Line2D 实线拖尾） ──
# ═══════════════════════════════════════════
@export_group("Comet Trail", "comet_")

@export var comet_enabled: bool = false
## 最大采样点数
@export var comet_max_samples: int = 28
## 外层线宽/颜色/透明度
@export var comet_outer_width: float = 6.0
@export var comet_outer_color: Color = Color.WHITE
@export var comet_outer_alpha: float = 0.35
## 中层线宽/颜色/透明度
@export var comet_mid_width: float = 3.4
@export var comet_mid_color: Color = Color.WHITE
@export var comet_mid_alpha: float = 0.62
## 内层线宽/颜色/透明度
@export var comet_inner_width: float = 1.8
@export var comet_inner_color: Color = Color.WHITE
@export var comet_inner_alpha: float = 0.96
## 蛇形摆动参数
@export var comet_sway_freq: float = 0.7
@export var comet_sway_amplitude: float = 1.1

# ═══════════════════════════════════════════
# ── 增强爆炸 / 命中 ──
# ═══════════════════════════════════════════
@export_group("Impact Burst", "impact_")

@export var impact_spark_count_min: int = 10
@export var impact_spark_count_max: int = 14
@export var impact_speed_min: float = 24.0
@export var impact_speed_max: float = 72.0
@export var impact_life_min: float = 0.12
@export var impact_life_max: float = 0.22
@export var impact_color: Color = Color.WHITE
@export var impact_particle_count: int = 20
@export var impact_lifetime: float = 0.4
@export var impact_radius_mult: float = 2.0
@export var impact_shake_strength: float = 0.0
@export var impact_shake_duration: float = 0.0

# ═══════════════════════════════════════════
# ── VFX 层级池配置（v0.3） ──
# ═══════════════════════════════════════════
@export_group("VFX Tier Overrides", "hit_vfx_")

## A层（小组）调用的效果 ID。空 = 使用全局默认。
@export var hit_vfx_tier_A: String = ""
## B层（中组）调用的效果 ID。空 = 使用全局默认。
@export var hit_vfx_tier_B: String = ""
## C层（大组）调用的效果 ID。空 = 使用全局默认。
@export var hit_vfx_tier_C: String = ""

## 技能自定义 Layer（不走层级池，技能独有效果）
@export var custom_hit_layers: Array[Resource] = []

# ── 旧参数兼容（不推荐新技能使用） ──
@export var glow_enabled: bool = true
@export var explosion_texture_path: String = ""
@export var explosion_particle_count: int = 20
@export var explosion_lifetime: float = 0.4
@export var explosion_radius_mult: float = 2.0
@export var hit_particle_count: int = 20
## 核心精灵纹理路径（旧参数，新技能用 tex_core_path）
@export var core_texture_path: String = ""

# ── 验证 ──
func is_valid() -> bool:
	return skill_id != "" and speed > 0

# ── 辅助方法 ──
func get_projectile_kind_name() -> String:
	match projectile_kind:
		0: return "MECHANICAL_BULLET"
		1: return "FIREBALL"
		2: return "GHOST_FIRE_SKULL"
		3: return "MISSILE_STORM"
		4: return "ICE_CYCLONE"
		5: return "CHAIN_LIGHTNING"
		6: return "BURNING_HANDS"
		7: return "ICE_RING"
		8: return "PLASMA_BEAM"
	return "MECHANICAL_BULLET"

func get_trajectory_type_name() -> String:
	match trajectory_type:
		0: return "LINEAR"
		1: return "HOMING"
		2: return "BEZIER_QUAD"
		3: return "BEZIER_CUBIC"
		4: return "SINE_WAVE"
		5: return "SPIRAL"
	return "LINEAR"

func get_telegraph_shape_name() -> String:
	match telegraph_shape:
		0: return "CIRCLE"
		1: return "RECT"
		2: return "FAN"
	return "CIRCLE"

func get_impact_level_name() -> String:
	match impact_level:
		0: return "LIGHT"
		1: return "MEDIUM"
		2: return "STRONG"
		3: return "CLIMAX"
	return "MEDIUM"
