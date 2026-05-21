extends Camera2D

## Camera2D with trauma-based screen shake
## VFX 系统通过 add_trauma(strength) 触发震动

@export var max_offset := Vector2(8.0, 8.0)
@export var max_roll := 0.05
@export var decay_rate := 1.5

var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _noise_y := 0.0

func _ready() -> void:
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

func add_trauma(value: float) -> void:
	_trauma = minf(_trauma + value, 1.0)

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return

	_noise_y += delta * 50.0
	var shake := _trauma * _trauma
	offset.x = max_offset.x * shake * _noise.get_noise_2d(_noise_y, 0.0)
	offset.y = max_offset.y * shake * _noise.get_noise_2d(0.0, _noise_y)
	rotation = max_roll * shake * _noise.get_noise_2d(_noise_y, _noise_y)

	_trauma = maxf(_trauma - decay_rate * delta, 0.0)
