# 技能系统技术踩坑记录

> 文档版本：v1.0（2026-04-23）
> 维护者：开发团队

---

## GPUParticles2D API 陷阱

**日期**：2026-04-23

**问题描述**：
投射物爆炸和拖尾粒子效果无法正常工作，编辑器报错：
```
Invalid assignment of property or key 'direction' with value of type 'Vector3' 
on a base object of type 'GPUParticles2D'.
```

**根本原因**：
GPUParticles2D **没有** `direction`、`spread`、`initial_velocity_min` 等属性。这些属性都在 **ParticleProcessMaterial** 中。

**错误做法**：
```gdscript
# ❌ 错误：直接在 GPUParticles2D 上设置
_trail_particles.direction = Vector3(1, 0, 0)
_trail_particles.spread = 30.0
explosion.direction = Vector2(0, 0)
```

**正确做法**：
```gdscript
# ✅ 正确：创建 ParticleProcessMaterial 并设置属性
var mat := ParticleProcessMaterial.new()
mat.direction = Vector3(dir.x * 50, dir.y * 50, 0)  # Vector3
mat.spread = 30.0
mat.initial_velocity_min = 10.0
mat.initial_velocity_max = 40.0
mat.scale_min = 0.3
mat.scale_max = 0.8
mat.gravity = Vector3(0, 50, 0)  # Vector3
particle_node.process_material = mat
```

**教训**：
- Godot 的粒子系统，属性配置在 ProcessMaterial 中，不在 Particle Node 上
- 遇到 "Invalid assignment on base object" 错误，说明属性根本不存在，不要纠结类型问题
- 应该先用编辑器脚本验证 API 是否存在

---

## SkillVisualDef 继承体系陷阱

**日期**：2026-04-23

**问题描述**：
```
Parse Error: The member "projectile_kind" already exists in parent class SkillVisualDef.
Parse Error: The member "trail_color" already exists in parent class SkillVisualDef.
```

**根本原因**：
子类 SkillVisualDefDefault 重复定义了基类 SkillVisualDef 中已有的字段。

**继承结构**：
```
SkillVisualDef（基类）
├── skill_id
├── projectile_kind (int)
├── trajectory_type (int)
├── telegraph_ms (int)
├── impact_level (int)
├── trail_color (Color)
├── speed (float)
├── core_texture_path
├── glow_enabled
├── trail_particle_enabled
└── ... 其他粒子参数

SkillVisualDefDefault（子类）
├── core_color (Color)       # 特有
├── core_radius (float)      # 特有
├── ribbon_width (float)     # 特有
└── impact_level_str (String) # 特有（避免与基类 int 冲突）
```

**教训**：
- 扩展基类前先检查基类已有字段
- 子类应该只添加"特有"字段，不要重复基类字段

---

## Resource.get() API 陷阱

**日期**：2026-04-23

**问题描述**：
```
Parse Error: Too many arguments for "get()" call. Expected at most 1 but received 2.
```

**根本原因**：
代码中使用了 `dict.get(key, default)` 格式，但 `_visual_def` 是 `Resource` 类型，不是 `Dictionary`。

**错误做法**：
```gdscript
# ❌ 错误：Resource 类型不支持 .get(key, default)
var core_radius = _visual_def.get("core_radius", 4.0)
var trail_enabled = _visual_def.get("trail_particle_enabled", false)
```

**正确做法**：
```gdscript
# ✅ 正确：直接访问属性，或用 "in" 检查
var core_radius: float = _visual_def.core_radius if "core_radius" in _visual_def else 4.0
```

**教训**：
- GDScript 中 Dictionary 和 Resource 的 API 不同
- Resource 不支持 `.get(key, default)` 语法
- 使用 `"property_name" in obj` 检查属性是否存在

---

## 调试器技能列表硬编码

**日期**：2026-04-23

**问题描述**：
skill_test.tscn 中的技能列表是硬编码的，新增技能后调试器列表不更新。

**错误做法**：
```gdscript
# ❌ 硬编码
var _skill_list: Array[String] = ["ironwall_basic", "ironwall_small_a", "ember_basic"]
```

**正确做法**：
```gdscript
# ✅ 从 SkillRegistry 动态获取
func _populate_skill_list() -> void:
    var registry = _skill_system.get_node_or_null("SkillRegistry")
    if registry and registry.has_method("get_all_skill_ids"):
        _skill_list = registry.get_all_skill_ids()
```

**教训**：
- 调试工具也应该动态化，避免每次改代码还要手动更新
- 利用已有的注册中心模式，保持数据一致性

---

## 状态记录

| 日期 | 问题 | 解决状态 |
|------|------|---------|
| 2026-04-23 | GPUParticles2D API 陷阱 | ✅ 已解决 |
| 2026-04-23 | SkillVisualDef 继承体系冲突 | ✅ 已解决 |
| 2026-04-23 | Resource.get() 参数问题 | ✅ 已解决 |
| 2026-04-23 | 调试器列表硬编码 | ✅ 已解决 |
