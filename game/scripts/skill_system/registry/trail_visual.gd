# trail_visual.gd
# 拖尾子 Resource — 拖尾粒子、前缘火焰、彗星拖尾
class_name TrailVisual
extends Resource

# ── 拖尾粒子 ──
@export_group("Trail Particles")
@export var trail_enabled: bool = false
@export var trail_count: int = 8
@export var trail_lifetime: float = 0.15
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
@export var tex_trail_path: String = ""

# ── 前缘火焰 ──
@export_group("Front Flame")
@export var flame_enabled: bool = false
@export var flame_count: int = 12
@export var flame_inner_min: float = 1.2
@export var flame_inner_max: float = 5.5
@export var flame_outer_min: float = 5.5
@export var flame_outer_max: float = 14.0
@export var flame_color_1: Color = Color.WHITE
@export var flame_color_2: Color = Color.WHITE
@export var flame_life_min: float = 0.1
@export var flame_life_max: float = 0.195
@export var tex_flame_path: String = ""

# ── 彗星拖尾（Line2D） ──
@export_group("Comet Trail")
@export var comet_enabled: bool = false
@export var comet_max_samples: int = 28
@export var comet_outer_width: float = 6.0
@export var comet_outer_color: Color = Color.WHITE
@export var comet_outer_alpha: float = 0.35
@export var comet_mid_width: float = 3.4
@export var comet_mid_color: Color = Color.WHITE
@export var comet_mid_alpha: float = 0.62
@export var comet_inner_width: float = 1.8
@export var comet_inner_color: Color = Color.WHITE
@export var comet_inner_alpha: float = 0.96
@export var comet_sway_freq: float = 0.7
@export var comet_sway_amplitude: float = 1.1
@export var comet_width_fade_start: float = 0.4
@export var comet_width_fade_mid: float = 0.25
@export var comet_width_fade_end: float = 0.05

# ── 路径粒子 ──
@export_group("Path Particles")
@export var path_particles_enabled: bool = false
@export var path_particle_interval: float = 0.04
@export var path_particle_lifetime: float = 0.3
@export var path_particle_color: Color = Color(1, 0.8, 0.4, 0.6)
@export var path_particle_size: float = 0.25
