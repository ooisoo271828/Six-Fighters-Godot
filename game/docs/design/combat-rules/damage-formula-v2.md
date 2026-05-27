# 伤害计算公式 v2 — 乘法公式体系

> 版本: v2.0 | 更新: 2026-05-27 | 状态: 定稿

---

## 一、核心公式

```
最终伤害 = 基础伤害 × 防御系数 × 元素系数 × 暴击系数 × 命中判定系数
```

---

## 二、基础伤害

```
基础伤害 = 技能固定值 + min(技能系数 × 施法者攻击力, 成长上限)
```

| 参数 | 类型 | 来源 | 说明 |
|------|------|------|------|
| `技能固定值` | float | SkillDef.base_damage | 保底伤害，不受攻防影响 |
| `技能系数` | float | SkillDef.skill_coefficient | 每点攻击转化比率 |
| `施法者攻击力` | float | CombatantStats.attack | 角色的攻击属性 |
| `成长上限` | float | SkillDef.growth_cap | 可选，0=无上限 |

**无上限时：**
```
基础伤害 = 技能固定值 + 技能系数 × 施法者攻击力
```

**有上限时：**
```
成长值 = min(技能系数 × 施法者攻击力, 成长上限)
基础伤害 = 技能固定值 + 成长值
```

---

## 三、防御系数

```
防御系数 = DEF_CONST / (DEF_CONST + 目标防御力)
```

**全局常量：DEF_CONST = 10000**

防御系数曲线：

| 目标防御力 | 防御系数 | 实际减伤 |
|-----------|---------|---------|
| 0 | 1.000 | 0% |
| 500 | 0.952 | 4.8% |
| 1000 | 0.909 | 9.1% |
| 2500 | 0.800 | 20.0% |
| 5000 | 0.667 | 33.3% |
| 10000 | 0.500 | 50.0% |
| 20000 | 0.333 | 66.7% |

---

## 四、后续乘法系数

### 4.1 元素系数（已有，保持不变）

```
元素系数 = element_damage_mult(damage_type, target_stats, combat_params)
```

读取目标对应元素抗性，经 CombatResolver 的 `element_damage_mult()` 函数计算。

### 4.2 暴击系数（已有，保持不变）

当命中判定为暴击时：`暴击系数 = 1.0 + crit_power / 100.0`

### 4.3 命中判定系数（已有，Round-table 保持不变）

| 判定结果 | 系数 |
|---------|------|
| Hit | 1.0 |
| Glance | 0.5 |
| Deflect | 0.0(无伤害) |
| Miss | 0.0(无伤害) |

---

## 五、完整计算流程图

```
技能固定值 + min(系数×攻击力, 成长上限)
                ↓
          基础伤害
                ↓
     基础伤害 × DEF_CONST/(DEF_CONST+防御)
                ↓
        穿透防御后伤害
                ↓
      × 元素系数(基于目标抗性)
                ↓
      × 暴击系数(如果暴击)
                ↓
      × 命中判定系数(Hit/Glance/Deflect/Miss)
                ↓
          最终伤害 → target.take_damage()
```

---

## 六、属性分配方案

### 全局常量

```
DEF_CONST = 10000
```

### 英雄初始属性

| 英雄 | 攻击力 | 防御力 | 定位 |
|------|--------|--------|------|
| Ironwall 🛡️ | 500 | 8000 | 高防坦克(44%减伤) |
| Ember 🔥 | 2500 | 500 | 高攻脆皮(4.8%减伤) |
| Moss 🌿 | 1200 | 3000 | 均衡辅助(23%减伤) |

### 敌人属性

| 单位 | 攻击力 | 防御力 | HP |
|------|--------|--------|----|
| 普通小怪 | 200 | 300 | 56 |
| 精英怪 | 500 | 1000 | 140 |
| Boss | 1500 | 5000 | 420 |

### 技能数值

| 技能 | 固定值(base_damage) | 系数 | 成长上限 | 说明 |
|------|-------------------|------|---------|------|
| **火球术** 🔥 | 20 | 1.2 | 200 | 高成长，Ember 核心输出 |
| **冰箭术** ❄️ | 12 | 0.5 | 100 | 三发追踪，总伤高 |
| **投石** 🪨 | 8 | 0.2 | 50 | 小怪普攻 |
| **投骨** 🦴 | 10 | 0.25 | 60 | 小怪普攻 |
| **飞镖** 🔱 | 6 | 0.15 | 40 | 小怪普攻 |
| **水浪术** 🌊 | 15 | 0.5 | 150 | 弹射三次 |
| **火焰之手** 🔥 | 10 | 0.3 | 80 | 持续9次灼烧 |
| **落石流星** ☄️ | 30 | 1.0 | 250 | 高爆发AOE |
| **导弹风暴** 🚀 | 15 | 0.6 | 150 | 12枚导弹追踪 |
| **小激光术** 🔫 | 8 | 0.4 | 80 | 5道光柱 |
| **大激光术** 🔴 | 12 | 0.6 | 150 | 持续4秒 |
| **魔眼激光** 👁️ | 15 | 0.5 | 120 | 椭圆扫描 |
| **气泡炸弹阵** 🫧 | 20 | 0.8 | 200 | 8颗延时炸弹 |
| **飞剑风暴** ⚔️ | 10 | 0.5 | 120 | 10柄飞剑 |
| **霰弹手里剑** 🌀 | 12 | 0.5 | 100 | 9发扇形 |

---

## 七、改动清单

### 7.1 `CombatantStats` 新增字段

```gdscript
var attack: float = 100.0
var defense: float = 100.0
```

各英雄静态构造方法补充初始值。

### 7.2 `SkillDef` 新增字段

```gdscript
@export var skill_coefficient: float = 1.0  # 技能伤害系数
@export var growth_cap: float = 0.0          # 成长上限（0=无上限）
# base_damage 保留作为固定值
```

### 7.3 `CombatResolver.resolve_attack()` 修改

入参从 `base_damage: float` 改为接收 `attacker_attack: float` 和 `defender_defense: float`，内部计算：

```gdscript
var growth := minf(skill_coefficient * attacker_attack, growth_cap) if growth_cap > 0 else skill_coefficient * attacker_attack
var base_damage := fixed_damage + growth
var defense_mult := DEF_CONST / (DEF_CONST + defender_defense)
var final_damage := base_damage * defense_mult
# ... 后续元素/暴击/命中系数不变 ...
```

### 7.4 `CombatParams` 新增

```gdscript
const DEF_CONST: float = 10000.0
```
