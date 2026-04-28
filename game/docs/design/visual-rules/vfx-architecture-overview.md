# VFX 架构设计 — 特效层级池系统

> 版本: v1.0 | 状态: 实施完成
> 最后更新: 2026-04-28
> 目标: 建立分层、可组合、数据驱动的技能受击特效系统

---

## 一、核心原则

1. **层级池管理** — 特效按层级（Tier）分组，每个层级是一个效果池，技能从各层自由调用
2. **一层一效果** — 一个技能在同一个层级中只能调用一个特效实例，不同层级互不冲突
3. **效果与技能解耦** — 效果做好后注册编号丢到对应层级池中，技能配置时自由挑选，不存在硬绑定
4. **保底缺省** — 每层有全局默认效果，技能未显式配置时自动使用
5. **适用范围** — 本系统管理**可复用的通用受击特效**，技能的独有效果由技能自身负责
6. **独立叠加** — 层级池效果 + 技能自身专属效果互不干扰，同时播放

---

## 二、层级（Tier）定义

### 2.1 当前层级

系统预设 **3 个层级**，后续可根据项目需要扩充：

| 层级 | 别名 | 定位 | 典型效果 |
|---|---|---|---|
| A层 | 小组（Small） | 轻微打击反馈 | 小粒子簇、微闪光 |
| B层 | 中组（Medium） | 标准命中反馈 | 常规粒子爆发、火花 |
| C层 | 大组（Large） | 强力命中反馈 | 大型爆炸、震屏 |

### 2.2 层级池

每个层级含一个效果列表。**效果 ID 使用有意义的英文名称**，而非纯数字编号：

```
A层池（小组）                  B层池（中组）                  C层池（大组）
  ├── spark_tiny                ├── spark_phys                ├── burst_fire
  ├── glint                     ├── spark_magic               └── shake_strong
                                └── spark_fire
```

命名惯例：`{type}_{variant}`，如 `spark_tiny`、`burst_fire`、`shake_strong`。

### 2.3 全局默认配置

定义于 `resources/vfx/vfx_global_config.tres`：

```
tier_defaults = {
    "A": "spark_tiny",    # A层默认 → 微粒子星爆
    "B": "spark_phys",    # B层默认 → 标准物理火花
    "C": "",              # C层默认 → 不调用
}
```

技能未显式配置某层时自动应用全局默认。可层层设、部分设、全部不设。

---

## 三、效果即 Layer

### 3.1 Layer 类型

每个已注册的特效是一个 **VFXLayerDef**，原子级视觉表现单元：

| kind | 作用 | 实现状态 | 关键参数 |
|---|---|---|---|
| `particle_burst` | Sprite2D 精灵径向爆发 | ✅ 已实现 | count, speed_min, speed_max, size_min, size_max, color, lifetime |
| `sprite_burst` | 带纹理的精灵飞出 | 🔧 预留 | — |
| `screen_shake` | 相机震动 | ✅ 已实现 | strength, duration |
| `flash` | 命中点闪白/闪色 | ✅ 已实现 | color, duration, radius |
| `ring` | 扩散环 | 🔧 预留 | — |

### 3.2 组合规则

一个技能命中时的完整受击效果按以下规则组合：

1. VFXManager 接收到 `skill_hit` 信号
2. 检查技能 VisualDef 是否接入了层级池（至少一个 `hit_vfx_tier_*` 非空）
3. 未接入 → VFXManager **跳过**，不影响技能（如 missile_storm）
4. 已接入 → 遍历 A/B/C 三层：
   - 技能显式指定 → 使用指定效果
   - 未指定 → 使用全局默认
5. 执行 `custom_hit_layers`（技能独有 Layer）
6. 所有层**同时触发、同时播放**，互不等待
7. 技能自有 `_spawn_explosion()` 独立并行执行

---

## 四、适用范围

| 技能/效果类型 | 走层级池？ | 说明 |
|---|---|---|
| 弹道技能命中 | ✅ 可选接入 | 接入则获层级效果 + 自有爆炸可叠加（如 fireball） |
| 弹道技能命中（自处理） | ❌ 跳过 | 自有爆炸已足够，VFXManager 不干预（如 missile_storm） |
| AOE 地面爆炸命中 | ✅ 可接入 | 对每个受击单位触发层级池效果 |
| 陷阱爆炸命中 | ✅ 可接入 | 对每个受击单位触发层级池效果 |
| 近战普攻击中 | ✅ 可接入 | 走层级池效果 |
| Buff / Debuff 施加 | ❌ | 不在此系统范围内 |
| 技能自身独有效果 | ❌ | 由技能自身的 `_spawn_explosion` 或 `custom_hit_layers` 处理 |

---

## 五、数据定义

### 5.1 VFXGlobalConfig — 全局 VFX 配置

```gdscript
class_name VFXGlobalConfig
extends Resource

@export var tier_defaults: Dictionary = {
    "A": "spark_tiny",
    "B": "spark_phys",
    "C": "",
}
```

文件：`resources/vfx/vfx_global_config.tres`

### 5.2 VFXLayerDef — 单层效果定义

```gdscript
class_name VFXLayerDef
extends Resource

@export var effect_id: String = ""               # 层内唯一 ID，如 "spark_tiny"
@export var kind: int = 0                       # 0=particle_burst, 1=sprite_burst, 2=screen_shake, 3=flash, 4=ring
@export var params: Dictionary = {}             # 类型特定参数
```

文件：`resources/vfx/layers/{tier}_{id}.tres`，如 `A_spark_tiny.tres`

### 5.3 VFXTierDef — 层级池定义

```gdscript
class_name VFXTierDef
extends Resource

@export var tier_id: String = ""
@export var display_name: String = ""
@export var effects: Array[Resource] = []       # Array[VFXLayerDef]
```

文件：`resources/vfx/tiers/tier_{id}.tres`，如 `tier_A.tres`

### 5.4 VFXTierRegistry — 运行时注册表

```gdscript
class_name VFXTierRegistry
extends Node

func initialize() -> void                        # 加载 config + tiers
func resolve(tier_id, effect_id) -> VFXLayerDef  # 查询层级池中的效果
func get_default(tier_id) -> VFXLayerDef         # 获取层级默认效果
func get_tier_effects(tier_id) -> Array[VFXLayerDef]
func get_tier_ids() -> Array[String]
```

文件：`scripts/skill_system/vfx/vfx_tier_registry.gd`

### 5.5 SkillVisualDef 扩展

```gdscript
# VFX 层级池配置（空字符串 = 使用全局默认）
@export var hit_vfx_tier_A: String = ""
@export var hit_vfx_tier_B: String = ""
@export var hit_vfx_tier_C: String = ""

# 技能自定义 Layer（不走层级池，技能独有效果）
@export var custom_hit_layers: Array[Resource] = []
```

---

## 六、运行时架构

### 6.1 组件

```
VFXManager（skill_vfx_manager.gd）
  ├── VFXTierRegistry（子节点）
  │   ├── 加载所有 resources/vfx/tiers/ 下的 VFXTierDef
  │   ├── 读取 vfx_global_config.tres
  │   ├── resolve(tier_id, effect_id) → VFXLayerDef
  │   └── get_default(tier_id) → VFXLayerDef | null
  │
  └── VFXExecutor（内部函数）
      ├── execute_layers(layers[], world_pos)
      ├── _exec_particle_burst(params, pos)    ✅
      ├── _exec_sprite_burst(params, pos)       🔧
      ├── _exec_screen_shake(params)            ✅
      ├── _exec_flash(params, pos)              ✅
      └── _exec_ring(params, pos)               🔧
```

### 6.2 命中事件流程

```
命中发生
  ↓
ProjectileNode._on_chain_hit() 或其他命中触发器
  ├── _chain.on_hit(target)
  ├── [技能自有] _spawn_explosion()  ← 独立执行
  └── skill_hit 信号 → VFXManager
                          ↓
                  VFXManager._on_skill_hit(info)
                    │
                    ├── 读取 skill_id → 查询 SkillVisualDef
                    ├── 检查技能是否接入了层级池
                    │     └── 未接入 → 跳过（如 missile_storm）
                    ├── 遍历 A/B/C 三层:
                    │     ├── 技能有显式指定？→ resolve(tier, effect_id)
                    │     ├── 未指定但全局有默认？→ get_default(tier)
                    │     └── 否则跳过本层
                    ├── 合并 custom_hit_layers
                    └── VFXExecutor.execute_layers(layers, hit_pos)
```

### 6.3 VFXExecutor 实现说明

- `particle_burst` 使用 Sprite2D + Tween，非 GPUParticles2D/CPUParticles2D
- 精灵是程序化白圆纹理，直接添加到场景根节点，Tween 驱动位置/透明度动画
- 无对象池（当前规模下创建开销可忽略）
- `screen_shake` 通过 `get_viewport().get_camera_2d().add_trauma()` 实现

---

## 七、VFX 资源目录

```
resources/vfx/
├── vfx_global_config.tres          ← 全局默认配置
├── tiers/                          ← VFXTierDef 层级池
│   ├── tier_A.tres
│   ├── tier_B.tres
│   └── tier_C.tres
├── layers/                         ← VFXLayerDef 单层效果
│   ├── A_spark_tiny.tres
│   ├── A_glint.tres
│   ├── B_spark_phys.tres
│   ├── B_spark_magic.tres
│   ├── B_spark_fire.tres
│   ├── C_burst_fire.tres
│   └── C_shake_strong.tres
└── textures/                       ← VFX 专用纹理（预留）
```

---

## 八、已有技能接入状态

| 技能 | 层级池接入 | 自有爆炸 | 说明 |
|---|---|---|---|
| missile_storm | ❌ 未接入 | ✅ `_spawn_explosion()` | 自有特效足够，VFXManager 跳过 |
| fireball_basic | ✅ 已接入 | ❌ 无 | B层→spark_fire, C层→burst_fire |

接入规则：
- 技能在 `SkillVisualDef` 中设置至少一个 `hit_vfx_tier_*` 为非空 → 接入层级池
- 所有 `hit_vfx_tier_*` 为空且 `custom_hit_layers` 为空 → 不接入，VFXManager 跳过

---

## 九、实施记录

| Phase | 内容 | 状态 |
|---|---|---|
| 1 | VFXLayerDef、VFXTierDef、VFXGlobalConfig、VFXTierRegistry | ✅ 已完成 |
| 2 | VFXManager 重构为层级池系统，移除硬编码 CPUParticles2D | ✅ 已完成 |
| 3 | 初始效果库（7 个 VFXLayerDef）注册到三层 | ✅ 已完成 |
| 4 | SkillVisualDef 新增 tier 配置字段 | ✅ 已完成 |
| 5 | 已有技能接入（fireball, missile_storm） | ✅ 已完成 |
| 6 | 持续扩充层级池效果库 | 📋 待办 |

---

## 十、注意事项与陷阱

1. **class_name 注册** — 新增 `class_name` Resource/Node 子类后，必须触发编辑器文件系统扫描（`ei.get_resource_filesystem().scan()`）才能被其他脚本识别
2. **全局脚本缓存** — `.godot/global_script_class_cache.cfg` 需要包含新的 `class_name`，否则编译时报 "Could not find type"；必要时可删除该文件让编辑器重新生成
3. **粒子替代方案** — 使用 Sprite2D + Tween 而非 GPUParticles2D/CPUParticles2D，避免了 Godot 4 粒子系统方向向量零值时的未定义行为（`direction = Vector3(0,0,0)` 会被 GPU 归一化为 `(1,0,0)`，导致所有粒子向右喷射）
4. **缩进一致性** — `.gd` 文件内 `@export` 字段的缩进必须全局一致，不可混用 0 tab 和 1 tab，否则 Godot 解析器报 "Unexpected Indent in class body"
