# VFX System Overhaul Proposal (v2.0)

**Status:** Proposed  
**Version:** 0.1  
**Date:** 2026-05-17  
**Owner:** Engineering + Art  
**Related:** `godot-skill-system-node-architecture.md` · `skill-system-architecture-2026-04-15.md` · `hit-feedback-juice-spec.md` · `pixel-art-visual-bible.md`  
**Scope:** Godot 4.6.2 技能视觉特效系统的全面升级——从"代码驱动 Sprite2D 层叠"进化为"Shader + 数据驱动的分层特效架构"。

---

## 1. Motivation

当前技能特效系统在**架构设计**上正确（数据驱动、对象池、Modifier 链），但在**渲染技术**上存在根本性瓶颈：

| 维度 | 现状 | 问题 |
|------|------|------|
| 渲染技术 | 零 Shader；全部靠 Sprite2D 层叠 + Tween | 视觉上限极低，无法实现发光/溶解/扭曲等现代 2D 特效 |
| 纹素资产 | 程序化 16×16 白色圆形（逐像素 `set_pixel`） | 拉伸后严重失真，无细节 |
| 命中特效 | 每次 `new Sprite2D()` + `queue_free()`，无池化 | 高频命中时 GC 压力；节点挂在 `scene.root` 无法被场景切换清理 |
| 执行器种类 | 5 种 kind 中 2 种为空实现（`sprite_burst`, `ring`） | 命中表现力不足 |
| SkillVisualDef | 285 行 God Object，100+ `@export` 字段 | 每加新技能就要膨胀，无法复用子模块 |
| 预警系统 | `_spawn_telegraph()` 只创建 CollisionShape2D，无视觉渲染 | 玩家看不到预警区域 |

**目标：** 以最小改动量获得最大视觉提升，为后续 8 技能 + BOSS 战打下可扩展的视觉基础。

---

## 2. Current State Audit

### 2.1 Keep (架构正确，保留)

| 模块 | 保留理由 |
|------|---------|
| `ExecutionChain` 状态载体 | Modifier 链的核心，运行良好 |
| `ModifierProcessor` 执行引擎 | 递归处理子链的逻辑正确 |
| `ProjectilePool` 对象池 | 100 预分配 + overflow 创建，已验证 |
| `SkillSignalBus` 信号总线 | 解耦良好，事件驱动正确 |
| `VFXTierRegistry` 分层数据 | A/B/C 三层组合的思路正确，保留数据层 |
| `.tres` 数据驱动 | 所有参数可配，Inspector 可编辑 |

### 2.2 Change (需要改造)

| 模块 | 当前实现 | 改造方向 |
|------|---------|---------|
| `ProjectileNode` 渲染 | 7× Sprite2D + 程序化纹理 | 引入 Shader 层 + 外部纹理资产 |
| `SkillVFXManager` 命中特效 | Sprite2D + Tween，无池化 | 命中特效对象池 + GPUParticles2D |
| 命中特效执行器 | match 分发，2 种空实现 | 策略模式 + 全部实现 + 新增类型 |
| `SkillVisualDef` | 285 行单体 Resource | 拆分为组合式子 Resource |
| `_spawn_telegraph()` | 仅 CollisionShape2D | Shader 驱动的可视预警 |
| 共享纹理 | 各类各自生成 16×16 圆形 | 全局纹理管理器 + 外部纹理资产 |

### 2.3 Known Bugs / Workarounds to Address

| 问题 | 位置 | 解决方案 |
|------|------|---------|
| Godot 4.6 bool 属性缓存 bug | `projectile_node.gd:457-459, 659-663` | 升级到 4.6.2 后验证是否仍存在；若仍在，用 int 0/1 替代 bool |
| GPUParticles2D 零方向归一化 | 设计文档记载 | 命中特效用 `EMIT_DIRECTION` + 随机方向锥，不传零向量 |
| 命中特效挂在 `scene.root` | `skill_vfx_manager.gd` | 迁移到场景树专用 VFX 层节点 |
| `projectile.tscn` 有未使用的 Core/Trail 子节点 | `nodes/projectile.tscn` | 清理场景文件，全部由脚本动态创建 |

---

## 3. Target Architecture

### 3.1 New File Structure

```
game/scripts/skill_system/
├── vfx/
│   ├── skill_vfx_manager.gd          ← [MODIFY] 总控，接入池化 + 策略分发
│   ├── hit_vfx_pool.gd               ← [NEW] 命中特效对象池
│   ├── hit_vfx_node.gd               ← [NEW] 池化命中特效节点
│   ├── vfx_tier_registry.gd          ← [KEEP] 分层数据查询
│   ├── vfx_layer_def.gd              ← [KEEP] 原子特效定义
│   ├── vfx_tier_def.gd               ← [KEEP] 层级池定义
│   ├── vfx_global_config.gd          ← [KEEP] 全局配置
│   ├── executors/                     ← [NEW] 策略模式执行器
│   │   ├── vfx_executor_base.gd      ← 执行器基类
│   │   ├── exec_particle_burst.gd    ← 粒子爆发（现有逻辑迁移）
│   │   ├── exec_sprite_burst.gd      ← 精灵爆发（新增实现）
│   │   ├── exec_screen_shake.gd      ← 震屏（现有逻辑迁移）
│   │   ├── exec_flash.gd             ← 闪光（现有逻辑迁移）
│   │   ├── exec_ring.gd              ← 扩散环（新增实现）
│   │   ├── exec_shockwave.gd         ← 冲击波（新增）
│   │   ├── exec_afterimage.gd        ← 残影（新增）
│   │   └── exec_rim_glow.gd          ← 边缘发光（新增）
│   └── shaders/                       ← [NEW] Shader 资产
│       ├── glow_shader.gdshader      ← 发光混合
│       ├── dissolve_shader.gdshader  ← 溶解消散
│       ├── ring_wave.gdshader        ← 冲击波环
│       ├── telegraph_shader.gdshader ← 预警区域
│       └── rim_glow_shader.gdshader  ← 边缘发光
├── pools/
│   ├── projectile_pool.gd            ← [KEEP]
│   ├── projectile_node.gd            ← [MODIFY] 接入 Shader 层
│   ├── executor_pool.gd              ← [KEEP]
│   └── (hit_vfx_pool moved to vfx/)
└── registry/
    ├── skill_visual_def.gd           ← [MODIFY] 拆分为子 Resource 引用
    ├── projectile_visual.gd          ← [NEW] 弹体外观子 Resource
    ├── trail_visual.gd               ← [NEW] 拖尾子 Resource
    ├── impact_visual.gd              ← [NEW] 命中爆发子 Resource
    └── vfx_override.gd               ← [NEW] VFX 层级覆盖子 Resource
```

### 3.2 Shader Library Strategy

当前项目零 Shader。引入 Shader 的原则：

1. **最小侵入** — Shader 作为可选层叠加在现有 Sprite2D 之上，不改现有渲染管线
2. **数据驱动** — Shader 参数通过 `ShaderMaterial` 的 `set_shader_parameter()` 从 `.tres` 资源读取
3. **渐进引入** — Phase 1 只做 3 个基础 Shader，验证管线后再扩展
4. **移动优先** — 所有 Shader 必须兼容 Godot 移动渲染器（避免全屏后处理）

### 3.3 Executor Strategy Pattern

替代当前的 `match layer.kind` 硬编码分发：

```
VFXLayerDef (Resource)
  ├── kind: StringName    ← 改为 StringName（非 int），支持动态查找
  └── params: Dictionary

VFXExecutorBase (RefCounted)
  ├── can_handle(kind: StringName) -> bool
  ├── execute(layer: VFXLayerDef, pos: Vector2, pool: HitVFXPool) -> void
  └── cleanup() -> void

VFXExecutorRegistry (Node)
  ├── _executors: Array[VFXExecutorBase]
  ├── register(executor: VFXExecutorBase)
  └── dispatch(kind: StringName, layer: VFXLayerDef, pos: Vector2)
```

**优势：** 新增特效类型只需新建一个 `VFXExecutorBase` 子类并注册，无需修改 `SkillVFXManager`。

---

## 4. Phase 1 — Shader Infrastructure

**目标：** 建立 Shader 基础设施，让弹体和命中特效可以使用 GPU 加速的视觉效果。

**前置条件：** 无  
**预计工作量：** 2–3 天  
**视觉提升：** ★★★★★（质变级）

### 4.1 Task 1.1: Create Glow Shader

**文件：** `game/scripts/skill_system/vfx/shaders/glow_shader.gdshader`

**功能：** 基于 alpha 通道的边缘发光效果，用于弹体核心层、命中闪光。

**技术规格：**
```glsl
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float glow_strength : hint_range(0.0, 3.0) = 1.5;
uniform float glow_radius : hint_range(0.0, 20.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;  // 0 = no pulse
uniform float time_offset : hint_range(0.0, 6.28) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float alpha = tex.a;
    // 边缘检测：alpha 梯度越大 = 越接近边缘
    float edge = smoothstep(0.0, 0.3, alpha) * (1.0 - smoothstep(0.7, 1.0, alpha));
    float pulse = pulse_speed > 0.0 ? 0.5 + 0.5 * sin(TIME * pulse_speed + time_offset) : 1.0;
    COLOR = mix(tex, glow_color, edge * glow_strength * pulse);
    COLOR.a = alpha + edge * glow_strength * pulse * 0.5;
}
```

**集成点：**
- `ProjectileNode._setup_visuals()` — 对 `_glow_sprite` 和 `_glow2_sprite` 应用此 Shader
- `SkillVFXManager._exec_flash()` — 命中闪光使用此 Shader 替代纯色 Sprite2D

**验收标准：**
- 弹体边缘可见柔和发光，颜色可从 `SkillVisualDef` 配置
- 性能：100 个弹体同时在场时帧率无下降（Shader 在 GPU 执行）

### 4.2 Task 1.2: Create Dissolve Shader

**文件：** `game/scripts/skill_system/vfx/shaders/dissolve_shader.gdshader`

**功能：** 基于噪声的溶解消散效果，用于弹体消亡、命中消融。

**技术规格：**
```glsl
shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;  // 0=完整, 1=完全溶解
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);  // 溶解边缘颜色
uniform float edge_width : hint_range(0.0, 0.3) = 0.05;
uniform sampler2D noise_texture;  // 外部噪声纹理

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float noise = texture(noise_texture, UV).r;
    // 噪声值低于溶解阈值的部分被丢弃
    float edge = smoothstep(dissolve_amount - edge_width, dissolve_amount, noise);
    float is_edge = smoothstep(dissolve_amount, dissolve_amount + edge_width, noise) - edge;
    COLOR = tex;
    COLOR.a *= step(dissolve_amount, noise);
    // 溶解边缘高亮
    COLOR.rgb += dissolve_color.rgb * is_edge * dissolve_color.a;
    COLOR.a = max(COLOR.a, is_edge * dissolve_color.a);
}
```

**集成点：**
- `ProjectileNode` 消亡序列 — 替代当前 300ms alpha Tween，改为溶解动画
- 命中后目标闪白 → 溶解效果（可选，视美术风格）

**噪声纹理：**
- 使用 Godot 内置 `NoiseTexture2D` + `FastNoiseLite`（程序化生成，无需外部文件）
- 或使用项目已有的 `assets/textures/vfx/` 中的纹理作为噪声源

**验收标准：**
- 溶解边缘有高亮色，溶解过程可配速
- 溶解参数可通过 `ShaderMaterial.set_shader_parameter()` 运行时控制

### 4.3 Task 1.3: Create Ring Wave Shader

**文件：** `game/scripts/skill_system/vfx/shaders/ring_wave.gdshader`

**功能：** 扩散环形冲击波，用于命中冲击、AOE 范围指示。

**技术规格：**
```glsl
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0=中心, 1=完全扩散
uniform vec4 ring_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform float ring_width : hint_range(0.01, 0.5) = 0.08;
uniform float fade_start : hint_range(0.0, 1.0) = 0.5;  // 开始淡出的进度

void fragment() {
    vec2 center = UV - 0.5;
    float dist = length(center) * 2.0;  // 归一化到 0-1
    // 环形：距离在 [progress - width, progress + width] 范围内
    float ring = smoothstep(progress - ring_width, progress, dist)
               - smoothstep(progress, progress + ring_width, dist);
    float fade = 1.0 - smoothstep(fade_start, 1.0, progress);
    COLOR = ring_color;
    COLOR.a = ring * fade;
}
```

**集成点：**
- 新增 `exec_ring.gd` 执行器使用此 Shader
- `ProjectileNode._spawn_explosion()` 可选用此 Shader 替代纯粒子爆发

**验收标准：**
- 环形从中心向外扩散，边缘柔和
- `progress` 可通过 Tween 0→1 驱动动画

### 4.4 Task 1.4: Global Texture Manager

**文件：** `game/scripts/skill_system/vfx/texture_manager.gd`

**功能：** 统一管理所有 VFX 纹理资产，替代当前各类各自 `_get_shared_circle_texture()` 的做法。

**设计：**
```gdscript
class_name VFXTextureManager
extends RefCounted

# 静态单例
static var _instance: VFXTextureManager
static func get_instance() -> VFXTextureManager:
    if _instance == null:
        _instance = VFXTextureManager.new()
    return _instance

# 纹理缓存
var _cache: Dictionary = {}  # StringName -> Texture2D

# 预定义纹理键
const CIRCLE := &"circle"
const NOSE_TRIANGLE := &"nose_triangle"
const RAY_STARBURST := &"ray_starburst"
const NOISE_PERLIN := &"noise_perlin"

func get_texture(key: StringName) -> Texture2D:
    if key in _cache:
        return _cache[key]
    var tex := _load_or_generate(key)
    _cache[key] = tex
    return tex

func _load_or_generate(key: StringName) -> Texture2D:
    match key:
        CIRCLE:
            return _generate_circle(32)  # 升级到 32x32
        NOSE_TRIANGLE:
            return _generate_nose(32)
        RAY_STARBURST:
            return _generate_ray(64)  # 升级到 64x64
        NOISE_PERLIN:
            var noise := NoiseTexture2D.new()
            noise.noise = FastNoiseLite.new()
            noise.width = 128
            noise.height = 128
            return noise
        _:
            # 尝试从 assets/textures/vfx/ 加载
            var path := "res://assets/textures/vfx/%s.png" % key
            if ResourceLoader.exists(path):
                return load(path)
            push_warning("VFXTextureManager: unknown texture key '%s'" % key)
            return _generate_circle(32)
```

**迁移步骤：**
1. 创建 `VFXTextureManager`
2. 将 `ProjectileNode._get_shared_circle_texture()` 等静态方法改为调用 `VFXTextureManager`
3. 将 `SkillVFXManager._shared_circle_tex` 同样迁移
4. 验证所有现有特效视觉无变化

**验收标准：**
- 所有 VFX 纹理统一从 `VFXTextureManager` 获取
- 程序化纹理分辨率从 16×16 升级到 32×32 或更高
- 纹理在所有 ProjectileNode 实例间共享（静态缓存）

---

## 5. Phase 2 — Hit VFX System Upgrade

**目标：** 命中特效池化、补全执行器、引入策略模式。

**前置条件：** Phase 1 完成（Shader 基础设施就绪）  
**预计工作量：** 3–4 天  
**视觉提升：** ★★★★☆

### 5.1 Task 2.1: Hit VFX Object Pool

**文件：**
- `game/scripts/skill_system/vfx/hit_vfx_pool.gd` — 池管理器
- `game/scripts/skill_system/vfx/hit_vfx_node.gd` — 池化节点

**设计：**

```
HitVFXPool (Node2D)
  ├── pool_size: int = 50
  ├── _available: Array[HitVFXNode]
  ├── _active: Array[HitVFXNode]
  ├── acquire() -> HitVFXNode
  └── release(node: HitVFXNode)

HitVFXNode (Node2D)
  ├── _sprite: Sprite2D          ← 用于 particle_burst / flash / ring
  ├── _particles: GPUParticles2D ← 可选，用于粒子型特效
  ├── _shader_rect: ColorRect    ← 用于 Shader 驱动的特效
  ├── setup(layer_def: VFXLayerDef, pos: Vector2) -> void
  ├── play() -> void
  ├── stop() -> void
  └── _on_lifetime_expired() -> void  ← 自动归还到池
```

**关键约束：**
- 命中特效节点必须挂在场景树的专用 VFX 层下（`ArenaScene/VFXLayer`），而非 `scene.root`
- 池节点在场景切换时必须可被批量清理（`VFXLayer.queue_free()` 或遍历归还）
- 溢出策略：池满时创建新节点（同 `ProjectilePool`）

**集成点：**
- `SkillVFXManager._execute_layers()` — 从池获取节点，而非 `new Sprite2D()`
- `ArenaScene` — 添加 `VFXLayer` 子节点，传递引用给 `SkillVFXManager`

**验收标准：**
- 连续 100 次命中后，活动节点数稳定在池上限，无持续增长
- 切换回 HubScene 后无残留命中特效节点

### 5.2 Task 2.2: Executor Strategy Pattern

**文件：**
- `game/scripts/skill_system/vfx/executors/vfx_executor_base.gd`
- `game/scripts/skill_system/vfx/executors/executor_registry.gd`

**VFXExecutorBase 设计：**
```gdscript
class_name VFXExecutorBase
extends RefCounted

# 子类必须实现
func get_kind() -> StringName:
    return &""

func execute(layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool) -> void:
    pass
```

**ExecutorRegistry 设计：**
```gdscript
class_name VFXExecutorRegistry
extends RefCounted

var _executors: Dictionary = {}  # StringName -> VFXExecutorBase

func register(executor: VFXExecutorBase) -> void:
    _executors[executor.get_kind()] = executor

func dispatch(kind: StringName, layer: VFXLayerDef, world_pos: Vector2, pool: HitVFXPool) -> void:
    if kind in _executors:
        _executors[kind].execute(layer, world_pos, pool)
    else:
        push_warning("VFXExecutorRegistry: no executor for kind '%s'" % kind)
```

**迁移步骤：**
1. 创建 `VFXExecutorBase` 和 `VFXExecutorRegistry`
2. 将 `SkillVFXManager._exec_particle_burst()` 逻辑迁移到 `exec_particle_burst.gd`
3. 将 `_exec_screen_shake()` 迁移到 `exec_screen_shake.gd`
4. 将 `_exec_flash()` 迁移到 `exec_flash.gd`
5. 在 `SkillVFXManager.initialize()` 中注册所有执行器
6. 将 `_execute_layers()` 中的 `match` 分发改为 `executor_registry.dispatch()`
7. 验证现有特效行为不变

**验收标准：**
- `SkillVFXManager` 不再包含任何 `match layer.kind` 分发逻辑
- 新增特效只需新建 Executor 文件 + 注册一行代码
- `VFXLayerDef.kind` 从 `int` 改为 `StringName`（向下兼容：旧 int 值自动转换）

### 5.3 Task 2.3: Implement `ring` Executor

**文件：** `game/scripts/skill_system/vfx/executors/exec_ring.gd`

**功能：** 命中时在目标位置生成扩散环形冲击波。

**实现方案：**
1. 从 `HitVFXPool` 获取节点
2. 使用 `RingWave Shader`（Phase 1 Task 1.3）
3. Tween 驱动 `progress` 从 0.0 → 1.0
4. 参数（从 `VFXLayerDef.params` 读取）：
   - `color: Color` — 环形颜色
   - `radius: float` — 最终半径（像素）
   - `duration: float` — 扩散持续时间（秒）
   - `width: float` — 环形宽度
5. 动画结束后归还节点到池

**验收标准：**
- 命中时可见清晰的环形扩散效果
- 环形颜色、半径、持续时间可从 `.tres` 配置

### 5.4 Task 2.4: Implement `sprite_burst` Executor

**文件：** `game/scripts/skill_system/vfx/executors/exec_sprite_burst.gd`

**功能：** 命中时生成一组精灵碎片向外飞散，模拟击碎/爆裂感。

**实现方案：**
1. 从 `HitVFXPool` 获取 N 个节点
2. 每个节点使用随机纹理（从纹理管理器获取 spark/碎片纹理）
3. 随机方向 + 随机速度 + 重力影响
4. Tween 驱动位移 + 旋转 + alpha 衰减
5. 参数：
   - `count: int` — 碎片数量
   - `speed_min/max: float` — 飞散速度范围
   - `gravity: float` — 重力加速度
   - `texture_keys: Array[StringName]` — 可选纹理列表（随机选取）
   - `lifetime: float` — 存活时间
   - `color: Color` — 颜色调制

**验收标准：**
- 碎片从命中点向外抛物线飞散，有物理感
- 碎片数量、速度、重力可配

### 5.5 Task 2.5: Implement `shockwave` Executor (New Kind)

**文件：** `game/scripts/skill_system/vfx/executors/exec_shockwave.gd`

**功能：** 强力命中时的全屏冲击波效果——屏幕短暂扭曲 + 扩散环。

**实现方案：**
1. 使用 `RingWave Shader` 生成大半径扩散环
2. 叠加一个短暂的屏幕扭曲效果（可选：通过 `CanvasLayer` + `ColorRect` + `distortion shader`）
3. 配合 `screen_shake` 使用
4. 参数：
   - `ring_color: Color`
   - `ring_radius: float`
   - `duration: float`
   - `distortion_strength: float` — 扭曲强度（0 = 无扭曲，仅环）

**VFXLayerDef 新增 kind：**
- `&"shockwave"` — 注册到 executor registry

**验收标准：**
- BOSS 技能命中时有冲击感
- 扭曲效果在移动端不造成明显性能下降

### 5.6 Task 2.6: Implement `afterimage` Executor (New Kind)

**文件：** `game/scripts/skill_system/vfx/executors/exec_afterimage.gd`

**功能：** 快速移动物体的残影效果——在运动轨迹上留下半透明副本。

**实现方案：**
1. 获取目标（命中者或弹体）的当前纹理和位置
2. 创建 N 个半透明 Sprite2D 副本，间隔固定时间
3. 每个副本 alpha 递减，颜色向单色偏移
4. Tween 驱动 alpha → 0 后归还池
5. 参数：
   - `count: int` — 残影数量
   - `interval: float` — 残影间隔（秒）
   - `color_tint: Color` — 残影色调
   - `alpha_start: float` — 起始透明度
   - `lifetime: float` — 每个残影存活时间

**VFXLayerDef 新增 kind：**
- `&"afterimage"`

**验收标准：**
- 高速弹体（如 missile_storm）的弹道上有残影拖尾
- 残影数量和间隔可配

---

## 6. Phase 3 — SkillVisualDef Decomposition

**目标：** 将 285 行的 God Object 拆分为组合式子 Resource。

**前置条件：** 无（可与 Phase 1/2 并行）  
**预计工作量：** 2 天  
**可维护性提升：** ★★★★★

### 6.1 Task 3.1: Define Sub-Resources

**新文件：**

| 文件 | 类名 | 职责 | 字段数 |
|------|------|------|--------|
| `game/scripts/skill_system/registry/projectile_visual.gd` | `ProjectileVisual` | 弹体外观（核心层、纹理、缩放、颜色） | ~30 |
| `game/scripts/skill_system/registry/trail_visual.gd` | `TrailVisual` | 拖尾（粒子尾迹、彗星尾迹、前缘火焰） | ~35 |
| `game/scripts/skill_system/registry/impact_visual.gd` | `ImpactVisual` | 命中爆发（火花、震屏、VFX 层级覆盖） | ~25 |
| `game/scripts/skill_system/registry/vfx_override.gd` | `VFXOverride` | VFX 层级池覆盖（tier A/B/C + custom layers） | ~5 |

**ProjectileVisual 设计：**
```gdscript
class_name ProjectileVisual
extends Resource

# ── Identity ──
@export var projectile_kind: int = 0  # 保留枚举值

# ── Core Layers ──
@export_group("Core")
@export var core_color: Color = Color.WHITE
@export var core_width: float = 16.0
@export var core_height: float = 16.0
@export var core_radius: float = 0.0
@export var core_texture_path: String = ""
@export var inner_enabled: bool = false
@export var inner_color: Color = Color.WHITE
@export var inner_width: float = 8.0
@export var inner_height: float = 8.0
@export var inner_offset_x: float = 0.0
@export var inner_offset_y: float = 0.0
@export var hotspot_enabled: bool = false
@export var hotspot_color: Color = Color.WHITE
@export var hotspot_width: float = 4.0
@export var hotspot_height: float = 4.0
@export var hotspot_offset_x: float = 0.0
@export var hotspot_offset_y: float = 0.0

# ── Glow ──
@export_group("Glow")
@export var glow_enabled: bool = true
@export var glow_color: Color = Color(1, 0.8, 0.4, 0.5)
@export var glow_radius: float = 16.0
@export var glow2_enabled: bool = false
@export var glow2_color: Color = Color(1, 0.9, 0.6, 0.3)
@export var glow2_radius: float = 10.0

# ── Nose ──
@export_group("Nose")
@export var nose_enabled: bool = false
@export var nose_color: Color = Color.WHITE
@export var nose_width: float = 12.0
@export var nose_height: float = 4.0
@export var nose_texture_path: String = ""

# ── Jitter ──
@export_group("Jitter")
@export var jitter_enabled: bool = false
@export var jitter_amplitude: float = 1.5
@export var jitter_freq_x: float = 12.0
@export var jitter_freq_y: float = 10.0

# ── Scale ──
@export var projectile_scale: float = 1.0

# ── Ray ──
@export_group("Ray")
@export var ray_enabled: bool = false
@export var ray_color: Color = Color(1, 0.9, 0.7, 0.4)
```

**TrailVisual 设计：**
```gdscript
class_name TrailVisual
extends Resource

# ── Trail Particles ──
@export_group("Trail Particles")
@export var trail_enabled: bool = true
@export var trail_count: int = 8
@export var trail_lifetime: float = 0.4
@export var trail_back_distance: float = 20.0
@export var trail_spread: float = 15.0
@export var trail_radius_min: float = 1.0
@export var trail_radius_max: float = 3.0
@export var trail_color_1: Color = Color(1, 0.6, 0.2)
@export var trail_color_2: Color = Color(1, 0.3, 0.1)
@export var trail_texture_path: String = ""

# ── Front Flame ──
@export_group("Front Flame")
@export var flame_enabled: bool = false
@export var flame_count: int = 6
@export var flame_inner_radius: float = 5.0
@export var flame_outer_radius: float = 12.0
@export var flame_spread_angle: float = 45.0
@export var flame_color_1: Color = Color(1, 0.7, 0.3)
@export var flame_color_2: Color = Color(1, 0.4, 0.1)

# ── Comet Trail (Line2D) ──
@export_group("Comet Trail")
@export var comet_enabled: bool = false
@export var comet_max_samples: int = 20
@export var comet_outer_width: float = 6.0
@export var comet_outer_color: Color = Color(1, 0.5, 0.2, 0.35)
@export var comet_mid_width: float = 3.4
@export var comet_mid_color: Color = Color(1, 0.6, 0.3, 0.62)
@export var comet_inner_width: float = 1.8
@export var comet_inner_color: Color = Color(1, 0.8, 0.4, 0.96)
@export var comet_sway_freq: float = 3.0
@export var comet_sway_amp: float = 4.0
```

**ImpactVisual 设计：**
```gdscript
class_name ImpactVisual
extends Resource

# ── Impact Level ──
@export_enum("LIGHT", "MEDIUM", "STRONG", "CLIMAX")
var impact_level: String = "MEDIUM"

# ── Spark Burst ──
@export_group("Spark Burst")
@export var spark_count_min: int = 8
@export var spark_count_max: int = 12
@export var spark_speed_min: float = 100.0
@export var spark_speed_max: float = 300.0
@export var spark_lifetime: float = 0.3
@export var spark_color: Color = Color(1, 0.7, 0.3)
@export var spark_particle_count: int = 3

# ── Screen Effects ──
@export_group("Screen Effects")
@export var shake_strength: float = 0.0
@export var flash_enabled: bool = false
@export var flash_color: Color = Color.WHITE
@export var flash_duration: float = 0.08
@export var flash_radius: float = 12.0

# ── Shader Effects ──
@export_group("Shader Effects")
@export var dissolve_on_hit: bool = false
@export var dissolve_color: Color = Color(1, 0.8, 0.3, 1.0)
@export var dissolve_duration: float = 0.4
@export var ring_on_hit: bool = false
@export var ring_color: Color = Color(1, 0.9, 0.5, 0.8)
@export var ring_radius: float = 40.0
```

### 6.2 Task 3.2: Modify SkillVisualDef to Use Sub-Resources

**文件：** `game/scripts/skill_system/registry/skill_visual_def.gd`

**变更：**
```gdscript
class_name SkillVisualDef
extends Resource

# ── Identity ──
@export var skill_id: String = ""

# ── Sub-Resources (composition) ──
@export var projectile_visual: ProjectileVisual
@export var trail_visual: TrailVisual
@export var impact_visual: ImpactVisual
@export var vfx_override: VFXOverride

# ── Timing & Trajectory (stay here — not visual-specific) ──
@export_group("Timing")
@export var telegraph_ms: int = 0
@export var travel_ms: int = 500

@export_group("Trajectory")
@export_enum("LINEAR", "HOMING", "BEZIER_QUAD", "BEZIER_CUBIC", "SINE_WAVE", "SPIRAL")
var trajectory_type: String = "LINEAR"

@export_group("Multi-Projectile")
@export var projectile_count_min: int = 1
@export var projectile_count_max: int = 1
@export var projectile_stagger_sec: float = 0.0

@export_group("Telegraph")
@export_enum("CIRCLE", "RECT", "FAN")
var telegraph_shape: String = "CIRCLE"
```

**向后兼容策略：**
- 保留旧字段作为 `@export`（标记为 `@deprecated`）
- 在 `_get()` 方法中，如果新子 Resource 为空但旧字段有值，自动创建临时子 Resource
- 提供一次性迁移脚本（Python 或 GDScript），将现有 `.tres` 文件的旧字段提取到新子 Resource 文件中

### 6.3 Task 3.3: Migration Script

**文件：** `game/tools/migrate_visual_defs.py`

**功能：** 读取现有 `skill_visual_defs/*.tres`，拆分为：
- `{skill_id}_projectile.tres` → ProjectileVisual
- `{skill_id}_trail.tres` → TrailVisual
- `{skill_id}_impact.tres` → ImpactVisual
- 更新原 `{skill_id}.tres` → 引用新子 Resource

**验收标准：**
- 迁移后所有现有技能（fireball_basic, missile_storm）的视觉效果不变
- 新 `.tres` 文件可在 Godot Inspector 中独立编辑

---

## 7. Phase 4 — New Effect Types

**目标：** 补充现代 2D 动作游戏的核心特效语言。

**前置条件：** Phase 1 + Phase 2 完成  
**预计工作量：** 2–3 天  
**视觉提升：** ★★★☆☆（在已有基础上锦上添花）

### 7.1 Task 4.1: Path Particles (路径粒子)

**功能：** 沿弹体飞行轨迹留下光点轨迹。

**实现方案：**
- 在 `ProjectileNode._process()` 中，每隔 N 帧记录当前位置到 `_trail_positions` 数组
- 使用 `GPUParticles2D` 的 `emission_points` 或直接在记录位置撒 Sprite2D 粒子
- 粒子 alpha 随时间衰减

**集成点：**
- `ProjectileNode` — 新增 `_path_particles_enabled` 标志
- `TrailVisual` — 新增 `path_particles_enabled`, `path_particle_interval`, `path_particle_lifetime` 字段

### 7.2 Task 4.2: Telegraph Visual Rendering

**文件：**
- `game/scripts/skill_system/vfx/shaders/telegraph_shader.gdshader`
- 修改 `skill_vfx_manager.gd._spawn_telegraph()`

**Shader 设计：**
```glsl
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0=开始, 1=完成
uniform vec4 fill_color : source_color = vec4(1.0, 0.2, 0.2, 0.3);
uniform vec4 border_color : source_color = vec4(1.0, 0.3, 0.3, 0.8);
uniform float border_width : hint_range(0.0, 0.2) = 0.03;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    vec2 center = UV - 0.5;
    float dist = length(center) * 2.0;
    // 填充：从外向内填充
    float fill = smoothstep(1.0, progress, dist);
    // 边框
    float border = smoothstep(1.0 - border_width, 1.0, dist);
    // 脉冲
    float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
    COLOR = mix(fill_color, border_color, border);
    COLOR.a *= fill * (0.5 + 0.5 * pulse);
}
```

**集成点：**
- `_spawn_telegraph()` — 替换空 CollisionShape2D 为 `ColorRect` + telegraph_shader
- 支持 CIRCLE / RECT / FAN 三种形状（通过不同的 UV 映射或不同 Shader 变体）

**验收标准：**
- BOSS 施法前地面出现红色预警区域，从外向内渐显
- 预警区域有脉冲呼吸效果，吸引玩家注意
- 施法完成后预警区域消失

### 7.3 Task 4.3: Rim Glow Effect (边缘发光)

**功能：** 命中后目标身体边缘短暂发光，表示受到冲击。

**实现方案：**
- 对目标 Unit 的 `_body`（ColorRect）应用 `rim_glow_shader`
- Tween 驱动发光强度从峰值衰减到 0
- 300ms 后移除 Shader

**Shader：**
```glsl
shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float edge = smoothstep(0.3, 0.5, tex.a) * (1.0 - smoothstep(0.7, 1.0, tex.a));
    COLOR = tex;
    COLOR.rgb += rim_color.rgb * edge * rim_strength;
}
```

**集成点：**
- `Unit.take_damage()` — 可选应用 rim glow
- `ImpactVisual` — 新增 `rim_glow_enabled`, `rim_glow_color`, `rim_glow_duration` 字段

---

## 8. Phase 5 — Performance & Polish

**目标：** 性能优化、边界情况处理、文档完善。

**前置条件：** Phase 1–4 完成  
**预计工作量：** 1–2 天

### 8.1 Task 5.1: Hit VFX Pool Sizing

- 在 SkillDemo 场景中压力测试：同时触发 200+ 命中
- 确定合理的池大小（建议默认 80）
- 验证溢出创建 → 归还的稳定性

### 8.2 Task 5.2: ProjectileNode Shader Batch

- 验证 100 个使用 Shader 的弹体同时在场的帧率
- 如有性能问题：考虑减少 Shader 层数、降低纹理分辨率、或使用 `CanvasGroup` 合批

### 8.3 Task 5.3: VFXLayerDef Kind Migration

- 将所有现有 `.tres` 中的 `kind: int` 迁移为 `kind: StringName`
- 提供向下兼容：代码中同时接受 int 和 StringName，int 自动转换

### 8.4 Task 5.4: Documentation Update

- 更新 `godot-skill-system-node-architecture.md` 的 VFX 部分
- 为每个新 Shader 编写内联注释（参数说明）
- 更新 `PROJECT-RULES.md` 中的文件结构说明

---

## 9. Implementation Order & Dependencies

```
Phase 1: Shader Infrastructure ─────────┐
  Task 1.1: Glow Shader                 │
  Task 1.2: Dissolve Shader             ├─ 可并行
  Task 1.3: Ring Wave Shader            │
  Task 1.4: Texture Manager ────────────┘
         │
         ▼
Phase 2: Hit VFX System Upgrade ────────┐
  Task 2.1: Hit VFX Pool               │
  Task 2.2: Executor Strategy Pattern   ├─ 2.1 → 2.2 → 2.3/2.4/2.5/2.6
  Task 2.3: Ring Executor               │   (2.3-2.6 可并行)
  Task 2.4: Sprite Burst Executor       │
  Task 2.5: Shockwave Executor          │
  Task 2.6: Afterimage Executor         │
         │
         ▼
Phase 3: SkillVisualDef Refactoring ────┐
  Task 3.1: Define Sub-Resources        ├─ 可与 Phase 1/2 并行
  Task 3.2: Modify SkillVisualDef       │
  Task 3.3: Migration Script            │
         │
         ▼
Phase 4: New Effect Types ──────────────┐
  Task 4.1: Path Particles              │
  Task 4.2: Telegraph Visual            ├─ 依赖 Phase 1 Shader
  Task 4.3: Rim Glow Effect             │
         │
         ▼
Phase 5: Performance & Polish
  Task 5.1–5.4
```

**AI 执行建议：**
- Phase 3（Resource 拆分）可以独立于 Phase 1/2 执行，由一个 AI agent 负责
- Phase 1（Shader）可以独立执行，由一个 AI agent 负责
- Phase 2（命中特效升级）依赖 Phase 1，由一个 AI agent 负责
- Phase 4（新特效类型）依赖 Phase 1+2，由一个 AI agent 负责
- Phase 5（收尾）由主 AI 协调

---

## 10. Risk & Constraints

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| Godot 移动渲染器对 Shader 支持有限 | 部分 Shader 效果不可用 | 所有 Shader 必须在移动渲染器下测试；提供 fallback（无 Shader 的纯 Sprite2D 模式） |
| SkillVisualDef 重构可能破坏现有 .tres | 迁移期间技能视觉异常 | 提供迁移脚本 + 向后兼容层 + 逐技能验证 |
| 命中特效池大小不足 | 溢出时频繁创建销毁 | 默认池大小 80 + 动态扩容 + 压力测试确定合理值 |
| Shader 参数过多导致调试困难 | 视觉效果难以调优 | 所有 Shader 参数通过 Inspector 可调 + SkillDemo 场景实时预览 |
| GPUParticles2D 零方向 bug 仍存在 | 命中粒子方向错误 | 在 `_exec_particle_burst` 中显式设置非零方向向量 |

---

## 11. Success Criteria

Phase 完成后的验收标准：

| Phase | 验收标准 |
|-------|---------|
| Phase 1 | 弹体可见 Shader 发光效果；溶解动画可在 SkillDemo 中预览；Ring Shader 可通过 Tween 驱动 |
| Phase 2 | 命中特效节点数在连续战斗中保持稳定（无泄漏）；ring/sprite_burst/shockwave 效果可从 .tres 配置并正确渲染 |
| Phase 3 | fireball_basic 和 missile_storm 的 SkillVisualDef 已拆分为子 Resource；视觉效果不变；新子 Resource 可在 Inspector 独立编辑 |
| Phase 4 | BOSS 施法有可视预警区域；高速弹体有残影效果；路径粒子在弹体飞行轨迹上可见 |
| Phase 5 | 100 弹体 + 连续命中场景下帧率 ≥ 30fps（移动端）；所有文档已更新 |

---

## 12. Out of Scope (This Proposal)

以下内容不在本次改造范围内，列为后续迭代：

| 内容 | 理由 |
|------|------|
| 角色动画系统 | 当前角色为 ColorRect，动画系统是独立课题 |
| 全屏后处理（Bloom, CRT） | 需要 `CanvasLayer` + 全屏 Shader，影响大，建议独立方案 |
| 音效系统 | 视觉与音效解耦，音效方案独立 |
| 新增技能定义 | 本次只改造特效基础设施，不新增技能 `.tres` |
| 3D 特效 | 项目为纯 2D |

---

## 13. Revision Record

| 版本 | 日期 | 说明 |
|------|------|------|
| 0.1 | 2026-05-17 | 初稿：5 Phase 方案，覆盖 Shader 基础设施、命中特效池化、SkillVisualDef 重构、新特效类型、性能优化 |
