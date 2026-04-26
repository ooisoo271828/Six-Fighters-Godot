# skill_visual_def.gd
# 技能视觉数据定义基类
# 包含所有视觉和表现参数，与战斗数据分离

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

# ── Sprite + Particle 纹理参数 ──
## 核心精灵纹理路径（留空则用纯色）
@export var core_texture_path: String = ""
## 是否启用发光
@export var glow_enabled: bool = true
## 拖尾粒子纹理（留空用 core_texture_path）
@export var trail_texture_path: String = ""
## 是否启用粒子拖尾
@export var trail_particle_enabled: bool = false
@export var trail_particle_count: int = 8
@export var trail_particle_lifetime: float = 0.15
## 爆炸粒子纹理
@export var explosion_texture_path: String = ""
@export var explosion_particle_count: int = 20
@export var explosion_lifetime: float = 0.4
## 爆炸半径系数（爆炸半径 = 投射物半径 * 此系数）
@export var explosion_radius_mult: float = 2.0
## 命中粒子数量
@export var hit_particle_count: int = 20

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
