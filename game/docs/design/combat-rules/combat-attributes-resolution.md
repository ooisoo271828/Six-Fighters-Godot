# Combat Attributes Resolution (Hit/Crit/Element)

Status: Draft
Version: v0.1
Owner: Design
Last Updated: 2026-03-20
Scope: Combat attribute resolution for v1 battles, including hit/miss, crit, elemental damage, and elemental status (DOT/CC) stacking; defines stable tokens and the integration interface for combat-core.
Related: docs/design/combat-rules/combat-core-decision-freeze-v1.md; docs/design/combat-rules/combat-core-l3-squad-autonomy.md; docs/design/combat-rules/values/combat-attributes-resolution-values.csv; docs/design/combat-rules/combat-data-table-families-v1.md (table family **D**)

Notes:
- Hit/Crit use an RNG probability model (non-deterministic per roll, deterministic per encounter RNG seed in implementation).
- Elemental statuses share the same "stack and refresh duration" state model, but the *effect types* differ:
  - `burn/poison` are DOT,
  - `frost` is CC (and can also have DOT if configured),
  - `shock` is a defense-debuff (no DOT tick damage).

## 1. Terminology (Stable Tokens)

### 1.1 Attack Input (conceptual)
- `baseDamage`: the pre-resolution damage amount aggregated from hero skill scaling, role modifiers, and other multipliers; resolution is responsible only for hit/crit/element/resist/status effects.
- `damageType`: the damage category of the attack instance.
  - `physical`: no elemental status application.
  - `elemental_fire | elemental_ice | elemental_lightning | elemental_poison` (v1 baseline set; can be extended).
- `attackerStats`: numeric combat stat channels on the attacker (examples: accuracy, crit_rate, crit_power, and elemental power).
- `targetStats`: numeric combat stat channels on the target (examples: evasion, element resistance per element, and defensive modifiers).

### 1.2 Resolution Outputs (conceptual)
- `hitOutcome`: one of `{miss,glance,deflect,hit}`.
- `crit`: whether the attack is a critical hit (only meaningful when `hitOutcome==hit`).
- `hitDamageMultiplier`: the damage multiplier derived from the hit outcome before applying any critical multiplier.
- `instantDamage`: damage applied immediately by the hit.
- `statusUpdate`: if the attack applies a status effect, how the corresponding status is updated (stack count and duration).
- `statusTickEvents`: future DOT/CC tick events driven by the status system (scheduled by duration and tick interval).

## 2. Hit Outcome Round Table (Miss/Glance/Deflect/Hit)

### 2.1 Hit quality score model (from accuracy/evasion)
When the attack is a direct damage instance that is eligible for accuracy checks:
1. Compute `hitQuality` from `attackerStats.accuracy` and `targetStats.evasion` using the parameterized curve in `docs/design/combat-rules/values/combat-attributes-resolution-values.csv`.
2. Clamp `hitQuality` to `[0,1]` using `hit_chance_min` / `hit_chance_max`.

For v1, `hitQuality` is treated as the expected "damage-quality" and will monotonically increase as player hit improves.

Implementation-facing formula shape (values live in CSV):
- `hitQuality = clamp(hit_chance_min, hit_chance_max, f_accuracy_evasion(attackerAccuracy, targetEvasion))`

### 2.2 Outcome damage multipliers (by hitOutcome)
Let the hit outcome be selected from `{miss,glance,deflect,hit}`:
- `miss`:
  - `hitDamageMultiplier = 0`
- `glance` (擦伤):
  - `hitDamageMultiplier` is rolled uniformly in `[glancing_damage_multiplier_min, glancing_damage_multiplier_max]` (recommended 0.10~0.20)
- `deflect` (偏斜):
  - `hitDamageMultiplier = deflect_damage_multiplier` (recommended 0.50)
- `hit`:
  - `hitDamageMultiplier = 1`

### 2.3 Round table weights (softmax around the expected multiplier)
1. Convert `hitQuality` into an "expected hit multiplier" `E`.
   - v1 mapping: `E = hitQuality`.
2. Define representative multipliers `m_i` for each outcome:
   - `miss`: `m_miss = 0`
   - `glance`: `m_glance = avg(glancing_damage_multiplier_min, glancing_damage_multiplier_max)`
   - `deflect`: `m_deflect = deflect_damage_multiplier`
   - `hit`: `m_hit = 1`
3. Compute unnormalized weights:
   - `w_i = exp(-hit_roundtable_softmax_k * |m_i - E|)`
4. Convert weights into probabilities:
   - `p_i = w_i / sum(w_j)`

Monotonic behavior guarantee (intent):
- As `hitQuality` increases, `E` moves towards `1`, which makes outcomes with lower mitigation (more damage, closer to `m_i`) more likely, and pushes `glance/deflect` towards lower probability.

### 2.4 Pruning rule ("最多挤出两种结果")
To ensure at most two outcomes can be effectively removed due to being too unlikely:
1. Prune any outcome with `p_i < hit_roundtable_min_prob`.
2. After pruning, if remaining outcomes count `< hit_roundtable_min_outcomes`, undo and keep only the top-`hit_roundtable_min_outcomes` outcomes by original `p_i`, then renormalize.

Implementation note:
- With recommended `hit_roundtable_min_outcomes=2`, the extreme case will retain exactly 2 outcomes on the round table.

### 2.5 Roll & finalize outcome
1. Draw `rng in [0,1)`.
2. Select one outcome from the remaining renormalized probabilities.
3. If selected outcome is `glance`, roll `hitDamageMultiplier` uniformly within its configured range.

## 3. Critical Hit Resolution (after Hit)

### 3.1 Crit chance model
If `hitOutcome==hit`, compute:
- `critChance` from `attackerStats.crit_rate` using configured parameters in `combat-attributes-resolution-values.csv`.
- Clamp to configured probability range.
Otherwise:
- `crit=false` and `critMultiplier=1` for this instance.

### 3.2 Roll
- Draw `rng in [0,1)`.
- If `rng < critChance` => `crit=true`, else `crit=false`.

### 3.3 Crit multiplier model
- Determine `critMultiplier` from `attackerStats.crit_power` using configured parameters in the CSV.
- Apply `critMultiplier` to the eligible damage components according to the module rules below.

Crit component rules (symbolic; coefficients in CSV):
- Immediate damage: `instantDamage` is multiplied by `critMultiplier` when `crit=true`.
- Element status potency:
  - The elemental status application potency (affecting DOT/CC strength) inherits from the triggering hit instance.
  - DOT tick damage may inherit crit or not, controlled by a CSV token.

## 4. Elemental Damage and Resistance

### 4.1 Element-to-status mapping (v1 baseline)
- `elemental_fire` -> `burn`
- `elemental_ice` -> `frost` (CC; DOT ticks if configured)
- `elemental_lightning` -> `shock` (defense debuff; no DOT ticks)
- `elemental_poison` -> `poison` (DOT)

If `damageType` is `physical`, skip all element resistance and status application.

### 4.2 Resistance multiplier model
When the attack is elemental:
1. Read defender resistance for the corresponding element: `targetStats.element_resistance[element]`.
2. Compute `elementDamageMultiplier` using the parameterized curve in the CSV.
3. Combine it with the damage amount from hit/crit stages.

Resolution ordering requirement:
- Hit outcome is evaluated first.
- Crit is evaluated next (only when `hitOutcome==hit`).
- Element resistance is applied to the damage produced by hit/crit.

## 5. Elemental Status Application (Stack + Refresh)

### 5.1 Status eligibility
This section applies to *elemental* statuses (burn/frost/shock/poison).
If and only if:
- the attack is `hitOutcome != miss`, and
- `damageType` is `elemental_*`,
then apply/update the corresponding status.

### 5.2 Stack policy (identical element)
For each elemental status type:
- Each eligible hit updates stacks and/or refreshes duration according to the configured stack/refresh policy in the CSV.
- Stacks are capped by `status_stack_max` for that status.
- When at cap:
  - duration refresh is still allowed (per policy),
  - but additional stacks do not exceed the cap.

### 5.3 DOT tick model (burn/poison/frost)
Only DOT-capable statuses produce tick events:
- `burn`
- `poison`
- `frost` (if tick coefficients are configured)

For each DOT status:
- `dot_tick_interval` defines tick pacing (CSV).
- `dot_tick_damage` is computed from:
  - the status application potency derived from the triggering hit instance,
  - per-status DOT coefficients (CSV),
  - current stack count (CSV).

DOT tick ordering:
- DOT ticks occur after the initial instant damage resolution.
- DOT ticks are independent from new incoming damage rolls; they only depend on the stored status state.

### 5.4 CC model (frost as v1 example)
Some elemental statuses may apply CC (e.g., `frost`):
- CC strength is derived from status stack count via configured coefficients in the CSV.
- CC is applied when the status is active (duration controlled by the status model).

### 5.5 Shock (Defense Debuff, no DOT)
`shock` (感电) does not deal sustained DOT damage. Instead, while `shock` is active, it reduces the target's `damage_mitigation` (or equivalent defense/armor mitigation value), thereby increasing the damage dealt to the target.

#### 5.5.1 Shock eligibility
- shock is applied when the attack is `hitOutcome != miss` and `damageType == elemental_lightning`.

#### 5.5.2 Shock stacking & max_refresh policy
shock uses `max_refresh`:
1. Each eligible hit computes a candidate shock intensity (stored as `shockStacks`) derived from the triggering hit instance.
   - v1 candidate rule (no extra parameters): `candidateShockStacks = round(hitDamageMultiplier * shock_status_stack_max)`
   - then clamp to `[1 .. shock_status_stack_max]`.
2. If the target already has `shock` active:
   - if `candidateShockStacks` is higher than current `shockStacks`, overwrite `shockStacks` and refresh duration,
   - otherwise, only refresh duration (keep current stacks/intensity).
3. If the target does not have `shock` active, set `shockStacks=candidateShockStacks` and start duration.

Candidate note:
- `hitDamageMultiplier` comes from the hit outcome round table (miss/glance/deflect/hit).

#### 5.5.3 Shock duration scaling
Shock duration scales with the stored `shockStacks` using existing CSV parameters:
- `shockDuration = shock_status_duration_base_sec + shock_status_duration_per_stack_add_sec * (shockStacks - 1)`

#### 5.5.4 Shock damage taken multiplier (instantDamage only)
While shock is active, it increases incoming *instantDamage* to the shocked target:
1. For each new incoming damage instance with `isInstantDamage=true`:
   - compute the regular hit/crit multipliers,
   - apply elemental resistance multiplier (if elemental),
   - then multiply by `shockDamageTakenMultiplier`.
2. Define `shockDamageTakenMultiplier` from stored `shockStacks` using the new CSV parameters:
   - `shockDamageTakenMultiplier = clamp(shock_damage_taken_multiplier_min, shock_damage_taken_multiplier_max, shock_damage_taken_multiplier_base + shock_damage_taken_multiplier_per_extra_stack * (shockStacks - 1))`
3. DOT tick events are NOT amplified by shock.

Important timing rule:
- The application instance that *creates* shock does not benefit from the debuff; only subsequent instantDamage instances are amplified.

### 5.6 Stun (Hard CC)
Some skills may carry a `stun` effect (provided as part of the `attack_instance` by combat-core).

#### 5.6.1 Stun eligibility
Stun is evaluated only when:
- `hitOutcome != miss` (aligned with elemental status eligibility),
- and the `attack_instance` includes `stunChance` and `stunDurationBaseSec` from the originating skill configuration.

#### 5.6.2 Stun chance roll
- Roll RNG using `stunChance` from the skill configuration.
- If the roll fails, do not apply stun.

#### 5.6.3 Stun duration contest (attacker vs target)
Let:
- `attackerStunPower` be the attacker's `stun_power` channel,
- `targetStunResistance` be the target's `stun_resistance` channel.

Compute a duration correction multiplier:
1. Compute a contest ratio:
   - `stunContest = attackerStunPower / (targetStunResistance + stun_resistance_offset)`
2. Map ratio into a multiplier:
   - `stunDurationMultiplier = clamp(stun_duration_multiplier_base + stun_duration_multiplier_scale * (stunContest - 1), stun_duration_multiplier_min, stun_duration_multiplier_max)`
3. Apply multiplier to the skill's base duration:
   - `stunDuration = clamp(stunDurationBaseSec * stunDurationMultiplier, stun_duration_min_sec, stun_duration_max_sec)`

The contest function `f_contest(...)` is defined by the generic contest/clamp parameters in:
- `docs/design/combat-rules/values/combat-attributes-resolution-values.csv`

#### 5.6.4 Stun stack / coexist policy
- `stun` can coexist with elemental statuses:
  - DOT ticks for burn/poison/frost if active,
  - CC for frost if active,
  - shock debuff for instantDamage if active.
- If the target is already stunned when a new stun is applied:
  - extend by taking the larger remaining duration (no infinite stacking).
  - implementation can treat this as `stunRemaining = max(stunRemaining, newStunDuration)`.

#### 5.6.5 Stun behavior impact (combat-core integration)
While `stun` is active, the combat-core autonomous pipeline must replace the target hero's normal role pipeline with a "stunned" behavior:
- role action selection is skipped,
- opportunity action selection is skipped,
- the hero only plays the stun idle/animation and does not execute role actions until stun expires.

## 6. Integration Interface with combat-core (v1)

Combat-core owns encounter flow and autonomous behavior. This module owns only the resolution semantics of a produced attack instance.

### 6.1 Call site (conceptual)
After the autonomous pipeline selects an action that produces one or more `attack_instance`s:
- For each `attack_instance`, combat-core calls `resolveAttackOutcome(...)`.

### 6.2 Returned state (conceptual)
`resolveAttackOutcome(attacker, target, attack_instance) ->`
- `hitOutcome: miss|glance|deflect|hit`
- `crit: bool`
- `hitDamageMultiplier: number`
- `instantDamage: number`
- `statusUpdate: { statusToken, addedStacks, newStackCount, durationRemaining }`
  - where `statusToken` may be one of `{burn,frost,shock,poison,stun}`
- `scheduledTicks: tick events derived from status state (burn/poison/frost only; shock has none)`

### 6.3 Determinism note for v1 readability
While hit/crit use RNG probability:
- implementation should use an encounter-stable RNG seed so replay/debug tooling can reproduce results,
- and combat-core should emit consistent VFX/SFX triggers for `hit`/`miss`/`crit` outcomes to preserve readability.

## 7. Numeric Parameters
All numeric coefficients and clamps referenced by this doc must be defined in:
- `docs/design/combat-rules/values/combat-attributes-resolution-values.csv`

