# 火球术 — 技能设计文档

---

## 元数据

```
Status: Implemented
Version: v2.0
Owner: Art + Design
Last Updated: 2026-04-27
Skill ID: fireball_basic
Plugin API: HasturOperationGD (remote GDScript execution)
Related: docs/design/visual-rules/pixel-art-visual-bible.md
```

---

## 1. 基本信息

| 字段 | 值 |
|------|-----|
| 技能 ID | `fireball_basic` |
| 显示名称 | 火球术 |
| 技能类型 | `proj` 发射类 |
| 伤害类型 | 火焰元素 |
| 基础伤害 | 42.0（可由 CSV 覆盖） |
| 冷却时间 | 2.8 秒 |
| 施法距离 | 400 px |
| 飞行速度 | 225 px/s |
| 设计优先级 | `P0`（已完成） |
| 设计状态 | `已实现` |

> **数值配置说明**：
> 所有战斗数值（伤害、冷却、施法距离等）已分离到 CSV 表格：
> `docs/design/combat-rules/values/skill-values.csv`
> 查找方式：在 CSV 中过滤 `category == "fireball_basic"`

---

## 2. 视觉设计

### 2.1 施法前摇（Wind-up）

- **持续时间**：0.42 秒（telegraph_ms = 420）
- **视觉效果**：
  - 施法者身上简短的火焰聚集光效（待实现）
  - 地面出现矩形警示区域（rect telegraph）
- **镜头效果**：无震屏（默认关闭）

---

### 2.2 发射 / 飞行阶段

- **描述**：火球以 225 px/s 沿直线飞向目标，带有抖动效果、拖尾粒子和前缘火焰粒子
- **飞行速度**：225 px/s（视觉定义 `speed` 字段）
- **飞行轨迹**：直线（LINEAR）
- **命中检测**：命中判定半径为中层区域（核心视觉半宽 × 1.5 + 10px），约 37px
- **视觉效果**：
  - **弹体核心（5 层 Sprite2D 结构）**：

    ```
    渲染顺序（从底到顶）         尺寸         颜色
    ┌─ 摩擦光晕 (Glow)          r=21px     #ff6f5f α0.48
    ├─ 核心 (Core)              36×36px    #b8231b
    ├─ 内核 (Inner)             21×17px    #e8624e 偏移(+2,-2)
    ├─ 热点 (Hotspot)           11×9px     #ffa487 偏移(-4,+3)
    └─ 弹尖 (Nose)              L18×W5    #d94435
    ```

  - **核心抖动**：振幅 0.9px，频率 X=2.3, Y=2.1（sin 函数驱动）
  - **弹尖朝向**：跟随飞行方向旋转
  - **程序化纹理**：共享静态 ImageTexture（16×16 白圆 + 16×16 三角）
  - **纹理覆盖**：火球使用 `fire_core_64.png`（弹体）、`soft_circle_64.png`（光晕）

  - **拖尾粒子**（GPUParticles2D）：
    - 发射数量：**20 个/次**（`amount = count × 4 = 80`）
    - 粒子寿命：**0.5 秒**
    - 粒子纹理：`fire_particle_32.png`
    - 缩放范围：**0.15 ~ 0.9**（纹理 32px 基准，实际 4.8 ~ 28.8 px）
    - 向后速度：30 ~ 120 px/s
    - 横向扩散：28 ~ 46°
    - **缩放曲线（关键特性）**：粒子随生命周期缩小
      ```
      寿命 0%  → 100% 大小
      寿命 15% → 95%  大小  ← 刚离开火球时保持较大
      寿命 35% → 70%  大小
      寿命 60% → 30%  大小
      寿命 100%→ 0%   大小  ← 尾部稀疏消失
      ```
    - 粒子颜色：`#ffd2c4`, `#ffba9f`, `#ffe9e3`
    - 尾部粒子**没有内核/热点等层级结构**，仅为弥散火焰粒子

  - **前缘火焰粒子**（GPUParticles2D）：
    - 弧形采样数：12
    - 内层径向速度：1.2 ~ 5.5 px/s
    - 外层径向速度：5.5 ~ 14.0 px/s
    - 缩放范围：0.2 ~ 0.6
    - 纹理：`fire_particle_16.png`
    - 颜色：`#ff7b69`, `#d5362c`
    - 寿命：100 ~ 195 ms

- **尺寸**：核心 36×36 px

---

### 2.3 命中 / 爆发阶段

- **描述**：火球命中目标后，**300ms 内弹体淡出**并触发**双层爆炸效果**
- **爆发半径**：约 37px（命中检测范围）
- **弹体淡出**：5 层 Sprite2D 同步透明度归零（`tween_property modulate:a → 0`）

#### 爆炸层 1：高速火花（打击力量感）

- **粒子数量**：**160 ~ 240 个**
- **扩散速度**：**350 ~ 800 px/s**
- **扩散角度**：**252°**（spread，非全方向，保证击中感）
- **粒子纹理**：`spark_16.png`
- **缩放范围**：0.3 ~ 1.0
- **角速度翻滚**：-300 ~ 300°/s（不规则翻滚）
- **粒子寿命**：250 ~ 600 ms
- **颜色**：**火红色 `#b8231b`**（与弹体核心一致）
- **发射窗口**：explosiveness = 0.6（较长喷射时间，非瞬间爆发）
- **缩放曲线**：先膨胀后缩小
  ```
  寿命 0%  → 40% 大小
  寿命 15% → 100% 大小 ← 爆发峰值
  寿命 50% → 60% 大小
  寿命 100%→ 0%  大小
  ```

#### 爆炸层 2：火焰碎片（绽放火焰效果）

- **粒子数量**：火花的 ~50%（约 80 ~ 120 个）
- **扩散速度**：火花的 20%~30%（**70 ~ 240 px/s**，与高速火花形成速度错落）
- **粒子纹理**：`fire_particle_16.png`（火焰纹理，非火花纹理）
- **缩放范围**：**0.8 ~ 2.5**（比火花大，视觉上像火焰瓣）
- **粒子寿命**：火花寿命 × 1.5（375 ~ 900 ms）
- **颜色**：橙红色变体（R×1.2, G×0.6, B×0.2）
- **发射窗口**：explosiveness = 0.4（更分散的飘散）
- **缩放曲线**：绽放型
  ```
  寿命 0%  → 20% 大小
  寿命 10% → 100% 大小 ← 快速绽放
  寿命 40% → 80% 大小
  寿命 100%→ 0%  大小
  ```

- **重力**：火花轻微下落（50 px/s²），火焰碎片更缓（30 px/s²）
- **镜头效果**：无震屏（默认关闭）

---

### 2.4 持续效果阶段

- **描述**：无持续效果（非DOT技能）
- **持续时间**：N/A

---

### 2.5 收尾 / 淡出

- **描述**：爆炸粒子自然淡出 + 弹体 300ms 淡出
- **弹体淡出时间**：**300 ms**（5 层 Sprite2D 同步）
- **火花粒子寿命**：250 ~ 600 ms
- **火焰碎片寿命**：375 ~ 900 ms
- **总回收时间**：粒子寿命 × 2.0 后自动 `queue_free`

---

## 3. 可读性约束

> 参考 `pixel-art-visual-bible.md` 第6节 VFX Priority vs Readability

- [x] 不遮挡敌方警戒范围 telegraph
- [x] 不遮挡玩家单位轮廓
- [ ] 爆发效果持续时间 ≤ 0.22 秒（当前 250-600ms，需评估）
- [ ] 拖尾粒子透明度上限：≤ 0.5
- [x] 色相与敌对/友方语义锚点不冲突（使用红/橙色系）

---

## 4. 参数配置

### 4.1 粒子系统参数

#### 弹体核心（5 层 Sprite2D）

| 参数 | 值 | 说明 |
|------|-----|------|
| core_width | 36 | 像素 |
| core_height | 36 | 像素 |
| core_color | `#b8231b` | 深红 |
| core_radius | 18.0 | 命中检测基准 |
| core_inner_enabled | true | |
| inner_width | 21 | 像素 |
| inner_height | 17 | 像素 |
| inner_color | `#e8624e` | 亮红 |
| inner_offset_x | 2 | 像素 |
| inner_offset_y | -2 | 像素 |
| hotspot_enabled | true | |
| hotspot_width | 11 | 像素 |
| hotspot_height | 9 | 像素 |
| hotspot_color | `#ffa487` | 橙白 |
| nose_enabled | true | |
| nose_length | 18 | 像素 |
| nose_width | 5 | 像素 |
| nose_color | `#d94435` | 暗红 |
| glow_radius | 21 | 像素 |
| glow_color | `#ff6f5f` | 粉橙 |
| glow_alpha | 0.48 | |
| jitter_enabled | true | |
| jitter_amplitude | 0.9 | px |
| jitter_freq_x | 2.3 | Hz |
| jitter_freq_y | 2.1 | Hz |

#### 纹理映射

| 用途 | 纹理路径 | 回退策略 |
|------|---------|---------|
| 弹体核心 | `fire_core_64.png` | 程序化白圆 16×16 |
| 光晕 | `soft_circle_64.png` | 复用核心纹理 |
| 拖尾粒子 | `fire_particle_32.png` | 复用核心纹理 |
| 前缘火焰 | `fire_particle_16.png` | 复用核心纹理 |
| 爆炸火花 | `spark_16.png` | 复用核心纹理 |
| 弹尖 | 无 | 程序化三角 16×16 |

#### 拖尾粒子

| 参数 | 值 | 说明 |
|------|-----|------|
| enabled | true | |
| particle_count | 20 | amount = count × 4 = 80 |
| lifetime | 0.5 | 秒 |
| scale_curve | 1.0→0.95→0.7→0.3→0.0 | 见 2.2 节曲线 |
| radius_min | 0.15 | 纹理缩放基准（32px）→ 4.8px |
| radius_max | 0.9 | → 28.8px |
| back_dist_min | 30 | px/s |
| back_dist_max | 120 | px/s |
| spread_min | 28 | 度 |
| spread_max | 46 | 度 |
| colors | `#ffd2c4`, `#ffba9f`, `#ffe9e3` | 浅橙白 |
| texture | `fire_particle_32.png` | |

#### 前缘火焰粒子

| 参数 | 值 | 说明 |
|------|-----|------|
| enabled | true | |
| arc_samples | 12 | |
| inner_min | 1.2 | px/s |
| inner_max | 5.5 | px/s |
| outer_min | 5.5 | px/s |
| outer_max | 14.0 | px/s |
| scale_min | 0.2 | |
| scale_max | 0.6 | |
| colors | `#ff7b69`, `#d5362c` | |
| life_min | 100 | ms |
| life_max | 195 | ms |
| texture | `fire_particle_16.png` | |

#### 命中爆发 — 高速火花层

| 参数 | 值 | 说明 |
|------|-----|------|
| spark_count_min | 160 | |
| spark_count_max | 240 | |
| speed_min | 350 | px/s |
| speed_max | 800 | px/s |
| spread | 252° | 比全方向集中 30% |
| life_min | 250 | ms |
| life_max | 600 | ms |
| scale_min | 0.3 | |
| scale_max | 1.0 | |
| scale_curve | 0.4→1.0→0.6→0.0 | 先膨胀后缩小 |
| angular_velocity | -300 ~ 300 | °/s |
| color | `#b8231b` | 与弹体一致 |
| texture | `spark_16.png` | |

#### 命中爆发 — 火焰碎片层

| 参数 | 值 | 说明 |
|------|-----|------|
| count | 火花的 50% | 约 80~120 |
| speed_min | 70 | px/s（火花的 20%） |
| speed_max | 240 | px/s（火花的 30%） |
| spread | 360° | 全方向飘散 |
| life | 火花 × 1.5 | 375~900 ms |
| scale_min | 0.8 | 比火花大 |
| scale_max | 2.5 | |
| scale_curve | 0.2→1.0→0.8→0.0 | 绽放型 |
| angular_velocity | -100 ~ 100 | °/s |
| color | R×1.2, G×0.6, B×0.2 | 橙红变体 |
| texture | `fire_particle_16.png` | 火焰纹理 |
| gravity | 30 px/s² | 缓下落 |

---

### 4.2 动画参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 施法前摇时长 | 0.42 | s |
| 飞行速度 | 225 | px/s（视觉定义控制） |
| 命中触半径 | 核心半宽 × 1.5 + 10px | 约 37px |
| 弹体淡出时长 | 0.3 | s（Tween 驱动） |
| 爆炸火花寿命 | 0.25 ~ 0.6 | s |
| 火焰碎片寿命 | 0.375 ~ 0.9 | s |
| 震屏 | 无 | 默认关闭 |

---

### 4.3 颜色方案

| 用途 | 颜色（Hex） | 说明 |
|------|------------|------|
| 核心色 | `#b8231b` | 深红 |
| 内核色 | `#e8624e` | 亮红 |
| 热点色 | `#ffa487` | 橙白 |
| 弹尖色 | `#d94435` | 暗红 |
| 光晕色 | `#ff6f5f` | 粉橙 |
| 拖尾色 | `#ffd2c4` | 浅橙 |
| 爆炸火花色 | `#b8231b` | 与核心同色 |
| 火焰碎片色 | R×1.2/G×0.6/B×0.2 | 橙红变体 |

---

## 5. 实现映射

| 资源类型 | 路径 | 说明 |
|---------|------|------|
| SkillDef | `res://resources/skills/skill_defs/fireball_basic.tres` | 战斗数值定义 |
| SkillVisualDef | `res://resources/skills/skill_visual_defs/fireball_basic.tres` | 视觉参数定义 |
| VFX 场景 | `res://scenes/skills/vfx/fireball_basic_vfx.tscn` | 骨架（视觉由代码生成） |
| 投射物运行时 | `res://scripts/skill_system/pools/projectile_node.gd` | ProjectileNode v2.0 |
| 技能执行器 | `res://scripts/skill_system/core/skill_executor.gd` | 技能施法执行 |
| 技能注册中心 | `res://scripts/skill_system/registry/skill_registry.gd` | 全局注册 + CSV 自动加载 |

---

## 6. 验证记录

### 验证 Checklist

- [x] 技能可正常从 SkillRegistry 加载
- [ ] 施法前摇视觉符合设计（矩形警示区—待实现）
- [x] 飞行弹体有抖动效果
- [x] 拖尾粒子正常发射（含 scale_curve 衰减）
- [x] 前缘火焰粒子正常发射
- [x] 命中爆炸有双层效果（高速火花 + 火焰碎片）
- [x] 弹体 300ms 淡出
- [x] 颜色方案符合调色板约束（深红/亮红/橙红色系）
- [ ] 不遮挡单位轮廓和 telegraph
- [ ] 在 0.5× / 1× / 2× 速度下表现正常
- [ ] 循环播放无异常

### 迭代历史

| 日期 | 版本 | 修改内容 | 验证结果 |
|------|------|---------|---------|
| 2026-04-27 | v1.0 | 从旧项目 TypeScript 代码翻译需求 | 草稿 |
| 2026-04-27 | v2.0 | 实现 5 层弹体、抖动、前缘火焰、增强拖尾、CSV 加载 | 代码完成，视觉待观察 |
| 2026-04-27 | v2.1 | 修复 CompressedTexture2D 类型错误；拖尾粒子 scale_curve 衰减；命中检测放大到中层；弹体 300ms 淡出；双层爆炸（火花+火焰碎片）；移除震屏；飞行速度降至 225 | 已实现，对应本文件 |

---

*本文档反映 Godot 项目中 fireball_basic 的实际实现状态。*
*实现语言：GDScript（Godot 4.6.2）*
