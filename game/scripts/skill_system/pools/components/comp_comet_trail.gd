# comp_comet_trail.gd
# Line2D 三层实线彗星拖尾组件
class_name CompCometTrail
extends ProjectileComponent

var _line_outer: Line2D
var _line_mid: Line2D
var _line_inner: Line2D

var _config: CometTrailConfig
var _trail_offsets: Array[Vector2] = []
var _last_global_pos: Vector2
var _pos_initialized: bool = false
var _width_curve: Curve

func create_nodes(parent: Node2D) -> void:
	_line_outer = Line2D.new()
	_line_outer.antialiased = true
	parent.add_child(_line_outer)
	_line_mid = Line2D.new()
	_line_mid.antialiased = true
	parent.add_child(_line_mid)
	_line_inner = Line2D.new()
	_line_inner.antialiased = true
	parent.add_child(_line_inner)


func configure(visual_def: SkillVisualDef, _chain: ExecutionChain, _tex_manager: VFXTextureManager) -> void:
	var trail := visual_def.get_trail()
	_config = trail.comet
	if not _config or not _config.is_enabled():
		_line_outer.points = []
		_line_mid.points = []
		_line_inner.points = []
		_trail_offsets.clear()
		_config = null
		return

	# 配置三层 Line2D
	_line_outer.width = _config.outer_width
	_line_outer.default_color = Color(_config.outer_color.r, _config.outer_color.g, _config.outer_color.b, _config.outer_alpha)
	_line_mid.width = _config.mid_width
	_line_mid.default_color = Color(_config.mid_color.r, _config.mid_color.g, _config.mid_color.b, _config.mid_alpha)
	_line_inner.width = _config.inner_width
	_line_inner.default_color = Color(_config.inner_color.r, _config.inner_color.g, _config.inner_color.b, _config.inner_alpha)

	# 宽度曲线
	_width_curve = _config.width_curve if _config.width_curve else CometTrailConfig.build_default_width_curve()
	_line_outer.width_curve = _width_curve
	_line_mid.width_curve = _width_curve
	_line_inner.width_curve = _width_curve

	# 初始化偏移
	_trail_offsets.clear()
	_trail_offsets.push_front(Vector2.ZERO)
	_pos_initialized = false


func update(_dt: float, parent: Node2D, chain: ExecutionChain) -> void:
	if not _config:
		return

	var current_pos := parent.global_position

	# 首帧：初始化位置，不产生假位移
	if not _pos_initialized:
		_pos_initialized = true
		_last_global_pos = current_pos
		_trail_offsets.clear()
		_trail_offsets.push_front(Vector2.ZERO)
		_line_outer.points = PackedVector2Array([current_pos])
		_line_mid.points = PackedVector2Array([current_pos])
		_line_inner.points = PackedVector2Array([current_pos])
		return

	var movement := current_pos - _last_global_pos
	_last_global_pos = current_pos

	# 反向补偿已有 trail 点
	for i in range(_trail_offsets.size()):
		_trail_offsets[i] -= movement

	# 当前位置 = 偏移 0
	_trail_offsets.push_front(Vector2.ZERO)

	# 裁剪
	while _trail_offsets.size() > _config.max_samples:
		_trail_offsets.pop_back()

	# 蛇形摆动
	var swayed := _trail_offsets.duplicate()
	var fwd := chain.direction if chain.direction.length() > 0 else Vector2.RIGHT
	var perp := fwd.rotated(PI / 2.0)
	for i in range(swayed.size()):
		var t := float(i) / float(max(1, swayed.size()))
		var offset := sin(t * TAU * _config.sway_freq + chain.elapsed_time * 2.0) * _config.sway_amplitude * t
		swayed[i] += perp * offset

	# 向后偏移到梯形尾部
	if _config.back_offset != 0.0:
		var tail_offset := -fwd * _config.back_offset
		for i in range(swayed.size()):
			swayed[i] += tail_offset

	_line_outer.points = PackedVector2Array(swayed)
	_line_mid.points = PackedVector2Array(swayed)
	_line_inner.points = PackedVector2Array(swayed)


func on_destroy(_parent: Node2D) -> void:
	_line_outer.points = []
	_line_mid.points = []
	_line_inner.points = []
	_trail_offsets.clear()


func reset() -> void:
	_config = null
	_trail_offsets.clear()
	_pos_initialized = false


func is_active() -> bool:
	return _config != null and _config.is_enabled()
