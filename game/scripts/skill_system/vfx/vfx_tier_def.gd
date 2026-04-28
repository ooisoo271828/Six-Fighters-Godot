# VFXTierDef — 层级池定义
# 一个 .tres 文件 = 一个层级及其包含的所有特效
class_name VFXTierDef
extends Resource

## 层级标识，如 "A", "B", "C"
@export var tier_id: String = ""

## 层级显示名称，如 "小组", "中组", "大组"
@export var display_name: String = ""

## 本层池中所有已注册效果
@export var effects: Array[Resource] = []
