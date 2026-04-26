## SkillSystem 调试测试脚本
## 挂在 SkillTestScene 根节点上，处理测试逻辑
## 注意：SkillSystem 是通过实例化 scenes/skill_system/skill_system.tscn 模板引入的，
## 不是内联子树。调试脚本通过 $"../SkillSystem" 访问技能系统根节点。
extends Node

var _skill_system: Node
var _skill_list: Array[String] = []
var _selected_skill: String = ""
var _caster_pos: Vector2 = Vector2(400, 300)

@onready var skill_btn: Button = %TestBtn
@onready var skill_option: OptionButton = %SkillList
@onready var status_label: Label = %StatusLabel
@onready var info_label: Label = %InfoLabel

func _ready() -> void:
	_skill_system = $"../SkillSystem"

	skill_option.item_selected.connect(_on_skill_selected)
	skill_btn.pressed.connect(_on_test_pressed)

	# 等待 SkillSystem 初始化
	await get_tree().create_timer(0.5).timeout
	_populate_skill_list()
	_update_status("SkillSystem 已初始化")

func _populate_skill_list() -> void:
	# 从 SkillRegistry 动态获取所有技能
	var registry = _skill_system.get_node_or_null("SkillRegistry") if _skill_system else null
	if registry == null:
		registry = _skill_system  # 尝试直接获取

	if registry and registry.has_method("get_all_skill_ids"):
		_skill_list = registry.get_all_skill_ids()
	else:
		# 后备：从 SkillRoot 获取
		var root = _skill_system.get_node_or_null("SkillRoot")
		if root and root.has_method("get_registry"):
			var reg = root.get_registry()
			if reg and reg.has_method("get_all_skill_ids"):
				_skill_list = reg.get_all_skill_ids()

	# 填充 OptionButton
	skill_option.clear()
	for i in range(_skill_list.size()):
		skill_option.add_item(_skill_list[i], i)

	if _skill_list.size() > 0:
		_selected_skill = _skill_list[0]
		info_label.text = "技能数: %d" % _skill_list.size()
	else:
		info_label.text = "未找到技能"
		push_warning("[DebugTest] No skills found in registry")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var click_pos := get_viewport().get_mouse_position()
			# 跳过 UI 区域
			if click_pos.x < 340 and click_pos.y < 500:
				return
			_cast_skill_at_position(click_pos)

func _on_skill_selected(index: int) -> void:
	if index >= 0 and index < _skill_list.size():
		_selected_skill = _skill_list[index]
		_update_status("已选择: " + _selected_skill)

func _on_test_pressed() -> void:
	_cast_skill_at_position(_get_random_position())

func _cast_skill_at_position(target_pos: Vector2) -> void:
	if not _skill_system:
		_update_status("SkillSystem 未就绪")
		return

	# 创建一个虚拟施法者（Node2D）
	var caster := Node2D.new()
	caster.name = "TestCaster"
	caster.global_position = _caster_pos
	get_tree().root.add_child(caster)

	# 创建一个虚拟目标
	var target := Node2D.new()
	target.name = "TestTarget"
	target.global_position = target_pos
	get_tree().root.add_child(target)

	_update_status("施放: " + _selected_skill)

	# 调用 SkillSystem
	_skill_system.cast_skill(caster, _selected_skill, target)

	# 1秒后清理
	await get_tree().create_timer(2.0).timeout
	caster.queue_free()
	target.queue_free()

	_update_status("施放完成")

func _get_random_position() -> Vector2:
	var vp_size := get_viewport().get_visible_rect().size
	var margin: float = 100.0
	var x := randf_range(margin, vp_size.x - margin)
	var y := randf_range(margin, vp_size.y - margin)
	return Vector2(x, y)

func _process(_dt: float) -> void:
	# 实时显示投射物数量
	# SkillSystem 现在是实例化场景，projectile_pool 路径：SkillSystem/ProjectilePool
	var pool = _skill_system.get_node_or_null("ProjectilePool") if _skill_system else null
	if pool and pool.has_method("get_active_count"):
		pass  # 不覆盖技能数量显示

func _update_status(msg: String) -> void:
	status_label.text = msg
