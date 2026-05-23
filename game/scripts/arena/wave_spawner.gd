class_name WaveSpawner
extends Node

## 波次刷怪执行器 — 将 WaveConfig 转换为时间分布的实际刷怪行为

signal wave_started(config: WaveConfig)
signal enemy_spawned(index: int, total: int, position: Vector2, is_elite: bool)
signal wave_completed()

## 刷怪回调：func(position: Vector2, config: WaveConfig, is_elite: bool) -> void
var spawn_callback: Callable

var is_active: bool = false
var remaining_count: int = 0
var remaining_elite: int = 0
var _config: WaveConfig
var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.0
var _spawned: int = 0
var _rng: Callable

## 开始一波刷怪
## rng_func: 返回 [0,1) 的随机函数
## callback: func(position: Vector2, config: WaveConfig, is_elite: bool) -> void
func start_wave(config: WaveConfig, rng_func: Callable, callback: Callable = Callable()) -> void:
	if is_active:
		push_warning("WaveSpawner: already active, ignoring start_wave")
		return

	_config = config
	_rng = rng_func
	remaining_count = config.count
	remaining_elite = config.elite_count

	_spawn_interval = config.spawn_duration / float(maxi(1, config.count))
	_spawn_timer = 0.0
	_spawned = 0
	is_active = true

	if callback.is_valid():
		spawn_callback = callback

	wave_started.emit(config)

func stop() -> void:
	is_active = false
	_config = null
	remaining_count = 0

func _process(delta: float) -> void:
	if not is_active or remaining_count <= 0:
		return

	_spawn_timer -= delta
	if _spawn_timer > 0:
		return

	_spawn_one()

	if remaining_count > 0:
		_spawn_timer = _spawn_interval

func _spawn_one() -> void:
	if remaining_count <= 0:
		return

	var pos := _pick_spawn_position()
	if pos == Vector2.INF:
		pos = Vector2.ZERO

	var is_elite := false
	if remaining_elite > 0:
		is_elite = true
		remaining_elite -= 1

	_spawned += 1

	if spawn_callback.is_valid():
		spawn_callback.call(pos, _config, is_elite)

	enemy_spawned.emit(_spawned, _config.count, pos, is_elite)

	remaining_count -= 1

	if remaining_count <= 0:
		is_active = false
		wave_completed.emit()

func _pick_spawn_position() -> Vector2:
	if _config.zones.is_empty():
		return Vector2.ZERO

	var zone_idx := int(_rng.call() * _config.zones.size())
	zone_idx = clampi(zone_idx, 0, _config.zones.size() - 1)
	var zone := _config.zones[zone_idx]
	return zone.get_position(_rng)
