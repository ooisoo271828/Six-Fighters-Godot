# 🛡 Godot AI 编程避坑指南

> **版本**: v4.1 | 创建: 2026-04-28 | 更新: 2026-05-25 | 状态: 持续更新
>
> 本指南汇总了 Six-Fighters-Godot 项目开发过程中反复出现的错误、隐蔽陷阱和系统性教训。
> 目标：避免团队在同一个坑里跌倒两次。

---

## 目录

1. [环境与工具链陷阱](#一环境与工具链陷阱)
2. [GDScript 语法与语义陷阱](#二gdscript-语法与语义陷阱)
3. [Godot 引擎特性陷阱](#三godot-引擎特性陷阱)
4. [粒子系统陷阱（重点）](#四粒子系统陷阱重点)
5. [资源与缓存陷阱](#五资源与缓存陷阱)
6. [工作流与方法论陷阱](#六工作流与方法论陷阱)
7. [UI 控件定位陷阱（重点）](#七ui-控件定位陷阱重点)
8. [连锁错误与修错方法论](#八连锁错误与修错方法论)
9. [数据流设计陷阱](#九数据流设计陷阱)
10. [GDScript 类型系统陷阱](#十gdscript-类型系统陷阱)
11. [AI 幻觉与上下文污染](#十一ai-幻觉与上下文污染)
12. [坐标与单位换算陷阱（重点）](#十二坐标与单位换算陷阱重点)
13. [架构设计陷阱](#十三架构设计陷阱)

---

## 一、环境与工具链陷阱

### 1.1 Git Bash 中 sed 的 `\t` 会变成字面字符

**症状**：用 `sed` 插入带 tab 的行时，得到的是 `t` 字母而不是 tab。
**根因**：Git Bash 的 `sed` 实现中，`\t` 在 replacement 部分不被识别为转义序列，而是字面字母 `t`。

```bash
# ❌ 错误写法：sed 会把 \t 当作字面字母 t
sed -i '590a\\t\tline.width_curve = curve' file.gd
# 结果: t	line.width_curve = curve  ← 行首多了一个 t！

# ✅ 正确写法一：用 Bash 变量
TAB=$'\t'
sed -i "590a\\${TAB}${TAB}line.width_curve = curve" file.gd

# ✅ 正确写法二：用 Python 替代 sed
python3 -c "
with open('file.gd', 'r+') as f:
    content = f.read()
    content = content.replace('old', '\tnew')
    f.seek(0)
    f.write(content)
    f.truncate()
"
```

**同样的陷阱也适用于 `\n`**：sed 的 `a` 命令中 `\n` 不可用，需要用反斜杠换行。

**最佳实践**：在 Godot 项目中对 `.gd` 文件做结构性修改时，**优先用 Python 脚本而非 sed**。Python 没有转义歧义，且可处理 UTF-8 中文。

---

### 1.2 终端中文显示乱码

**症状**：Python 读取 `.gd` 文件时，中文注释显示为 `# ��� 硬编码参数`。
**根因**：Windows 终端编码非 UTF-8，但 `.gd` 文件使用 UTF-8 编码。
**预防**：
- Python 读写 `.gd` 文件时始终指定 `encoding='utf-8'`
- 终端输出用 ASCII 替代中文

```python
# ✅ 正确
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# ❌ 错误（Windows 默认 gbk 编码）
with open(path, 'r') as f:  # 可能抛 UnicodeDecodeError
    content = f.read()
```

---

## 二、GDScript 语法与语义陷阱

### 2.1 类体内缩进不一致 → "Unexpected Indent in class body"

**症状**：Godot 报 `Unexpected "Indent" in class body.`，且同一文件中的后续所有 `@export` 字段都无法解析。
**根因**：GDScript 要求类体内所有成员声明使用**一致的缩进层级**。混用 0 tab 和 1 tab 会导致解析器中断。

```
# ❌ 错误：同一文件中混用缩进
@export var impact_shake_duration: float = 0.0  # 0 tab
# ── 新加字段 ──
    @export var hit_vfx_tier_A: String = ""     # 1 tab ← 不一致！
# ── 旧参数 ──
@export var glow_enabled: bool = true           # 0 tab

# ✅ 正确：全部统一
@export var impact_shake_duration: float = 0.0
@export var hit_vfx_tier_A: String = ""
@export var glow_enabled: bool = true
```

**最佳实践**：
- 修改 `.gd` 文件前先 `cat -A` 查看真实缩进
- 新加字段的缩进层级与相邻字段**完全一致**
- 不要同时使用 `0 tab` 和 `1 tab` 两种风格

---

### 2.2 忘记声明 `class_name`

**症状**：`Could not find type "XXX" in the current scope.`
**根因**：脚本文件定义了新类但未写 `class_name`，或写了但编辑器尚未注册。
**规律**：这个问题今天出现了两次（`VFXLayerDef` 等 3 个 Resource 子类 + `VFXTierRegistry`）。

```gdscript
# ❌ 错误：没有 class_name
extends Node
func initialize() -> void:
    pass

# ✅ 正确
class_name VFXTierRegistry
extends Node
```

**触发编辑器注册的方法**：
```gdscript
var ei = executeContext.editor_plugin.get_editor_interface()
ei.get_resource_filesystem().scan()
# 或删除 .godot/global_script_class_cache.cfg 后重启编辑器
```

---

### 2.3 `Line2D.width_curve` 需要 `Curve` 而非 `CurveTexture`

**症状**：`Value of type "CurveTexture" cannot be assigned to a variable of type "Curve".`
**根因**：`Line2D.width_curve` 属性期望 `Curve` 资源对象，而非 `CurveTexture`（后者是 `ParticleProcessMaterial.scale_curve` 用的）。
**修复**：
```gdscript
# ❌ 错误
var ct := CurveTexture.new()
ct.curve = curve
line.width_curve = ct

# ✅ 正确
line.width_curve = curve  # curve 已经是 Curve 对象
```

---

### 2.4 `ParticleProcessMaterial.acceleration` 不是合法属性

**症状**：`Invalid assignment of property or key 'acceleration' with value of type 'Vector3' on a base object of type 'ParticleProcessMaterial'.`
**根因**：`ParticleProcessMaterial` 没有 `acceleration` 属性。加速效果通过 `gravity` 属性实现。
**修复**：使用 `mat.gravity = Vector3(x, y, z)` 替代。

---

### 2.5 局部变量未使用警告

**症状**：`UNUSED_VARIABLE` 或 `UNUSED_PARAMETER` 警告。
**根因**：声明了变量但没有使用。
**修复**：前缀加下划线：`_life_min`、`_base_w`、`_max_pts`。
**注意**：前缀下划线只是**压制警告**，不改变变量行为。如果变量确实需要被使用，修复使用逻辑而非压制。

---

### 2.6 同文件声明多个 `class_name` 只有第一个生效

**症状**：一个 `.gd` 文件中写了两个 `class_name`，第二个类在场景或其他脚本中提示 `Identifier not declared`。

```gdscript
# ❌ 错误：wave_spawner.gd 中声明了两个 class_name
class_name WaveConfig
extends RefCounted
# ... 中间代码 ...
class_name WaveSpawner  # ← 此声明被 Godot 静默忽略！
extends Node
```

**根因**：Godot 4 规定**每个 `.gd` 文件只能有一个 `class_name`**。第二个 `class_name` 会被解析器忽略，不报错、不警告，但该类型无法在任何地方使用。

**排查思路**：
- 文件定义了多个类？搜索文件中的 `class_name` 出现次数
- 报 `Identifier not declared` 但文件看起来有声明？检查是否是该文件中**第二个** `class_name`

**修复**：每个类独立一个文件，文件按类名命名：
```
wave_config.gd   → class_name WaveConfig
wave_spawner.gd  → class_name WaveSpawner
```

**规则**：**在 GDScript 中，永远一个文件一个类**。当一次 PR 需要新增多个类时，容易为了"减少文件数量"把多个类塞进一个文件，这是必须抵制的诱惑。

---

### 2.7 函数参数名遮蔽类成员变量

**症状**：编译通过但报 `SHADOWED_VARIABLE` 警告。参数名和成员变量同名，函数体内无法通过变量名访问成员变量。

```gdscript
# ❌ 错误：参数 center 遮蔽了成员变量 center
var center: Vector2

static func circle(center: Vector2, radius: float) -> SpawnZone:
    return SpawnZone.new(Type.CIRCLE, center, Vector2(radius, 0))
    # 此处的 center 是参数（static 函数中也不是问题），但 IDE 警告

# ✅ 正确：参数加 p_ 前缀区分
static func circle(p_center: Vector2, radius: float) -> SpawnZone:
    return SpawnZone.new(Type.CIRCLE, p_center, Vector2(radius, 0))
```

**规范**：所有可能和成员变量冲突的参数加 `p_` 前缀（`p_center`、`p_count`、`p_name`）。特别在静态工厂方法中，这是高频错误。

### 2.8 内部类（inner class）成员的缩进与外部类相同

**症状**：`Parse Error: Unexpected "Indent" in class body`
**根因**：GDScript 的内部类（`class` 关键字定义的嵌套类）的成员变量和方法，使用与外部类**相同级别**的缩进（一个制表符），而不是"更深一级"。

```gdscript
class_name SkillEffect
extends RefCounted

class SkillExecutionContext:
    extends RefCounted

    var caster: Node2D
    var visual_def: Resource

    # ❌ 错误：新加的字段用了双制表符（看起来像是"再深一层"）
        var delivery_type: String = "projectile"
        var tracking_enabled: bool = false

    # ✅ 正确：与其他成员字段使用相同的单制表符缩进
    var delivery_type: String = "projectile"
    var tracking_enabled: bool = false

    func _to_string() -> String:
        return "Context"
```

**心理陷阱**：人眼看到 `class SkillExecutionContext:` 后面有缩进，会直觉认为"里面的成员应该再缩进一层"。但 GDScript 的 `class` 块不增加缩进层级——它和 `var`、`func` 一样是类体的顶层成员。

**排查思路**：收到 `Unexpected "Indent"` 时，检查内部类的字段是否意外多了一层缩进。

---

## 三、Godot 引擎特性陷阱

### 3.1 资源缓存不刷新

**症状**：修改了 `.gd` 或 `.tres` 文件，重启编辑器甚至删除 `.godot/` 后旧行为仍然存在。
**根因**：Godot 4 维护多层资源缓存（RAM 缓存 + 文件系统缓存 + UID 缓存），外部文件修改可能不被及时检测。

**诊断方法**：
```gdscript
# 检查编辑器是否加载了最新脚本
var script = load("res://path/to/file.gd")
print("Source length: " + str(script.source_code.length()))
# 检查关键内容是否存在
print("Has new code: " + str("new_function" in script.source_code))
```

**解决步骤**（按强度递增）：
1. 编辑器内触发文件系统扫描：`ei.get_resource_filesystem().scan()`
2. 用 `ResourceLoader.load(path, "", 1)` 以 CACHE_MODE_REPLACE 模式重新加载
3. 删除 `.godot/global_script_class_cache.cfg` 和 `.godot/uid_cache.bin`
4. **完整关闭并重启 Godot 编辑器**
5. 删除整个 `.godot/` 目录后重启（核武器选项）

---

### 3.2 `print()` 输出在游戏运行时不经过编辑器插件日志

**症状**：在游戏场景（`ei.play_custom_scene()`）中添加的调试 `print()` 语句，在 `hastur.py logs` 中不可见。
**根因**：`HasturLogger` 是编辑器插件级别的日志系统，仅捕获编辑器进程的 `OS.print()` 调用。游戏运行时进程的 `print()` 输出只在 Godot 编辑器的 Output 面板可见。
**预防**：区分调试输出的目标渠道：
- 编辑器插件级别的日志 → `hastur.py logs`
- 游戏运行时的调试 → 在 Godot 编辑器的 Output 面板查看
- 或通过 `Engine.get_main_loop()` 等方式输出到编辑器

---

### 3.3 Camera2D 平滑跟随导致场景切换时镜头漂移

**症状**：离开基地场景再返回时，镜头从左上角平滑漂移到玩家上次所在位置，即使已经正确恢复了 `camera_anchor.position`。

**根因**：Camera2D 的 `position_smoothing_enabled`（启用平滑跟随）与 Godot 节点的初始化顺序共同导致。

```
场景加载时序:
  1. Camera2D._ready() 执行
     → 此时父节点 CameraAnchor.position = (0,0)（场景文件默认值）
     → Camera2D 内部 smoothed_position = (0,0)  ← 问题起源
  2. 父节点 hub_scene._ready() 执行
     → _restore_camera_position() 设置 CameraAnchor.position = saved_pos
     → Camera2D 检测到父节点位置变化
     → 从 smoothed_position (0,0) 向 saved_pos 平滑插值 ← 可见漂移！
```

这就是为什么明明位置设对了，镜头仍然从左上往右下移动——Camera2D 的平滑系统在第一步就锚定了初始位置，后续父节点跳变被它当作"需要平滑跟随的运动"来处理。

**修复**：在恢复位置后立即调用 `reset_smoothing()`，告知 Camera2D 立刻对齐目标位置，跳过平滑过渡：

```gdscript
func _restore_camera_position() -> void:
	camera_anchor.position = GameManager.hub_camera_position
	camera_2d.reset_smoothing()  # ← 关键：清除平滑缓存，瞬间对齐
```

**`reset_smoothing()` 的作用**：重置 Camera2D 内部缓存的 `smoothed_x` / `smoothed_y` 值为当前目标位置。调用后下一帧直接渲染最终位置，没有任何插值过渡。

**教学要点**：
1. Godot `_ready()` 调用顺序是**自底向上**（子节点先于父节点）。这意味着子节点的 `_ready()` 执行时，父节点的属性尚未被自定义逻辑修改
2. `position_smoothing_enabled` 不仅控制游戏中的平滑跟随，也会在**场景初始化和节点位置跳变时生效**——这是它最容易被忽略的副作用
3. 任何需要在场景切换后"瞬间就位"的 Camera2D，都应该在位置恢复后调用 `reset_smoothing()`
4. 同一原理也适用于 `RemoteTransform2D`、`PathFollow2D` 等有插值/跟随行为的节点——场景切换时可能需要重置内部状态

**排查思路**：
```
镜头位置正确但仍有漂移动画 → 检查 Camera2D 是否启用 smoothing
                             → 检查是否有节点在 _ready() 之后改变父节点位置
                             → 在位置恢复处添加 reset_smoothing()
```

**适用场景**：
- 基地/城镇场景切换回主场景时
- 传送门/关卡切换后镜头归位
- 任何通过 `change_scene_to_file()` 返回的场景
- 打开/关闭 UI 面板后恢复镜头位置

---

### 3.4 从现有代码推断行为不可靠——可能有旧版缓存

**症状**：修改了函数逻辑后，运行时行为与代码内容不匹配。
**根因**：编辑器可能运行的是旧版编译后的脚本，而非磁盘上当前文件的内容。
**诊断**：在函数入口添加唯一定位标记（如 `print("**_FUNCTION_NAME_**")`），通过检查日志确认函数是否真的执行了新代码。

### 3.5 新增 `@export` 属性后，现有 `.tres` 资源不识别新属性

**症状**：给脚本新增了 `@export var hit_aoe_radius: float = 0.0`，但通过 `ResourceLoader.load()` 加载的 .tres 文件访问该属性时报 `Invalid access to property or key`。

**根因**：Godot 的资源缓存机制。.tres 文件在首次加载时被缓存，缓存中不包含脚本后来新增的属性。即使磁盘上的 .tres 文件已经写了新属性值，缓存中的资源对象仍然没有该属性。

**修复**：强制重新加载并保存资源：
```gdscript
# 强制忽略缓存加载
var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
# 重新保存到磁盘（更新缓存）
ResourceSaver.save(res, path)
```

**触发场景**：
- 给 SkillDef 等 Resource 脚本新增 `@export` 字段后
- 编辑器重启后，旧 .tres 文件的缓存仍然有效
- 通过 Hastur 执行代码访问新属性时失败

**预防**：新增 `@export` 属性后，**立即对所有引用该脚本的 .tres 文件执行强制重载+保存**。或者重启编辑器（会清理缓存）。

### 3.6 静态单例持旧代码——编辑器内 Play 不重置 `static var`

**症状**：修改了 `class_name` 脚本（如 `VFXTextureManager`）并在其中添加了新功能（例如新的程序化纹理生成函数），但在编辑器内 Play 场景时，新功能不生效。旧版本代码仍然运行。

**根因**：Godot 编辑器中 `EditorInterface.play_custom_scene()` 在**同一进程内**运行场景。`static var`（类静态变量）在进程生命周期内持久存在。修改脚本后重新 Play，`_instance` 仍然是旧脚本创建的对象，不具备新功能。

```gdscript
# ❌ 错误：retain old instance that was created before script modifications
static func get_instance() -> VFXTextureManager:
    if _instance == null:
        _instance = VFXTextureManager.new()
    return _instance  # may be outdated if script was recompiled
```

**修复**：在入口处主动失效旧实例：

```gdscript
func _ready() -> void:
    VFXTextureManager._instance = null  # ← 强制下次 get_instance() 创建新实例
    _tex_manager = VFXTextureManager.get_instance()
```

**规律**：涉及 `static var _instance` 缓存的单例，在编辑器内 Play 场景时必然遇到此问题。如果在 Play 过程中修改了单例脚本，缓存的旧实例不会自动失效。

**排查思路**：
- 修改了 `class_name` 脚本但 Play 后不生效 → 检查是否有 `static var` 缓存了旧实例
- 在 `_ready()` 中添加 `ClassName._instance = null` 测试是否修复
- 对比：**"新游戏进程"**（菜单 → 新游戏，跑独立进程）vs **"编辑器内 Play"**（`EditorInterface.play_custom_scene()`，同一进程）

---

### 3.7 `HitVFXNode.setup_sprite()` 已自动将节点加入场景树——不要重复 `add_child()`

**症状**：`Can't add child '...' to 'VFX', already has a parent 'SkillDemo'.`

**根因**：`HitVFXNode.setup_sprite()` 内部调用 `_ensure_in_tree()`，已经将节点添加到场景树。之后再调用 `parent.add_child(node)` 会报错。

```gdscript
# ❌ 错误：重复 add_child
var burn: HitVFXNode = HitVFXNode.new()
burn.setup_sprite(tex, color, scale, pos, lifetime)  # ← 已经加入场景树
burn.play()
parent.add_child(burn)  # ← "already has a parent"！

# ✅ 正确：setup_sprite 后不再 add_child
var burn: HitVFXNode = HitVFXNode.new()
burn.setup_sprite(tex, color, scale, pos, lifetime)
burn.play()
```

**规律**：`HitVFXNode` 和 `Sprite2D` 的行为不同：
- `Sprite2D.new()` → **不**自动加入场景树，需要手动 `add_child()`
- `HitVFXNode.new()` + `setup_sprite()` → **自动**加入场景树，不要重复 `add_child()`

**排查思路**：报 `already has a parent` 错误时，检查被添加的节点是否通过 `setup_sprite()`/`_ensure_in_tree()` 已自动加入树。自定义 Sprite2D 和池化 HitVFXNode 的树管理策略不同。

---

## 四、粒子系统陷阱（重点）

### 4.1 `GPUParticles2D.direction = Vector3(0,0,0)` 导致粒子向右喷射

**症状**：所有粒子向右方向喷射，无论设置什么 spread 值。
**根因**：`ParticleProcessMaterial.direction` 在 Godot 4 中默认值为 `Vector3(1, 0, 0)`（向右）。当赋值为零向量 `Vector3(0,0,0)` 时，GPU 的 `normalize()` 操作结果未定义，不同的 GPU 驱动有不同行为。实测中退化为默认值 `(1, 0, 0)`（向右）。

```gdscript
# ❌ 错误：零向量导致未定义 GPU 行为
mat1.direction = Vector3(0, 0, 0)
mat1.spread = 252.0  # 粒子在右向 252° 锥体内喷射 → 大部分向右

# ✅ 正确：用非零方向向量 + 360° spread = 全方位均匀喷射
mat1.direction = Vector3(0, -1, 0)  # 向上，非零
mat1.spread = 360.0                 # 360° = 全方向
mat1.gravity = Vector3.ZERO          # 无重力偏斜
```

**更可靠方案**：完全放弃 `GPUParticles2D/CPUParticles2D`，改用 `Sprite2D + Tween` 手动实现粒子爆发。完全可控，无 GPU 行为不确定性。

```gdscript
# Sprite2D + Tween 粒子爆发（推荐方案）
for i in range(count):
    var angle := float(i) / float(count) * TAU + randf_range(-0.15, 0.15)
    var dir := Vector2(cos(angle), sin(angle))
    var speed := randf_range(speed_min, speed_max)
    var spark := Sprite2D.new()
    spark.texture = shared_circle_texture
    spark.global_position = hit_pos
    spark.modulate = color
    get_tree().root.add_child(spark)

    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(spark, "global_position", spark.position + dir * speed * 0.3, lifetime)
    tween.tween_property(spark, "modulate:a", 0.0, lifetime).set_delay(lifetime * 0.3)
    tween.tween_callback(spark.queue_free).set_delay(lifetime + 0.1)
```

---

### 4.2 `CPUParticles2D` 默认方向右、重力向下

**症状**：所有受击粒子向右下角喷射。
**根因**：`CPUParticles2D` 的默认值：
- `direction = Vector2(1, 0)`（向右）
- `gravity = Vector2(0, 10)`（向下）
- `spread = 0`（无扩散）

如果创建 `CPUParticles2D` 后不设置这些参数，粒子全部向右飞并受重力下拉。这就是最初的"受击特效向右下角喷射"问题的根因。

**修复**：创建粒子后立即覆盖默认值：
```gdscript
p.direction = Vector2(0, -1)  # 向上
p.spread = 360.0               # 全方向
p.gravity = Vector2.ZERO       # 无重力
```

---

### 4.3 多套 VFX 系统同时执行导致重叠

**症状**：同一个命中事件触发两套独立的粒子效果（新 Sprite2D 爆发 + 旧 CPUParticles2D 爆发），方向相互矛盾。
**根因**：`ProjectileNode._spawn_explosion()` 和 `SkillVFXManager._on_skill_hit()` 是两个独立的 VFX 触发路径，都监听同一命中事件。
**预防**：
- 明确分层：每套 VFX 系统有清晰的责任边界
- 用 skill_id 白名单阻止冲突：VFXManager 跳过自行处理特效的技能
```gdscript
var skip_skills := ["missile_storm"]
if info.get("skill_id", "") in skip_skills:
    return
```

---

### 4.4 GPUParticles2D.emission_shape / emission_rect_extents 在 Godot 4.6 中不存在

**症状**：编译报错或运行时报错 `Invalid assignment of property or key 'emission_shape'`。

**根因**：Godot 4.6 的 `GPUParticles2D` 没有 `emission_shape` 和 `emission_rect_extents` 属性。2D 粒子系统不支持矩形发射区域。

```gdscript
# 错误：在 GPUParticles2D 上使用不存在的属性
_particles.emission_shape = 1

# 正确：用多个 Sprite2D 手动排列成线/弧
for i in range(count):
    var s := Sprite2D.new()
    var t := float(i) / float(count - 1) - 0.5
    s.position = perp * t * width
    parent.add_child(s)
```

**预防**：使用前先枚举 `GPUParticles2D` 的属性列表确认属性存在。

---

### 4.5 Sprite2D.scale vs GPUParticles2D 粒子缩放：含义完全不同

**症状**：用 `Sprite2D` 代替粒子系统时，`scale = Vector2.ONE * 5.0` 后 Sprite 变得极大。

**根因**：GPUParticles2D 的 scale 是相对缩放系数，Sprite2D 的 scale 是纹理像素的直接倍数。

```gdscript
# 错误
s.scale = Vector2.ONE * 5.0  # 32x32 CIRLCE  → 160x160 像素

# 正确：按期望像素尺寸计算
var desired_px: float = 10.0
var tex_size := tex.get_size()
s.scale = Vector2.ONE * (desired_px / tex_size.x)
```

**最佳实践**：从 GPUParticles2D 迁移到 Sprite2D 时，scale 先缩小 10 倍再逐步调整。

---

## 五、资源与数据文件陷阱

### 5.1 `.tres` 文件属性不存在的静默忽略

**症状**：在 `.tres` 文件中设置了属性值，但运行时读取到的是默认值。
**根因**：当 `.tres` 引用的脚本类不包含某属性时，Godot 会**静默忽略**该属性行，不报错、不警告。只有通过 `get_property_list()` 才能发现差异。

**诊断**：
```gdscript
var res = load("path/to/resource.tres")
print(res.get("property_name"))  # 返回 null 或默认值
```

**解决**：确保 `.tres` 引用的脚本文件已更新并包含所需属性，然后清理资源缓存。

---

### 5.2 `vfx://` 纹理前缀需要在每个组件中单独实现

**症状**：在 `SkillVisualDef.tres` 中设置了 `tex_glow_path = "vfx://flame_aura"`，但运行时光晕仍然显示为默认圆形。

**根因**：`vfx://` 前缀支持只在 `comp_core_sprite.gd` 中实现了，但 `comp_glow.gd` 中加载光晕纹理的代码没有处理该前缀。

```gdscript
# ❌ comp_glow.gd 不支持 vfx://
if _body.tex_glow_path != "" and ResourceLoader.exists(_body.tex_glow_path):
    _glow_texture = load(_body.tex_glow_path)
# ResourceLoader.exists("vfx://flame_aura") 返回 false
# _glow_texture 保持 null，回退到 soft_circle（圆形！）

# ✅ 正确 需要与 comp_core_sprite.gd 一样支持 vfx://
if _body.tex_glow_path != "":
    if _body.tex_glow_path.begins_with("vfx://"):
        var key: StringName = StringName(_body.tex_glow_path.trim_prefix("vfx://"))
        _glow_texture = tex_manager.get_texture(key)
    elif ResourceLoader.exists(_body.tex_glow_path):
        _glow_texture = load(_body.tex_glow_path)
```

**规律**：项目中有多个纹理加载点（`comp_core_sprite`、`comp_glow`、`comp_trail_particles` 等），每个都需要独立添加 `vfx://` 支持。新增一种纹理引用方式时，**必须 grep 全项目所有纹理加载点**。

---

### 5.3 `.tres` 属性不存在的静默回退

**症状**：在 `.tres` 中设置了新的视觉属性，运行时表现为默认值，且无任何报错。

**根因**：当 `.tres` 引用的 Resource 子类不包含某个属性时，Godot **静默忽略**该属性行。后续代码读取到的是 `@export` 声明的默认值。

**本项目的典型场景**：
1. 给 `ProjectileVisual` 新增了 `@export var core_rotation_speed: float = 0.0`
2. 在 `falling_meteor.tres` 中设置了 `core_rotation_speed = 0.5`
3. 但编辑器中 `projectile_visual.gd` 的缓存尚未更新
4. `.tres` 加载时 `core_rotation_speed` 不被识别 → 静默忽略
5. `vis.body.core_rotation_speed` 读取到的是默认值 `0.0`

**预防**：新增 `@export` 属性后，**强制重启编辑器**（仅文件扫描不够）。

---

### 5.4 程序化纹理的中心点偏移误区

**症状**：生成的纹理看起来是菱形/橄榄形而非预期的水滴形。

**根因**：程序化生成纹理时，把最宽点放在了纹理中心（x=50%），导致左右对称、形似菱形。正确的水滴形需要把最宽点偏右（35-40%），右侧保持圆弧，左侧逐渐收窄。

```gdscript
# ❌ 菱形：最宽点在中心，左右对称
var cx := size * 0.5
if dx >= 0.0:
    local_radius = front_radius * (1.0 - dx / (size * 0.5))
else:
    local_radius = back_radius
# 最宽点在 x=0.5 处 → 左右对称 → 菱形！

# ✅ 水滴形：最宽点偏右，右侧圆弧，左侧收窄
var center_x := size * 0.4
if px >= center_x:
    local_r = round_r * (1.0 - pow(t, 2.5))  # 右侧圆弧
else:
    local_r = tail_min_r + (round_r - tail_min_r) * pow(1.0 - t, 2.0)  # 左侧收窄
```

**设计原则**：任何"前圆后尖"形状的最宽点都不在中心——圆头的中心才是最宽点。设计程序化纹理时先画出期望形状的截面图，再转化成数学公式。

---

### 5.5 旋转 Sprite 时需考虑所有相关层

**症状**：设置了 `_glow_sprite.rotation = angle`，但火焰气团纹理仍然显示为水平朝向。

**根因**：光晕系统有多个 Sprite 层（`_glow_sprite`、`_glow2_sprite`、`_ray_sprite`），但只旋转了主光晕层，其他层的默认朝向（水平向右/0°）覆盖了视觉效果。

```gdscript
# ❌ 只旋转了主光晕，外层光晕仍然是水平朝向
_glow_sprite.rotation = chain.direction.angle()

# ✅ 旋转所有光晕层
if chain.direction.length() > 0.0:
    var dir_angle: float = chain.direction.angle()
    _glow_sprite.rotation = dir_angle
    _glow2_sprite.rotation = dir_angle
```

**规律**：Godot 的 Component 模式中，一个视觉效果由多个 Sprite 层叠加构成。修改一个层的 transform 时，检查所有相关层是否需要同步修改。

---

### 5.6 资源 UID 缓存过期

**症状**：删除 `.godot/` 后重新打开项目，资源引用仍然错误。
**根因**：`.godot/uid_cache.bin` 保存了所有资源的 UID 映射。如果文件被移动或重命名，缓存会过期。
**解决**：删除 `.godot/uid_cache.bin` 和 `.godot/global_script_class_cache.cfg` 后重启编辑器。

---

## 六、工作流与方法论陷阱

### 6.1 修改错代码路径

**症状**：拼命修改一个文件但行为不变——因为真正执行的代码在另一个文件。
**根因**：通过信号连接、继承体系、或对象池机制，实际运行的代码路径与直觉不符。
**案例**：受击特效向右喷射的问题，反复修改 `projectile_node.gd:_spawn_explosion()` 无效，最终发现真正的"元凶"是 `skill_vfx_manager.gd:_on_skill_hit()` 中的独立第二套粒子系统。
**预防**：排查时用 `print()` 断言每段代码是否执行，沿着信号/调用链向上追溯。

---

### 6.2 一次性改太多，无法定位问题

**症状**：一口气改了几处代码，出问题后不知道哪一处改坏了。
**预防**：
- **每次只改一个地方**，改完就测试
- 用 git 分步提交：`git add -p` 分块
- 不改的代码绝不碰（"Surgical Changes" 原则）

---

### 6.3 用不可靠的工具做精细修改

**症状**：sed、echo、shell 重定向等工具在复杂文件修改场景中频繁引入隐性错误。
**根因**：shell 工具：
- 不感知文件编码（UTF-8 vs GBK）
- 不感知 GDScript 语法
- 转义规则与 Godot 不同
- Windows 环境下行为不一致

**建议工具优先级**：
1. ✅ **Python 脚本** — 可处理编码、精确字符串操作、语法安全
2. ✅ **Godot 编辑器 API**（通过 plugin）— 引擎级操作
3. ⚠️ **sed/awk** — 仅用于一行以内的简单替换
4. ❌ **shell 重定向 + echo** — 避免

### 6.4 Python 字符串替换的隐性陷阱

**症状**：用 Python 执行 `content.replace(old, new)` 后，文件内容没有变化。或者替换了错误的位置。

**陷阱一：中文编码匹配失败**

Python 在 Windows 终端下读取含中文的 `.gd` 文件时，`repr()` 输出的中文显示为乱码 `�`。此时在 Python 脚本中构造的 `old` 字符串如果包含这些中文注释，**替换会静默失败**。

```python
# ❌ 失败：old 中的中文注释无法匹配（终端编码问题）
old = '\t# 火焰气团纹理（水滴形：前圆后尖）'
content.replace(old, new, 1)  # 返回原字符串，不报错！

# ✅ 成功：用不含中文的唯一代码锚点匹配
old = 'func _generate_flame_aura(size: int) -> Texture2D:'
# 或者用 Python 的 index + slice 方式
idx = content.find('关键变量名')
content = content[:idx] + new_code + content[idx + len(old_code):]
```

**预防**：
- 在 Python 替换脚本中，用**代码关键词**（函数名、变量名）而非注释作为匹配锚点
- 如果必须按上下文替换，用 `content.find()` 定位后再切片替换
- 替换后立即验证：`print('存在' if old in content else '不存在')`

**陷阱二：`content.replace()` 替换了错误的同名变量**

当文件中多个位置有相同的变量名时，`content.replace()` 替换的是**第一个**匹配，可能导致错误位置的变量被修改。

```python
# ❌ 替换了 _generate_rock_irregular 中的变量，而非 _generate_mushroom_frame 中的
fixes = [('var img := Image.create(...)', 'var img: Image = Image.create(...)')]
for old, new in fixes:
    content = content.replace(old, new, 1)  # 替换了第一个匹配
    # 如果两个函数都有 var img :=，替换的是第一个函数中的！
```

**预防**：
- 使用 `content.rfind()` 替换最后一个匹配（适合新追加的函数）
- 或使用 `content.find()` 定位到目标区域后切片替换
- 或在替换前先检查目标区域是否唯一

**陷阱三：替换结果受原文件缩进影响**

用 `content[:idx] + replacement` 方式替换时，`content[:idx]` 已经包含了原行的缩进（tab 字符）。如果 `replacement` 也带了缩进，最终结果是**两层缩进叠加**，导致缩进错误。

```python
# 原文件：\t\t_glow_sprite.rotation = chain.direction.angle()
idx = content.find('_glow_sprite.rotation = chain.direction.angle()')
# content[:idx] 以 \t\t 结尾（原行的缩进）
replacement = '\tif xxx:\n\t\tbody'  # 也带了缩进
# 最终：\t\t\tif xxx   ← 三层缩进！比预期多一层

# ✅ 正确：replacement 不带缩进，或与 content[:idx] 的缩进互补
replacement = 'if xxx:\n\t\t\tbody'
```

**预防准则**：
1. 替换后**立即检查文件内容**，确认替换效果
2. 切片替换时，`replacement` 不带前导缩进，利用 `content[:idx]` 已有的缩进
3. 使用 `content.replace()` 时，替换后 `print('成功' if old not in content else '失败')` 验证
4. 避免在 old/new 字符串中包含中文注释

---

### 6.4 没有区分"编辑器日志"和"游戏运行时日志"

**症状**：在游戏场景中添加的 `print()` 在开发工具的日志查询中不可见。
**预防**：
- 明确调试输出的目标系统
- 编辑器插件交互 → `hastur.py logs`
- 游戏运行时调试 → Godot Output 面板
- 必要时使用 `push_error()/push_warning()` 强制输出到编辑器

### 6.5 多个脚本并行修改同一文件导致重复声明

**症状**：`Parse Error: Variable "xxx" has the same name as a previously declared variable`
**根因**：当两个独立的 Python 脚本（或两次独立的编辑操作）先后修改同一个 .gd 文件，各自添加一个变量声明时，第二次修改不会检查第一次是否已经添加了同名变量。

**案例**：本次重构中，一个脚本给 `skill_effect.gd` 的 `SkillExecutionContext` 添加了 `hit_aoe_radius`，另一个脚本随后添加 `available_targets` 时也顺带添加了 `hit_aoe_radius`。结果同一个类中有两个 `var hit_aoe_radius: float = 0.0` 声明。

**预防**：
- 每次修改前检查目标文件中是否已存在同名变量/函数
- 用 `grep "变量名" 文件名` 验证后再写入
- 合并多个修改到同一个脚本中执行，避免分散操作

---

## 七、UI 控件定位陷阱（重点）

### 7.1 `anchors_preset` 不等于"锚点生效"

**症状**：设置 `anchors_preset = PRESET_CENTER` 后，控件仍然出现在左上角。
**根因**：`anchors_preset` 是一个"快捷设置"，它同时设置锚点和偏移。但存在多个陷阱：

1. **设置顺序问题**：如果先设 `offsets` 再设 `anchors_preset`，preset 会**覆盖** offsets
2. **父节点尺寸为 0**：锚点是相对于父节点尺寸计算的。父节点尺寸为 0 时，`anchor=0.5` 等于 `anchor=0`（都是左上角）
3. **Control 默认尺寸为 0**：一个空的 `Control` 节点，不设置尺寸，其子控件的居中锚点全部失效

**正确做法**：
```gdscript
# ✅ 手动设置锚点，不依赖 preset
dialog.anchor_left = 0.5
dialog.anchor_top = 0.5
dialog.anchor_right = 0.5
dialog.anchor_bottom = 0.5
# 然后设置偏移（相对于锚点）
dialog.offset_left = -150
dialog.offset_right = 150
dialog.offset_top = -80
dialog.offset_bottom = 120

# ❌ 错误写法：preset 可能被后续操作覆盖，或父节点尺寸为 0
dialog.anchors_preset = Control.PRESET_CENTER
dialog.offset_left = -150  # 可能不生效
```

**作为弹窗父节点的 Control 必须撑满屏幕**：
```gdscript
# ✅ 弹窗组件的根节点必须填满父容器
anchors_preset = Control.PRESET_FULL_RECT  # 这里用 preset 是安全的
# 之后子控件的 anchor=0.5 才能正确居中
```

**为什么 PRESET_FULL_RECT 可以用 preset 而 PRESET_CENTER 不行**：
- `PRESET_FULL_RECT` 设置锚点为 `(0,0,1,1)` + 偏移为 `(0,0,0,0)`，这是一个**绝对值**，不依赖父节点尺寸
- `PRESET_CENTER` 设置锚点为 `(0.5,0.5,0.5,0.5)`，偏移取决于控件**当前尺寸**，而新创建的控件尺寸为 0

---

### 7.2 弹窗/对话框定位规范

**规则**：所有弹窗、对话框、确认框、信息提示，必须相对于**视口（屏幕）**定位，不是相对于游戏场景。

```gdscript
# ✅ 标准弹窗模式
func _setup_dialog() -> void:
    # 1. 根节点撑满屏幕
    anchors_preset = Control.PRESET_FULL_RECT

    # 2. 半透明遮罩
    var backdrop := ColorRect.new()
    backdrop.color = Color(0, 0, 0, 0.5)
    backdrop.anchors_preset = Control.PRESET_FULL_RECT
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(backdrop)

    # 3. 弹窗面板 — 手动锚点居中
    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    # 移动端：略偏下方方便拇指操作
    panel.offset_left = -half_width
    panel.offset_right = half_width
    panel.offset_top = -half_height + 20
    panel.offset_bottom = half_height + 20
    add_child(panel)
```

**关键约束**：
- 遮罩和弹窗都放在 `CanvasLayer` 中（UILayer），不放在场景节点树中
- `mouse_filter = MOUSE_FILTER_STOP` 防止点击穿透
- 移动端弹窗整体下移 20-40px，方便单手操作

---

## 八、"修一个错冒出下一个"连锁错误（方法论重点）

### 8.1 典型连锁错误案例

一次修改中连续出现 5 个错误，每个都是"修完一个冒出下一个"：

```
错误1: TILE_SIZE not declared
  ↓ 修复: 改为 TownTileset.TILE_SIZE
错误2: input_enabled invalid assignment on Node2D
  ↓ 修复: 改为 camera_anchor.set("input_enabled", true)
错误3: Cannot infer type of anchor_pos
  ↓ 修复: 改为 var anchor_pos: Vector2 = ...
错误4: Nonexistent function set_joystick_input in base Node2D
  ↓ 修复: 发现 .tscn 中 CameraAnchor 没有挂脚本
错误5: 修复 .tscn 脚本引用后一切正常
```

**根因分析**：

| 表面原因 | 根本原因 |
|---------|---------|
| 每次只修当前报错 | 没有全局扫描依赖链 |
| 改代码不改场景 | 没有检查 .tscn 文件的脚本引用 |
| 用类型技巧绕过问题 | 没有追溯"为什么类型不对"的源头 |
| 一个一个试 | 没有在动手前做完整的依赖分析 |

### 8.2 防连锁错误检查清单

**修复任何错误前，先做这三步**：

1. **读完整错误链**：不仅看第一个报错，要看所有报错。用 `grep` 搜索所有相关引用
2. **追溯源头**：错误是因为"缺了什么"还是"多了什么"？缺的在哪里定义？多了的是谁加的？
3. **检查所有载体**：代码在 `.gd` 中，但配置可能在 `.tscn`、`.tres`、`project.godot` 中

**修复时的"蝴蝶效应"检查**：
```bash
# 改了函数签名？检查所有调用方
grep -rn "function_name" scripts/

# 改了类名？检查所有引用
grep -rn "OldClassName" scripts/ scenes/

# 删除了方法？检查所有场景是否还在调用
grep -rn "deleted_method" scripts/ scenes/

# 改了 .gd 文件？检查 .tscn 是否引用了它
grep -rn "script_path.gd" scenes/
```

### 8.3 重构时"一锅端"导致功能缺失

**症状**：将多处重复代码集中到统一模块后，原来依赖这些代码的其他功能突然报错。
**根因**：重构时只关注了主要使用场景（如英雄生成），忽略了同一函数在其他上下文中的使用（如敌人生成）。

**案例**：将英雄生成逻辑集中到 `GameManager.spawn_squad()` 时，顺带删除了 `arena_scene.gd` 中的 `_add_unit_shadow()` 函数。但敌人生成仍在本地调用该函数，导致运行时 `Function "_add_unit_shadow()" not found`。

```
重构前:
  arena_scene._add_unit_shadow(hero)   ← 英雄阴影
  arena_scene._add_unit_shadow(enemy)  ← 敌人阴影

重构后（错误）:
  GameManager.spawn_squad() 内部处理英雄阴影
  arena_scene._add_unit_shadow() 被删除
  arena_scene._spawn_minion() 仍然调用 _add_unit_shadow(enemy) ← 报错！
```

**预防**：
- 删除函数前，`grep -rn "function_name"` 查找**所有**调用方
- 区分"被集中化的使用"和"保留本地的使用"——后者不能删
- 重构完成后，跑一遍所有相关场景的完整流程

```bash
# 删除函数前的标准检查
grep -rn "_add_unit_shadow" scripts/ scenes/
# 结果会显示：hero 调用（已迁移）+ enemy 调用（仍需保留）
```

---

### 8.4 状态机的"终点"检查：最后一个状态的退出条件

**症状**：写完波次系统后，前 4 波敌人推进正常，但第 5 波打完永远不会触发胜利——玩家清完怪后卡在场景中。

**根因**：状态机设计时只关注了"正常路径"的推进逻辑（第 0→1→2→3 波），忽略了**最后一个状态没有"下一步"** 的问题。`_should_advance_boss_wave()` 对最后一波返回 `false`（因为后面没有波次了），导致 `_trigger_victory()` 永远不会被调用。

```
波次推进:
  波0 → 满足条件 → advance → 波1 → advance → 波2 → advance → 波3 → advance → 波4
  波4 → _should_advance 返回 false（因为 index >= 4）→ 永远卡在这里！
```

**规律**：状态机末尾状态的退出条件被忽略是一个系统性陷阱。不仅限于波次系统，也常见于：
- 动画状态机的最后一个动画播放完没有过渡
- 关卡设计的最后一波怪物
- 新手引导的最后一个步骤
- 场景过渡动画的最后一个阶段

**预防检查清单**（写完任何状态机后检查）：
```
☐ 每个状态的"进入"逻辑是什么？
☐ 每个状态的"运行"逻辑是什么？
☐ 每个状态的"退出"条件是什么？
☐ 最后一个状态退出后会发生什么？ ← 最容易被忽略
```

### 8.5 删除/重命名符号后必须 grep 全项目

**症状**：删除了一个变量/函数后，另一个文件报错 "Identifier not declared"。或运行时崩溃。

**根因**：全局搜索只搜了当前文件，没搜其他文件。在 GDScript 项目中，一个函数可能被 `@onready` 引用、被 `.tscn` 连接、被 Callable 绑定——这些不在同一个文件中。

**案例**：熔岩洞穴竞技场重构时，删除了 `_boss_wave_spawning` 变量，替换为 `_wave_spawner.is_active`。但 `_should_advance_boss_wave()` 中残留了 `if _boss_wave_spawning:` 的引用——编译报错。

**修复规范**：
```bash
# 删除/重命名 任何符号后的标准流程：
# 1. grep 全项目
grep -rn "_boss_wave_spawning" scripts/ scenes/

# 2. 确认引用分布：哪些是定义，哪些是使用，哪些是信号绑定
# 3. 所有使用处全部更新
# 4. 最后删除定义
```

**核心原则**：**先 grep 再删除，先 grep 再重命名**。这是防止"修好一个地方漏了三个地方"的最简单有效的习惯。

### 8.6 数据管线泄漏：新增字段忘记在传递链中赋值

**症状**：下游系统收到的某个字段值始终为默认值（空字符串、0、false），但上游明明设置了该值。

**根因**：数据管线有多层传递（SkillDef → SkillExecutionContext → ExecutionChain → ProjectileNode）。新增一个字段时，只在源头（SkillDef）和终点（ProjectileNode）写了代码，但中间的传递层（`_create_chain()`）漏掉了赋值。

**案例**：本次重构中，`skill_id` 字段在 SkillDef 中有值，在 ExecutionChain 中有声明，但 `_create_chain()` 函数漏了 `chain.skill_id = context.skill_id` 这一行。结果 VFX 管理器收到的 `skill_id` 始终为空字符串，命中特效静默失败。调试花了很长时间。

**诊断方法**：
```
# 在下游入口打印上游传来的值
print("[DEBUG] skill_id=", chain.skill_id)
# 如果为空，逐层向上追溯：
# chain.skill_id ← _create_chain() ← context.skill_id ← cast_skill() ← SkillDef
```

**预防**：新增字段后，**从源头到终点逐层 grep 该字段名**，确认每一层传递都有赋值。

```gdscript
# 检查清单：
# 1. SkillDef 有 @export var xxx
# 2. SkillExecutionContext 有 var xxx
# 3. _create_chain() 中有 chain.xxx = context.xxx
# 4. ExecutionChain.duplicate() 中有 c.xxx = xxx
# 5. SkillRoot.cast_skill() 中有 context.xxx = skill_def.xxx
# 6. ProjectileNode/下游代码读取 chain.xxx
```

---
### 8.7 `await` 延时期间 `_process` 仍在运行

**症状**：在 `await get_tree().create_timer(0.2).timeout` 之后，出现了意料之外的第二次触发（如命中两次、生成两个对象）。

**根因**：`await` 暂停当前函数的执行，但**不暂停节点的 `_process()`**。在 await 等待期间：
- `_process()` 每帧持续运行
- 命中检测、碰撞检查等逻辑继续执行
- 如果在 await 之前已经满足了触发条件但没有及时阻止，等待期间可能重复触发

```gdscript
# 错误：await 期间 _process 继续运行，可以再次命中
func _bounce_respawn(target, next) -> void:
    _hide_all_visuals()
    var new_chain := _chain.duplicate()
    # 此时 _chain.behavior_state 仍然是 "Flying"
    # _process 继续运行，_check_hit 可能再次触发

    await get_tree().create_timer(0.2).timeout
    # 0.2 秒后可能已经被第二次命中了！

    pool.spawn(new_chain, _visual_def, _signal_bus)
    _chain.destroy()

# 正确：await 前立即阻止所有后续处理
func _bounce_respawn(target, next) -> void:
    set_process(false)              # 停止 _process
    _hide_all_visuals()             # 隐藏视觉
    # 通知各组件清理
    _comp_flame.on_destroy(self)

    var new_chain := _chain.duplicate()
    # ... 设置 new_chain ...

    await get_tree().create_timer(0.2).timeout
    if not is_instance_valid(self):
        return

    pool.spawn(new_chain, _visual_def, _signal_bus)
    _chain.destroy()  # 现在安全了：_process 已停止
```

**规律**：任何在 `await` 前改变了游戏状态的函数，都必须考虑 await 期间 `_process` 继续运行的影响。

**排查清单**：
- await 前是否调用了 `set_process(false)`
- await 条件的检查是否是幂等的（多次检查结果相同）
- 如果 await 期间有其他代码改变了状态，是否会导致 await 后的逻辑出错

---

### 8.8 提前设置 `behavior_state = "Destroyed"` 导致 `destroy()` 短路

**症状**：技能只能播放一次，后续技能全部卡死。对象池中的节点永不归还。

**根因**：`ExecutionChain.destroy()` 的实现是幂等的——如果 `behavior_state` 已经为 `"Destroyed"`，它会**直接 return**，不发出 `chain_destroyed` 信号。

```gdscript
# ExecutionChain.destroy() 的实现
func destroy() -> void:
    if behavior_state == "Destroyed":
        return                  # ← 如果状态已是 Destroyed，什么都不做！
    behavior_state = "Destroyed"
    chain_destroyed.emit(self)  # ← 信号永不发出！
```

如果在调用 `_chain.destroy()` 之前设置了 `_chain.behavior_state = "Destroyed"`，`destroy()` 会被短路。`chain_destroyed` 信号永不发出 → `_on_chain_destroyed` 不执行 → `pool.despawn()` 不调用 → 节点永不归还对象池 → 对象池耗尽 → 所有新技能无法生成。

```gdscript
# 错误：提前设置 Destroyed 状态
func _bounce_respawn(target, next) -> void:
    _chain.behavior_state = "Destroyed"  # ← 隐患：后续 destroy() 被短路
    # ...
    await get_tree().create_timer(0.2).timeout
    _chain.destroy()  # 静默失败：chain_destroyed 信号永不发出！

# 正确：只停 _process，不动 behavior_state
func _bounce_respawn(target, next) -> void:
    set_process(false)  # 停止 _process 就够了
    # ...
    await get_tree().create_timer(0.2).timeout
    _chain.destroy()  # 正常发出 chain_destroyed，触发完整回收流程
```

**核心规则**：`behavior_state` 是链的状态机核心变量。它应该只由 `destroy()`、`explode()`、`keep_alive()` 等专用方法修改。**永远不要手动设置 `behavior_state`**。

**排查思路**：技能只能播放一次 → 怀疑对象池不归还 → 检查 `_on_chain_destroyed` 是否执行 → 检查 `chain_destroyed` 信号是否发出 → 回溯是否在调用 `destroy()` 之前修改了 `behavior_state`。

---


## 九、数据流设计陷阱

### 9.1 "保存"与"关闭"的数据生命周期

**症状**：用户在编辑器中操作后关闭，数据丢失。
**根因**：没有区分"确认保存"和"关闭退出"的数据流。

**规则**：任何编辑界面，关闭时的行为必须明确设计：

| 场景 | 行为 |
|------|------|
| 点击"确认" | 保存数据 → 通知父系统 → 关闭 |
| 点击"取消/返回" | **也要保存**（用户期望），或弹出"是否保存"确认 |
| 点击遮罩外部 | 同"取消" |
| 按返回键 | 同"取消" |

```gdscript
# ✅ 标准：关闭时自动保存
func _on_close() -> void:
    _save_current_data()  # 无论哪种关闭方式都保存
    closed.emit()
    queue_free()

# ❌ 错误：关闭时不保存，用户以为数据还在
func _on_close() -> void:
    closed.emit()
    queue_free()
```

### 9.2 "压缩存储"导致位置信息丢失

**症状**：`["", "", "hero_c", "", "hero_e", ""]` 保存后变成 `["hero_c", "hero_e"]`，重新加载时 hero_c 跑到了位置 0。
**根因**：存储时过滤掉了空位，加载时按顺序填充。

**规则**：带位置信息的数据必须按**固定索引**存储，空位保留占位符：

```gdscript
# ✅ 固定长度数组，空位保留
func save_formation(slots: Array[String]) -> void:
    # slots 长度固定为 6，空位为 ""
    GameManager.set_roster(slots)  # 内部保证 6 元素

# ❌ 压缩存储，丢失位置信息
func save_formation(slots: Array[String]) -> void:
    var roster: Array[String] = []
    for s in slots:
        if s != "":  # 空位被过滤，位置信息丢失！
            roster.append(s)
    GameManager.set_roster(roster)
```

### 9.3 "唯一数据源"原则

**规则**：项目中的核心数据（阵容、装备、属性）必须有**唯一定义处**，所有消费方从同一源头读取。

**反面案例**：hub_scene 和 arena_scene 各自定义了 `FORMATION_OFFSETS`，修改一处另一处不同步。

**正面模式**：
```
GameManager（唯一数据源）
  ├── FORMATION_OFFSETS（唯一定义）
  ├── spawn_squad()（唯一生成接口）
  ├── set_roster() / get_roster()（唯一读写接口）
  └── 任何场景只调用，不重复定义
```

**新场景接入模板**：
```gdscript
# 任何新玩法场景的标准接入方式
var result := GameManager.spawn_squad(parent, center_pos, {
    "hero_registry": hero_registry,
    "skill_registry": skill_registry,
    "add_shadow": true,
})
heroes = result["heroes"]
hero_slot_indices = result["slot_indices"]
```

### 9.4 顺序索引 vs 槽位索引

**症状**：布阵界面中英雄放在"中左"（槽位1），但进入战斗后站到了"前中"（位置0）。
**根因**：遍历阵容时使用了**顺序索引** `i`（0, 1, 2...）而非**槽位索引** `slot_index`（跳过空位后不连续）。

```gdscript
# 阵容: ["", "hero_b", "hero_c", "", "hero_e", ""]
# get_active_roster() 返回: ["hero_b", "hero_c", "hero_e"]

# ❌ 错误：用顺序索引 i 查阵型偏移
for i in range(heroes.size()):
    var target := center + GameManager.get_formation_offset(i)
    # hero_b → offset[0] = 前中  ← 错！应该在中左(1)
    # hero_c → offset[1] = 中左  ← 错！应该在中右(2)
    # hero_e → offset[2] = 中右  ← 错！应该在后中(4)

# ✅ 正确：用槽位索引 slot_index
for i in range(heroes.size()):
    var slot_index: int = hero_slot_indices[i]
    var target := center + GameManager.get_formation_offset(slot_index)
    # hero_b → offset[1] = 中左  ✓
    # hero_c → offset[2] = 中右  ✓
    # hero_e → offset[4] = 后中  ✓
```

**规则**：`spawn_squad()` 返回的 `slot_indices` 数组必须与 `heroes` 数组**同步使用**。任何需要阵型位置的逻辑，都必须通过 `slot_indices[i]` 获取真实槽位，不能用循环变量 `i` 代替。

**触发条件**：当使用 `get_active_roster()`（压缩空位）+ 顺序遍历 时必然出现。解决方案：使用 `get_roster()`（保留空位）+ `slot_indices` 追踪。

---

## 十、GDScript 类型系统陷阱

### 10.1 `:=` 推断失败于未类型化的容器和函数返回值

**症状**：`Cannot infer the type of "xxx" variable because the value doesn't have a set type.`

**根因**：GDScript 的 `:=` 要求右侧表达式有明确的静态类型。当右侧涉及以下情况时，类型系统无法推导：

1. **未类型化数组的元素是 Variant**
2. **`Callable.call()` 返回值是 Variant**
3. **未类型化数组迭代中的循环变量是 Variant**

```gdscript
# ❌ 错误 1：const Array 的元素是 Variant
const NAMES := ["前中", "中左", "中右"]
var name := NAMES[0]  # 编译错误

# ✅ 正确方案一：显式标注类型
var name: String = NAMES[0]

# ✅ 正确方案二：声明时加类型
const NAMES: Array[String] = ["前中", "中左", "中右"]
var name := NAMES[0]  # 现在可以推断为 String
```

```gdscript
# ❌ 错误 2：Callable.call() 返回 Variant
var rng := func() -> float: return 0.5
var x := rng.call() * 100.0  # Cannot infer type

# ✅ 正确：显式标注
var x: float = rng.call() * 100.0
```

```gdscript
# ❌ 错误 3：未类型化数组的迭代变量是 Variant
for dx in [-1, 0, 1]:
    var nx := tx + dx  # Cannot infer type — dx is Variant
    var ny := ty + dy

# ✅ 正确：显式标注
for dx in [-1, 0, 1]:
    var nx: int = tx + dx

# ✅ 也正确：类型化数组
for dx in [-1, 0, 1] as Array[int]:
    var nx := tx + dx  # 现在可以推导
```

**排查思路**：
- 遇到 `Cannot infer type`，**追溯上游**——是数组没标注类型？是 Callable 返回值？是循环变量？
- 不要绕路（如用 `= 0` 占位），要找到类型丢失的源头

**规律**：这个陷阱在熔岩洞穴竞技场一章中出现超过10次——几乎所有的 `:=` 在涉及 `rng.call()` 或 `[-1,0,1]` 循环时都会触发。**在 GDScript 中使用回调函数、未标注类型数组、或内联数组时，优先用显式声明**。

```gdscript
# ❌ 错误：const Array 的元素是 Variant
const NAMES := ["前中", "中左", "中右"]
var name := NAMES[0]  # 编译错误：Cannot infer type

# ✅ 正确方案一：显式标注类型
var name: String = NAMES[0]

# ✅ 正确方案二：声明时加类型
const NAMES: Array[String] = ["前中", "中左", "中右"]
var name := NAMES[0]  # 现在可以推断为 String
```

### 10.2 脚本定义的属性/方法不能通过类型化引用访问

**症状**：`Invalid call. Nonexistent function 'xxx' in base 'Node2D'`
**根因**：当变量声明为具体类型（如 `Node2D`）时，GDScript 只允许访问该类型定义的方法。脚本扩展的方法需要通过 `set()`/`call()` 或去除类型标注来访问。

```gdscript
# ❌ 错误：camera_anchor 声明为 Node2D，但 set_joystick_input 是脚本方法
@onready var camera_anchor: Node2D = $CameraAnchor
camera_anchor.set_joystick_input(dx, dy)  # 编译错误

# ✅ 方案一：去除类型标注
@onready var camera_anchor = $CameraAnchor
camera_anchor.set_joystick_input(dx, dy)  # OK，运行时解析

# ✅ 方案二：用 set() 访问属性
camera_anchor.set("input_enabled", true)

# ✅ 方案三：用 call() 调用方法
camera_anchor.call("set_joystick_input", dx, dy)
```

**但更重要的是**：如果报"方法不存在"，先检查 .tscn 中节点是否真的挂了脚本！这比绕类型系统更根本。

### 10.3 跨类常量访问需要类名前缀

**症状**：`Identifier "TILE_SIZE" not declared in the current scope.`
**根因**：GDScript 中 `const` 常量属于定义它的类。从外部访问时必须使用 `ClassName.CONSTANT` 形式。

```gdscript
# town_tileset.gd
class_name TownTileset
const TILE_SIZE := 32

# hub_scene.gd
# ❌ 错误：直接使用常量名
var width := MAP_WIDTH * TILE_SIZE  # 编译错误

# ✅ 正确：加类名前缀
var width := TownMapData.MAP_WIDTH * TownTileset.TILE_SIZE
```

**常见场景**：
- 跨文件常量引用（最常见）
- 从 `const Array` 中取元素后用 `:=` 推断类型（见 10.1）
- 混淆"当前类的 const"和"其他类的 const"

**预防**：报 `Identifier "XXX" not declared` 时，先搜索 `XXX` 在哪个文件定义，确认是否需要加类名前缀。

### 10.4 类型化数组（Array[T]）不接受未类型化的 Array

**症状**：`Invalid type in function 'xxx' in base 'yyy'. The array of argument N (Array) does not have the same element type as the expected typed array argument.`
**根因**：GDScript 4.x 中，函数参数声明为 `Array[ConcreteType]` 时，调用方必须传入**同样类型化的数组**。把单个元素包装成 `[element]` 会创建一个未类型的 `Array`（等价于 `Array[Variant]`），即使元素类型正确也会被拒绝。

```gdscript
# 函数签名
func apply_status_updates(updates: Array[CombatResolver.StatusUpdate], params: CombatParams) -> void

# ❌ 错误：把每个 update 包装成 [update] 再传
for update in result.status_updates:
    target.apply_status_updates([update], combat_params)  # 运行时报错！
#                                ^^^^^^^^ 这是 Array（未类型化），不是 Array[StatusUpdate]

# ✅ 正确：直接传整个类型化的数组
target.apply_status_updates(result.status_updates, combat_params)
```

**原理**：
- `result.status_updates` 的类型是 `Array[StatusUpdate]`（由 `CombatResolver.ResolveResult` 定义）——可以直接传
- `[update]` 的类型是 `Array`（未类型化，即 `Array[Variant]`）——即使 `update` 本身是 `StatusUpdate`，包装后的数组类型也不同

**常见触发场景**：
- 从一个类型化数组中取出元素，再用 `[element]` 包装后传给期望 `Array[T]` 的函数
- 用 `Array.append()` 逐个添加元素到未初始化的数组，然后传给期望 `Array[T]` 的函数

**预防**：如果函数签名用了 `Array[T]`，调用方要么传入同样类型化的数组，要么用 `Array[Type]()` 显式构造。

---

## 十一、AI 幻觉与上下文污染（方法论重点）

### 11.1 AI 凭空编造不存在的项目内容

**症状**：AI 在回答中引用了从未提供过的文件、项目或技术栈，且描述得非常详细和自信。
**根因**：大语言模型的训练数据中包含大量不同项目。当上下文不足或问题模糊时，模型可能从训练数据中"拼接"出看似合理但完全虚构的内容。

**案例**：在讨论 Godot 2D 游戏的错误分析时，AI 突然引用了一个名为 `00_GravityLab_Game_Design_Overview.txt` 的文件，声称来自一个 UE5 项目（"GravityLab"），并详细描述了其中的"蓝图系统"和"虚幻引擎"相关内容。实际上：
- 该文件从未在对话中出现
- 项目是 Godot 4.x 2D 游戏，与 UE5 完全无关
- AI 将不同技术栈的训练数据混入了当前项目上下文

**特征**：
- 引用的文件名格式合理（如 `00_ProjectName_Overview.txt`），但**不存在于项目中**
- 描述的技术细节内部一致，但与当前项目**技术栈矛盾**
- AI 表现得非常自信，没有"我不确定"或"需要确认"的措辞

**防御措施**：
1. **立即质疑**：当 AI 引用你不认识的文件时，直接指出"我没有发过这个文件"
2. **技术栈校验**：任何建议必须与当前项目的技术栈匹配（Godot vs UE vs Unity）
3. **要求溯源**：要求 AI 说明引用来源（"这个信息来自哪里？"）
4. **不要被细节迷惑**：越详细的描述越需要验证，细节丰富不代表真实

### 11.2 上下文窗口污染的连锁效应

**症状**：AI 在一次错误的幻觉之后，后续回答也开始基于虚构内容推理。
**根因**：上下文窗口中的所有内容（包括 AI 自己的错误输出）都会被当作"已知事实"继续使用。一次幻觉会"污染"后续所有推理。

**预防**：
- 发现幻觉后**立即明确纠正**："这个内容不存在，请从上下文中移除"
- 不要在幻觉内容基础上继续提问（这会强化幻觉）
- 如果幻觉严重，考虑开新对话重新开始

---
### 11.3 AI 编造不存在的 API / 属性 / 枚举值

**症状**：AI 在代码中使用了实际上不存在的类名、属性名或枚举值，导致编译或运行时报错。例如使用 `GPUParticles2D.EMISSION_SHAPE_RECTANGLE` 或 `GPUParticles2D.emission_rect_extents`。

**根因**：AI 的训练数据中包含不同版本的 Godot API。当其"记忆"的 API 与当前使用的 Godot 版本（4.6）不匹配时，可能编造出看起来合理但其实不存在的 API。特别是在以下场景中症状明显：

- **枚举值**：AI 可能从 Godot 3.x 或 Godot 4.0-4.2 的记忆中提取枚举名，但这些在 4.6 中不存在或已改名
- **属性名**：`GPUParticles3D` 的属性被错误应用到 `GPUParticles2D` 上
- **函数签名**：参数数量或类型与实际不匹配
- **类名**：引用的类在 Godot 4.6 的项目中不存在（如 `GPUParticlesEmissionShape2D`）

```gdscript
# AI 可能生成的错误代码：
_particles.emission_shape = GPUParticles2D.EMISSION_SHAPE_RECTANGLE  # 不存在
_particles.emission_rect_extents = Vector2(1, 25)                    # 不存在

# AI 可能编造的类：
var emit_shape = GPUParticlesEmissionShape2D.new()  # 不存在
```

**防御措施**：

1. **怀疑所有"看起来太方便"的 API** — 如果感觉这个 API 像是"专门为我的需求设计的"，先查文档确认
2. **`get_property_list()` 验证** — 怀疑某个属性不存在时，用代码枚举确认：
   ```gdscript
   var obj = ClassName.new()
   for prop in obj.get_property_list():
       print(prop.name)
   ```
3. **区分 GPUParticles2D vs GPUParticles3D** — 两个类的 API 在 Godot 4.6 中有显著差异（3D 有 emission_shape，2D 没有）
4. **区分 Sprite2D vs GPUParticles2D 的行为差异** — scale 的含义不同、树管理策略不同、坐标空间不同

**规律**：以下场景最容易触发 AI 编造 API：
- 粒子系统的高级配置（发射区域、发射形状）
- 版本间 API 有差异的特性（2D 粒子、ShaderMaterial、自定义 Resource）
- Godot 4.0 → 4.2 → 4.6 之间发生变化的 API

---


## 十二、坐标与单位换算陷阱（重点）

### 12.1 瓦片坐标 vs 世界坐标混淆

**症状**：波次触发的 y 阈值明明设对了，但怪物刷不出来或者刷错位置。

**根因**：设计数据使用**瓦片坐标**（如 `y_trigger = 205` 表示第 205 行瓦片），但运行时的比较逻辑直接使用 `camera_anchor.position.y`（**世界坐标**，205 × 32 = 6560），相差一个 `TILE_SIZE` 因子。

**教训**：坐标系是 2D 游戏开发中最高频的 Bug 来源之一。一个简单的规范可以避免绝大多数此类问题：**在变量名或注释中标注其坐标空间**。

```gdscript
# ❌ 容易混淆：y_trigger 是瓦片还是世界单位？
const SPAWN_TRIGGER_Y: Array[int] = [205, 125, 60]

# ✅ 明确标注
const SPAWN_TRIGGER_TILE_Y: Array[int] = [205, 125, 60]
# 使用时
if camera_anchor.position.y < trigger_tile_y * TILE_SIZE:
```

**编码规范**：
- 瓦片坐标的变量/常量 → 加 `_tile` 后缀：`spawn_tile_y`、`trigger_tile_x`
- 世界坐标的变量/常量 → 无特殊后缀（默认是世界坐标）
- 转换 → 始终在引用处做乘法/除法，不要中间存储

**常见陷阱场景**：
- 地图设计时用瓦片坐标（方便设计），运行时用世界坐标（方便引擎）——二者混淆
- `TileMap.set_cell()` 用瓦片坐标，`Node2D.position` 用世界坐标——混用时不加注释
- 路径点定义用瓦片坐标，碰撞体生成用世界坐标——转换因子的缺失

### 12.2 不同的"单位"在同一表达式中的静默混用

**症状**：计算看起来没问题，但结果是错误的。比如"30 秒步行"的走廊长度算出来对不上。

**根因**：计算中混用了不同来源的数据——玩家的移动速度是 `px/s`，走廊长度是 `tiles`，时间要求是 `seconds`。三者之间缺乏显式的单位标注和换算检查。

```gdscript
# ✅ 显式标注：
const ANCHOR_SPEED := 250.0       # px/s
const WALK_SECONDS := 30.0         # s
const TILE_SIZE := 32              # px/tile
var corridor_length_px := ANCHOR_SPEED * WALK_SECONDS     # 7500 px
var corridor_length_tiles := corridor_length_px / TILE_SIZE  # ~234 tiles
```

**规范**：在常量命名中包含单位：

```gdscript
const SPEED_PX_PER_SEC := 250.0
const CORRIDOR_LENGTH_TILES := 234
const CORRIDOR_LENGTH_PX := CORRIDOR_LENGTH_TILES * TILE_SIZE
```

---

## 十三、架构设计陷阱

### 13.1 重构时只跟踪新路径，忽略边界状态

**症状**：重构后主要功能跑通了，但在边界条件下（最后一波、空列表、最小配置）崩溃或卡死。

**根因**：重构时的思维模式是"新代码能不能跑通"，而不是"所有路径是否都有出口"。人脑天然倾向于关注高频路径，低频路径（边界状态、错误处理、最后一轮）容易被忽略。

**案例**：熔岩洞穴竞技场整合 WaveSpawner 时，前三波 Boss 战推进正常，但最后一波完成后 `_trigger_victory()` 没有被调用——因为 `_should_advance_boss_wave()` 对最后一波返回 `false`。详细分析见 [8.4 状态机的"终点"检查](#84-状态机的终点检查最后一个状态的退出条件)。

**预防办法 —— 重构完成后的状态机审计**：
```
对每个状态问三个问题：
  1. 进入条件是什么？
  2. 运行时逻辑是什么？
  3. 退出条件是什么？
特别注意最后一个状态的退出条件 ← 最容易忽略
```

**通用原则**：
- 重构不只是在替换代码逻辑——你也在替换对代码的**心理模型**
- 旧代码可能有隐藏的边界处理，重构时无意中丢弃了
- 每次重构完成后，**除了测试主路径，更要测试边界条件**：0 元素、最后一轮、空状态

### 13.2 批量删除代码段时"范围溢出"——误删不相关的函数

**症状**：重构后场景无法启动，或关键函数（如 `_ready()`、`_process()`）消失。

**根因**：当从一个大文件中按"段"删除代码时，段的边界往往不精确。如果删除范围覆盖了多个逻辑段，不相关的函数会被一并删除。

**案例**：从 `arena_scene.gd`（672行）中删除"战斗逻辑段"时，删除了从"战斗常量"到"阶段逻辑"之间的所有内容。本意是只删 `_update_combat()`、`_update_dots()`、`_find_nearest_*()`、`_cleanup_dead_units()`，但实际上把 `_ready()`、`_initialize()`、`_create_tilemap()`、`_create_hud()`、`_setup_joystick()`、`_start_combat()`、`_process()`、`_update_hero_follow()` 也一并删除了——因为这些函数在文件中位于被删除段的边界之内。

**预防方法**：

1. **逐函数删除**，而非按段删除：每次只删除一个函数，删除前确认该函数没有被其他未迁移的代码调用
2. **删除前列出清单**：明确哪些函数要删、哪些要留，逐个确认
3. **删除后立即验证**：用编辑器或 Hastur 加载脚本，确认所有 `func` 定义仍然存在
4. **备份**：删除大段代码前，先 `git stash` 或创建分支

**自检清单**（删除段后立即执行）：
```
grep "func " 文件名 | wc -l    # 对比删除前后的函数数量
# 如果数量少了，检查少了哪些
```

**通用原则**：代码删除的"爆炸半径"往往比你预想的大。宁可多删几次小的，不要一次删一大块。

### 13.3 Effect 代码强制覆盖配置值——破坏了数据驱动设计

**症状**：在 SkillVisualDef 中配置了 `trajectory_type = 0`（直线），但投射物仍然按曲线飞行。

**根因**：Effect 执行代码中硬编码了行为覆盖。`emit_projectile.gd` 对所有多弹道技能强制设置 `chain.trajectory_type = 1`（贝塞尔曲线），无视 SkillVisualDef 中的配置。

```gdscript
# ❌ 错误：强制覆盖配置
for i in range(count):
    var chain := _create_chain(context)
    chain.trajectory_type = 1  # 强制贝塞尔，无视 visual_def 的配置

# ✅ 正确：尊重配置，只对需要的技能添加变化
for i in range(count):
    var chain := _create_chain(context)
    # 只对已配置为贝塞尔的技能添加随机变化
    if is_multi and not is_tracking and chain.trajectory_type == 1:
        chain.control_point_offset = randf_range(20.0, 160.0)
```

**教训**：Effect 执行代码应该**增强**配置（添加随机变化），而不是**覆盖**配置（强制改变类型）。配置是数据驱动设计的核心，代码应该尊重它。

**预防**：在 Effect 代码中修改 chain 属性前，问自己："这个值是应该来自配置，还是应该由代码决定？"如果 SkillVisualDef 已经定义了该值，就不应该覆盖。

---

## 附录：检查清单

在提交代码或声称修复完成前，逐项检查：

**基础质量**：
- [ ] 所有 `.gd` 文件的缩进是否一致（Tab，非空格）
- [ ] 新创建的类是否有 `class_name` 声明
- [ ] `.tres` 文件引用的脚本是否包含所有属性
- [ ] 新增 `@export` 后是否重启了编辑器（文件扫描不够）
- [ ] 新 `vfx://` 纹理是否在所有组件中注册了加载支持
- [ ] `class_name` 单例（`static var _instance`）修改后是否失效了旧实例
- [ ] 编辑器内 Play 场景 vs 独立进程运行，`static var` 行为是否一致

**粒子/VFX 系统**：
- [ ] 粒子系统的 `direction` 是否非零、`spread` 是否 360（如需全方向）
- [ ] 粒子系统的 `gravity` 是否需要置零
- [ ] 是否有多套 VFX 系统在竞争同一事件
- [ ] 自定义 Sprite2D 和 HitVFXNode 的树管理策略是否正确（HitVFXNode 自动加树）
- [ ] Sprite2D 的 scale 是否基于像素计算（不是粒子系统的相对缩放逻辑）
- [ ] `GPUParticles2D.emission_shape` 在当前 Godot 版本中是否存在（4.6 中不存在）

**UI 控件**：
- [ ] 弹窗/对话框的锚点是否手动设置为 0.5（不依赖 preset）
- [ ] 弹窗的根节点 Control 是否撑满屏幕（PRESET_FULL_RECT）

**数据流**：
- [ ] 核心数据是否只有一处定义（唯一数据源），各场景是否从同一接口读取
- [ ] 带位置的数据是否按固定索引存储（不压缩空位）
- [ ] 阵型相关逻辑是否使用 `slot_indices` 而非顺序索引

**重构安全**：
- [ ] 修改/删除函数前，是否 grep 了所有调用方（包括 .tscn 中的信号连接）
- [ ] 删除函数前，是否区分了"已迁移的调用"和"仍需保留的本地调用"
- [ ] 重构完成后，是否跑了一遍所有相关场景的完整流程

**工作流**：
- [ ] 脚本/资源修改后是否触发了文件系统扫描
- [ ] 调试 `print()` 是否被正确路由到预期目标（编辑器 vs 游戏运行时）
- [ ] 确认修改的是真正执行的代码路径，而非同名/同类文件
- [ ] 用 Python 而非 sed 处理需要精确缩进的多行替换
- [ ] Python 替换后验证：`print('存在' if old in content else '替换失败')`
- [ ] Python 替换时考虑 `content[:idx]` 已有缩进，避免双重缩进
- [ ] 替换含中文注释的代码时，用函数名/变量名做锚点而非注释

**坐标系与单位**：
- [ ] 涉及坐标的常量和变量是否标注了坐标空间（`_tile` 后缀、`_px` 后缀）
- [ ] 跨系统换算（tile → px、tile → 秒）是否有显式乘除法
- [ ] 设计文档中的坐标和代码中的坐标使用同一套单位体系

**状态机与边界**：
- [ ] 状态机中的所有状态是否都有"进入→运行→退出"的完整定义
- [ ] **最后一个状态的退出条件**被正确处理
- [ ] 重构后测了边界条件：最后一轮、0 元素、空列表、最小配置
- [ ] `await` 前是否调用了 `set_process(false)` 阻止 _process 继续运行
- [ ] `behavior_state` 是否只用专用方法修改（`destroy()`、`explode()`、`keep_alive()`），永不手动赋值

**重构安全**：
- [ ] 删除/重命名函数或变量前，**grep 了全项目**的所有引用
- [ ] 检查了 `.tscn` 文件中的信号连接和节点引用
- [ ] 重构完成后，除主路径外测试了所有边界状态

**class_name 规范**：
- [ ] 每个 `.gd` 文件只有一个 `class_name`
- [ ] 文件名和类名一致（`WaveConfig` → `wave_config.gd`）

**相机与场景切换**：
- [ ] 场景切换后镜头位置是否正确，有无平滑漂移
- [ ] 如果恢复了节点位置，调用 `reset_smoothing()` 清除 Camera2D 平滑缓存
- [ ] 子节点 `_ready()` 在先、父节点 `_ready()` 在后的时序影响初始化逻辑

**AI 协作**：
- [ ] AI 引用的文件确实存在于项目中
- [ ] AI 的建议与当前技术栈匹配（Godot/Python，非 UE/Unity）
- [ ] AI 使用的类名/属性/枚举值在当前 Godot 版本中真实存在（用 `get_property_list()` 验证）
- [ ] 区分了 `GPUParticles2D` 和 `GPUParticles3D` 的 API 差异
- [ ] 区分了 `Sprite2D.scale`（像素倍数）和 `GPUParticles2D` 的粒子缩放（相对值）

---

*本指南将持续更新。每次遇到新的系统性陷阱后，在此追加记录。*
