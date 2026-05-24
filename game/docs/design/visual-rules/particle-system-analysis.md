# 弹体粒子系统现状分析与优化建议

> 2026-05-24 | 作者：AI Assistant

---

## 一、架构总览

### 1.1 数据层：两套并存的定义体系

弹体视觉数据存在 **两套并行的定义结构**，这是历史演进的产物：

| 层级 | 文件 | 状态 |
|------|------|------|
| v1.0 扁平字段 | `SkillVisualDef` 的 `@export` 属性（如 `trail_particle_enabled`、`trail_color_1`） | **运行时实际使用** |
| v3.0 组合式子 Resource | `TrailVisual`、`ProjectileVisual`、`ImpactVisual`、`VFXOverride` | **定义了但未被运行时读取** |

例如火球术的 `.tres` 文件中同时存在：
- 主文件 `fireball_basic.tres`：扁平字段（`trail_particle_enabled = true`、`trail_color_1 = Color(...)`）
- 子文件 `fireball_basic_trail.tres`：`TrailVisual` Resource（`trail_enabled = true`、`tex_trail_path = "fire_particle_32.png"`）

**实际运行时**，`_configure_trail_particles()` 等函数只读取 `SkillVisualDef` 的扁平字段（通过 `"field_name" in _visual_def` 模式），完全不使用 `TrailVisual` 子 Resource。

### 1.2 运行时层：ProjectileNode 的三种拖尾系统

`projectile_node.gd` 中实现了 **三种独立的拖尾机制**，它们同时运行、互不感知：

| 系统 | 实现方式 | 配置来源 | 特点 |
|------|----------|----------|------|
| 拖尾粒子 `_trail_particles` | `GPUParticles2D` + `ParticleProcessMaterial` | `trail_particle_*` 扁平字段 | 粒子向后喷射，带缩放曲线 |
| 前缘火焰 `_front_flame_particles` | `GPUParticles2D` + `ParticleProcessMaterial` | `front_flame_*` 扁平字段 | 粒子向前方喷射 |
| 彗星拖尾 `_comet_line_*` | 三层 `Line2D` | `comet_*` 扁平字段 | 蛇形摆动实线，宽度渐变 |

三种系统各自有独立的纹理、颜色、生命周期参数，但都从同一个 `_visual_def` 扁平字段读取。

### 1.3 纹理与颜色的渲染链路

粒子最终颜色 = **纹理颜色** × **material.color** × **color_initial_ramp** × **modulate**

```
┌─────────────┐   ┌──────────────────┐   ┌───────────────────┐   ┌──────────┐
│ 纹理 tex    │ × │ material.color   │ × │ color_initial_ramp│ × │ modulate │
│ (texture)   │   │ (ParticleProcess │   │ (GradientTexture) │   │ (Sprite) │
│             │   │  Material)       │   │                   │   │          │
└─────────────┘   └──────────────────┘   └───────────────────┘   └──────────┘
```

**核心问题**：当某一层设为白色/默认时，不影响最终颜色。但当所有层都被设置时，颜色会被多次叠加乘算，导致原始设计意图被破坏。

---

## 二、当前问题清单

### P1：`color_initial_ramp` 无条件应用，覆盖自定义纹理颜色

**现状**：`_configure_trail_particles()` 中，我最近添加了 `color_initial_ramp`，无条件读取 `trail_color_1/2/3` 作为粒子生命周期颜色渐变。

**影响**：
- **冰箭**（无自定义纹理，白色软圆 + 蓝色 color ramp）→ 正常，蓝色粒子
- **火球**（有自定义纹理 `fire_particle_32.png`，红橙色火焰粒子 + 暖白色 color ramp）→ 纹理颜色被暖白 ramp 覆盖，原本丰富的红橙火焰拖尾褪成淡白色

**根因**：违反了"自定义纹理不应被下游代码覆盖"的原则。color ramp 只应用于无自定义纹理的场景。

### P2：`trail_color_1/2/3` 的用途不明确

**现状**：三个颜色字段在 `SkillVisualDef` 和 `TrailVisual` 中都有声明，但历史用途不明：
- 在 Web 原版中可能用于粒子着色
- 在当前 Godot 版本中，之前从未在 `_configure_trail_particles()` 中使用（是我最近才加入的）
- 火球的 `trail_color_1/2/3` 是暖白色调（`Color(1, 0.82, 0.77)`），不是火焰主色——说明它们不是设计给粒子纹理着色用的

**问题**：这些字段到底是"纹理的替代着色方案"还是"纹理的辅助叠加方案"？没有文档定义。

### P3：VFXTextureManager 共享材质的副作用

**现状**：`get_shared_material()` 通过 `shader_path + params.hash()` 缓存材质。相同参数的弹体共享同一个 `ShaderMaterial` 实例。

**风险**：如果运行时修改某个弹体的 shader 参数（如呼吸效果），会影响所有使用相同材质的弹体。

**当前影响**：暂无直接 bug，但限制了未来做单弹体发光动画的能力。

### P4：纹理加载链路与对象池复用的交互

**现状**：`_load_textures()` 流程：

```
_reset all textures to null_     ← 我的修复
→ 读取 tex_core_path → load     ← 有路径才赋值
→ glow_texture: 有路径用路径，无路径回退 core_texture
→ trail_texture: 有路径用路径，无路径回退 core_texture
→ ...
```

**问题**：对于没有 `tex_core_path` 的技能（如冰箭），`_core_texture` 为 null，`_glow_texture` 和 `_trail_texture` 的回退链断裂，全部变为 null。`_configure_trail_particles()` 会降级为 `SOFT_CIRCLE` 程序纹理。

这对于冰箭是正确的（需要程序纹理 + 颜色着色），但对于未来有 `tex_trail_path` 但没有 `tex_core_path` 的技能，回退逻辑可能不符合预期。

### P5：v3.0 子 Resource 架构未生效

**现状**：`SkillVisualDef` 的 `get_projectile_visual()`、`get_trail_visual()` 等方法可以将扁平字段转换为子 Resource，但 `_configure_trail_particles()` 等运行时代码从不调用这些方法。

**影响**：
- 子 Resource 文件（如 `fireball_basic_trail.tres`）的内容被完全忽略
- 扁平字段和子 Resource 存在数据冗余，修改时需要同步两处
- v3.0 架构的组合式设计意图没有兑现

---

## 三、现有技能的粒子配置对比

| 参数 | 火球术 | 冰箭术 | 飞弹风暴 |
|------|--------|--------|----------|
| **自定义纹理** | `fire_particle_32.png` ✅ | 无 ❌ | 无 ❌ |
| **trail_particle_enabled** | true | true | 未设置(false) |
| **front_flame_enabled** | true | 未设置(false) | 未设置(false) |
| **comet_enabled** | 未设置 | true | true |
| **trail_color_1** | 暖白 `(1,0.82,0.77)` | 浅蓝 `(0.8,0.95,1.0)` | 暖白 `(1,0.94,0.86)` |
| **trail_color_2** | 暖粉 `(1,0.73,0.62)` | 中蓝 `(0.4,0.7,1.0)` | 暖黄 `(1,0.79,0.56)` |
| **trail_color_3** | 浅粉 `(1,0.91,0.89)` | 深蓝 `(0.2,0.4,0.9)` | 未设置(=WHITE) |

**当前实际表现**（加了 `color_initial_ramp` 后）：
- 火球：纹理火焰色 × 暖白 ramp = 褪色 → **视觉降级**
- 冰箭：白色软圆 × 蓝色 ramp = 蓝色粒子 → 正确
- 飞弹：白色软圆 × 暖白 ramp = 淡暖白 → 可接受但未充分利用

---

## 四、优化建议

### 方案 A：最小修复（推荐先行）

**原则**：`color_initial_ramp` 仅在无自定义纹理时生效。

```gdscript
# _configure_trail_particles() 中
_trail_particles.texture = _trail_texture if _trail_texture else _get_soft_circle_tex()

# 只有使用默认纹理时才应用颜色渐变
if not _trail_texture:
    var tc1 = _visual_def.trail_color_1 if "trail_color_1" in _visual_def else Color.WHITE
    var tc2 = _visual_def.trail_color_2 if "trail_color_2" in _visual_def else tc1
    var tc3 = _visual_def.trail_color_3 if "trail_color_3" in _visual_def else tc2
    var grad := Gradient.new()
    grad.add_point(0.0, Color(tc1.r, tc1.g, tc1.b, 0.9))
    grad.add_point(0.4, Color(tc2.r, tc2.g, tc2.b, 0.6))
    grad.add_point(1.0, Color(tc3.r, tc3.g, tc3.b, 0.0))
    var grad_tex := GradientTexture1D.new()
    grad_tex.gradient = grad
    mat.color_initial_ramp = grad_tex
```

**效果**：
- 火球：`fire_particle_32.png` 纹理颜色完整保留，不被 ramp 覆盖 ✅
- 冰箭：白色软圆 + 蓝色 ramp = 蓝色粒子 ✅
- 飞弹（无自定义纹理）：白色软圆 + 暖白 ramp = 淡暖白 ✅

### 方案 B：建立纹理与颜色的优先级规范

为所有粒子相关参数定义清晰的优先级规则：

```
规则 1：有自定义纹理 → 纹理即最终颜色，不叠加任何 ramp
规则 2：无自定义纹理 → 使用程序纹理(soft_circle) + color_initial_ramp 着色
规则 3：trail_color_1/2/3 仅作为"无纹理时的着色方案"，不用于覆盖有纹理的粒子
规则 4：front_flame 的颜色来自 flame_color_1/2（ParticleProcessMaterial 方向色）
规则 5：comet 拖尾颜色直接来自 comet_*_color 字段（Line2D.default_color）
```

### 方案 C：长期架构——激活 v3.0 子 Resource 体系

**目标**：让运行时代码从子 Resource 读取配置，而非扁平字段。

**步骤**：

1. `_configure_trail_particles()` 改为从 `TrailVisual` 读取：
   ```gdscript
   var tv := _visual_def.get_trail_visual()
   _trail_particles.texture = load(tv.tex_trail_path) if tv.tex_trail_path else _get_soft_circle_tex()
   ```

2. `_apply_visual()` 中弹体核心部分改为从 `ProjectileVisual` 读取

3. 移除 `SkillVisualDef` 上的扁平字段（保留 `@export` 但标记为 deprecated）

4. 子 Resource `.tres` 文件成为唯一数据源

**收益**：
- 消除数据冗余，单一数据源
- 子 Resource 可独立编辑、复用
- `SkillVisualDef` 变为纯容器，职责清晰

**风险**：
- 需要迁移所有现有技能的 `.tres` 文件
- `_configure_trail_particles()` 等函数需要全面重写
- 工作量大，建议在功能稳定后批量执行

---

## 五、工程规则建议（可直接采纳）

### 5.1 纹理生命周期规则

```
[规则] 粒子纹理选择优先级：
  1. 技能 visual_def 指定的 tex_path → 加载并使用
  2. 未指定 → 使用程序化默认纹理（soft_circle / circle）
  
[规则] 程序化纹理由 VFXTextureManager 统一管理，带缓存：
  - SOFT_CIRCLE：带 alpha 渐变的软边圆（用于 glow/粒子默认纹理）
  - CIRCLE：硬边圆（用于核心 sprite、碰撞检测辅助等）
  - NOSE_TRIANGLE：弹尖三角形
  - RAY_STARBURST：辐射射线
```

### 5.2 颜色应用规则

```
[规则] 粒子颜色来源优先级：
  1. 自定义纹理 → 纹理颜色即最终颜色，不叠加 color_initial_ramp
  2. 程序化纹理（白色） → 通过 color_initial_ramp 着色
  3. color_initial_ramp 使用 trail_color_1/2/3 作为生命周期渐变色
  
[规则] 拖尾系统颜色来源：
  - trail_particles：由上述规则决定
  - front_flame_particles：ParticleProcessMaterial 方向色
  - comet Line2D：comet_*_color 字段直接赋值
```

### 5.3 对象池复用规则

```
[规则] ProjectileNode.initialize() 必须重置所有视觉状态：
  - 所有纹理变量归 null
  - 所有粒子 emitting = false
  - 所有 Sprite modulate = Color(1,1,1,1)
  - 所有 Line2D points 清空
  
[规则] _apply_visual() 必须为每个视觉组件明确设值：
  - 启用的组件：配置并 visible = true
  - 未启用的组件：停止 emitting、visible = false
  - 不允许"不设值就保留上一技能状态"的隐式行为
```

### 5.4 Shader 材质规则

```
[规则] 共享材质（VFXTextureManager.get_shared_material）仅用于静态参数：
  - 相同参数的弹体共享材质，减少 GPU 状态切换
  - 禁止运行时修改共享材质的 uniform（会影响所有使用者）
  
[规则] 需要运行时动画的材质：
  - 使用 duplicate_material() 创建独立副本
  - 或直接 new ShaderMaterial() + 手动设置参数
```

---

## 六、优先级排序

| 优先级 | 事项 | 工作量 |
|--------|------|--------|
| **P0 立即修复** | 方案 A：`color_initial_ramp` 仅在无自定义纹理时应用 | 小 |
| **P1 短期** | 建立 5.1-5.3 的工程规则文档，后续开发遵循 | 小 |
| **P2 中期** | 补充 `trail_color_1/2/3` 字段的设计意图文档 | 小 |
| **P3 长期** | 方案 C：激活 v3.0 子 Resource 体系 | 大 |
