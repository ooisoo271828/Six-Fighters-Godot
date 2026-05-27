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
const BONE := &"bone"
const SHURIKEN := &"shuriken"
const MUSHROOM_CLOUD := &"mushroom_cloud"
const FLAME_AURA := &"flame_aura"
const WAVE_FAN := &"wave_fan"

# ── 程序化纹理分辨率 ──

const CIRCLE_SIZE := 32
const NOSE_SIZE := 32
const RAY_SIZE := 64
const RING_SPIKY_SIZE := 128
const ROCK_IRREGULAR_SIZE := 64
const BONE_SIZE := 64
const SHURIKEN_SIZE := 32
const MUSHROOM_FRAME_SIZE := 96
const WAVE_FAN_SIZE := 64


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
		BONE:
			return _generate_bone(BONE_SIZE)
		SHURIKEN:
			return _generate_shuriken(SHURIKEN_SIZE)
		FLAME_AURA:
			return _generate_flame_aura(64)
		WAVE_FAN:
			return _generate_wave_fan(WAVE_FAN_SIZE)
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


# ── 骨头纹理（两端粗中间细的骨节状，浅米白色） ──

func _generate_bone(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx: float = float(size) * 0.5 - 0.5
	var cy: float = float(size) * 0.5 - 0.5
	var half_len: float = float(size) * 0.42
	var half_w: float = float(size) * 0.10

	var bone_color: Color = Color(0.91, 0.84, 0.69, 1)
	var dark_color: Color = Color(0.70, 0.60, 0.45, 1)
	var light_color: Color = Color(0.95, 0.90, 0.78, 1)

	for x in range(size):
		var px: float = float(x)
		for y in range(size):
			var py: float = float(y)
			var dx: float = px - cx
			var dy: float = py - cy

			# 沿 X 轴的动物腿骨形状：中间细、两头粗
			var t: float = clampf(abs(dx) / half_len, 0.0, 1.0)
			# 从中心到两端逐渐变粗，端部膨大最明显
			var width_factor: float = 0.2 + 0.8 * pow(t, 0.3)
			var local_half_w: float = half_w * width_factor

			var norm_dy: float = abs(dy) / maxf(local_half_w, 0.01)
			if norm_dy <= 1.0 and abs(dx) <= half_len:
				var alpha: float = 1.0 - pow(norm_dy, 2.0)
				# 两端略微圆润过渡
				if abs(dx) > half_len * 0.85:
					var end_t: float = (abs(dx) - half_len * 0.85) / (half_len * 0.15)
					alpha *= 1.0 - end_t
				alpha = clampf(alpha, 0.0, 1.0)

				# 着色：中间亮两端暗，带微纹理
				var shade: float = 0.5 + 0.5 * sin(px * 0.3 + py * 0.2)
				var col: Color = bone_color.lerp(dark_color, t * 0.3)
				col = col.lerp(light_color, shade * 0.15)
				# 关节处略深
				if t > 0.7:
					col = col.darkened((t - 0.7) * 0.3)
				col.a = alpha
				img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


# ── 飞镖纹理（八芒星手里剑） ──

func _generate_shuriken(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx: float = float(size) * 0.5 - 0.5
	var cy: float = float(size) * 0.5 - 0.5
	var r_outer: float = float(size) * 0.42
	var r_inner: float = float(size) * 0.14

	# 构建八芒星顶点
	var pts: PackedVector2Array = []
	for i in range(8):
		var angle := float(i) * PI / 4.0 - PI / 2.0
		var r := r_outer if i % 2 == 0 else r_inner
		pts.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))

	# 填充多边形
	for x in range(size):
		for y in range(size):
			if _point_in_polygon(Vector2(x, y), pts):
				# 金属渐变：外围亮银，中心略暗
				var dist := Vector2(x, y).distance_to(Vector2(cx, cy))
				var t := dist / r_outer
				var brightness := 0.75 + 0.25 * (1.0 - t)
				img.set_pixel(x, y, Color(brightness, brightness, brightness, 1))

	# 中心小圆孔
	var center_r2: float = (float(size) * 0.06) * (float(size) * 0.06)
	for x in range(size):
		for y in range(size):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy < center_r2:
				img.set_pixel(x, y, Color(0.25, 0.25, 0.3, 1))

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

	var base_color: Color = Color(0.65, 0.38, 0.15, 0.9)
	var top_color: Color = Color(0.85, 0.5, 0.2, 0.8)
	var fade_color: Color = Color(0.7, 0.55, 0.4, 0.0)

	# 先算冠位置，再让茎延伸到冠中心，确保无间隙
	var cap_radius: float = size * (0.15 + progress * 0.20)
	var cap_center_y: float = cy * (0.48 - progress * 0.18)
	var cap_vert_radius: float = cap_radius * 1.3
	var stem_height: float = cy - cap_center_y + size * 0.05
	var stem_width: float = size * (0.12 - progress * 0.03)
	var dissipation: float = maxf(0.0, (progress - 0.6) / 0.4)
	var top_fade: float = clampf((progress - 0.5) * 3.0, 0.0, 1.0)

	for x in range(size):
		for y in range(size):
			var px: float = float(x)
			var py: float = float(y)
			var alpha: float = 0.0

			# 冠部（椭圆：纵向半径 × 1.3）
			var dy_cap: float = py - cap_center_y
			var dx_cap: float = px - cx
			var norm_dist: float = sqrt(dx_cap * dx_cap + (dy_cap / 1.3) * (dy_cap / 1.3))
			if norm_dist <= cap_radius:
				var radial_factor: float = 1.0 - norm_dist / cap_radius
				var cap_alpha: float = clampf(radial_factor * 1.2, 0.0, 0.9)
				# 上下半球平滑过渡（消除中心水平线）
				var vert_t: float = clampf(dy_cap / maxf(cap_vert_radius, 1.0), -1.0, 1.0)
				var half_blend: float = lerpf(1.1, 0.85, vert_t * 0.5 + 0.5)
				cap_alpha *= half_blend
				if dissipation > 0.0:
					var diss_edge: float = 1.0 - radial_factor
					cap_alpha *= 1.0 - diss_edge * dissipation * 1.5
				cap_alpha = clampf(cap_alpha, 0.0, 1.0)
				alpha = maxf(alpha, cap_alpha)

			# 茎部（延伸到冠中心，与冠高 alpha 区重叠）
			var dist_stem_center: float = abs(px - cx)
			if py >= cy - stem_height and py <= cy:
				var stem_alpha: float = 1.0 - smoothstep(stem_width * 0.5, stem_width, dist_stem_center)
				stem_alpha = clampf(stem_alpha, 0.0, 0.7)
				var bottom_factor: float = (py - (cy - stem_height)) / stem_height
				stem_alpha *= (0.4 + bottom_factor * 0.6)
				# 底部不规则碎裂边缘（多层噪声扰动 + 柔化渐变）
				var n1: float = sin(px * 0.45 + py * 0.7) * 0.06
				var n2: float = cos(px * 0.8 - py * 0.35) * 0.04
				var n3: float = sin(px * 1.5 + py * 1.2) * 0.02
				var noise_offset: float = (n1 + n2 + n3) * stem_height
				var bottom_edge: float = cy + noise_offset
				var bottom_fade: float = smoothstep(bottom_edge, bottom_edge - stem_height * 0.12, py)
				stem_alpha *= bottom_fade
				alpha = maxf(alpha, stem_alpha)

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
			var _alpha_scale: float = 1.0
			
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


## 扇形水浪纹理：前宽后窄，前圆后尖，带波浪边缘
func _generate_wave_fan(size: int) -> Texture2D:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cy: float = float(size) * 0.5
	var front_x: float = float(size) * 0.92
	var back_x: float = float(size) * 0.08
	var max_half_h: float = float(size) * 0.44
	var min_half_h: float = float(size) * 0.06
	var edge_softness: float = float(size) * 0.04

	for x in range(size):
		var px: float = float(x)
		var t: float = clampf((px - back_x) / (front_x - back_x), 0.0, 1.0)
		var half_h: float = lerpf(min_half_h, max_half_h, pow(t, 0.6))
		# 波浪边缘（靠近尾部更明显）
		var wave1: float = sin(px * 0.35 + 1.0) * float(size) * 0.018 * (1.0 - t)
		var wave2: float = cos(px * 0.55 - 0.5) * float(size) * 0.012 * (1.0 - t)
		half_h += wave1 + wave2
		half_h = maxf(half_h, 1.0)

		for y in range(size):
			var py: float = float(y)
			var dy: float = abs(py - cy)
			if dy <= half_h + edge_softness:
				var alpha: float = 1.0
				if dy > half_h:
					alpha = 1.0 - (dy - half_h) / edge_softness
				# 中心更亮，边缘渐淡
				var core_blend: float = clampf(1.0 - dy / maxf(half_h, 1.0), 0.0, 1.0)
				alpha *= 0.5 + 0.5 * core_blend
				# 尾部尖端渐隐
				if t < 0.15:
					alpha *= t / 0.15
				alpha = clampf(alpha, 0.0, 1.0)
				if alpha > 0.01:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)
