# skill_visual_def.gd
# 技能视觉数据定义 — 纯容器，持有元数据 + 子 Resource 引用
# v4.0：删除所有扁平字段，运行时只从子 Resource 读取

class_name SkillVisualDef
extends Resource

# ═══════════════════════════════════════════
# ── 顶层元数据
# ═══════════════════════════════════════════

@export var skill_id: String = ""

@export_enum(
	"MECHANICAL_BULLET:0",
	"FIREBALL:1",
	"GHOST_FIRE_SKULL:2",
	"MISSILE_STORM:3",
	"ICE_CYCLONE:4",
	"CHAIN_LIGHTNING:5",
	"BURNING_HANDS:6",
	"ICE_RING:7",
	"PLASMA_BEAM:8",
	"SHURIKEN:9"
)
var projectile_kind: int = 0

@export_enum("CIRCLE:0", "RECT:1", "FAN:2")
var telegraph_shape: int = 0

@export_enum("LIGHT:0", "MEDIUM:1", "STRONG:2", "CLIMAX:3")
var impact_level: int = 1

@export var telegraph_ms: int = 350
@export var travel_ms: int = 700
@export var projectile_scale: float = 1.0

# ── 弹体投射参数（EmitProjectileEffect 读取）──
@export var speed: float = 300.0
@export var projectile_count_min: int = 1
@export var projectile_count_max: int = 1
@export var projectile_stagger_sec: float = 0.0

@export_enum(
	"LINEAR:0",
	"HOMING:1",
	"BEZIER_QUAD:2",
	"BEZIER_CUBIC:3",
	"SINE_WAVE:4",
	"SPIRAL:5"
)
var trajectory_type: int = 0

# ═══════════════════════════════════════════
# ── 子 Resource 引用
# ═══════════════════════════════════════════

@export_group("Sub-Resources")

## 弹体核心视觉（多层 Sprite、光晕、弹尖、抖动、纹理）
@export var body: ProjectileVisual

## 拖尾系统（粒子、火焰、彗星、路径光点）
@export var trail: TrailDef

## 命中视觉（火花爆发、震屏、VFX 层级池）
@export var impact: ImpactVisual

# ═══════════════════════════════════════════
# ── 安全访问器（缺失时返回默认值）
# ═══════════════════════════════════════════

func get_body() -> ProjectileVisual:
	if body:
		return body
	return ProjectileVisual.new()

func get_trail() -> TrailDef:
	if trail:
		return trail
	return TrailDef.new()

func get_impact() -> ImpactVisual:
	if impact:
		return impact
	return ImpactVisual.new()

# ── 验证 ──

func is_valid() -> bool:
	return skill_id != ""

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
		9: return "SHURIKEN"
	return "MECHANICAL_BULLET"

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
