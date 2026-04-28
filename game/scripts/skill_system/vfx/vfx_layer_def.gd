# VFXLayerDef — 单层受击特效定义
# 一个 .tres 文件 = 一个可复用的特效原子
class_name VFXLayerDef
extends Resource

## 特效 ID（层内唯一），使用有意义的英文名称
## 如: "spark_tiny", "burst_fire", "ring_plasma", "shake_strong"
@export var effect_id: String = ""

## 特效类型
@export_enum(
	"particle_burst:0",
	"sprite_burst:1",
	"screen_shake:2",
	"flash:3",
	"ring:4"
)
var kind: int = 0

## 类型特定参数（Dictionary，运行时由 VFXExecutor 读取）
## particle_burst: {count, speed_min, speed_max, size_min, size_max, color, lifetime, spread}
## sprite_burst:   {count, speed, size, texture_path, fade_time, jitter}
## screen_shake:   {strength, duration}
## flash:          {color, duration, radius}
## ring:           {speed, max_radius, width, color}
@export var params: Dictionary = {}
