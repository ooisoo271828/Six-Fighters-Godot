# shader_preset.gd
# 着色器预设 — 类型安全的 ShaderMaterial 配置
# 替代裸 Dictionary 传参，支持编辑器可视化配置
class_name ShaderPreset
extends Resource

## 着色器文件路径
@export var shader_path: String = ""

## 显示名称（编辑器中识别用）
@export var display_name: String = ""

# ── Glow Shader 参数 ──
@export_group("Glow")
@export var glow_color: Color = Color(1.0, 0.6, 0.2, 1.0)
@export var glow_strength: float = 1.5
@export var glow_radius: float = 8.0
@export var pulse_speed: float = 0.0
@export var time_offset: float = 0.0

## 转换为 Dictionary（兼容 VFXTextureManager.get_shared_material 接口）
func to_params() -> Dictionary:
	var params := {}
	if shader_path.ends_with("glow_shader.gdshader") or shader_path.ends_with("rim_glow_shader.gdshader"):
		params = {
			"glow_color": glow_color,
			"glow_strength": glow_strength,
			"glow_radius": glow_radius,
			"pulse_speed": pulse_speed,
			"time_offset": time_offset,
		}
	return params


## 获取或创建 ShaderMaterial（通过 VFXTextureManager 缓存）
func get_material(tex_manager: VFXTextureManager) -> ShaderMaterial:
	if shader_path == "":
		return null
	return tex_manager.get_shared_material(shader_path, to_params())
