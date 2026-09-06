---
tags: [area/engine, type/reference]
---

# Damage Pipeline

All damage in the game flows through one of exactly **two** static entry points on `Character`, and
choosing the wrong one is a subtle, real bug that will not show up in a smoke test. Everything below
lives in `scripts/character_component.gd` unless stated otherwise.

```
resolve_damage        (skill damage)      ─┐
                                           ├─→ deal_*_damage ─→ receive_*_damage ─→ receive_damage
resolve_effect_damage (effect/DoT damage) ─┘        (mitigation ladder)    (HP + triggers)
```

## The two entry points

```gdscript
static func resolve_damage(context, target, pre_mod_damage, damage_type):
    var owner = context['owner']
    if not owner.used_ability:
        return
    if target.is_ignoring_skill(owner.used_ability, context):   # Casseur de Logistille
        return
    var mod_damage = owner.used_ability.get_true_damage(owner, target, pre_mod_damage, null, damage_type)
    if mod_damage < owner.used_ability.minimum_damage:
        mod_damage = owner.used_ability.minimum_damage
    if not target.is_ignoring_damage(true):
        var reflect_state = Character._capture_reflect(target)
        context.battle.log_damage(owner, target, mod_damage, damage_type, owner.used_ability)
        owner.deal_ability_damage(owner.used_ability, mod_damage, target, damage_type)
        Character._fire_reflect(reflect_state, target, owner, mod_damage)
    else:
        context.battle.log_invuln_block(owner, target, owner.used_ability)
```
`scripts/character_component.gd:2111`

```gdscript
static func resolve_effect_damage(context, eff, target, pre_mod_damage, damage_type):
    var mod_damage = eff.source.get_true_damage(eff.user, target, pre_mod_damage, eff, damage_type)
    if not target.is_ignoring_damage(false):
        var reflect_state = Character._capture_reflect(target)
        context.battle.log_damage(eff.user, target, mod_damage, damage_type, eff.source, eff)
        eff.user.deal_effect_damage(eff, mod_damage, target, damage_type)
        Character._fire_reflect(reflect_state, target, eff.user, mod_damage)
    else:
        context.battle.log_invuln_block(eff.user, target, eff.source)
```
`scripts/character_component.gd:2130`

| | `resolve_damage` | `resolve_effect_damage` |
|---|---|---|
| Use it for | damage a skill deals **at the moment of use** | DoT ticks, counter/reflect payouts, trigger payloads, redirected damage |
| Attribution | `context['owner']` + `owner.used_ability` | `eff.user` + `eff.source` |
| Bails when… | `owner.used_ability` is null | never |
| Ignore-skill gate | **yes** (`is_ignoring_skill`) | no |
| `minimum_damage` floor | **yes** | no |
| `get_true_damage` source arg | `null` → boosts key on `damager.used_ability.ability_name` | `eff` → boosts key on `eff.source.ability_name` |
| Dodge/ignore check | `is_ignoring_damage(true)` | `is_ignoring_damage(false)` |

> [!danger] `is_ignoring_damage(true)` vs `(false)` — this is the subtle one
> ```gdscript
> func is_ignoring_damage(ability_source):
>     for eff in effects.get_effects_by_type(EffectType.Type.IGNORE_DAMAGE):
>         if not eff.ability_only or ability_source:
>             if eff.remove_once_triggered:      eff.target.effects.consume_effect(eff)
>             elif eff.full_remove_once_triggered: eff.target.effects.consume_effect(eff, true)
>             return true
>     return false
> ```
> `scripts/character_component.gd:1671`
>
> The boolean answers *"is this real skill damage?"*. An `ability_only` IGNORE_DAMAGE charge — a
> one-turn dodge meant to eat an incoming **skill** — engages, and is **consumed**, only when the
> argument is `true`. Route DoT damage through `resolve_damage` and every tick burns a charge the
> player was saving for a skill; route skill damage through `resolve_effect_damage` and the dodge
> never fires at all. Neither failure logs anything.

> [!warning] `resolve_damage` reads `owner.used_ability`, which is stale outside a skill
> `used_ability` is only cleared on the next turn's `refresh()`, so calling `resolve_damage` from
> inside a trigger or DoT callback attributes the hit to whatever skill that character last used.
> That is exactly why `is_ignoring_skill` is keyed on `effect.source` at the *effect* sites rather
> than on `used_ability` — the same reason invuln keys on `effect.source`.

### Reflect must be captured before the hit

`_capture_reflect(target)` (`:2154`) runs **before** the damage call and `_fire_reflect` (`:2171`)
after. This is not stylistic:

> [!danger] Any "react to damage received" logic that reads effects AFTER the damage call silently
> no-ops on lethal hits
> The damage call can kill the target, and `die()` → `cleanse_death_effects()` erases every effect
> whose `user` is the dying character — which is exactly Yubel's own "Terror Incarnate" /
> "Ultimate Nightmare" markers. A post-damage `has_effect` lookup found nothing, so **the killing
> blow was the one hit that never reflected**. Holding the `Effect` reference across the call is
> safe: `erase_effect` only unlinks it from the storage list, and since effects are parented the
> object is not freed until match end.
>
> `_fire_reflect` uses `deal_effect_damage` directly rather than `resolve_effect_damage`, so the
> reflected hit does not re-enter the capture — no ping-pong.

## `get_true_damage` — the pre-mitigation modifier pass

`abilities/scripts/ability_component.gd:642`. Runs on **both** paths, so a `DAMAGE_MOD` boost applies
to direct hits and DoT ticks alike.

1. Collect `DAMAGE_MOD` effects **on the damager**.
   - **`NO_BOOST` gate**: if `damager.can_boost()` is false (any `NO_BOOST` effect present —
     Astolfo's Trap of Argalia, `:1685`), **positive** mods are skipped. Negative mods still apply.
   - `class_targets` / `exclusion_targets` on a DAMAGE_MOD filter by **`damage_type`**, not by
     ability class, despite the field names.
   - `ability_targets` filters by `source_name` — which is `eff.source.ability_name` when a source
     effect was passed, else `damager.used_ability.ability_name`.
   - `per_stack` multiplies by `stack_count()`.
   - A negative mod is forced to `0` against `TRUE` damage.
   - Cross-team mods respect `shrug_off_type(DAMAGE_MOD)`.
2. Clamp to `>= 0`.
3. Add `VULNERABILITY` effects **on the target**, with the same `class_targets` / `ability_targets` /
   `per_stack` filtering.
4. `extra_damage_calc(damager, target, mod_damage)` — a no-op hook any ability may override.

> [!warning] In-script damage math is not covered by `NO_BOOST`
> `can_boost()` only gates the general `DAMAGE_MOD` loop. An ability that computes its own bonus in
> `execute()` must call `can_boost()` itself.

## The mitigation ladder

`deal_ability_damage` (`:532`) and `deal_effect_damage` (`:694`) are near-duplicates. `self` is the
**dealer**. Order matters and several steps `return` outright.

| # | Step | On whom | Notes |
|---|---|---|---|
| 1 | `CHAIN_NULLIFY` | dealer | forces damage to 0 |
| 2 | `check_damage_nullification` (`:811`) | **dealer** | `DAMAGE_NULLIFICATION` = "this character deals N% less damage"; multiplicative, then `int()` |
| 3 | Nirvana (Arthur) | dealer marked | converts the damage into Nullify on itself, **returns** — ability path only |
| 4 | Plasmantle (Arthur) | target marked, Harmful | converts into an invisible Shield on the target, **returns** — ability path only |
| 5 | Blood Spear (Power) | target marked, non-Bleed | adds the raw amount to the target's BLEED payload, **returns** |
| 6 | Uranus Lip Rod / World Shaking | dealer + target | +5 |
| 7 | `get_damage_cap()` (`:490`, default 100) | **dealer** | "cannot deal more than N in a single hit"; Crush Card Virus banks the clamped excess |
| 8 | `target.get_damage_cap_receive()` (`:500`) | target | "cannot receive more than N" |
| 9 | `damage_reversed()` | dealer | turns the hit into healing on the target, **returns** — **ability path only** |
| 10 | Erza Heaven's Wheel vs `AFFLICTION` | target | **returns** |
| 11 | Esdeath marks | dealer | −10 / −5 |
| 12 | Minene Escape Diary | target | −20% per stack, then all stacks consumed |
| 13 | Saturn Crystal / Silence Wall | target marked, `not redirected` | halves and re-deals the half elsewhere |
| 14 | **Nullify → Shield → flat DR → % DR** | see below | skipped entirely for `AFFLICTION` and `BLEED` |
| 15 | `check_damage_redirect` (`:962`) | target, `not redirected` | moves a share to another character |
| 16 | Nagisa "Natural Assassin" | target, dealer silenced | −5 |
| 17 | Heavenly Intervention (Lyserg) | lethal + target marked | damage → 0, Lyserg takes 35 — **ability path only** |
| 18 | `receive_*_damage` | target | HP and receive-triggers |
| 19 | health drain, Lord of Gluttony lifesteal, `check_damage_dealt_triggers` | dealer | only when `mod_damage > 0` |

> [!danger] "Nullify" is a DEBUFF ON THE DEALER, not a shield on the defender
> ```gdscript
> mod_damage = check_damage_against_barriers(ability, mod_damage, self)      # self == the DEALER
> mod_damage = check_damage_against_shielding(ability, mod_damage, target)   # the DEFENDER
> ```
> `scripts/character_component.gd:647-648`
>
> `BARRIER` ("N points of Nullify") is applied to **enemies** — `abilities/frieren2.gd` reads
> "Gives target enemy 15 Nullify", `abilities/chrome1.gd` applies it via `add_hostile_effect`. It
> soaks the damage the holder **deals**. `SHIELD` is the defensive one and is read off the target.
> The parameter of `check_damage_against_barriers` is literally named `attacker`. Read those two
> lines carefully before assuming a bug.

Both absorbers share the same shape (`:819`, `:845`): call the effect's `barrier_func` / `shield_func`
callback, fire `check_damage_absorb_triggers`, then either fully deplete (set `breaker`, run
`check_effect_breaking`, zero the mag, `consume_effect`) or subtract and return 0. This is the same
teardown `shatter_barrier` / `shatter_shields` perform — see [[Effects and Durations]] for why you
must never raw-`erase_effect` one of these.

Flat `DAMAGE_REDUCTION` (`:919`) and `PERCENT_DR` (`:943`) are skipped when the damage type is
`PIERCING` or `TRUE`, or when the target is `def_broken()` (a `DEF_NEGATE` / "Shattered" effect).

### Damage types

`scripts/types/damage_type.gd`: `NORMAL, ENERGY, PHYSICAL, PIERCING, AFFLICTION, BLEED, TRUE`.

| Type | Nullify | Shield | Flat DR | % DR | Invuln (ticking path) |
|---|---|---|---|---|---|
| `NORMAL` / `ENERGY` / `PHYSICAL` | yes | yes | yes | yes | blocked |
| `PIERCING` | yes | yes | **no** | **no** | blocked |
| `TRUE` | yes | yes | **no** | **no** | blocked |
| `AFFLICTION` | **no** | **no** | **no** | **no** | **pierces** |
| `BLEED` | **no** | **no** | **no** | **no** | **pierces** |

The invuln column is `execute_ticking_effect` (`new multiplayer/battle_manager.gd:1229`), which skips
a DAMAGE tick against an invulnerable holder unless the source has the `Bypassing` class, the effect
sets `bypassing`, or the type is `AFFLICTION` / `BLEED`.

> [!info] Invulnerability is not checked inside the damage functions
> For skills, invuln is a **targeting** gate — the target is dropped before `execute()` ever runs.
> See [[Targeting and Main Target]] and [[Cleanse Silence and Effect Removal]].

### Bleed

A Bleed DoT is a `DAMAGE` effect with `damage_type = BLEED`
(`Effect.damage_effect(mag, DamageType.Type.BLEED, dur)`); add `last_turn_only = true` for a single
delayed tick. **Any healing staunches all of it** — `receive_healing` calls `staunch_bleeding()`
(`:1065`) on `healing > 0`, which erases every BLEED-typed DAMAGE effect on the healed character.

> [!warning] Trap — a mark that outlives its payload becomes invulnerability
> Power's Blood Spear is a `MARK` plus a separate BLEED payload effect. Because healing staunches
> the payload but not the mark, the interception's `return` **must be inside** `if spear_payload:`
> (`:568`, `:708`). With an unconditional return the lingering mark voids **all** non-Bleed damage
> for the rest of its duration.

### Redirect

```gdscript
func check_damage_redirect(source, damage, target, damage_type, origin = null):
    for redirect in target.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT):
        if redirect.source != null and redirect.source.has_method("take_redirect_budget"):
            damage = redirect.source.take_redirect_budget(source, damage, target, damage_type, redirect, origin)
            continue
        var redirected_damage = damage * redirect.mag
        damage -= redirected_damage
        if not target.is_ignoring_damage(true):
            source.deal_effect_damage(redirect, redirected_damage, redirect.character_target, damage_type, true)
    return damage
```
`scripts/character_component.gd:962`

Two models. The default moves a **fixed fraction** (`redirect.mag`) of every hit to
`redirect.character_target`. That cannot express "up to N damage per turn, shared across several
protected allies", so an ability may opt in by exposing `take_redirect_budget()` and owning the
decision — one shared pool for any number of per-ally effects (Stark's Superhuman Resilience /
Cowardice). `origin` exists only so the budget can tell one skill's hits apart from another's.

Everything re-dealt by redirect, Saturn Crystal or Silence Wall passes `redirected = true`, which is
what stops steps 13 and 15 from recursing.

## Landing the damage

```gdscript
func receive_ability_damage(ability, damage, dealer, damage_type = -1):
    # (muichiro beheading branch first)
    receive_damage(damage, dealer, ability)
    if damage > 0:
        check_damage_taken_triggers(ability, damage, damage_type)
```
`:412` (and `:449` for the effect path)

`receive_damage` (`:471`) writes HP via `health.modify_hp`, emits `damage_dealt` /
`damage_received`, and calls `check_health_change_triggers()`. Note the trigger asymmetry: dealt- and
taken-triggers fire only on `damage > 0`, but `check_health_change_triggers` fires unconditionally.

> [!tip] `damage_type` is threaded, not inferred
> `check_damage_taken_triggers` (`:1293`) takes an optional `damage_type` and writes it into
> `context.damage_type`, mirroring `check_damage_dealt_triggers` (`:1254`). That is what lets a
> `DAMAGE_RECEIVE_TRIGGER` filter by type (Power's Blood Fiend heals only on BLEED).
> `receive_effect_damage` deliberately prefers the **runtime** argument over `effect.damage_type`,
> because redirect/Saturn/Silence-Wall/Heavenly-Intervention all pass a `MARK` whose own
> `damage_type` is `null` and would mis-type redirected Bleed.

Bots read the same numbers players do — see [[Bots and Training]] for `bot_damage_hint()` and the
observation layer's parity rule.

## Healing, briefly

The mirror-image pair is `resolve_healing` / `resolve_effect_healing` (`:2181`, `:2188`), gated on
`is_isolated()` instead of `is_ignoring_damage`, running through
`give_ability_healing` / `give_effect_healing` → `receive_healing` (`:1031`). `receive_healing`
applies `HEALING_RECEIVED_MOD` flat mods, then a multiplicative mark, clamps to
`get_modified_max_hp()`, and — on any `healing > 0` — staunches bleed and fires
`check_healing_given_triggers` on the **healer**.

## Related

- [[Effects and Durations]] — Shield/Nullify teardown, `cleansable`, effect lifetimes
- [[Trigger Types]] — the receive/dealt triggers this pipeline fires, and DoT timing
- [[Targeting and Main Target]] — where invuln, dodge and the target list are decided
- [[Cleanse Silence and Effect Removal]] — invuln bypass and the exec-time invuln filter
- [[The Turn Pipeline]] — where `execute_ticking_effect` sits in a turn
- [[Traps That Have Bitten Us]] — the lethal-reflect and Blood-Spear failures in narrative form
