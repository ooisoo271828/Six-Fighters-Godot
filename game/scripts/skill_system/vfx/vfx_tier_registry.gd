# VFXTierRegistry — 层级池注册表
# 加载全局配置和所有层级池，提供效果查询接口
class_name VFXTierRegistry
extends Node

## VFX 资源配置根目录
const VFX_ROOT: String = "res://resources/vfx/"
const CONFIG_PATH: String = VFX_ROOT + "vfx_global_config.tres"
const TIERS_DIR: String = VFX_ROOT + "tiers/"

var _global_config: VFXGlobalConfig
var _tiers: Dictionary = {}  # tier_id → VFXTierDef


func _ready() -> void:
	pass


## 初始化：加载全局配置 + 所有层级池
func initialize() -> void:
	_load_config()
	_load_tiers()


func _load_config() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		_global_config = ResourceLoader.load(CONFIG_PATH)
		if _global_config:
			print("[VFXTierRegistry] Config loaded: " + CONFIG_PATH)
		else:
			push_warning("[VFXTierRegistry] Failed to load config: " + CONFIG_PATH)
			_global_config = VFXGlobalConfig.new()
	else:
		print("[VFXTierRegistry] No config found, using defaults")
		_global_config = VFXGlobalConfig.new()


func _load_tiers() -> void:
	var dir := DirAccess.open(TIERS_DIR)
	if dir == null:
		print("[VFXTierRegistry] Tier directory not found: " + TIERS_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var path := TIERS_DIR + file_name
			var tier: VFXTierDef = ResourceLoader.load(path)
			if tier and tier.tier_id != "":
				_tiers[tier.tier_id] = tier
				print("[VFXTierRegistry] Loaded tier: " + tier.tier_id)
		file_name = dir.get_next()
	dir.list_dir_end()


## 获取某层级的默认效果
func get_default(tier_id: String) -> VFXLayerDef:
	if _global_config == null:
		return null
	var default_id: String = _global_config.tier_defaults.get(tier_id, "")
	if default_id == "":
		return null
	return resolve(tier_id, default_id)


## 根据层级 ID + 效果 ID 查找 VFXLayerDef
func resolve(tier_id: String, effect_id: String) -> VFXLayerDef:
	if not _tiers.has(tier_id):
		return null
	var tier: VFXTierDef = _tiers[tier_id]
	for e in tier.effects:
		var layer := e as VFXLayerDef
		if layer and layer.effect_id == effect_id:
			return layer
	return null


## 获取某层级的全部效果列表（用于编辑器浏览/选择）
func get_tier_effects(tier_id: String) -> Array[VFXLayerDef]:
	if not _tiers.has(tier_id):
		return []
	var tier: VFXTierDef = _tiers[tier_id]
	var result: Array[VFXLayerDef] = []
	for e in tier.effects:
		var layer := e as VFXLayerDef
		if layer:
			result.append(layer)
	return result


## 获取所有已注册的层级 ID
func get_tier_ids() -> Array[String]:
	return _tiers.keys()
