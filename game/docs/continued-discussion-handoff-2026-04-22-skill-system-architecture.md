# 会话交接文档：技能系统架构讨论
**Date:** 2026-04-22
**Participants:** Engineering + Design
**Scope:** 技能系统整体架构讨论 + Modifier 系统设计

---

## 1. 本次会话做了什么

### 1.1 文档落档
- `docs/tech/architecture/godot-skill-system-node-architecture.md` — 技术架构文档 v1.0
- `docs/design/feature-systems/skill-modifier-system-v1.md` — Modifier 设计文档 v1.0
- `docs/continued-discussion-handoff-2026-04-22-skill-system-architecture.md` — 本文件

### 1.2 SkillSystem 场景骨架（核心完成）
完整的 `skill_system.tscn` 场景及全部脚本已创建：

```
scripts/skill_system/
├── skill_root.gd                          ← 场景根，cast_skill() 入口
├── core/
│   ├── skill_effect.gd                    ← Effect 基类 + ExecutionContext
│   ├── execution_chain.gd                 ← 执行链状态载体
│   ├── skill_modifier.gd                  ← Modifier 基类
│   ├── condition_evaluator.gd            ← 条件评估器
│   ├── skill_executor.gd                  ← 施法执行器
│   ├── damage_resolver.gd                 ← 伤害结算
│   ├── modifier_processor.gd              ← Modifier 执行引擎
│   ├── skill_visual_def_default.gd        ← 视觉数据默认实现
│   ├── effects/
│   │   ├── emit_projectile.gd             ← 发射抛射物
│   │   ├── area_damage.gd                 ← 区域伤害
│   │   ├── apply_status.gd                ← 施加状态
│   │   └── emit_burst.gd                  ← 爆发效果
│   └── modifiers/
│       ├── scatter.gd                     ← 散射
│       ├── bounce.gd                      ← 弹射
│       ├── fission.gd                      ← 分裂
│       ├── curved_path.gd                 ← 曲线路径
│       ├── expansion.gd                   ← 膨胀
│       ├── projectile_hp.gd               ← 抛射物HP
│       ├── conditional_suppress.gd        ← 条件压制
│       └── color_shift.gd                 ← 色彩偏移
├── registry/
│   ├── skill_registry.gd                 ← 技能注册表
│   ├── modifier_registry.gd               ← Modifier 注册表
│   └── skill_def_default.gd               ← 内联默认 SkillDef
├── pools/
│   ├── projectile_pool.gd                 ← 投射物对象池
│   ├── projectile_node.gd                 ← 投射物运行时节点
│   └── executor_pool.gd                   ← 执行器对象池
├── vfx/
│   └── skill_vfx_manager.gd               ← VFX 总控
└── signal_bus/
    └── skill_signal_bus.gd                 ← 信号总线

scenes/skill_system/
├── skill_system.tscn                      ← 技能系统场景
├── skill_test.tscn                        ← 独立调试场景
└── nodes/
    ├── projectile.tscn
    └── executor.tscn

resources/skills/
├── skill_defs/                            ← 技能数据
│   ├── ironwall_basic.tres
│   ├── ironwall_small_a.tres
│   ├── ember_basic.tres
│   ├── ember_small_a.tres
│   ├── moss_basic.tres
│   └── moss_small_a.tres
├── skill_visual_defs/
│   └── ironwall_basic_vfx.tres
└── modifiers/
    └── scatter.tres
```

---

## 2. 已落档的文档

| 文档路径 | 内容 |
|---------|------|
| `docs/tech/architecture/godot-skill-system-node-architecture.md` | 技术架构文档 v1.0 |
| `docs/design/feature-systems/skill-modifier-system-v1.md` | Modifier 设计文档 v1.0 |
| 本文件 | 会话交接文档 |

---

## 3. 下一步工作

### 立即执行：构建 SkillSystem 场景骨架

按 `godot-skill-system-node-architecture.md` §2 的节点树开始：

**Phase 1：核心类实现**
```
scripts/skill_system/
├── skill_root.gd                        ← 场景根
├── skill_effect.gd                      ← Effect 基类
├── execution_chain.gd                   ← 执行链（状态载体）
├── skill_modifier.gd                    ← Modifier 基类
├── modifier_processor.gd                ← 执行引擎
├── skill_registry.gd                    ← 技能注册表
├── modifier_registry.gd                 ← Modifier 注册表
├── skill_signal_bus.gd                  ← 信号总线
├── skill_executor.gd                    ← 施法执行器
├── damage_resolver.gd                   ← 伤害结算
└── pool_manager.gd                      ← 对象池基类
```

**Phase 2：Modifier 子类实现（第一批）**
- `ScatterModifier`
- `BounceModifier`
- `FissionModifier`
- `CurvedPathModifier`
- `ExpansionModifier`
- `ConditionalSuppressModifier`

**Phase 3：Projectile 系统**
- `projectile_pool.gd`
- `projectile_node.gd`
- `skill_vfx_manager.gd`

**Phase 4：数据资源**
- `resources/skills/skill_defs/` — 技能数据 .tres
- `resources/skills/modifiers/` — Modifier 数据 .tres
- `resources/skills/skill_visual_defs/` — 视觉参数 .tres

### Phase 2：技能实例验证

第一个技能 `ironwall_basic`（直线机械子弹）：
- 实现 `EmitProjectileEffect`
- 实现 `LinearTrajectory`（无 Modifier 时的默认轨迹）
- 接入 ProjectilePool
- 在 SkillViewer 中手动触发验证

---

## 4. 悬而未决的议题

| 议题 | 状态 | 说明 |
|------|------|------|
| AuraManager 子系统 | 待实现 | `conditional_suppress` 和 `aura_amplify` 依赖此子系统 |
| ConditionEvaluator | 待实现 | 所有条件标签的评估器，后续扩展 |
| SkillVisualDef 和 VFX 资源 | 待设计 | 投射物美术数据（颜色/粒子/ribbon配置）|
| Passive Skill 系统 | 待讨论 | Hero Skill Template v1 中的 3 个被动槽位 |
| 对象池的预创建数量 | 待定 | 根据实际使用场景配置 |
| ChainIdGenerator | 待实现 | 全局唯一 ID 生成器 |

---

## 5. 关键设计决策备忘

1. **Modifier 不改 Effect，只改执行参数或插入分支**
2. **Modifier 顺序决定结果**（Scatter→Bounce ≠ Bounce→Scatter）
3. **ConditionEvaluator 统一处理所有激活条件**
4. **.tres 资源文件是所有配置的唯一来源，代码只实现逻辑**
5. **SkillSignalBus 是所有模块间通信的唯一通道**
6. **ProjectilePool 是 Node2D，在世界坐标系中与 Unit 同空间**
7. **竞技场是 SkillSystem 的消费者，不是拥有者**

---

**Next session should:** 读取 `godot-skill-system-node-architecture.md` 和 `skill-modifier-system-v1.md` 继续从 Phase 1 开始实现。
