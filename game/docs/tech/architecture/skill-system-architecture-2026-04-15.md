# Skill System Architecture
**Status:** Implemented
**Version:** 1.0
**Date:** 2026-04-15
**Owner:** Engineering + Design
**Related:** `hero-skill-template-v1.md` · `b-series-skill-schema-v0.md` · `role-tags-fixed-role-ai-contract.md`

---

## 1. Design Philosophy: Reference vs Ownership

The central architectural principle is that **skills and units are in a reference relationship, not an ownership relationship**.

```
Unit (Hero / Monster)
  └─ skillIds: string[]   ← 只引用 SKILL_TABLE 中的 skillId
                           不持有 SkillDef 实例本身

SKILL_TABLE (global registry)
  └─ SkillDef[]           ← 全局唯一，任意单位可引用
```

**Why this matters:**
- Any unit (hero or monster/boss) can use any skill by referencing its `skillId`
- Boss designs can combine hero skills (e.g., a boss that uses `ember_ultimate`)
- Heroes can transform to use monster skills without code changes
- Skill balance changes propagate globally without patching every unit
- New skills only need to be added to `SKILL_TABLE` — existing units gain access by referencing them

---

## 2. Type System

All types live in `six-fighter-web/src/combat/types.ts`.

### 2.1 SkillDef — Complete Skill Definition

```typescript
interface SkillDef {
  skillId: string;           // e.g. 'ironwall_basic', 'ember_ultimate'
  category: SkillCategory;    // 'basic' | 'smallA' | 'smallB' | 'ultimate'
  baseDamage: number;
  damageType: DamageType;    // 'physical' | 'elemental_fire' | 'elemental_ice' | ...
  stunChance?: number;       // 0..1, optional
  stunDurationBaseSec?: number;
  cooldown: number;          // seconds
  rageCost?: number;         // ultimate only
  visual: SkillVisualDef;     // all visual/presentation parameters
}
```

### 2.2 SkillVisualDef — Visual Parameters

```typescript
interface SkillVisualDef {
  behavior: ProjectileBehavior;   // which Behavior class to use
  label: string;                  // display/debug label
  telegraphMs: number;            // telegraph/indicator duration
  travelMs: number;               // projectile flight duration
  telegraphShape: 'circle' | 'rect';
  impactLevel: 'medium' | 'strong';
  projectileKind: ProjectileKind;  // which ProjectileDef visual asset to use
}
```

### 2.3 ProjectileKind — Visual Asset Kind

```typescript
type ProjectileKind =
  | 'mechanical_bullet'   // 直线机械子弹
  | 'fireball'            // 火球（抖动核心+尾焰粒子）
  | 'ghost_fire_skull'    // 幽灵火焰骷髅
  | 'missile_storm'       // 导弹风暴（弧线）
  | 'ice_cyclone'         // 冰龙卷风
  | 'chain_lightning'     // 闪电链
  | 'burning_hands'       // 火焰之手（扇形）
  | 'ice_ring'            // 冰环（环形扩散）
  | 'plasma_beam';        // 等离子光束
```

### 2.4 ProjectileBehavior — Movement/Logic Pattern

```typescript
type ProjectileBehavior =
  | 'linear'           // 直线飞行 + ribbon trail
  | 'homingStorm'     // 弧线弹道 + comet trail
  | 'ghostFireSkull'  // 追踪骷髅弹头 + AOE on impact
  | 'cyclone'         // 多层椭圆龙卷风
  | 'chainLightning'  // 状态机闪电链（FLYING/INCOMING/DWELL/OUTGOING）
  | 'burningHands'    // 扇形扩散火焰
  | 'iceRing'         // 环形扩散冰晶
  | 'plasmaBeam';     // 三层光束（core/mid/outer）+ build/fade
```

### 2.5 ProjectileDef — Visual Asset Data

Each projectile kind has a data file (`src/combat/vfx/projectiles/{kind}.ts`) exporting a `ProjectileDef` object:

```typescript
interface ProjectileDef {
  id: ProjectileKind;
  core: ProjectileCoreShape;              // 主体形状
  coreInner?: { offsetX, offsetY, ... };  // 内核（可选）
  coreHotspot?: { ... };                   // 热点（可选）
  nose?: { length, width, color };         // 鼻锥（可选）
  frictionGlow?: { radius, color };        // 摩擦光晕（可选）
  trailParticles?: TrailParticleConfig;    // 尾迹粒子配置
  frontFlameParticles?: FrontFlameConfig;  // 前缘火焰粒子配置（fireball专用）
  impactBurst?: ImpactBurstConfig;         // 撞击爆发配置
  ribbonWidth?: number;                    // ribbon trail 宽度
  ribbonColors?: [number, number];         // ribbon 颜色
}
```

**Key insight:** New projectile variants only require a new `ProjectileDef` data file. No Behavior code changes needed.

---

## 3. Registry Pattern

`src/data/skillRegistry.ts`

```typescript
const table = new Map<string, SkillDef>();

export function loadSkills(skills: SkillDef[]): void { ... }
export function getSkill(skillId: string): SkillDef | undefined { ... }
export function getHeroSkills(skillIds: readonly string[]): SkillDef[] { ... }
export function getHeroSkill(skillIds: readonly string[], category: SkillCategory): SkillDef | undefined { ... }
export function validateUnitSkills(skillIds: string[]): string[] { ... }
export function allSkillIds(): string[] { ... }
```

**Boot sequence** (`BootScene.ts`):
1. `loadSkills(SKILL_TABLE)` — synchronously registers all skills
2. `validateUnitSkills([...hero.skillIds])` — validates all hero references exist
3. `Promise.all([loadCombatParams(), loadVisualPresentation()])` — loads CSV params
4. Scene navigation starts

---

## 4. Behavior / Visual Separation

Two independent axes:

| Axis | What it controls | How to change |
|------|-----------------|---------------|
| **ProjectileBehavior** (Strategy) | Movement pattern, trajectory, logic | Edit Behavior class in `src/combat/vfx/behaviors/` |
| **ProjectileDef** (Data) | Colors, sizes, particle params | Edit data file in `src/combat/vfx/projectiles/` |

**Example:** `ironwall_smallA` and `ember_smallA` both use `behavior: 'linear'` but different `projectileKind` (`fireball` vs `mechanical_bullet`). The LinearBehavior class is identical — only the visual data differs.

### 4.1 Behavior Classes (`src/combat/vfx/behaviors/`)

Each extends `BaseBehavior`:

```typescript
abstract class BaseBehavior {
  protected ctx!: BehaviorContext;
  init(ctx: BehaviorContext): void { this.ctx = ctx; }
  abstract play(): void;
  protected rand(min, max): number { ... }
  protected randInt(min, max): number { ... }
}
```

Available behaviors:
- `LinearBehavior` — straight flight + ribbon trail + fireball particle systems
- `HomingStormBehavior` — quadratic bezier arc + comet trail
- `GhostFireSkullBehavior` — homing skull + spiral + AOE ring on impact
- `CycloneBehavior` — multi-layer ellipse cyclone + swirl particles
- `ChainLightningBehavior` — 4-state machine (FLYING/INCOMING/DWELL/OUTGOING) + arc rings
- `BurningHandsBehavior` — fan-shaped spread + flame particles + alpha breathing
- `IceRingBehavior` — ring expansion + crystal particles + center glow
- `PlasmaBeamBehavior` — three-layer beam + build/fade phases + jitter

### 4.2 Projectile Data Files (`src/combat/vfx/projectiles/`)

```
mechanical_bullet.ts   ← 机械子弹 ribbon trail
fireball.ts            ← 火球 jitter core + trail + front flame particles
ghost_fire_skull.ts
missile_storm.ts       ← missile storm comet trail
ice_cyclone.ts
chain_lightning.ts
burning_hands.ts
ice_ring.ts
plasma_beam.ts
index.ts               ← getProjectileDef(kind: ProjectileKind): ProjectileDef
```

---

## 5. SkillVisualizer Orchestration Layer

`src/combat/skillVisualizer.ts`

```typescript
export function playSkillVisual(
  skillId: string,           // for debug labeling
  casterX: number,
  casterY: number,
  targetX: number,
  targetY: number,
  scene: Phaser.Scene,
  visual: SkillVisualDef,
): void {
  const behavior = createBehavior(visual.behavior);  // factory
  const proj = getProjectileDef(visual.projectileKind);
  behavior.init({ casterX, casterY, targetX, targetY, scene, visual, proj });
  behavior.play();  // fire-and-forget, non-blocking
}
```

**Fire-and-forget:** `playSkillVisual()` is async/non-blocking. Combat logic does not wait for visual to complete. This ensures visual effects never stall combat resolution.

---

## 6. SKILL_TABLE Structure

`src/data/skillDefinitions.ts`

20 skills across 3 heroes + 8 demo showcase variants:

| Hero | basic | smallA | smallB | ultimate |
|------|-------|--------|--------|---------|
| ironwall (frontliner) | ironwall_basic | ironwall_smallA | ironwall_smallB | ironwall_ultimate |
| ember (dps) | ember_basic | ember_smallA | ember_smallB | ember_ultimate |
| moss (support) | moss_basic | moss_smallA | moss_smallB | moss_ultimate |

Demo showcase (SkillDemoScene cycle): `demo_fireball`, `demo_ghost_fire_skull`, `demo_missile_storm`, `demo_ice_cyclone`, `demo_chain_lightning`, `demo_burning_hands`, `demo_ice_ring`, `demo_plasma_beam`, `ironwall_basic`

---

## 7. Data Flow

```
BootScene
  └─ loadSkills(SKILL_TABLE)           ← 注册所有技能到 SkillRegistry

ArenaScene / SkillDemoScene
  │
  ├─ pickAutonomousAction(hero, timers, hpFrac)
  │    └─ getHeroSkill(skillIds, category)     ← 从 Registry 查询 SkillDef
  │         └─ returns AutonomyPick { skill, label, attack }
  │
  ├─ resolveAttackOutcome({ attack: pick.attack, ... })
  │    └─ computes damage + status updates (combat logic)
  │
  ├─ applyHitFeedback(scene, vp, tier, target)   ← hit stop + camera shake
  │
  └─ playSkillVisual(skillId, casterX, casterY, targetX, targetY, scene, skill.visual)
       ├─ createBehavior(visual.behavior)          ← factory → Behavior class
       ├─ getProjectileDef(visual.projectileKind) ← data file lookup
       └─ behavior.play()                         ← fire-and-forget visual
```

---

## 8. File Structure

```
six-fighter-web/src/
├── combat/
│   ├── types.ts                          ← all shared types (SkillDef, ProjectileDef, etc.)
│   ├── skillVisualizer.ts                ← orchestration entry point
│   ├── autonomy.ts                       ← fixed_role_ai: survival → role → opportunity
│   ├── resolveAttackOutcome.ts           ← combat resolution
│   ├── vfx/
│   │   ├── behaviors/
│   │   │   ├── BaseBehavior.ts           ← abstract base + BehaviorContext
│   │   │   ├── LinearBehavior.ts         ← straight flight + ribbon trail + fireball particles
│   │   │   ├── HomingStormBehavior.ts
│   │   │   ├── GhostFireSkullBehavior.ts
│   │   │   ├── CycloneBehavior.ts
│   │   │   ├── ChainLightningBehavior.ts
│   │   │   ├── BurningHandsBehavior.ts
│   │   │   ├── IceRingBehavior.ts
│   │   │   ├── PlasmaBeamBehavior.ts
│   │   │   └── index.ts                 ← createBehavior() factory + BEHAVIOR_MAP
│   │   └── projectiles/
│   │       ├── index.ts                 ← getProjectileDef(kind): ProjectileDef
│   │       ├── mechanical_bullet.ts
│   │       ├── fireball.ts              ← jitter core + trail + front flame particles
│   │       ├── ghost_fire_skull.ts
│   │       ├── missile_storm.ts
│   │       ├── ice_cyclone.ts
│   │       ├── chain_lightning.ts
│   │       ├── burning_hands.ts
│   │       ├── ice_ring.ts
│   │       └── plasma_beam.ts
│   └── (resolveAttackOutcome.ts, combatParams.ts, ...)
└── data/
    ├── skillRegistry.ts                  ← global skill registry + query functions
    ├── skillDefinitions.ts              ← SKILL_TABLE (20 skills)
    └── heroes.ts                        ← HeroDef with skillIds: readonly [string,string,string,string]
```

---

## 9. Revision Record

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-15 | Engineering | Initial implementation: SkillRegistry + Behavior/Visual separation + SkillVisualizer + SKILL_TABLE + ArenaScene/SkillDemoScene integration |
