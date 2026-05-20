# vfx_override.gd
# VFX 层级池覆盖子 Resource — 技能独有 VFX 配置
class_name VFXOverride
extends Resource

# ── VFX 层级池配置 ──
@export_group("Tier Overrides")
## A层（小组）调用的效果 ID。空 = 使用全局默认。
@export var tier_A: String = ""
## B层（中组）调用的效果 ID。空 = 使用全局默认。
@export var tier_B: String = ""
## C层（大组）调用的效果 ID。空 = 使用全局默认。
@export var tier_C: String = ""

## 技能自定义 Layer（不走层级池，技能独有效果）
@export var custom_layers: Array[Resource] = []
