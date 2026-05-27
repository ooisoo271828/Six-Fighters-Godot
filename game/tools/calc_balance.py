import math

# ═══ 命中系统参数（已确认） ═══
SLOPE = 0.05
HQ_MIN = 0.05
HQ_MAX = 0.95
GLANCE_MIN = 0.3
GLANCE_MAX = 0.5
DEFLECT_MULT = 0.5
K = 7.0
MIN_PROB = 0.05

DEF_CONST = 10000.0
ATK_CONST = 8000.0

# ═══ 英雄属性（已确认新ACC/EVA） ═══
heroes = {
    "Ember":     {"acc": 52, "eva": 16, "atk": 750, "def": 1111, "hp": 600, "crit_rate": 28, "crit_power": 45},
    "Moss":      {"acc": 50, "eva": 15, "atk": 500, "def": 2500, "hp": 600, "crit_rate": 10, "crit_power": 18},
    "Ironwall":  {"acc": 48, "eva": 14, "atk": 300, "def": 6667, "hp": 600, "crit_rate": 8,  "crit_power": 15},
}

# ═══ 英雄技能（来自 hero_registry.gd + skill-values.csv） ═══
# Ember: basic=fireball_basic, small_a=ice_arrow
# Moss: basic=water_wave, small_a=small_laser_beam
# Ironwall: basic=burning_hands, small_a=falling_meteor
hero_skills = {
    "Ember":    {"coeff": 1.2, "base_dmg": 20, "cooldown": 4.0},   # fireball_basic
    "Moss":     {"coeff": 0.5, "base_dmg": 15, "cooldown": 5.0},   # water_wave
    "Ironwall": {"coeff": 0.3, "base_dmg": 10, "cooldown": 5.0},   # burning_hands
}

# ═══ 敌人命中属性（已确认） ═══
enemy_acc_eva = {
    "Minion": {"acc": 37.5, "eva": 11.2},
    "Elite":  {"acc": 55.0, "eva": 16.5},
    "Boss":   {"acc": 65.0, "eva": 19.5},
}

# ═══ 敌人技能配置 ═══
enemy_skills = {
    "Minion": {"skill": "rock_toss",      "coeff": 0.2,  "base_dmg": 8,  "cooldown": 0.9},
    "Elite":  {"skill": "fireball_basic",  "coeff": 1.2,  "base_dmg": 20, "cooldown": 4.0},
    "Boss":   {"skill": "ice_arrow",       "coeff": 0.5,  "base_dmg": 12, "cooldown": 3.5},
}

enemy_crit_rate = 12.0
enemy_crit_power = 20.0

# ═══ 计算函数 ═══
def calc_hq(acc, eva):
    x = SLOPE * (acc - eva)
    sig = 1.0 / (1.0 + math.exp(-x))
    return max(HQ_MIN, min(HQ_MAX, sig))

def calc_round_table(hq):
    glance_avg = (GLANCE_MIN + GLANCE_MAX) / 2.0
    rows = [
        {"name": "MISS",    "m": 0.0},
        {"name": "GLANCE",  "m": glance_avg},
        {"name": "DEFLECT", "m": DEFLECT_MULT},
        {"name": "HIT",     "m": 1.0},
    ]
    weights = [math.exp(-K * abs(r["m"] - hq)) for r in rows]
    total = sum(weights)
    probs = [w / total for w in weights]
    adjusted = [max(p, MIN_PROB) for p in probs]
    sum_adj = sum(adjusted)
    return {rows[i]["name"]: adjusted[i] / sum_adj for i in range(4)}

def calc_hit_mult(rt):
    glance_avg = (GLANCE_MIN + GLANCE_MAX) / 2.0
    return rt["HIT"] * 1.0 + rt["GLANCE"] * glance_avg + rt["DEFLECT"] * DEFLECT_MULT

def calc_crit_mult(crit_rate, crit_power):
    cr = min(crit_rate / 100.0, 0.8)
    cm = 1.0 + crit_power / 100.0
    return 1.0 * (1.0 - cr) + cm * cr

def calc_raw_damage(atk, coeff, base_dmg, defender_def):
    eff_atk = atk * ATK_CONST / (ATK_CONST + atk)
    growth = coeff * eff_atk
    raw = base_dmg + growth
    def_mult = DEF_CONST / (DEF_CONST + defender_def)
    return raw * def_mult

def hero_dps(h, sk, enemy_ev, enemy_def):
    eff_atk = h["atk"] * ATK_CONST / (ATK_CONST + h["atk"])
    growth = sk["coeff"] * eff_atk
    raw = (sk["base_dmg"] + growth) * (DEF_CONST / (DEF_CONST + enemy_def))
    hq = calc_hq(h["acc"], enemy_ev)
    rt = calc_round_table(hq)
    hm = calc_hit_mult(rt)
    cm = calc_crit_mult(h["crit_rate"], h["crit_power"])
    return raw * hm * cm / sk["cooldown"]

def enemy_dps(e_acc, e_atk, e_crit_rate, e_crit_power, sk, hero_ev, hero_def):
    raw = calc_raw_damage(e_atk, sk["coeff"], sk["base_dmg"], hero_def)
    hq = calc_hq(e_acc, hero_ev)
    rt = calc_round_table(hq)
    hm = calc_hit_mult(rt)
    cm = calc_crit_mult(e_crit_rate, e_crit_power)
    return raw * hm * cm / sk["cooldown"]

# ═══ STEP 1: 敌人 ATK ═══
print("=" * 70)
print("  STEP 1: 敌人 ATK（目标 TTK vs Ember）")
print("=" * 70)

target_enemy_ttks = {"Minion": 7.0, "Elite": 10.0, "Boss": 15.0}
found_atk = {}

for etype in ["Minion", "Elite", "Boss"]:
    es = enemy_acc_eva[etype]
    sk = enemy_skills[etype]
    target_ttk = target_enemy_ttks[etype]
    h = heroes["Ember"]

    best_atk = 1
    best_diff = 999999
    for atk_test in range(1, 5000):
        dps = enemy_dps(es["acc"], atk_test, enemy_crit_rate, enemy_crit_power, sk, h["eva"], h["def"])
        if dps > 0:
            ttk = h["hp"] / dps
            diff = abs(ttk - target_ttk)
            if diff < best_diff:
                best_diff = diff
                best_atk = atk_test

    found_atk[etype] = best_atk
    dps = enemy_dps(es["acc"], best_atk, enemy_crit_rate, enemy_crit_power, sk, h["eva"], h["def"])
    raw = calc_raw_damage(best_atk, sk["coeff"], sk["base_dmg"], h["def"])
    ttk = h["hp"] / dps if dps > 0 else 999
    eff_atk = best_atk * ATK_CONST / (ATK_CONST + best_atk)
    print(f"  {etype:8s}: ATK={best_atk:5d}  skill={sk['skill']:20s} coeff={sk['coeff']}")
    print(f"            eff_ATK={eff_atk:.0f}  growth={sk['coeff']*eff_atk:.0f}  raw_hit={raw:.0f}")
    print(f"            DPS={dps:.0f}  TTK vs Ember={ttk:.1f}s (target={target_ttk}s)")
    print()

# ═══ STEP 2: 固定敌人 DEF，算英雄 DPS，反推 HP ═══
print("=" * 70)
print("  STEP 2: 敌人 DEF + HP（固定DEF，算6英雄总DPS，反推HP）")
print("=" * 70)

# 敌人 DEF 设定（游戏设计层面考虑）
# Minion: 较低 DEF，容易被清理
# Elite: 中等 DEF，需要集火
# Boss: 高 DEF，持久战
enemy_def_plan = {"Minion": 1500, "Elite": 4000, "Boss": 10000}
target_hero_ttks = {"Minion": 2.0, "Elite": 4.0, "Boss": 12.0}

print()
for etype in ["Minion", "Elite", "Boss"]:
    es = enemy_acc_eva[etype]
    def_val = enemy_def_plan[etype]
    target_ttk = target_hero_ttks[etype]

    total_dps = 0
    print(f"  {etype} (DEF={def_val}):")
    for hname, h in heroes.items():
        sk = hero_skills[hname]
        dps = hero_dps(h, sk, es["eva"], def_val)
        total_dps += dps
        print(f"    {hname:10s}: DPS={dps:.1f}")
    implied_hp = round(target_ttk * total_dps / 100) * 100
    actual_ttk = implied_hp / total_dps if total_dps > 0 else 999
    print(f"    Total DPS={total_dps:.0f}  HP={implied_hp}  TTK={actual_ttk:.1f}s (target={target_ttk}s)")
    print()

# ═══ STEP 3: 汇总验证 ═══
print("=" * 70)
print("  STEP 3: 全场景验证")
print("=" * 70)

# 构建最终敌人数据
final = {}
for etype in ["Minion", "Elite", "Boss"]:
    es = enemy_acc_eva[etype]
    sk = enemy_skills[etype]
    def_val = enemy_def_plan[etype]
    atk_val = found_atk[etype]

    total_dps = 0
    for hname, h in heroes.items():
        hsk = hero_skills[hname]
        total_dps += hero_dps(h, hsk, es["eva"], def_val)
    hp = round(target_hero_ttks[etype] * total_dps / 100) * 100

    final[etype] = {
        "acc": es["acc"], "eva": es["eva"], "atk": atk_val, "def": def_val, "hp": hp,
        "skill": sk["skill"], "coeff": sk["coeff"], "base_dmg": sk["base_dmg"], "cooldown": sk["cooldown"],
    }

print()
print("  --- 最终配置 ---")
print(f"  {'Type':8s} {'ACC':>5s} {'EVA':>5s} {'ATK':>5s} {'DEF':>6s} {'HP':>6s} {'Skill':20s}")
print("  " + "-" * 65)
for etype, r in final.items():
    print(f"  {etype:8s} {r['acc']:5.1f} {r['eva']:5.1f} {r['atk']:5d} {r['def']:6d} {r['hp']:6d} {r['skill']:20s}")

print()

# 敌人打英雄
print("  --- 敌人打各英雄 ---")
for etype, r in final.items():
    sk = {"skill": r["skill"], "coeff": r["coeff"], "base_dmg": r["base_dmg"], "cooldown": r["cooldown"]}
    for hname, h in heroes.items():
        dps = enemy_dps(r["acc"], r["atk"], enemy_crit_rate, enemy_crit_power, sk, h["eva"], h["def"])
        raw = calc_raw_damage(r["atk"], r["coeff"], r["base_dmg"], h["def"])
        ttk = h["hp"] / dps if dps > 0 else 999
        print(f"  {etype:8s} -> {hname:10s}: raw={raw:.0f}  DPS={dps:.0f}  TTK={ttk:.1f}s")

print()

# 英雄打敌人
print("  --- 英雄打各敌人 ---")
for hname, h in heroes.items():
    sk = hero_skills[hname]
    for etype, r in final.items():
        dps = hero_dps(h, sk, r["eva"], r["def"])
        raw = calc_raw_damage(h["atk"], sk["coeff"], sk["base_dmg"], r["def"])
        ttk = r["hp"] / dps if dps > 0 else 999
        print(f"  {hname:10s} -> {etype:8s}: raw={raw:.0f}  DPS={dps:.0f}  TTK={ttk:.1f}s")

print()

# 6 英雄集火
print("  --- 6 英雄集火敌人 ---")
for etype, r in final.items():
    total_dps = 0
    for hname, h in heroes.items():
        hsk = hero_skills[hname]
        total_dps += hero_dps(h, hsk, r["eva"], r["def"])
    ttk = r["hp"] / total_dps if total_dps > 0 else 999
    print(f"  6 heroes -> {etype:8s}: HP={r['hp']}  total_DPS={total_dps:.0f}  TTK={ttk:.1f}s")

print()

# 敌人互打
print("  --- 敌人互打 ---")
for a_type in ["Minion", "Elite", "Boss"]:
    for d_type in ["Minion", "Elite", "Boss"]:
        if a_type == d_type:
            continue
        a = final[a_type]
        d = final[d_type]
        sk = {"skill": a["skill"], "coeff": a["coeff"], "base_dmg": a["base_dmg"], "cooldown": a["cooldown"]}
        dps = enemy_dps(a["acc"], a["atk"], enemy_crit_rate, enemy_crit_power, sk, d["eva"], d["def"])
        raw = calc_raw_damage(a["atk"], a["coeff"], a["base_dmg"], d["def"])
        ttk = d["hp"] / dps if dps > 0 else 999
        print(f"  {a_type:8s} -> {d_type:8s}: raw={raw:.0f}  DPS={dps:.0f}  TTK={ttk:.1f}s")

print()

# 命中分布
print("  --- 命中分布 ---")
print(f"  {'Matchup':30s} {'MISS':>6s} {'GLANCE':>7s} {'DEFLECT':>8s} {'HIT':>6s} {'E[dmg]':>7s}")
print("  " + "-" * 70)

all_matchups = []
for a_name, a in heroes.items():
    for d_name, d in heroes.items():
        if a_name == d_name:
            continue
        hq = calc_hq(a["acc"], d["eva"])
        rt = calc_round_table(hq)
        hm = calc_hit_mult(rt)
        all_matchups.append((f"{a_name}->{d_name}", rt, hm))

for etype, r in final.items():
    for hname, h in heroes.items():
        hq = calc_hq(r["acc"], h["eva"])
        rt = calc_round_table(hq)
        hm = calc_hit_mult(rt)
        all_matchups.append((f"{etype}->{hname}", rt, hm))

        hq2 = calc_hq(h["acc"], r["eva"])
        rt2 = calc_round_table(hq2)
        hm2 = calc_hit_mult(rt2)
        all_matchups.append((f"{hname}->{etype}", rt2, hm2))

for label, rt, hm in all_matchups:
    print(f"  {label:30s} {rt['MISS']*100:5.1f}% {rt['GLANCE']*100:6.1f}% {rt['DEFLECT']*100:7.1f}% {rt['HIT']*100:5.1f}% {hm:7.3f}")
