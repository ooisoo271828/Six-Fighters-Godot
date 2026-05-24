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
const ROCK_IRREGULAR := &"rock_irregular"
const MUSHROOM_CLOUD := &"mushroom_cloud"
const FLAME_AURA := &"flame_aura"

# ── 程序化纹理分辨率 ──

const CIRCLE_SIZE := 32
const NOSE_SIZE := 32
const RAY_SIZE := 64
const RING_SPIKY_SIZE := 128
const ROCK_IRREGULAR_SIZE := 64
const MUSHROOM_FRAME_SIZE := 96


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
		ROCK_IRREGULAR:
			return _generate_rock_irregular(ROCK_IRREGULAR_SIZE)
		FLAME_AURA:
			return _generate_flame_aura(64)
		NOISE_PERLIN:
			var noise := NoiseTexture2D.new()
			noise.noise = FastNoiseLite.new()
			noise.width = 128
			noise.height = 128
			return noise
		_:
			# 检查蘑菇云帧
			var key_str: String = String(key)
			if key_str.begins_with("mushroom_cloud_frame_"):
				var parts: PackedStringArray = key_str.split("_")
				if parts.size() == 4:
					var frame_idx: int = int(parts[3])
					if frame_idx >= 0 and frame_idx < 8:
						return _generate_mushroom_frame(MUSHROOM_FRAME_SIZE, frame_idx)
			# ���Դ� assets/textures/vfx/ ����
			var path: String = "res://assets/textures/vfx/%s.png" % key
			if ResourceLoader.exists(path):
				return load(path)
			push_warning("VFXTextureManager: unknown texture key '%s'" % key)
			return _generate_circle(CIRCLE_SIZE)


# ── 程序化纹理生成 ──

func _generate_circle(size: int) -> Texture2D:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
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
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
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
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
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
	var cx: float = float(size) * 0.5 - 0.5
	var cy: float = float(size) * 0.5 - 0.5
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
	var cx: float = float(size) * 0.5 - 0.5
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

# ── 陨石纹理（不规则深褐色岩石） ──

func _generate_rock_irregular(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx: float = float(size) * 0.5 - 0.5
	var cy := float(size) * 0.5 - 0.5
	var base_radius: float = float(size) * 0.38

	# 深褐色调
	var rock_dark: Color = Color(0.27, 0.16, 0.08, 1)
	var rock_light: Color = Color(0.40, 0.25, 0.12, 1)

	# 随机顶点生成不规则多边形（固定种子保证每次加载一致）
	var seed_val: int = 42
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val

	var vertices: Array[Vector2] = []
	var vertex_count: int = 12
	for i in range(vertex_count):
		var angle: float = float(i) / float(vertex_count) * TAU + rng.randf_range(-0.08, 0.08)
		var radius_offset: float = base_radius * rng.randf_range(0.65, 1.2)
		var vx: float = cx + cos(angle) * radius_offset
		var vy: float = cy + sin(angle) * radius_offset
		vertices.append(Vector2(vx, vy))

	# 扫描填充
	for x in range(size):
		for y in range(size):
			var point: Vector2 = Vector2(float(x), float(y))
			if _point_in_polygon(point, vertices):
				var noise_val: float = rng.randf_range(0.0, 1.0)
				var col: Color = rock_dark.lerp(rock_light, noise_val * 0.35)
				var dist_center: float = point.distance_to(Vector2(cx, cy))
				var edge_factor: float = clampf((dist_center - base_radius * 0.3) / (base_radius * 0.7), 0.0, 1.0)
				col = col.darkened(edge_factor * 0.12)
				img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


static func _point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	var inside: bool = false
	var j: int = polygon.size() - 1
	for i in range(polygon.size()):
		if (polygon[i].y > point.y) != (polygon[j].y > point.y) and 			point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x:
			inside = not inside
		j = i
	return inside


# ── 蘑菇云帧动画（8 帧） ──

func _generate_mushroom_frame(size: int, frame: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx := float(size) * 0.5
	var cy: float = float(size) * 0.75
	var progress: float = float(frame) / 7.0

	var base_color: Color = Color(0.35, 0.22, 0.12, 0.85)
	var top_color: Color = Color(0.55, 0.32, 0.15, 0.7)
	var fade_color: Color = Color(0.5, 0.4, 0.3, 0.0)

	var stem_height: float = size * (0.15 + progress * 0.25)
	var stem_width: float = size * (0.10 - progress * 0.03)
	var cap_radius: float = size * (0.15 + progress * 0.20)
	var cap_center_y: float = cy - stem_height - size * (0.05 + progress * 0.08)
	var dissipation: float = maxf(0.0, (progress - 0.6) / 0.4)
	var top_fade: float = clampf((progress - 0.5) * 3.0, 0.0, 1.0)

	for x in range(size):
		for y in range(size):
			var px: float = float(x)
			var py: float = float(y)
			var alpha: float = 0.0

			# 茎部
			var dist_stem_center: float = abs(px - cx)
			if py >= cy - stem_height and py <= cy:
				var stem_alpha: float = 1.0 - dist_stem_center / maxf(stem_width, 1.0)
				stem_alpha = clampf(stem_alpha, 0.0, 0.7)
				var bottom_factor: float = (py - (cy - stem_height)) / stem_height
				stem_alpha *= (0.5 + bottom_factor * 0.5)
				alpha = maxf(alpha, stem_alpha)

			# 冠部
			var dy: float = py - cap_center_y
			var dx: float = px - cx
			var dist_cap: float = sqrt(dx * dx + dy * dy)
			if dist_cap <= cap_radius:
				var radial_factor: float = 1.0 - dist_cap / cap_radius
				var cap_alpha: float = clampf(radial_factor * 1.2, 0.0, 0.9)
				if dy < 0:
					cap_alpha *= 1.1
				else:
					cap_alpha *= 0.6
				if dissipation > 0.0:
					var diss_edge: float = 1.0 - radial_factor
					cap_alpha *= 1.0 - diss_edge * dissipation * 1.5
				cap_alpha = clampf(cap_alpha, 0.0, 1.0)
				alpha = maxf(alpha, cap_alpha)

			if alpha > 0.01:
				var col: Color = base_color.lerp(top_color, progress)
				if dissipation > 0.0:
					col = col.lerp(fade_color, dissipation * 0.6)
				col.a = alpha * (1.0 - top_fade * 0.5)
				img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)

# ── 火焰气团纹理（水滴形：前圆后尖，用于陨石火焰拖拽变形） ──

func _generate_flame_aura(size: int) -> Texture2D:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cy: float = float(size) * 0.5
	var center_x: float = float(size) * 0.4
	var round_r: float = float(size) * 0.38
	var tail_min_r: float = 1.5

	for x in range(size):
		var px: float = float(x)
		for y in range(size):
			var py: float = float(y)
			var dy: float = py - cy
			
			var local_r: float
			var alpha_scale: float = 1.0
			
			if px >= center_x:
				var t: float = (px - center_x) / (float(size) - center_x)
				local_r = round_r * (1.0 - pow(t, 2.5))
				local_r *= 1.0 + sin(px * 0.6 + py * 0.4) * 0.06
			else:
				var t: float = (center_x - px) / center_x
				local_r = tail_min_r + (round_r - tail_min_r) * pow(1.0 - t, 2.0)
				local_r *= 1.0 + sin(px * 0.7 + py * 0.5) * 0.12
				local_r *= 1.0 + cos(py * 0.3 - px * 0.4) * 0.08
				local_r *= 1.0 - t * 0.2
			
			local_r = maxf(local_r, tail_min_r)
			
			if abs(dy) <= local_r:
				var ratio: float = abs(dy) / local_r
				var edge_noise: float = sin(px * 0.9 + py * 1.3) * 0.08 + cos(py * 0.7 - px * 0.5) * 0.06
				var threshold: float = 1.0 + edge_noise * 0.25
				if ratio <= threshold:
					var alpha: float = 1.0 - pow(ratio / threshold, 1.8)
					if px < center_x:
						var tail_depth: float = (center_x - px) / center_x
						alpha *= 1.0 - tail_depth * 0.35
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)
