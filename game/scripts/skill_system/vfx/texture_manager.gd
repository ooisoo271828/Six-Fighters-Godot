class_name VFXTextureManager
extends RefCounted

## 统一管理所有 VFX 纹理资产和 ShaderMaterial 缓存。
## 替代各类各自 _get_shared_circle_texture() 的做法。

# ── 静态单例 ──

static var _instance: VFXTextureManager

static func get_instance() -> VFXTextureManager:
	if _instance == null:
		_instance = VFXTextureManager.new()
	return _instance

# ── 纹理缓存 ──

var _cache: Dictionary = {}  # StringName -> Texture2D

# ── ShaderMaterial 缓存 ──

var _material_cache: Dictionary = {}  # String -> ShaderMaterial

# ── 预定义纹理键 ──

const CIRCLE := &"circle"
const NOSE_TRIANGLE := &"nose_triangle"
const RAY_STARBURST := &"ray_starburst"
const NOISE_PERLIN := &"noise_perlin"

# ── 程序化纹理分辨率 ──

const CIRCLE_SIZE := 32
const NOSE_SIZE := 32
const RAY_SIZE := 64


## 获取纹理（带缓存）
func get_texture(key: StringName) -> Texture2D:
	if key in _cache:
		return _cache[key]
	var tex := _load_or_generate(key)
	_cache[key] = tex
	return tex


## 获取共享 ShaderMaterial（静态参数相同则共享同一实例）
func get_shared_material(shader_path: String, params: Dictionary) -> ShaderMaterial:
	var key := shader_path + "|" + str(params.hash())
	if key in _material_cache:
		return _material_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	for p_name in params:
		mat.set_shader_parameter(p_name, params[p_name])
	_material_cache[key] = mat
	return mat


## 复制一份独立的 ShaderMaterial（用于运行时动画参数）
func duplicate_material(shared: ShaderMaterial) -> ShaderMaterial:
	return shared.duplicate()


## 清除所有缓存（场景切换时调用）
func clear() -> void:
	_cache.clear()
	_material_cache.clear()


# ── 内部：加载或生成纹理 ──

func _load_or_generate(key: StringName) -> Texture2D:
	match key:
		CIRCLE:
			return _generate_circle(CIRCLE_SIZE)
		NOSE_TRIANGLE:
			return _generate_nose(NOSE_SIZE)
		RAY_STARBURST:
			return _generate_ray(RAY_SIZE)
		NOISE_PERLIN:
			var noise := NoiseTexture2D.new()
			noise.noise = FastNoiseLite.new()
			noise.width = 128
			noise.height = 128
			return noise
		_:
			# 尝试从 assets/textures/vfx/ 加载
			var path := "res://assets/textures/vfx/%s.png" % key
			if ResourceLoader.exists(path):
				return load(path)
			push_warning("VFXTextureManager: unknown texture key '%s'" % key)
			return _generate_circle(CIRCLE_SIZE)


# ── 程序化纹理生成 ──

func _generate_circle(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := float(size) * 0.5 - 0.5
	var radius_sq := pow(float(size) * 0.5 - 1.0, 2.0)
	for x in range(size):
		for y in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			if dx * dx + dy * dy <= radius_sq:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _generate_nose(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var half := float(size) * 0.5
	for y in range(size):
		var half_h: float = half - abs(float(y) - (half - 0.5))
		if half_h <= 0.0:
			continue
		for x in range(size):
			var progress: float = float(x) / float(size - 1)
			var max_half: float = half_h * (1.0 - progress * 0.7)
			var dy: float = abs(float(y) - (half - 0.5))
			if dy <= max_half and x >= int(half * 0.5):
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _generate_ray(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx := float(size) * 0.5 - 0.5
	var cy := float(size) * 0.5 - 0.5
	var core_radius := float(size) * 0.14
	var glow_radius := float(size) * 0.36
	# 核心光晕
	for x in range(size):
		for y in range(size):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= core_radius:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif dist <= glow_radius:
				var a := 1.0 - (dist - core_radius) / (glow_radius - core_radius)
				img.set_pixel(x, y, Color(1, 1, 1, a * 0.6))
	# 辐射射线（12条）
	var ray_count := 12
	var ray_inner := int(float(size) * 0.09)
	var ray_outer := int(float(size) * 0.56)
	for r in range(ray_count):
		var angle := float(r) / float(ray_count) * TAU
		var sin_a := sin(angle)
		var cos_a := cos(angle)
		for d in range(ray_inner, ray_outer):
			var px := int(cx + cos_a * float(d) + 0.5)
			var py := int(cy + sin_a * float(d) + 0.5)
			if px >= 0 and px < size and py >= 0 and py < size:
				var a := 1.0 - float(d - ray_inner) / float(ray_outer - ray_inner)
				for w in range(-1, 2):
					var wx := int(cx + cos_a * float(d) + sin_a * float(w) * 0.5 + 0.5)
					var wy := int(cy + sin_a * float(d) - cos_a * float(w) * 0.5 + 0.5)
					if wx >= 0 and wx < size and wy >= 0 and wy < size:
						var existing := img.get_pixel(wx, wy)
						var new_a := maxf(existing.a, a * 0.35)
						img.set_pixel(wx, wy, Color(1, 1, 1, new_a))
	return ImageTexture.create_from_image(img)
