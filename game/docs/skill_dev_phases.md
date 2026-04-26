# 技能开发阶段规范

> 文档版本：v1.0（2026-04-23）
> 维护者：开发团队

---

## 核心理念

做游戏一定要一步一步来。技能系统的建设分为明确的阶段，每个阶段有清晰的交付目标。

---

## 当前阶段：基础原型技能库

### 目标

实现一批经典的、**单体逻辑完整、视觉效果到位**的原型技能，放入技能库。

### 交付标准

每个技能必须满足：
- ✅ 战斗属性完整（伤害、冷却、范围、预警时间等）
- ✅ 视觉效果符合预期（投射物、运动轨迹、命中表现）
- ✅ 技能逻辑独立闭环（从施法到命中的完整流程）
- ✅ **与释放主体无关**（任何单位都可使用）

### 禁止事项

- ❌ 任何 Modifier/变形/组合效果（放到下一阶段）
- ❌ 技能名称中出现具体角色/单位名称
- ❌ 跳过基础阶段直接做技能变形

### 目标技能清单（参考）

| 序号 | 技能名称 | 类型 | 核心机制 |
|------|----------|------|----------|
| 1 | 火球术 | 投射物 | 单体伤害 + 爆炸AOE |
| 2 | 闪电链 | 连锁弹射 | 弹射至附近目标 |
| 3 | 子弹风暴 |弹幕 | 多发投射物连续发射 |
| 4 | 冰霜新星 | 区域 | 中心向周围扩散 |
| 5 | 暗影之刺 | 投射物 | 追踪目标 |
| 6 | 治疗光环 | 增益 | 范围治疗 |

---

## 下一阶段：Modifier 变形系统

在基础技能库（≥5个）完成后开启。

### 目标

- 引入 Modifier 效果（弹射、散射、分裂、膨胀、曲线路径等）
- 参考 POE / 流星蝴蝶剑 等游戏的技能变形风格
- 同一基础技能 + 不同 Modifier = 变体技能

### Modifier 清单（待启用）

| Modifier ID | 效果 |
|-------------|------|
| Scatter | 散射（单发变多发扇形） |
| Bounce | 弹射（命中后弹向附近目标） |
| Fission | 分裂（飞行一段后分裂） |
| Expansion | 膨胀（飞行中逐渐扩大） |
| CurvedPath | 曲线路径（弧线飞行） |
| ProjectileHP | 投射物生命值 |
| ConditionalSuppress | 条件抑制 |
| ColorShift | 颜色变换 |

> 当前 `ModifierProcessor` 和 `ModifierRegistry` 代码框架已就绪，但 `base_modifier_ids` 全部为空，Modifier 系统尚未启用。

---

## 核心设计原则

### 技能与释放主体无关

```
❌ 错误示例
- "玩家A的火球术"
- "敌人的闪电链"
- "Boss专属技能"

✅ 正确示例
- "火球术"（任何单位可释放）
- "闪电链"（任何单位可释放）
- "子弹风暴"（任何单位可释放）
```

**原因**：
- 技能是游戏世界的通用能力，不是某个角色的私有财产
- 同一技能可以被玩家、敌人、NPC 共同使用
- 技能池是共享资源，便于管理和扩展

### 技能分类

| 分类维度 | 类别 |
|---------|------|
| **技能类别** | BASIC / SMALL_A / SMALL_B / MEDIUM / ULTIMATE |
| **伤害类型** | PHYSICAL / FIRE / ICE / LIGHTNING / DARK / HEAL |
| **效果类型** | emit_projectile / area_damage / apply_status / emit_burst |
| **目标类型** | SINGLE / MULTI / SELF / AREA |

---

## 技能定义规范

每个技能由两个资源文件组成：

```
resources/skills/
├── skill_defs/
│   └── {skill_id}.tres      # 战斗属性（伤害、冷却、范围等）
└── skill_visual_defs/
    └── {skill_id}.tres      # 视觉属性（颜色、大小、轨迹等）
```

**命名规范**：`{theme}_{variant}.tres`
- `fireball_basic.tres`（火球术·基础）
- `fireball_explosive.tres`（火球术·爆炸）
- `lightning_chain.tres`（闪电链）
- `bullet_storm.tres`（子弹风暴）

---

## 开发工作流

```
1. 设计 → 确定技能机制、属性数值、视觉方案
2. 编写 skill_def.tres → 战斗属性
3. 编写 skill_visual_def.tres → 视觉属性
4. 在 skill_test.tscn 中调试 → 验证逻辑和视觉
5. 提交到技能库 → 完成
```

---

## 状态记录

- 阶段一启动时间：2026-04-23
- 当前技能库：fireball_basic, ember_basic, ember_small_a, ironwall_basic, ironwall_small_a, moss_basic, moss_small_a
- Modifier 系统：框架就绪，尚未启用
- 视觉系统：已完成 Sprite2D + GPUParticles2D 重构，支持程序化纹理
- 技术踩坑：详见 `docs/skill_tech_pitfalls.md`

---

## 今日里程碑（2026-04-23）

### 完成的修复

1. **GPUParticles2D 粒子系统重构**
   - 将粒子属性配置迁移到 ParticleProcessMaterial
   - 支持拖尾粒子和爆炸粒子效果

2. **SkillVisualDef 继承体系整理**
   - 消除基类/子类字段重复
   - 统一视觉参数体系

3. **调试器动态化**
   - 技能列表从 SkillRegistry 动态加载
   - 新增技能自动出现在调试器中

### 技术债务

- ⚠️ 调试器在连续施放技能时可能卡死（_input 中 await 问题）
- ⚠️ 程序化纹理生成流程待优化

### 明天的工作

- 继续完善火球术视觉效果（火焰粒子拖尾）
- 添加更多基础原型技能
- 优化粒子效果参数
