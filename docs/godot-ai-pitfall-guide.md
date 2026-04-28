# 🛡 Godot AI 编程避坑指南

> **版本**: v1.0 | 创建: 2026-04-28 | 状态: 持续更新
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

## 附录：检查清单

在提交代码或声称修复完成前，逐项检查：

- [ ] 所有 `.gd` 文件的缩进是否一致（`cat -A` 确认）
- [ ] 新创建的类是否有 `class_name` 声明
- [ ] `.tres` 文件引用的脚本是否包含所有属性
- [ ] 粒子系统的 `direction` 是否非零、`spread` 是否 360（如需全方向）
- [ ] 粒子系统的 `gravity` 是否需要置零
- [ ] 是否有多套 VFX 系统在竞争同一事件
- [ ] 脚本/资源修改后是否触发了文件系统扫描
- [ ] 调试 `print()` 是否被正确路由到预期目标
- [ ] 确认修改的是真正执行的代码路径，而非同名/同类文件
- [ ] 用 `Python` 而非 `sed` 处理需要精确缩进的多行替换

---

*本指南将持续更新。每次遇到新的系统性陷阱后，在此追加记录。*
