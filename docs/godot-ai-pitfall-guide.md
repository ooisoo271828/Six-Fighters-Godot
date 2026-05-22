# 🛡 Godot AI 编程避坑指南

> **版本**: v2.0 | 创建: 2026-04-28 | 更新: 2026-05-23 | 状态: 持续更新
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

### 3.3 从现有代码推断行为不可靠——可能有旧版缓存

**症状**：修改了函数逻辑后，运行时行为与代码内容不匹配。
**根因**：编辑器可能运行的是旧版编译后的脚本，而非磁盘上当前文件的内容。
**诊断**：在函数入口添加唯一定位标记（如 `print("**_FUNCTION_NAME_**")`），通过检查日志确认函数是否真的执行了新代码。

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

### 5.2 资源 UID 缓存过期

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

---

### 6.4 没有区分"编辑器日志"和"游戏运行时日志"

**症状**：在游戏场景中添加的 `print()` 在开发工具的日志查询中不可见。
**预防**：
- 明确调试输出的目标系统
- 编辑器插件交互 → `hastur.py logs`
- 游戏运行时调试 → Godot Output 面板
- 必要时使用 `push_error()/push_warning()` 强制输出到编辑器

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

### 10.1 `:=` 推断失败于未类型化的容器

**症状**：`Cannot infer the type of "xxx" variable because the value doesn't have a set type.`
**根因**：GDScript 的 `const Array`（不带类型标注）的元素类型是 `Variant`，`:=` 无法从 Variant 推断类型。

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

## 附录：检查清单

在提交代码或声称修复完成前，逐项检查：

**基础质量**：
- [ ] 所有 `.gd` 文件的缩进是否一致（Tab，非空格）
- [ ] 新创建的类是否有 `class_name` 声明
- [ ] `.tres` 文件引用的脚本是否包含所有属性

**粒子/VFX 系统**：
- [ ] 粒子系统的 `direction` 是否非零、`spread` 是否 360（如需全方向）
- [ ] 粒子系统的 `gravity` 是否需要置零
- [ ] 是否有多套 VFX 系统在竞争同一事件

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

**AI 协作**：
- [ ] AI 引用的文件是否确实存在于项目中
- [ ] AI 的建议是否与当前技术栈匹配（Godot/Python，非 UE/Unity）

---

*本指南将持续更新。每次遇到新的系统性陷阱后，在此追加记录。*
