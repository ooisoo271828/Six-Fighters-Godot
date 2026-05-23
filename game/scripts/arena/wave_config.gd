class_name WaveConfig
extends RefCounted

## 波次配置 — 描述一波怪物的数量、时间分布、空间分布

var count: int = 1                # 本波怪物总数
var spawn_duration: float = 3.0   # 在本时间段内(秒)陆续刷完所有怪物
var zones: Array[SpawnZone] = []  # 可选多个刷怪区域，随机选
var elite_count: int = 0          # 其中精英怪数量（从后往前分配）
var hp_multiplier: float = 1.0
var attack_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var tags: Dictionary = {}         # 扩展标签（如 { "boss_wave": 0 }）

func _init(p_count: int = 1, p_duration: float = 3.0):
	count = p_count
	spawn_duration = p_duration

func add_zone(zone: SpawnZone) -> WaveConfig:
	zones.append(zone)
	return self

func set_elite(count: int) -> WaveConfig:
	elite_count = count
	return self

func set_tag(key: String, value) -> WaveConfig:
	tags[key] = value
	return self
