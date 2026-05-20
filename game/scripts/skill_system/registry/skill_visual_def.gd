# skill_visual_def.gd
# 技能视觉数据定义基类
# 包含所有视觉和表现参数，与战斗数据分离
# v3.0：组合式子 Resource 架构（ProjectileVisual, TrailVisual, ImpactVisual, VFXOverride）

class_name SkillVisualDef
extends Resource

# ── 视觉标识 ──
@export var skill_id: String = ""

# ═══════════════════════════════════════════
# ── 子 Resource 引用（v3.0 组合式架构）
# ═══════════════════════════════════════════
@export_group("Sub-Resources")
@export var projectile_visual: ProjectileVisual
@export var trail_visual: TrailVisual
@export var impact_visual: ImpactVisual
@export var vfx_override: VFXOverride

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
## 宽度渐变曲线
@export var comet_width_fade_start: float = 0.4
@export var comet_width_fade_mid: float = 0.25
@export var comet_width_fade_end: float = 0.05

# ═══════════════════════════════════════════
# ── 路径粒子 ──
# ═══════════════════════════════════════════
@export_group("Path Particles", "path_particle_")

@export var path_particles_enabled: bool = false
@export var path_particle_interval: float = 0.04
@export var path_particle_lifetime: float = 0.3
@export var path_particle_color: Color = Color(1, 0.8, 0.4, 0.6)
@export var path_particle_size: float = 0.25

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


## ── 子 Resource 访问器（优先读子 Resource，回退旧字段）──

func get_projectile_visual() -> ProjectileVisual:
	if projectile_visual:
		return projectile_visual
	# 从旧字段创建临时子 Resource
	var pv := ProjectileVisual.new()
	pv.core_color = core_color
	pv.core_width = core_width
	pv.core_height = core_height
	pv.core_radius = core_radius
	pv.inner_enabled = core_inner_enabled
	pv.inner_color = core_inner_color
	pv.inner_width = core_inner_width
	pv.inner_height = core_inner_height
	pv.inner_offset = core_inner_offset
	pv.hotspot_enabled = core_hotspot_enabled
	pv.hotspot_color = core_hotspot_color
	pv.hotspot_width = core_hotspot_width
	pv.hotspot_height = core_hotspot_height
	pv.hotspot_offset = core_hotspot_offset
	pv.nose_enabled = core_nose_enabled
	pv.nose_color = core_nose_color
	pv.nose_length = core_nose_length
	pv.nose_width = core_nose_width
	pv.glow_radius = core_glow_radius
	pv.glow_color = core_glow_color
	pv.glow_alpha = core_glow_alpha
	pv.glow2_radius = core_glow2_radius
	pv.glow2_color = core_glow2_color
	pv.glow2_alpha = core_glow2_alpha
	pv.jitter_enabled = jitter_enabled
	pv.jitter_amplitude = jitter_amplitude
	pv.jitter_freq_x = jitter_freq_x
	pv.jitter_freq_y = jitter_freq_y
	pv.tex_core_path = tex_core_path
	pv.tex_glow_path = tex_glow_path
	pv.tex_explosion_path = tex_explosion_path
	pv.tex_nose_path = tex_nose_path
	pv.projectile_scale = projectile_scale
	return pv


func get_trail_visual() -> TrailVisual:
	if trail_visual:
		return trail_visual
	# 从旧字段创建临时子 Resource
	var tv := TrailVisual.new()
	tv.trail_enabled = trail_particle_enabled
	tv.trail_count = trail_particle_count
	tv.trail_lifetime = trail_particle_lifetime
	tv.trail_back_dist_min = trail_back_dist_min
	tv.trail_back_dist_max = trail_back_dist_max
	tv.trail_spread_min = trail_spread_min
	tv.trail_spread_max = trail_spread_max
	tv.trail_radius_min = trail_radius_min
	tv.trail_radius_max = trail_radius_max
	tv.trail_color_1 = trail_color_1
	tv.trail_color_2 = trail_color_2
	tv.trail_color_3 = trail_color_3
	tv.trail_life_min = trail_life_min
	tv.trail_life_max = trail_life_max
	tv.tex_trail_path = tex_trail_path if tex_trail_path != "" else trail_texture_path
	tv.flame_enabled = front_flame_enabled
	tv.flame_count = front_flame_count
	tv.flame_inner_min = front_flame_inner_min
	tv.flame_inner_max = front_flame_inner_max
	tv.flame_outer_min = front_flame_outer_min
	tv.flame_outer_max = front_flame_outer_max
	tv.flame_color_1 = front_flame_color_1
	tv.flame_color_2 = front_flame_color_2
	tv.flame_life_min = front_flame_life_min
	tv.flame_life_max = front_flame_life_max
	tv.tex_flame_path = tex_front_flame_path
	tv.comet_enabled = comet_enabled
	tv.comet_max_samples = comet_max_samples
	tv.comet_outer_width = comet_outer_width
	tv.comet_outer_color = comet_outer_color
	tv.comet_outer_alpha = comet_outer_alpha
	tv.comet_mid_width = comet_mid_width
	tv.comet_mid_color = comet_mid_color
	tv.comet_mid_alpha = comet_mid_alpha
	tv.comet_inner_width = comet_inner_width
	tv.comet_inner_color = comet_inner_color
	tv.comet_inner_alpha = comet_inner_alpha
	tv.comet_sway_freq = comet_sway_freq
	tv.comet_sway_amplitude = comet_sway_amplitude
	tv.comet_width_fade_start = comet_width_fade_start
	tv.comet_width_fade_mid = comet_width_fade_mid
	tv.comet_width_fade_end = comet_width_fade_end
	return tv


func get_impact_visual() -> ImpactVisual:
	if impact_visual:
		return impact_visual
	# 从旧字段创建临时子 Resource
	var iv := ImpactVisual.new()
	iv.spark_count_min = impact_spark_count_min
	iv.spark_count_max = impact_spark_count_max
	iv.spark_speed_min = impact_speed_min
	iv.spark_speed_max = impact_speed_max
	iv.spark_life_min = impact_life_min
	iv.spark_life_max = impact_life_max
	iv.spark_color = impact_color
	iv.spark_particle_count = impact_particle_count
	iv.spark_lifetime = impact_lifetime
	iv.spark_radius_mult = impact_radius_mult
	iv.shake_strength = impact_shake_strength
	iv.shake_duration = impact_shake_duration
	iv.impact_effect_kind = impact_effect_kind
	return iv


func get_vfx_override() -> VFXOverride:
	if vfx_override:
		return vfx_override
	# 从旧字段创建临时子 Resource
	var vo := VFXOverride.new()
	vo.tier_A = hit_vfx_tier_A
	vo.tier_B = hit_vfx_tier_B
	vo.tier_C = hit_vfx_tier_C
	vo.custom_layers = custom_hit_layers
	return vo
