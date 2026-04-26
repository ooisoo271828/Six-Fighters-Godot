# 技能系统重构 — 2026-04-15 交接文档

**状态:** 完成（Step 1–8 全部通过）
**Date:** 2026-04-15
**Related:** `docs/tech/architecture/skill-system-architecture-2026-04-15.md`

---

## 1. 今日完成范围

本次是技能系统数据驱动重构的**全部落地**，覆盖以下步骤：

| Step | 内容 | 文件变更 |
|------|------|---------|
| 1 | types.ts 类型定义扩展 | `six-fighter-web/src/combat/types.ts` |
| 2 | 所有 ProjectileDef 素材数据文件 | `six-fighter-web/src/combat/vfx/projectiles/` (9个文件) |
| 3 | Behavior 类（策略模式） | `six-fighter-web/src/combat/vfx/behaviors/` (8个类) |
| 4 | SkillRegistry + SkillVisualizer 编排层 | `skillRegistry.ts` + `skillVisualizer.ts` |
| 5 | SKILL_TABLE 技能数据表（20个技能） | `skillDefinitions.ts` |
| 6 | heroes.ts 重构（移除工厂函数，改用 skillIds） | `heroes.ts` |
| 7 | ArenaScene + SkillDemoScene 接入新架构 | `ArenaScene.ts` · `SkillDemoScene.ts` |
| 8 | 构建验证 | `npm run build` ✓ `npm run dev` ✓ |

**架构核心成果：** 技能和单位从**硬绑定关系**变为**引用关系**——任意单位通过 `skillIds: string[]` 引用 SKILL_TABLE 中的技能，boss 设计可以复用英雄技能，英雄也可以通过引用使用怪物技能，无需代码改动。

---

## 2. 各文件说明

### `src/combat/types.ts`
扩展了原有 combat 类型，新增：
- `SkillCategory` — `'basic' | 'smallA' | 'smallB' | 'ultimate'`
- `ProjectileKind` — 9种投射物视觉种类
- `ProjectileBehavior` — 8种行为模式
- `ProjectileDef` — 视觉素材数据（颜色/尺寸/粒子参数）
- `SkillVisualDef` — 技能视觉参数（behavior key + projectile kind + timing）
- `SkillDef` — 完整技能定义（战斗参数 + 视觉参数合并）

### `src/combat/vfx/projectiles/` (9个文件)
每个文件导出对应 `ProjectileKind` 的 `ProjectileDef` 数据对象：
`mechanical_bullet` · `fireball` · `ghost_fire_skull` · `missile_storm` · `ice_cyclone` · `chain_lightning` · `burning_hands` · `ice_ring` · `plasma_beam`

其中 `fireball.ts` 包含 `trailParticles` + `frontFlameParticles` 配置，已被 `LinearBehavior` 正确消费。

### `src/combat/vfx/behaviors/` (8个类)
每个 Behavior 类对应一种 `ProjectileBehavior`：

| Behavior | 对应技能示例 | 视觉特点 |
|---------|------------|---------|
| `LinearBehavior` | ironwall_basic, demo_fireball | 直线飞行 + ribbon trail + fireball 粒子系统 |
| `HomingStormBehavior` | ironwall_smallB, demo_missile_storm | 弧线弹道 + comet trail |
| `GhostFireSkullBehavior` | demo_ghost_fire_skull | 追踪骷髅弹头 + spiral + AOE ring |
| `CycloneBehavior` | moss_ultimate, demo_ice_cyclone | 多层椭圆龙卷风 |
| `ChainLightningBehavior` | ember_smallB, demo_chain_lightning | 4状态机闪电链 |
| `BurningHandsBehavior` | moss_smallB, demo_burning_hands | 扇形扩散火焰 |
| `IceRingBehavior` | moss_smallA, demo_ice_ring | 环形扩散冰晶 |
| `PlasmaBeamBehavior` | ironwall_ultimate, demo_plasma_beam | 三层光束 + build/fade |

### `src/data/skillRegistry.ts`
全局技能注册表 + 查询接口：
```typescript
loadSkills(skills: SkillDef[]): void
getSkill(skillId: string): SkillDef | undefined
getHeroSkills(skillIds: readonly string[]): SkillDef[]
getHeroSkill(skillIds: readonly string[], category: SkillCategory): SkillDef | undefined
validateUnitSkills(skillIds: string[]): string[]
allSkillIds(): string[]
```

### `src/data/skillDefinitions.ts`
`SKILL_TABLE: SkillDef[]` — 20个技能：
- ironwall: basic / smallA / smallB / ultimate（4）
- ember: basic / smallA / smallB / ultimate（4）
- moss: basic / smallA / smallB / ultimate（4）
- demo 展示技能（8）

### `src/data/heroes.ts`
`HeroDef` 结构：
```typescript
interface HeroDef {
  id: HeroId;
  displayName: string;
  roleFamily: 'frontliner' | 'dps' | 'support';
  baseStats: CombatantStats;
  skillIds: readonly [string, string, string, string]; // basic/smallA/smallB/ultimate
}
```
所有工厂函数已移除，英雄不再持有技能实例，只持有 `skillId` 引用。

### `src/combat/autonomy.ts`
已更新为从 SkillRegistry 查询技能：
```typescript
pickAutonomousAction(hero: HeroDef, timers, selfHpFrac): AutonomyPick | null
// → getHeroSkill(skillIds, category) 替代原有工厂方法
// → 返回 AutonomyPick { skill: SkillDef, label, attack: AttackInstance }
```

### `src/scenes/BootScene.ts`
启动时同步加载技能数据：
```typescript
loadSkills(SKILL_TABLE);
for (const heroId of ['ironwall', 'ember', 'moss']) {
  const missing = validateUnitSkills([...hero.skillIds]);
  // Missing skills → console.error
}
```

### `src/scenes/ArenaScene.ts`
- 导入 `playSkillVisual`
- `runCombatAI()` 内：在 `applyHitFeedback()` 之后调用 `playSkillVisual(skillId, casterX, casterY, targetX, targetY, scene, skill.visual)`
- 视觉层完全 fire-and-forget，不阻塞战斗逻辑

### `src/scenes/SkillDemoScene.ts`
- 移除 `DEMO_SKILLS` 硬编码数组 (~15个内联视觉方法)
- 替换为 `DEMO_SKILL_IDS: string[]`（指向 SKILL_TABLE 中的 demo 技能）
- `playSelectedSkill()` 改用 `getSkill(skillId)` + `playSkillVisual()`
- 代码量从 ~2370行 → ~270行
- 保留了 `applyHitFeedback()` 的 hit flash + camera shake

### `src/combat/skillVisualizer.ts`
编排入口：
```typescript
playSkillVisual(skillId, casterX, casterY, targetX, targetY, scene, visual): void
// → createBehavior(visual.behavior) → getProjectileDef(visual.projectileKind)
// → behavior.init(ctx) → behavior.play()  (fire-and-forget)
```

---

## 3. Bug Fix: LinearBehavior 粒子发射缺失

**问题描述：** 普攻（机械子弹）和火球术在 SkillDemoScene 中缺少粒子拖尾和火焰粒子效果。

**根因：** `LinearBehavior.ts` 之前只实现了位置更新逻辑，缺少 `emitFireTrailParticles()` / `emitFrontFlameParticles()` / `drawRibbon()` 实现。

**修复：** 在 `LinearBehavior.ts` 中补充了三个方法，从 `ProjectileDef` 读取粒子配置并正确发射。`fireball.ts` 和 `mechanical_bullet.ts` 中的 `trailParticles` / `frontFlameParticles` 字段此前一直存在，只是 Behavior 代码没有消费它们。

**修复后：** `LinearBehavior` 完全从 `ProjectileDef` 驱动——任何新 `ProjectileKind` 只需在数据文件中配置粒子参数，无需修改 Behavior 代码。

---

## 4. 待跟进事项（无 P0 阻塞）

以下为非阻塞优化方向，可在下个迭代考虑：

1. **攻击特效（hit flash）未接入 SkillVisualizer**
   - ArenaScene 中 `applyHitFeedback()` 仍在内联调用
   - 未来可将 hit flash 封装为 `HitFlashBehavior` 或纳入 `SkillVisualizer`

2. **enemy 攻击无视觉表现**
   - ArenaScene 的 `runCombatAI()` 内，enemy 攻击段（grunt/boss普攻）尚未调用 `playSkillVisual()`
   - 需要为 enemy 配置独立的技能表（可参考 SKILL_TABLE 格式）

3. **SkillDemoScene 多目标集群场景**
   - 当前 SkillDemoScene 只用单目标 `target`
   - 闪电链（chain lightning）行为的多目标 bouncing 视觉依赖于行为类内部实现
   - `GhostFireSkullBehavior` / `ChainLightningBehavior` 内部hardcode了5个目标位置，未来可通过 `BehaviorContext.extraTargets` 参数化

4. **SkillEnhancement（技能强化）尚未接入**
   - `hero-skill-template-v1.md` 中 Passive3 的 `skill_enhancement_level` 联动尚未实现
   - 当前 SKILL_TABLE 中所有技能均为 base level

---

## 5. 关键设计决策记录

| 决策 | 理由 |
|------|------|
| 技能和单位为引用关系而非拥有关系 | 支持 boss 复用英雄技能、英雄变形使用怪物技能等灵活设计 |
| SkillDef 合并战斗参数 + 视觉参数 | 单一数据源，避免战斗/表现分离导致的同步丢失 |
| playSkillVisual 为 fire-and-forget | 视觉层永不阻塞战斗逻辑，保证 autonomy 实时性 |
| Behavior 类用 Strategy 模式，ProjectileDef 用数据对象 | 新粒子效果只需加数据文件，不改 Behavior 代码 |
| ghostFireSkull 作为独立的 ProjectileBehavior | 与 homingStorm 视觉效果不同（骷髅 vs 导弹），行为类独立便于差异化扩展 |

---

## 6. 验证方式

```bash
cd six-fighter-web
npm run build    # ✓ built in ~580ms
npm run dev     # → http://localhost:5178/
```

**手动验证路径：**
1. 启动后进入 BaseTown → 导航到 Arena → 观察 ironwall 普攻和火球术粒子拖尾
2. 进入 SkillDemoScene → 循环播放9个 demo 技能 → 确认所有视觉表现正常

**TypeScript 验证：**
```bash
npx tsc --noEmit  # 0 errors
```
