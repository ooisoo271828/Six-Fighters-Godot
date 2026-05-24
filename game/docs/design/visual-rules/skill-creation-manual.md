# 技能视觉制作手册 (VFX System v4.0)

> 2026-05-24 | 适用于 Godot 4.x

---

## 一、架构概述

### 1.1 数据分离原则

每个技能有两个独立的 `.tres` 文件：

| 文件 | 内容 | 位置 |
|------|------|------|
| SkillDef | 战斗数值（伤害、冷却、目标模式） | `resources/skills/skill_defs/` |
| SkillVisualDef | 视觉配置（弹体、拖尾、命中特效） | `resources/skills/skill_visual_defs/` |

修改数值不影响视觉，修改视觉不影响数值。

### 1.2 SkillVisualDef 结构

```
SkillVisualDef (容器)
├── 顶层元数据：skill_id, projectile_kind, speed, projectile_count_min/max, trajectory_type
├── body: ProjectileVisual    ← 弹体核心视觉
├── trail: TrailDef           ← 拖尾系统（可选子配置）
└── impact: ImpactVisual      ← 命中视觉 + VFX 层级池
```

---

## 二、创建新技能的完整流程

### Step 1：创建 SkillDef（战斗数据）

在 `resources/skills/skill_defs/` 下创建 `my_skill.tres`：

1. Godot 编辑器 → 右键 → New Resource → 选择 `SkillDef`
2. 填写字段：
   - `skill_id`: "my_skill"（必须与文件名一致）
   - `display_name`: "我的技能"
   - `base_damage`: 30.0
   - `cooldown`: 1.5
   - `effect_type`: "emit_projectile"
   - `target_mode`: NEAREST
   - 其他战斗参数...
3. 保存为 `my_skill.tres`

### Step 2：创建 SkillVisualDef（视觉数据）

在 `resources/skills/skill_visual_defs/` 下创建 `my_skill.tres`：

#### 2.1 创建容器

1. New Resource → `SkillVisualDef`
2. 填写顶层字段：
   - `skill_id`: "my_skill"
   - `projectile_kind`: 选择类型（FIREBALL, ICE_CYCLONE 等）
   - `speed`: 300.0
   - `projectile_scale`: 1.0
   - `projectile_count_min/max`: 1 / 1（单发）

#### 2.2 配置弹体核心（body: ProjectileVisual）

创建子 Resource → `ProjectileVisual`，赋值给 `body` 字段：

**基础弹体（纯色圆）**：
```
core_color = Color(1, 0.3, 0.1, 1)    # 红橙色
core_radius = 8.0
```

**多层弹体（核心+内核+热点+弹尖）**：
```
core_color = Color(0.72, 0.14, 0.11, 1)
core_width = 36.0
core_height = 36.0
core_radius = 18.0

inner_enabled = true
inner_color = Color(0.91, 0.38, 0.31, 1)
inner_width = 21.0
inner_height = 17.0
inner_offset = Vector2(2, -2)

hotspot_enabled = true
hotspot_color = Color(1, 0.64, 0.53, 1)
hotspot_width = 11.0
hotspot_height = 9.0

nose_enabled = true
nose_color = Color(0.85, 0.27, 0.21, 1)
nose_length = 18.0
nose_width = 5.0
```

**光晕**：
```
glow_radius = 21.0
glow_color = Color(1, 0.44, 0.37, 1)
glow_alpha = 0.48
glow_offset_forward = 0.0    # 正值=朝弹头偏移
```

**自定义纹理**：
```
tex_core_path = "res://assets/textures/vfx/fire_core_64.png"
tex_glow_path = "res://assets/textures/vfx/soft_circle_64.png"
tex_nose_path = ""            # 留空=使用程序化三角
```

**抖动**：
```
jitter_enabled = true
jitter_amplitude = 0.9
jitter_freq_x = 2.3
jitter_freq_y = 2.1
```

#### 2.3 配置拖尾（trail: TrailDef）

创建子 Resource → `TrailDef`，赋值给 `trail` 字段。

TrailDef 持有 4 个可选子配置，按需创建：

**A. 向后散射粒子（ParticleTrailConfig）**：

适合：火焰碎片、冰晶散射、魔法光点

```
enabled = true
count = 20                    # 粒子数量
lifetime = 0.5
back_dist_min = 30.0          # 向后喷射最小距离
back_dist_max = 120.0         # 向后喷射最大距离
radius_min = 0.15             # 粒子最小尺寸
radius_max = 0.9              # 粒子最大尺寸
texture_path = "res://assets/textures/vfx/fire_particle_32.png"  # 自定义纹理
# texture_path = ""           # 留空=白色软圆 + color_ramp 着色
color_1 = Color(1, 0.82, 0.77, 1)   # 生命周期起始色（仅无纹理时生效）
color_2 = Color(1, 0.73, 0.62, 1)   # 生命周期中间色
color_3 = Color(1, 0.91, 0.89, 1)   # 生命周期结束色
```

**B. 向前前缘火焰（FlameTrailConfig）**：

适合：火球头部燃烧、能量前缘

```
enabled = true
count = 12
inner_min = 1.2
outer_max = 14.0
color_1 = Color(1, 0.48, 0.41, 1)
color_2 = Color(0.84, 0.21, 0.17, 1)
texture_path = "res://assets/textures/vfx/fire_particle_16.png"
```

**C. Line2D 实线彗星拖尾（CometTrailConfig）**：

适合：冰箭流光、魔法尾迹、导弹尾烟

```
enabled = true
max_samples = 28              # 拖尾长度
sway_freq = 0.7               # 蛇形摆动频率
sway_amplitude = 1.1          # 蛇形摆动幅度
width_curve = <Curve>         # 可选，留空=默认锥形衰减

# 三层配置（外→内，透明度递增）
outer_width = 6.0
outer_color = Color(0.5, 0.8, 1.0, 1)
outer_alpha = 0.3
mid_width = 3.4
mid_color = Color(0.4, 0.7, 1.0, 1)
mid_alpha = 0.62
inner_width = 1.8
inner_color = Color.WHITE
inner_alpha = 0.96
```

**D. 路径光点（PathDotConfig）**：

适合：毒雾轨迹、奥术印记

```
enabled = true
interval = 0.04               # 生成间隔（秒）
lifetime = 0.3                # 光点存活时间
color = Color(1, 0.8, 0.4, 0.6)
size = 0.25
```

#### 2.4 配置命中视觉（impact: ImpactVisual）

创建子 Resource → `ImpactVisual`，赋值给 `impact` 字段：

**火花爆发**：
```
spark_count_min = 400
spark_count_max = 600
spark_speed_min = 200.0
spark_speed_max = 600.0
spark_life_min = 0.4
spark_life_max = 1.0
spark_color = Color(0.72, 0.14, 0.11, 1)
```

**屏幕震动**：
```
shake_strength = 8.0          # 0 = 不震动
shake_duration = 0.3
```

**VFX 层级池**：
```
tier_A = ""                   # 空=使用全局默认
tier_B = "spark_fire"         # B层使用火焰火花
tier_C = "ring_fire"          # C层使用火焰冲击波
custom_layers = []            # 技能独有效果（高级用法）
```

### Step 3：注册技能

在 `SkillRegistry` 中，技能会在 `_ready()` 时自动加载。确保：
- `skill_defs/my_skill.tres` 的 `skill_id` = "my_skill"
- `skill_visual_defs/my_skill.tres` 的 `skill_id` = "my_skill"
- 两个文件名一致（不含扩展名）

### Step 4：测试

在 SkillDemo 场景中测试技能视觉效果。

---

## 三、常用技能模板

### 3.1 火球术（多层核心 + 火焰纹理 + 散射粒子 + 前缘火焰）

```
body: core=红橙, inner=亮红, hotspot=暖黄, nose=深红, glow=暖红
trail: particles(enabled, fire_particle_32.png) + flame(enabled, fire_particle_16.png)
impact: spark_color=红, tier_B=spark_fire, tier_C=ring_fire
```

### 3.2 冰箭术（细长核心 + 程序纹理着色 + 彗星拖尾）

```
body: core=深蓝, inner=浅蓝, nose=白蓝, glow=蓝, glow2=深蓝
trail: particles(enabled, 无纹理, 蓝色ramp) + comet(enabled, 蓝色三层)
impact: spark_color=蓝, tier_B=spark_magic, tier_C=burst_ice
```

### 3.3 飞弹风暴（小核心 + 暖色彗星）

```
body: core=默认, inner=暖黄, hotspot=默认, glow=橙
trail: particles(enabled, 无纹理, 暖白ramp) + comet(enabled, 暖色三层)
impact: spark_color=暖白
```

---

## 四、着色器预设

### 4.1 内置预设

| 预设名 | 用途 | 参数 |
|--------|------|------|
| `glow_default` | 标准边缘发光 | strength=1.5, radius=8.0 |
| `glow_intense` | 强发光（Ultimate） | strength=2.5, radius=15.0 |
| `glow_subtle` | 微弱发光（普通弹体） | strength=0.8, radius=5.0 |
| `glow_pulsing` | 呼吸脉冲发光 | strength=2.0, pulse=3.0 |

### 4.2 使用预设

在 `ProjectileVisual` 中，通过 `VFXTextureManager` 获取材质：

```gdscript
var tex_manager = VFXTextureManager.get_instance()
var mat = tex_manager.get_material_from_preset(&"glow_intense")
sprite.material = mat
```

### 4.3 创建自定义预设

1. 在 `resources/vfx/shader_presets/` 下创建 `.tres`
2. 选择 `ShaderPreset` 类型
3. 设置 `shader_path` 和参数
4. 预设会自动加载（由 `VFXTextureManager.load_presets_from_dir()`）

---

## 五、美术资源规范

### 5.1 目录结构

```
assets/textures/vfx/
├── particles/     ← 粒子纹理（32×32，带 alpha）
├── cores/         ← 弹体核心纹理（64×64）
├── glows/         ← 光晕纹理（64×64，软边）
└── misc/          ← 其他（弹尖等）
```

### 5.2 命名规范

`{用途}_{变体}_{尺寸}.png`

示例：`fire_particle_32.png`, `ice_crystal_32.png`, `fire_core_64.png`

### 5.3 导入设置

| 类型 | Filter | Mipmaps | Fix Alpha Border |
|------|--------|---------|------------------|
| 粒子纹理 | Linear | Off | On |
| 核心纹理 | Linear | On | Off |
| 光晕纹理 | Linear | Off | Off |

### 5.4 程序化纹理（代码生成，不放文件）

| Key | 用途 | 尺寸 |
|-----|------|------|
| `SOFT_CIRCLE` | 默认粒子/光晕纹理 | 32×32 |
| `CIRCLE` | 硬边圆（核心回退） | 32×32 |
| `NOSE_TRIANGLE` | 弹尖三角 | 32×32 |
| `RAY_STARBURST` | 辐射射线 | 64×64 |

---

## 六、扩展指南

### 6.1 添加新的拖尾类型

1. 创建 `scripts/skill_system/registry/my_trail_config.gd`（继承 Resource）
2. 在 `TrailDef` 中添加 `@export var my_trail: MyTrailConfig`
3. 创建 `scripts/skill_system/pools/components/comp_my_trail.gd`（继承 ProjectileComponent）
4. 在 `ProjectileNode._setup_components()` 中注册

### 6.2 添加新的 VFX 执行器

1. 创建 `scripts/skill_system/vfx/executors/exec_my_effect.gd`（继承 VFXExecutorBase）
2. 在 `SkillVFXManager._register_executors()` 中注册
3. 在 `KIND_MAP` 中添加 kind 映射
