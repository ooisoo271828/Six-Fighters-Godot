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

# ── ShaderPreset 注册表 ──

var _preset_map: Dictionary = {}  # StringName -> ShaderPreset

# ── 预定义纹理键 ──

const CIRCLE := &"circle"
const NOSE_TRIANGLE := &"nose_triangle"
const SOFT_CIRCLE := &"soft_circle"
const RAY_STARBURST := &"ray_starburst"
const NOISE_PERLIN := &"noise_perlin"
const RING_SPIKY := &"ring_spiky"

# ── 程序化纹理分辨率 ──

const CIRCLE_SIZE := 32
const NOSE_SIZE := 32
const RAY_SIZE := 64
const RING_SPIKY_SIZE := 128


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


# ── ShaderPreset 管理 ──

## 注册预设
func register_preset(key: StringName, preset: ShaderPreset) -> void:
	_preset_map[key] = preset

## 获取预设
func get_preset(key: StringName) -> ShaderPreset:
	return _preset_map.get(key)

## 通过预设获取 ShaderMaterial
func get_material_from_preset(preset_key: StringName) -> ShaderMaterial:
	var preset := get_preset(preset_key)
	if preset == null:
		push_warning("VFXTextureManager: unknown preset '%s'" % preset_key)
		return null
	return preset.get_material(self)


## 清除所有缓存（场景切换时调用）
func clear() -> void:
	_cache.clear()
	_material_cache.clear()
	# 注意：不清理 _preset_map，预设是静态配置

## 从目录加载所有 ShaderPreset .tres 文件
func load_presets_from_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path := dir_path.path_join(file_name)
			var preset := load(full_path) as ShaderPreset
			if preset:
				var key := StringName(file_name.get_basename())
				register_preset(key, preset)
		file_name = dir.get_next()
	dir.list_dir_end()


# ── 内部：加载或生成纹理 ──

func _load_or_generate(key: StringName) -> Texture2D:
	match key:
		CIRCLE:
			return _generate_circle(CIRCLE_SIZE)
		SOFT_CIRCLE:
			return _generate_soft_circle(CIRCLE_SIZE)
		NOSE_TRIANGLE:
			return _generate_nose(NOSE_SIZE)
		RAY_STARBURST:
			return _generate_ray(RAY_SIZE)
		RING_SPIKY:
			return _generate_ring_spiky(RING_SPIKY_SIZE)
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



func _generate_soft_circle(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := float(size) * 0.5 - 0.5
	var radius := float(size) * 0.5 - 1.0
	for x in range(size):
		for y in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= radius:
				var t := dist / radius
				# Smooth falloff: solid core, soft edge
				var a := smoothstep(1.0, 0.3, t)
				img.set_pixel(x, y, Color(1, 1, 1, a))
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


## 生成带不规则尖刺的冲击环纹理（爆炸感边缘）
func _generate_ring_spiky(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx := float(size) * 0.5 - 0.5
	var cy := float(size) * 0.5 - 0.5
	var base_radius := float(size) * 0.35
	var spike_count := 24

	# 预生成每根尖刺的随机参数（长度、宽度衰减）
	var spike_data: Array = []
	for s in range(spike_count):
		var angle := float(s) / float(spike_count) * TAU
		angle += randf_range(-0.06, 0.06)
		var spike_len := base_radius * randf_range(0.3, 0.85)
		var spike_base_half := randf_range(2.0, 6.0)
		spike_data.append({"angle": angle, "length": spike_len, "base_half": spike_base_half})

	for x in range(size):
		for y in range(size):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy)
			var pixel_angle := atan2(dy, dx)

			# 基础圆盘（实心，带软边）
			var disk_a := 0.0
			if dist <= base_radius:
				if dist <= base_radius * 0.7:
					disk_a = 1.0
				else:
					disk_a = smoothstep(base_radius, base_radius * 0.7, dist)

			# 尖刺：从 base_radius 边缘向外辐射
			var spike_a := 0.0
			for spike in spike_data:
				var angle_diff: float = absf(wrapf(pixel_angle - float(spike.angle), -PI, PI))
				if angle_diff > 0.5:
					continue
				var spike_start := base_radius * 0.85
				var spike_end: float = base_radius + float(spike.length)
				if dist >= spike_start and dist <= spike_end:
					var radial_t: float = (dist - spike_start) / (spike_end - spike_start)
					var angle_tolerance: float = (float(spike.base_half) / base_radius) * (1.0 - radial_t * 0.6)
					if angle_diff < angle_tolerance:
						var a := smoothstep(1.0, 0.3, radial_t)
						a *= smoothstep(angle_tolerance, angle_tolerance * 0.4, angle_diff)
						spike_a = maxf(spike_a, a)

			var final_a := maxf(disk_a, spike_a)
			if final_a > 0.01:
				var brightness := 1.0
				if spike_a > disk_a:
					brightness = randf_range(0.7, 0.95)
				img.set_pixel(x, y, Color(brightness, brightness, brightness, final_a))

	return ImageTexture.create_from_image(img)
