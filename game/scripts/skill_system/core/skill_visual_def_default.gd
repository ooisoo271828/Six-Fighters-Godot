## SkillVisualDefDefault — 技能视觉定义（程序化默认实现）
## 继承 SkillVisualDef，统一视觉参数体系
## 注意：core_color 和 core_radius 已移至基类 SkillVisualDef
class_name SkillVisualDefDefault
extends SkillVisualDef

# ── Default 特有的字段（不在基类中的）──
## Ribbon 拖尾宽度（Line2D 模式）
@export var ribbon_width: float = 3.0

## 命中冲击等级（light/medium/strong/climax）
## 注意：子类覆盖基类的 int 字段，.tres 中写字符串值
var impact_level_str: String = "medium"

func _init(data: Dictionary = {}) -> void:
	# 基类字段由 @export 自动处理
	if not data.is_empty():
		core_color = data.get("core_color", Color(0.8, 0.85, 1.0))
		core_radius = data.get("core_radius", 4.0)
		ribbon_width = data.get("ribbon_width", 3.0)
		impact_level_str = data.get("impact_level_str", "medium")
		# 基类字段
		skill_id = data.get("skill_id", "")
		core_texture_path = data.get("core_texture_path", "")
		glow_enabled = data.get("glow_enabled", true)
		trail_texture_path = data.get("trail_texture_path", "")
		trail_particle_enabled = data.get("trail_particle_enabled", false)
		trail_particle_count = data.get("trail_particle_count", 8)
		trail_particle_lifetime = data.get("trail_particle_lifetime", 0.15)
		explosion_texture_path = data.get("explosion_texture_path", "")
		explosion_particle_count = data.get("explosion_particle_count", 20)
		explosion_lifetime = data.get("explosion_lifetime", 0.4)
		explosion_radius_mult = data.get("explosion_radius_mult", 2.0)
		hit_particle_count = data.get("hit_particle_count", 20)
