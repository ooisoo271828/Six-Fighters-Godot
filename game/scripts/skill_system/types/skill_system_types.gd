class_name SkillCategory
extends RefCounted
## 技能类别

## 普攻
const BASIC: int = 0
## 小技能A
const SMALL_A: int = 1
## 小技能B
const SMALL_B: int = 2
## 大招
const ULTIMATE: int = 3

static func get_name(value: int) -> String:
	match value:
		0: return "BASIC"
		1: return "SMALL_A"
		2: return "SMALL_B"
		3: return "ULTIMATE"
	return "BASIC"

static func from_string(s: String) -> int:
	match s:
		"BASIC": return 0
		"SMALL_A": return 1
		"SMALL_B": return 2
		"ULTIMATE": return 3
	return 0
