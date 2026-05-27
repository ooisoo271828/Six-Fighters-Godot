# 战斗数值调优方案 — 待实装

> 状态: **方案待确认**
> 日期: 2026-05-28
> 目标: Hero互打 HIT% >= 60%，战斗节奏合理，怪物数据独立

---

## 一、命中圆桌参数修改

**文件**: `scripts/core/game_manager.gd` -> `_create_default_combat_params()`

| 参数 | 当前值 | 新值 | 说明 |
|------|--------|------|------|
| `hit_roundtable_softmax_k` | 2.0 | **7.0** | 压缩 DEFLECT 概率，让 HQ 高的直接拿 HIT |
| `deflect_mult` | 0.75 | **0.5** | 降低 DEFLECT 锚点，使其远离 HQ 集中区 |

---

## 二、英雄 ACC / EVA 调整

**文件**: `scripts/data/combatant_stats.gd`

| 英雄 | ACC 旧值 | ACC 新值 | EVA 旧值 | EVA 新值 |
|------|---------|---------|---------|---------|
| Ember | 48 | **52** | 18 | **16** |
| Moss | 38 | **50** | 22 | **15** |
| Ironwall | 35 | **48** | 10 | **14** |

---

## 三、敌人 ACC / EVA

**比例**: Hero : Minion : Elite : Boss = 1 : 0.75 : 1.1 : 1.3

| 类型 | ACC | EVA |
|------|-----|-----|
| Minion | 37.5 | 11.2 |
| Elite | 55.0 | 16.5 |
| Boss | 65.0 | 19.5 |

---

## 四、技能配置范式重构

### 4.1 CD 规范（新标准）

| 单位类型 | 技能数量 | CD 范围 | 说明 |
|---------|---------|--------|------|
| 英雄 | 2 个常规主动技能 | 6~8s | 从现有 3.5~5s 上调 |
| 精英 | 2 个常规主动技能 | 6~8s | 与英雄同级 |
| 小怪 | 1 个弱技能（丢石头/骨头/飞镖） | 6~8s | 从 0.9s 大幅上调 |
| Boss | 3 个常规主动技能 | 8~10s | 比英雄/精英更慢但更强 |

### 4.2 英雄技能配置

| 英雄 | 技能1 | 技能1 CD | 技能2 | 技能2 CD |
|------|-------|---------|-------|---------|
| Ember | fireball_basic | 7.0s | ice_arrow | 6.0s |
| Moss | water_wave | 7.0s | small_laser_beam | 6.0s |
| Ironwall | burning_hands | 7.0s | falling_meteor | 8.0s |

> CD 从 .tres 文件读取，需要更新对应 .tres 的 cooldown 字段
> 其他未分配给英雄的技能（missile_storm, bubble_bomb_array 等）也统一调整 CD 到 6~8s

### 4.3 怪物技能配置

#### 小怪（1 个弱技能，CD 6~8s，属性各不相同）

| 小怪变体 | enemy_id | 技能 | base_dmg | coeff | CD | ATK | DEF | HP |
|---------|----------|------|----------|-------|-----|-----|-----|-----|
| 丢石头 | minion_rock | rock_toss | 15 | 0.3 | 7.0s | 1230 | 1500 | 300 |
| 丢骨头 | minion_bone | bone_throw | 18 | 0.35 | 7.0s | 820 | 1200 | 350 |
| 丢飞镖 | minion_shuriken | shuriken_throw | 12 | 0.25 | 6.0s | 1720 | 1000 | 250 |

> 三种小怪各有侧重：石头=高攻高防，骨头=均衡，飞镖=低血低防高攻速

#### 精英（2 个主动技能，CD 6~8s，随机选一个变体出场）

| 精英变体 | enemy_id | 技能1 | 技能2 | ATK | DEF | HP |
|---------|----------|-------|-------|-----|-----|-----|
| 火+冰 | elite_fire_ice | fireball_basic | ice_arrow | 350 | 4000 | 400 |
| 水+飞镖 | elite_water_shuriken | water_wave | scatter_shuriken | 470 | 3500 | 450 |
| 激光+灼烧 | elite_laser_burn | small_laser_beam | burning_hands | 470 | 3000 | 500 |

> 出场方式：每次刷精英时从 3 个变体中随机选一个

精英技能参数（怪物版本，与英雄版本不同）:

| 技能 | base_damage | skill_coefficient | cooldown |
|------|-------------|-------------------|----------|
| fireball_basic | 30 | 0.8 | 7.0s |
| ice_arrow | 18 | 0.5 | 6.0s |
| water_wave | 22 | 0.5 | 7.0s |
| scatter_shuriken | 20 | 0.5 | 6.0s |
| small_laser_beam | 15 | 0.4 | 6.0s |
| burning_hands | 15 | 0.4 | 7.0s |

#### Boss（3 个主动技能，CD 8~10s，最后一波出场）

| Boss | enemy_id | 技能1 | 技能2 | 技能3 | ATK | DEF | HP |
|------|----------|-------|-------|-------|-----|-----|-----|
| Boss1 | boss_meteor_eye | falling_meteor | evil_eye_laser | bubble_bomb_array | 680 | 10000 | 900 |

> Boss 在第 5 波（最后一波）与小怪一同出场

Boss 技能参数（怪物版本，与英雄版本不同）:

| 技能 | base_damage | skill_coefficient | cooldown |
|------|-------------|-------------------|----------|
| falling_meteor | 20 | 0.7 | 9.0s |
| evil_eye_laser | 15 | 0.5 | 8.0s |
| bubble_bomb_array | 20 | 0.8 | 9.0s |

> falling_meteor 从 coeff=1.0 降到 0.7，避免 raw_hit=631 一击秒杀英雄（HP=600）
> 三个技能交替释放，平均 coeff=0.67, avg CD=8.7s

---

## 五、怪物数据独立化 — 架构设计

### 5.1 核心原则

#### 战斗数值 → CSV，美术效果 → .tres

- CSV 存放所有战斗逻辑数值（ATK/DEF/HP/技能系数/CD 等）
- .tres 只存放视觉效果相关数据（弹体外观、拖尾、命中特效等）
- 怪物和英雄用同一套 CSV 加载机制（复用 `load_values_from_csv()` 模式）

### 5.2 问题

当前英雄和怪物共享同一个 SkillDef：
- 英雄的 fireball_basic 和精英的 fireball_basic 用相同的 base_damage/coefficient/cooldown
- 无法分别调数值

### 5.3 数据架构

#### CSV 文件

**`docs/design/combat-rules/values/enemy-values.csv`** — 敌人单位属性

```csv
id,domain,category,parameter,key,value,notes
1,enemy,minion_rock,stats,max_hp,300,丢石头小怪
2,enemy,minion_rock,stats,attack,1230,
3,enemy,minion_rock,stats,defense,1500,
4,enemy,minion_rock,stats,accuracy,37.5,
5,enemy,minion_rock,stats,evasion,11.2,
6,enemy,minion_rock,stats,pattern_cooldown,7.0,
7,enemy,minion_rock,skills,skill_1,rock_toss,技能ID（复用视觉）
8,enemy,minion_bone,stats,max_hp,350,丢骨头小怪
...
15,enemy,elite_fire_ice,stats,max_hp,400,精英火+冰
16,enemy,elite_fire_ice,skills,skill_1,fireball_basic,
17,enemy,elite_fire_ice,skills,skill_2,ice_arrow,
...
28,enemy,boss_meteor_eye,stats,max_hp,900,Boss
29,enemy,boss_meteor_eye,skills,skill_1,falling_meteor,
30,enemy,boss_meteor_eye,skills,skill_2,evil_eye_laser,
31,enemy,boss_meteor_eye,skills,skill_3,bubble_bomb_array,
```

**`docs/design/combat-rules/values/monster-skill-values.csv`** — 怪物技能数值

```csv
id,domain,category,parameter,key,value,notes
1,monster,rock_toss,damage,base_damage,15,怪物版丢石头
2,monster,rock_toss,damage,skill_coefficient,0.3,
3,monster,rock_toss,damage,growth_cap,99999,
4,monster,rock_toss,cooldown,cooldown,7.0,
5,monster,rock_toss,damage,damage_type,physical,
6,monster,fireball_basic,damage,base_damage,30,怪物版火球（精英用）
7,monster,fireball_basic,damage,skill_coefficient,0.8,
8,monster,fireball_basic,cooldown,cooldown,7.0,
...
20,monster,falling_meteor,damage,base_damage,20,怪物版陨石（Boss用）
21,monster,falling_meteor,damage,skill_coefficient,0.7,
22,monster,falling_meteor,cooldown,cooldown,9.0,
```

> 同一个 skill_id（如 fireball_basic）在 hero 和 monster 域中各有独立行，数值不同

#### 数据加载类

**新增** `scripts/data/enemy_registry.gd` — 从 CSV 加载敌人数据

```gdscript
class_name EnemyRegistry extends Node

# enemy_id -> { max_hp, attack, defense, accuracy, evasion, pattern_cooldown, skill_ids: [] }
var _enemy_map: Dictionary = {}

func _ready() -> void:
    _load_from_csv()

func _load_from_csv() -> void:
    # 读取 enemy-values.csv，按 category(enemy_id) 分组
    # 同一 category 下的 stats 行 → 构建属性字典
    # skills 行 → 收集 skill_id 列表
    pass

func get_enemy_data(enemy_id: String) -> Dictionary:
    return _enemy_map.get(enemy_id, {})

func get_enemy_ids() -> Array[String]:
    var result: Array[String] = []
    for k in _enemy_map:
        result.append(k)
    return result
```

> EnemyRegistry 返回 Dictionary 而非 Resource，数据全部来自 CSV
> 不需要 EnemyData Resource 类

**扩展** `scripts/skill_system/registry/skill_def.gd` — 支持怪物域加载

```gdscript
# 当前 load_values_from_csv() 只读 hero 域
# 新增：支持读取 monster 域的 CSV 行
func load_monster_values_from_csv(monster_skill_id: String) -> void:
    # 从 monster-skill-values.csv 读取 category=monster_skill_id 的行
    # 覆盖 base_damage, skill_coefficient, cooldown 等字段
    pass
```

> 或者更简单：SkillRegistry 加载时，对每个 skill_id 同时读 hero 和 monster 两行
> 存为 `_skill_map[skill_id]`（hero版）和 `_monster_skill_map[skill_id]`（monster版）

#### SkillRegistry 扩展

```gdscript
# skill_registry.gd 新增
var _monster_skill_map: Dictionary = {}   # skill_id -> SkillDef (怪物版数值)

func get_monster_skill(skill_id: String) -> Resource:
    return _monster_skill_map.get(skill_id, _skill_map.get(skill_id))
```

### 5.4 CombatMediator 改动

```gdscript
# _on_projectile_hit() 和 _resolve_and_apply_damage() 中：
# 判断施法者是英雄还是怪物，选择不同的 SkillDef 数值

var is_monster: bool = caster.get_meta("is_enemy", false)
var skill_def: Resource
if is_monster:
    skill_def = skill_system.get_monster_skill(skill_id)
else:
    skill_def = skill_system.get_skill(skill_id)

# 后续 skill_def.base_damage / skill_coefficient / growth_cap 自动区分
```

### 5.5 Enemy 改动

```gdscript
# enemy.gd 新增
var _enemy_id: String = ""
var _skill_ids: Array[String] = []
var _skill_index: int = 0     # Boss 多技能轮换

func setup_from_registry(enemy_id: String, data: Dictionary) -> void:
    _enemy_id = enemy_id
    var stats := CombatantStats.create_base()
    stats.attack = data.get("attack", 500.0)
    stats.defense = data.get("defense", 1765.0)
    stats.accuracy = data.get("accuracy", 40.0)
    stats.evasion = data.get("evasion", 15.0)
    setup("enemy", enemy_id, stats, data.get("max_hp", 500.0))
    pattern_cooldown = data.get("pattern_cooldown", 7.0)
    _skill_ids = data.get("skill_ids", [])
    set_meta("is_enemy", true)

func get_next_skill_id() -> String:
    if _skill_ids.is_empty():
        return ""
    var sid := _skill_ids[_skill_index % _skill_ids.size()]
    _skill_index += 1
    return sid
```

### 5.6 arena_scene.gd 改动

```gdscript
# 当前：手动拼参数 + set_meta("skill_id")
# 改为：从 EnemyRegistry 读取数据

var data: Dictionary = enemy_registry.get_enemy_data("minion_rock")
enemy.setup_from_registry("minion_rock", data)
# skill_id 由 enemy.get_next_skill_id() 在攻击时获取
```

### 5.7 .tres 文件用途（仅视觉效果）

```
resources/skills/skill_defs/         # SkillDef .tres — 保留，但只存视觉/效果字段
├── fireball_basic.tres              # effect_type, delivery_type, cast_range, target_mode
├── rock_toss.tres                   # 弹体外观引用、拖尾配置
└── ...

resources/skills/skill_visual_defs/  # SkillVisualDef .tres — 弹体/拖尾/命中视觉
└── ...
```

> .tres 中的 base_damage / cooldown / skill_coefficient 字段保留默认值
> 实际战斗数值由 CSV 加载后覆盖

### 5.6 Boss 波次结构重构

**当前**: 5 波全部用 `_on_wave_spawn()` 统一处理，精英和小怪混刷

**新结构**:

| 波次 | 小怪数 | 精英数 | Boss | 说明 |
|------|--------|--------|------|------|
| Wave 1 | 6 | 0 | - | 纯小怪，随机变体 |
| Wave 2 | 8 | 0 | - | 纯小怪，随机变体 |
| Wave 3 | 10 | 1 | - | 小怪 + 1 精英（随机变体） |
| Wave 4 | 12 | 1 | - | 小怪 + 1 精英（随机变体） |
| Wave 5 | 18 | 0 | 1 | Boss + 小怪，无精英 |

> `BOSS_WAVE_COUNTS` 不变: [6, 8, 10, 12, 18]
> 新增 `BOSS_WAVE_ELITE_COUNTS`: [0, 0, 1, 1, 0]
> 新增 `BOSS_WAVE_HAS_BOSS`: [false, false, false, false, true]

小怪变体分配：每波的小怪从 3 种变体中随机选取（等概率）
精英变体分配：从 3 种精英变体中随机选取（等概率）

---

## 六、敌人攻防数值（基于新 CD 重算）

> CD 变化对 DPS 影响巨大：小怪从 0.9s -> 7s（DPS 降 7.8x），英雄从 4s -> 7s（DPS 降 1.75x）
> 因此 ATK/HP 需要完全重算

### 6.1 英雄 DPS 变化（CD 6~8s）

| 英雄 | 技能 | 旧CD | 新CD | ATK | vs Minion(DEF=1500) | vs Elite(DEF=4000) | vs Boss(DEF=10000) |
|------|------|------|------|-----|--------------------|--------------------|-------------------|
| Ember | fireball | 4.0s | 7.0s | 750 | DPS=101 | DPS=79 | DPS=54 |
| Moss | water_wave | 5.0s | 7.0s | 500 | DPS=31 | DPS=24 | DPS=17 |
| Ironwall | burning_hands | 5.0s | 7.0s | 300 | DPS=10 | DPS=8 | DPS=5 |
| **6英雄合计** | | | | | **142** | **111** | **76** |

### 6.2 敌人配置总览

| 类型 | enemy_id | 技能 | coeff | base_dmg | CD | ATK | DEF | HP | TTK vs Ember |
|------|----------|------|-------|----------|-----|-----|-----|-----|-------------|
| 小怪A | minion_rock | rock_toss | 0.3 | 15 | 7.0s | 1230 | 1500 | 300 | 9.3s |
| 小怪B | minion_bone | bone_throw | 0.35 | 18 | 7.0s | 820 | 1200 | 350 | 9.6s |
| 小怪C | minion_shuriken | shuriken_throw | 0.25 | 12 | 6.0s | 1720 | 1000 | 250 | 9.9s |
| 精英A | elite_fire_ice | fireball+ice_arrow | 0.8/0.5 | 30/18 | 7.0s | 350 | 4000 | 400 | 7.2s |
| 精英B | elite_water_shuriken | water_wave+scatter | 0.5/0.5 | 22/20 | 7.0s | 470 | 3500 | 450 | 7.4s |
| 精英C | elite_laser_burn | laser+burning | 0.4/0.4 | 15/15 | 7.0s | 470 | 3000 | 500 | 7.0s |
| Boss | boss_meteor_eye | 3技能轮换 | 0.7/0.5/0.8 | 20/15/20 | 8~9s | 680 | 10000 | 900 | 11.7s |

> Elite raw_hit 最高 434（fireball），略超 Ember HP=600，但 HIT 概率 ~76%，GLANCE/DEFLECT 减伤，实际不会一击必杀

### 6.3 6 英雄集火各变体

| 目标 | HP | DEF | 总DPS | TTK |
|------|----|-----|-------|-----|
| 小怪A (rock) | 300 | 1500 | 142 | **2.1s** |
| 小怪B (bone) | 350 | 1200 | 147 | **2.4s** |
| 小怪C (shuriken) | 250 | 1000 | 152 | **1.6s** |
| 精英A (fire_ice) | 400 | 4000 | 111 | **3.6s** |
| 精英B (water_shuriken) | 450 | 3500 | 120 | **3.8s** |
| 精英C (laser_burn) | 500 | 3000 | 128 | **3.9s** |
| Boss | 900 | 10000 | 76 | **11.8s** |

### 6.4 敌人打 Ember (HP=600, DEF=1111)

| 攻击者 | 技能 | raw_hit | DPS | TTK |
|--------|------|---------|-----|-----|
| 小怪A (rock) | rock_toss | 316 | 45 | 9.3s |
| 小怪B (bone) | bone_throw | 316 | 45 | 9.3s |
| 小怪C (shuriken) | shuriken_throw | 316 | 45 | 9.3s |
| 精英A (fireball) | fireball_basic | 434 | 62 | 6.8s |
| 精英B (water) | water_wave | 283 | 40 | 10.4s |
| 精英C (laser) | small_laser_beam | 283 | 40 | 10.4s |
| Boss (avg) | 3技能均值 | 314 | 36 | 11.7s |

### 6.5 敌人打 Ironwall (HP=600, DEF=6667)

| 攻击者 | raw_hit | DPS | TTK |
|--------|---------|-----|-----|
| 小怪A (rock) | 214 | 31 | 13.7s |
| 精英A (fireball) | 293 | 42 | 10.1s |
| Boss (avg) | 212 | 24 | 17.3s |

---

## 七、改动文件清单

### 新增文件

| 文件 | 用途 |
|------|------|
| `docs/design/combat-rules/values/enemy-values.csv` | 敌人单位属性 + 技能分配（战斗数值） |
| `docs/design/combat-rules/values/monster-skill-values.csv` | 怪物技能数值（独立于英雄版本） |
| `scripts/data/enemy_registry.gd` | 从 CSV 加载敌人数据的注册表 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `scripts/core/game_manager.gd` | hit params: k=7.0, d=0.5 |
| `scripts/data/combatant_stats.gd` | Hero ACC/EVA: Ember(52/16), Moss(50/15), Ironwall(48/14) |
| `scripts/data/arena_config.gd` | 移除旧的 minion_base_* 系列，改为从 EnemyRegistry 读取 |
| `scripts/arena/arena_scene.gd` | spawn 逻辑重构：EnemyRegistry + Boss 波次结构（5波差异化） |
| `scripts/units/enemy.gd` | 新增 setup_from_registry()，支持多技能轮换，set_meta("is_enemy") |
| `scripts/combat/combat_mediator.gd` | 按施法者类型选择 hero/monster 版 SkillDef |
| `scripts/skill_system/registry/skill_registry.gd` | 新增 _monster_skill_map + get_monster_skill()，加载 monster CSV |
| `scripts/skill_system/registry/skill_def.gd` | 支持从 monster-skill-values.csv 加载怪物域数值 |
| `resources/skills/skill_defs/*.tres` | .tres 仅保留视觉/效果字段，战斗数值由 CSV 覆盖 |
| `docs/design/combat-rules/values/skill-values.csv` | 英雄技能 CD 统一调整到 6~8s |
