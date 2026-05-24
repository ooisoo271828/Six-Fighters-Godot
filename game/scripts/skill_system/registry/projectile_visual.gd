# projectile_visual.gd
# 弹体外观子 Resource — 核心层、光晕、弹尖、抖动、纹理
# v4.0：增加 glow_offset_forward、运行时状态查询方法
class_name ProjectileVisual
extends Resource

# ── 核心层 ──
@export_group("Core")
@export var core_color: Color = Color.WHITE
@export var core_width: float = 0.0
@export var core_height: float = 0.0
@export var core_radius: float = 4.0

# ── 内核层 ──
@export_group("Inner Core")
@export var inner_enabled: bool = false
@export var inner_color: Color = Color.WHITE
@export var inner_width: float = 0.0
@export var inner_height: float = 0.0
@export var inner_offset: Vector2 = Vector2.ZERO

# ── 热点层 ──
@export_group("Hotspot")
@export var hotspot_enabled: bool = false
@export var hotspot_color: Color = Color.WHITE
@export var hotspot_width: float = 0.0
@export var hotspot_height: float = 0.0
@export var hotspot_offset: Vector2 = Vector2.ZERO

# ── 弹尖 ──
@export_group("Nose")
@export var nose_enabled: bool = false
@export var nose_color: Color = Color.WHITE
@export var nose_length: float = 0.0
@export var nose_width: float = 0.0

# ── 光晕 ──
@export_group("Glow")
@export var glow_radius: float = 0.0
@export var glow_color: Color = Color.WHITE
@export var glow_alpha: float = 0.48
@export var glow2_radius: float = 0.0
@export var glow2_color: Color = Color.WHITE
@export var glow2_alpha: float = 0.25
## 辉光层前向偏移（正值=朝弹头方向偏移）
@export var glow_offset_forward: float = 0.0

# ── 抖动 ──
@export_group("Jitter")
@export var jitter_enabled: bool = false
@export var jitter_amplitude: float = 0.9
@export var jitter_freq_x: float = 2.3
@export var jitter_freq_y: float = 2.1

# ── 纹理路径 ──
@export_group("Textures")
@export var tex_core_path: String = ""
@export var tex_glow_path: String = ""
@export var tex_explosion_path: String = ""
@export var tex_nose_path: String = ""

# ── 缩放 ──
@export var projectile_scale: float = 1.0

# ── 旧参数兼容 ──
@export var glow_enabled: bool = true
