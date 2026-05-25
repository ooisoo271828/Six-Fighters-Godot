---
name: gdscript-runtime-pitfalls
description: set_script() 不可靠用 Script.new()，Tween 不是 Node 用 create_tween()，GPUParticles2D 必须设置 texture 否则不可见。
metadata: 
  node_type: memory
  type: reference
  originSessionId: bc79e782-1c8a-48ad-8dcd-6daf37732708
---

### 运行时创建节点
`Node2D.new() + set_script(script)` 在运行时不可靠（会报 Nonexistent function）。用：
```gdscript
var script = load("res://script.gd")
return script.new() as Node2D  # 或 PackedScene.instantiate()
```

### Tween 不是 Node
Godot 4 中 Tween 继承 RefCounted 而非 Node。用 `create_tween()` 替代 `Tween.new() + add_child()`。

### GPUParticles2D 必须设置 texture
默认 texture=null，粒子完全不可见且**无报错**。创建后立即赋值纹理。

### 脚本编译失败检测
`load()` 返回的脚本如果 `get_script_method_list().size() == 0`，说明有编译错误（"zombie" 脚本）。用 `ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)` 强制重载。

### 成员变量位置
所有成员变量集中在 extends 后的文件顶部声明，不夹在函数定义之间（否则解析器可能产生 "Variable has same name" 错误）。

**Why:** 上述每个问题都导致过 >=30 分钟的调试时间，且都因为"无报错"或"报错信息误导"而难以定位。
**How to apply:** 每条都是创建节点/粒子/脚本时的硬性检查点。
