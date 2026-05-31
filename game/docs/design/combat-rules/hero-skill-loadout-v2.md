# 英雄技能配置方案 v2.0

## 一、设计原则

1. **每个英雄4个技能**：1普攻 + 2小技能 + 1大招
2. **普攻定位**：低伤害高频，类似怪物普攻强度
3. **小技能定位**：中等伤害，中等CD，独立触发
4. **大招定位**：高伤害，视觉华丽，怒气触发
5. **元素一致性**：每个英雄的技能元素属性与角色定位匹配

## 二、角色定位与元素主题

| 英雄 | 角色 | 主元素 | 副元素 | 战斗风格 |
|------|------|--------|--------|----------|
| ember | DPS输出 | 火 | 冰 | 远程，高爆发，元素切换 |
| moss | SUPPORT辅助 | 水 | 光 | 远程，弹射控制，团队支援 |
| ironwall | FRONTLINER坦克 | 物理 | 火 | 近战，AOE清怪，战场压制 |

## 三、英雄技能配置

### 3.1 ember (DPS/火+冰)

| 槽位 | 技能ID | 显示名 | 类型 | 伤害类型 | 设计理由 |
|------|--------|--------|------|----------|----------|
| BASIC | ember_shot | 火弹 | 新建 | FIRE | 远程火属性普攻，保持输出节奏 |
| SMALL_A | ice_arrow | 冰箭术 | 现有 | ICE | 3发冰箭，tracking，冰属性控制 |
| SMALL_B | burning_hands | 火焰之手 | 现有 | FIRE | 扇形持续灼烧，近战AOE，火属性爆发 |
| ULTIMATE | inferno | 烈焰风暴 | 改名原fireball_basic | FIRE | 大火球AOE，视觉华丽，高伤害 |

**战斗逻辑**：
- 远程普攻输出（ember_shot）
- 小技能A：冰箭减速控制（ice_arrow）
- 小技能B：近战火焰AOE爆发（burning_hands）
- 大招：烈焰风暴清场（inferno）

### 3.2 moss (SUPPORT/水+光)

| 槽位 | 技能ID | 显示名 | 类型 | 伤害类型 | 设计理由 |
|------|--------|--------|------|----------|----------|
| BASIC | moss_shot | 种子弹 | 新建 | PHYSICAL | 远程物理普攻，绿色种子形态 |
| SMALL_A | water_wave | 水浪术 | 现有 | PHYSICAL | 弹射2次，LOWEST_HP目标，控制+伤害 |
| SMALL_B | small_laser_beam | 小激光术 | 现有 | PHYSICAL | 5道光柱120度扇区，远程AOE |
| ULTIMATE | bubble_bomb_array | 气泡炸弹阵 | 现有 | ICE | 8颗延时炸弹，大范围控制 |

**战斗逻辑**：
- 远程普攻输出（moss_shot）
- 小技能A：水浪弹射清怪（water_wave）
- 小技能B：激光扇区覆盖（small_laser_beam）
- 大招：气泡炸弹阵大范围控制（bubble_bomb_array）

### 3.3 ironwall (FRONTLINER/物理+火)

| 槽位 | 技能ID | 显示名 | 类型 | 伤害类型 | 设计理由 |
|------|--------|--------|------|----------|----------|
| BASIC | ironwall_strike | 盾击 | 新建 | PHYSICAL | 近战普攻，短射程200px |
| SMALL_A | falling_meteor | 落石流星 | 现有 | PHYSICAL+fire | 从天坠落，AOE=80，混合伤害 |
| SMALL_B | evil_eye_laser | 魔眼激光 | 现有 | FIRE | 椭圆扫描，无限目标，中距离压制 |
| ULTIMATE | flying_sword_storm | 飞剑风暴 | 现有 | PHYSICAL | 10柄飞剑从天降，大范围AOE |

**战斗逻辑**：
- 近战普攻输出（ironwall_strike，短射程）
- 小技能A：落石流星AOE清怪（falling_meteor）
- 小技能B：魔眼激光扫描压制（evil_eye_laser）
- 大招：飞剑风暴大范围清场（flying_sword_storm）

## 四、技能数值设计

### 4.1 设计目标

DPS比例 铁墙:苔藓:余烬 ≈ 0.7:1.0:1.4

### 4.2 英雄基础属性

| 英雄 | attack | 说明 |
| --- | --- | --- |
| ember | 750 | DPS定位，高攻击 |
| moss | 500 | 辅助定位，适中攻击 |
| ironwall | 450 | 坦克定位，适度攻击（原300过低） |

### 4.3 ember 技能数值 (目标DPS ≈ 280)

| 技能 | base_damage | skill_coeff | cooldown | range | 单次伤害 | 理论DPS |
| --- | --- | --- | --- | --- | --- | --- |
| ember_shot | 8 | 0.18 | 2.5s | 600 | 143 | 57 |
| ice_arrow | 10 | 0.45 | 6.0s | 500 | 1043 | 174 |
| burning_hands | 8 | 0.25 | 7.0s | 300 | 1764 | 252 |
| **合计(理论)** | | | | | | **483** |
| **合计(60%利用率)** | | | | | | **290** |

### 4.4 moss 技能数值 (目标DPS ≈ 200)

| 技能 | base_damage | skill_coeff | cooldown | range | 单次伤害 | 理论DPS |
| --- | --- | --- | --- | --- | --- | --- |
| moss_shot | 8 | 0.15 | 3.0s | 500 | 83 | 28 |
| water_wave | 15 | 0.50 | 7.0s | 500 | 795 | 114 |
| small_laser_beam | 8 | 0.40 | 6.0s | 850 | 1040 | 173 |
| **合计(理论)** | | | | | | **315** |
| **合计(60%利用率)** | | | | | | **189** |

### 4.5 ironwall 技能数值 (目标DPS ≈ 140)

| 技能 | base_damage | skill_coeff | cooldown | range | 单次伤害 | 理论DPS |
| --- | --- | --- | --- | --- | --- | --- |
| ironwall_strike | 15 | 0.30 | 1.5s | 200 | 150 | 100 |
| falling_meteor | 40 | 1.20 | 6.0s | 600 | 580 | 97 |
| evil_eye_laser | 20 | 0.60 | 6.0s | 700 | 290 | 48 |
| **合计(理论)** | | | | | | **245** |
| **合计(60%利用率)** | | | | | | **147** |

### 4.6 DPS比例验证

| 英雄 | 实际DPS | 比例 | 目标比例 |
| --- | --- | --- | --- |
| ironwall | 147 | 0.78 | 0.7 |
| moss | 189 | 1.0 | 1.0 |
| ember | 290 | 1.53 | 1.4 |

### 4.3 普攻视觉形态

| 英雄 | 普攻ID | projectile_kind | 视觉描述 |
|------|--------|-----------------|----------|
| ember | ember_shot | FIREBALL(1) | 小型火球，橙红色，火焰尾迹 |
| moss | moss_shot | MECHANICAL_BULLET(0) | 绿色种子，叶子纹理，旋转飞行 |
| ironwall | ironwall_strike | BURNING_HANDS(6)极简版 | 扇形近战，短射程，无持续灼烧 |

**视觉差异化**：
- ember_shot：火球形态（FIREBALL类型），与ember的火元素主题一致
- moss_shot：种子形态（MECHANICAL_BULLET），绿色自然风格，与moss的辅助定位一致
- ironwall_strike：扇形近战（BURNING_HANDS极简版），无投射物，符合近战坦克定位

## 五、怒气系统设计

### 5.1 设计目标

大招攒怒满气时间约20~25秒。

### 5.2 怒气获取机制

两个来源：**攻击怒气**和**受伤怒气**。

**攻击怒气**：造成伤害时获得怒气

- 公式：`rage += damage * rage_gain_rate`
- 统一系数：`rage_gain_rate = 2.0%`

**受伤怒气**：受到伤害时获得怒气

- 公式：`rage += damage_taken * damage_taken_rage_rate`
- 每个英雄独立系数（见下表）

| 英雄 | damage_taken_rage_rate | 设计理由 |
| --- | --- | --- |
| ember | 0.3% | DPS定位，不依赖受伤攒怒 |
| moss | 0.6% | 辅助定位，适度受伤攒怒 |
| ironwall | 1.0% | 前排坦克，频繁受伤需更快攒怒 |

**怒气上限**：100

### 5.3 满怒时间预估

假设战斗中英雄每秒受到伤害约100 DPS：

| 英雄 | 攻击怒气/秒 | 受伤怒气/秒 | 总怒气/秒 | 满怒时间 |
| --- | --- | --- | --- | --- |
| ember | 5.8 | 0.3 | 6.1 | 16.4秒 |
| moss | 3.78 | 0.6 | 4.38 | 22.8秒 |
| ironwall | 2.94 | 1.0 | 3.94 | 25.4秒 |

### 5.4 怒气消耗

- 大招释放时消耗全部怒气（rage = 0）
- 不消耗其他资源

## 六、现有技能category修改

### 6.1 category变更汇总

| 技能ID | 原category | 新category | 变化原因 |
|--------|-----------|-----------|----------|
| fireball_basic | BASIC(0) | ULTIMATE(3) | 高伤害+华丽视觉，改名为inferno |
| ice_arrow | SMALL_A(1) | SMALL_A(1) | 不变 |
| burning_hands | SMALL_A(1) | SMALL_B(2) | 近战AOE，适合小技能B |
| water_wave | BASIC(0) | SMALL_A(1) | 弹射机制，提升为小技能 |
| small_laser_beam | SMALL_A(1) | SMALL_B(2) | 远程AOE，适合小技能B |
| bubble_bomb_array | SMALL_A(1) | ULTIMATE(3) | 大范围延时炸弹，适合大招 |
| falling_meteor | SMALL_B(2) | SMALL_A(1) | AOE伤害，适合小技能A |
| evil_eye_laser | SMALL_B(2) | SMALL_B(2) | 不变 |
| flying_sword_storm | SMALL_A(1) | ULTIMATE(3) | 10柄飞剑，视觉华丽，适合大招 |

### 6.2 skill-values.csv数值更新

需要更新CSV中的category字段，以及添加新普攻技能的数值。

## 七、新普攻技能需要创建的资源

### 7.1 需要新建的.tres文件

| 文件路径 | 技能ID | 基于模板 |
|----------|--------|----------|
| game/resources/skills/skill_defs/ember_shot.tres | ember_shot | 基于rock_toss |
| game/resources/skills/skill_defs/moss_shot.tres | moss_shot | 基于bone_throw |
| game/resources/skills/skill_defs/ironwall_strike.tres | ironwall_strike | 基于burning_hands(极简版) |

### 7.2 需要新建的视觉.tres文件

| 文件路径 | 技能ID | 基于模板 |
|----------|--------|----------|
| game/resources/skills/skill_visual_defs/ember_shot.tres | ember_shot | 基于fireball_basic(缩小版) |
| game/resources/skills/skill_visual_defs/moss_shot.tres | moss_shot | 基于rock_toss(改绿色) |
| game/resources/skills/skill_visual_defs/ironwall_strike.tres | ironwall_strike | 基于burning_hands(极简版) |

## 八、hero-values.csv更新

### 8.1 基础属性更新

```text
# ironwall attack 从300提升到450
25,hero,ironwall,stats,attack,450,
```

### 8.2 新增受伤怒气系数

```text
# 新增 damage_taken_rage_rate
新增,hero,ember,stats,damage_taken_rage_rate,0.003,
新增,hero,moss,stats,damage_taken_rage_rate,0.006,
新增,hero,ironwall,stats,damage_taken_rage_rate,0.01,
```

### 8.3 技能配置更新

```text
# ember
10,hero,ember,skills,skill_1,ember_shot
11,hero,ember,skills,skill_2,ice_arrow
新增,hero,ember,skills,skill_3,burning_hands
新增,hero,ember,skills,skill_4,inferno

# moss
20,hero,moss,skills,skill_1,moss_shot
21,hero,moss,skills,skill_2,water_wave
新增,hero,moss,skills,skill_3,small_laser_beam
新增,hero,moss,skills,skill_4,bubble_bomb_array

# ironwall
30,hero,ironwall,skills,skill_1,ironwall_strike
31,hero,ironwall,skills,skill_2,falling_meteor
新增,hero,ironwall,skills,skill_3,evil_eye_laser
新增,hero,ironwall,skills,skill_4,flying_sword_storm
```

## 九、实施步骤

1. **Phase 1**：重写RoleAI（独立触发 + 释放队列 + 受伤怒气）
2. **Phase 2**：创建新普攻技能.tres文件（ember_shot, moss_shot, ironwall_strike）
3. **Phase 3**：更新现有技能的category
4. **Phase 4**：更新skill-values.csv（技能数值调整）
5. **Phase 5**：更新hero-values.csv（基础属性 + 受伤怒气系数 + 技能配置）
6. **Phase 6**：重命名fireball_basic为inferno
7. **Phase 7**：测试验证
