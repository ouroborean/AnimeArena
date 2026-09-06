---
tags: [area/engine, type/reference]
---

# Trigger Types

A trigger is an [[Effects and Durations|Effect]] whose `effect_type` is one of the `*_TRIGGER`
members of `EffectType.Type` (`scripts/types/effect_type.gd`) and whose `trigger` field holds a
`Trigger`. Everything reactive in this game — counters, DoTs, on-death payouts, per-turn brands,
passive machinery — is one of these. There is no separate event bus; each `check_*_triggers` method
on `Character` walks that character's effects of one type and calls `trigger.check(context)`.

## The primitive

```gdscript
class_name Trigger

func check(context):
    if condition.satisfied(context):
        payload.call(context)
        return true
    return false
```
`scripts/trigger.gd:25`

Two fields: a `Condition` (`scripts/condition.gd`, composable via `Condition.multi` / `any` /
`is_not`, with ~25 built-in predicates) and a payload `Callable`. Build one with
`Trigger.always(callback)` when the firing site itself is the only condition — which is the common
case, because most gating is easier to express as an early `return` inside the payload.

Wrap it in an effect with:

```gdscript
Effect.trigger_effect(trig, EffectType.Type.<SOME>_TRIGGER, dur, desc)
```
`scripts/effect_component.gd:192`

That factory does two things you must know about:

- `effect.cleansable = dur >= 0` — a **finite** trigger is a gameplay outcome (a DoT, a temporary
  reactive debuff) and cleanse should strip it; a **permanent** (`dur == -1`) trigger is passive
  machinery whose removal permanently kills the passive, so it is protected. Override at the call
  site for the exceptions (a permanent enemy debuff that *should* cleanse; a finite trigger that is
  critical machinery).
- For the six use/receive types it sets `waiting = true` — see [Self-trigger suppression](#self-trigger-suppression).

## The catalogue

| Type | Fired by | When |
|---|---|---|
| `ACTION_USE_TRIGGER` | `check_ability_use_triggers` (`scripts/character_component.gd:1338`) | the holder uses any skill |
| `HARMFUL_USE_TRIGGER` / `HELPFUL_USE_TRIGGER` | `:1387` / `:1400` | …and it carried that class |
| `ACTION_RECEIVE_TRIGGER` | `check_ability_receive_triggers` (`:1367`), called on every target | the holder is targeted by any skill |
| `HARMFUL_RECEIVE_TRIGGER` / `HELPFUL_RECEIVE_TRIGGER` | `:1413` / `:1428` | …and it carried that class |
| `DAMAGE_DEALT_TRIGGER` | `check_damage_dealt_triggers` (`:1254`) | after the **dealer** lands `> 0` damage |
| `DAMAGE_RECEIVE_TRIGGER` | `check_damage_taken_triggers` (`:1293`) | after the **target** takes `> 0` damage |
| `HEALTH_CHANGE_TRIGGER` | `check_health_change_triggers` (`:1281`) | any HP change, damage or heal |
| `HEALING_GIVEN_TRIGGER` | `check_healing_given_triggers` (`:1307`) | after healing lands |
| `ABSORB_TRIGGER` | `check_damage_absorb_triggers` (`:1321`) | a Shield or Nullify soaked a hit |
| `STUN_RECEIVED_TRIGGER` | `check_stun_received_triggers` (`:1159`) | a STUN was applied |
| `INVULN_RECEIVED_TRIGGER` | `check_invuln_received_triggers` (`:1181`) | a character **becomes** invulnerable |
| `ON_DEATH_TRIGGER` | `check_death_triggers` (`:1459`) | inside `die()`, **before** the death cleanse |
| `START_OF_TURN_TRIGGER` | `check_start_of_turn_triggers` (`:1451`) | every turn transition, **for both sides** |
| `END_OF_TURN_TRIGGER` | `check_end_of_turn_triggers` (`:1443`) | end of the acting team's turn only |
| `TICKING_TRIGGER` | the ticking engine, `battle_manager.execute_ticking_effect` (`:1252`) | as an ordered execution step in the effect-user's turn |
| `COUNTER_USE` / `COUNTER_RECEIVE` / `REFLECT_USE` / `REFLECT_RECEIVE` | the counter/reflect check in `execute_ability` | a skill is used at / by the holder |
| `MISSION_TRIGGER_*` (26 of them) | alongside the gameplay trigger at each site | mission/mastery progress only |

`INVULN_RECEIVED_TRIGGER` fires **before** the invuln is stored (`apply_effect`,
`scripts/character_component.gd:171`) — otherwise Igris's Piercing punish, which does not bypass
invuln, would be blocked by the very invuln it reacts to.

### Context shape

| Firing style | Constructor | `owner` | `target` | `source` | `effect` | extras |
|---|---|---|---|---|---|---|
| use/receive/damage triggers | `QueryContext.from_trigger_source(src, eff, target, value)` | the acting character | who was hit | the `Ability` or `Effect` that caused it | **the trigger effect** | `value` = the damage/heal amount; `damage_type` set at the damage sites |
| self-contained triggers (ticking, EoT, SoT, death) | `QueryContext.from_effect_end(eff)` | `eff.user` (who applied it) | `eff.target` (who holds it) | the effect | the effect | — |

`scripts/query_context.gd:38`, `:52`. Note the asymmetry: with `from_effect_end`, `context.owner` is
the **applier** and `context['effect'].target` is the **holder**. Getting these backwards is a
classic source of a payload that damages the wrong side.

## `TICKING_TRIGGER` is the convention

> [!tip] Use `TICKING_TRIGGER` for anything that happens each turn
> Measured in the current tree: **84** files under `abilities/` reference `TICKING_TRIGGER`, versus
> **18** for `END_OF_TURN_TRIGGER` and **10** for `START_OF_TURN_TRIGGER`.

Why it wins:

- It **fires only for the acting side**, so it needs no side-gate. `get_ticking_effects`
  (`new multiplayer/battle_manager.gd:821`) gathers an effect only when `effect.user in team`, where
  `team` is the acting team.
- It costs exactly **2 duration per fire**, which is what the duration arithmetic in
  [[Effects and Durations]] assumes.
- It resolves as an **ordered execution step at the end of its user's turn**, which is what "at the
  end of my turn" actually means to a player.

`START_OF_TURN_TRIGGER`, by contrast, fires for **every** character at every turn transition and has
no built-in team gate. It is right for machinery that must reset every turn (a per-turn budget) and
wrong for a player-facing per-turn effect. If you use it for a per-enemy effect you must gate by
hand:

```gdscript
var acting_team = battle.enemy.team if battle.waiting_for_turn else battle.player.team
if not holder in acting_team.characters:
    return
```

(the `abilities/gasai5.gd` idiom — and note `waiting_for_turn` is the player/enemy **side**, not
"my team"; see [[The Turn Pipeline]]).

> [!danger] Never reuse the START_OF_TURN gate inside a TICKING_TRIGGER
> On the user's own turn `waiting_for_turn` resolves `acting_team` to the *user's* team, not the
> holder's — so pasting the gasai5 gate into a ticking callback breaks it.

### What the ticking engine actually gathers

```gdscript
func get_ticking_effects(character, is_enemy := false) -> Array:
    for effect in character.get_damage_effects():
        if effect.user in team and (not effect.last_turn_only or effect.duration == 1): ...
    for effect in character.get_healing_effects():
        if effect.user in team: ...
    for effect in character.get_ticking_triggers():
        if effect.user in team: ...
    for effect in character.get_delayed_skills():
        if effect.user in team and effect.duration == 1: ...
```
`new multiplayer/battle_manager.gd:821`

Four effect types are "ticking": `DAMAGE`, `HEALING`, `TICKING_TRIGGER`, `DELAYED_SKILL`. A
`last_turn_only` DAMAGE effect is gathered **only at `duration == 1`** — that is how a single delayed
hit is expressed.

`get_ticking_effect_information` (`:782`) groups them into `execution_order` keyed from **3** upward,
grouping by `[source.ability_name, effect_type, effect.id]` so one skill's ticks on several targets
form one draggable step. Keys 0-2 are the acting team's characters (their queued skills).

`execute_ticking_effect` (`:1219`) then applies the per-step gates:

| Guard | Effect |
|---|---|
| holder `dead` or `banished` | skip |
| `source.classes["Action"]` and the **user** is stunned | skip |
| `effect.removed` | skip |
| DAMAGE + holder invuln to `effect.source` | skip — unless `Bypassing` class, `effect.bypassing`, or damage type is `AFFLICTION` / `BLEED` |
| DAMAGE + `last_turn_only` + `duration != 1` | skip |
| TICKING_TRIGGER, applier is an ally of the holder, holder `is_isolated()` | skip |
| TICKING_TRIGGER, applier is hostile, holder invuln (and not bypassing) | skip |
| `per_stack` | the payload runs `stack_count()` times |

Within one step, effects are sorted by `twin_priority` (`execute_step`, `:1130`).

## The single most expensive mistake: the missing first instance

> [!danger] A ticking effect cannot fire on the turn it is planted
> The side's ticking effects are **snapshotted before that turn's abilities execute**.
> `process_turn_package` builds `ticking_information` at `new multiplayer/battle_manager.gd:1601`
> and only then calls `start_round_loop()` at `:1619`; `turn_end_clicked` (`:716`) does the same for
> the local actor. An effect a skill plants during that turn is simply not in the batch.
> (The same is true of a `START_OF_TURN_TRIGGER` applied on the caster's own turn — those already
> fired.)

So **any skill whose text promises a recurring per-turn effect over a window must deal its first
instance by hand**:

```gdscript
Character.resolve_damage(context, target, dmg, type)   # instance 1, right now
Effect.damage_effect(dmg, type, 2 * K - 1)             # K-1 further ticks
```

"for 3 turns" = an immediate hit + duration **5**. `abilities/squalo1.gd` is the canonical shipped
example — 15 Piercing immediately, then `Effect.damage_effect(15, PIERCING, 5, true)`, and its text
reads "for 3 turns". `abilities/genos3.gd` is the second precedent. `fern3` (Zoltraak Blasts) and
`stark3` (Cowardice's regen) both shipped wrong and were fixed.

> [!warning] Do NOT "fix" a short window by lengthening the duration
> That restores the *total* but leaves the whole effect a turn late, and desynchronised from the
> skill's other clauses. Cowardice at duration 7 healed on offsets `[+2, +4, +6]` while its own mark
> and redirect ran `+0..+5`, so the last heal landed **after the skill had ended**.

A **single delayed event** ("at the end of the following turn…", "on his next turn…") is not this
case and correctly has nothing on the cast turn. `abilities/frieza2.gd` (Nova Strike's payout) is
the model: a `TICKING_TRIGGER` at duration 3, `system = true` so it cannot be dragged earlier in the
player-authored reorder list, `display_system = true` so both players can still see it coming.

### Reactive triggers fire mid-round, so their durations differ

A `HARMFUL_RECEIVE_TRIGGER` payload runs **during the enemy's turn** — half a round later than a
self-cast. A `last_turn_only` BLEED applied on the caster's own turn needs `dur = 3` to tick on their
next turn; the same bleed applied from a counter needs **`dur = 2`**. `dur = 3` there expires without
ever ticking, because `get_ticking_effects` only gathers a `last_turn_only` DAMAGE effect at
`duration == 1` on the owner's team turn. (Denji's Chainsaw Block.)

## Self-trigger suppression: the `waiting` flag

`Effect.trigger_effect` sets `waiting = true` for the six types in
`EffectType.use_or_receive_triggers()` (`scripts/types/effect_type.gd:169`). Every one of those
firing sites contains the same clause:

```gdscript
if eff.waiting and ability == eff.source:
    eff.waiting = false
    continue
```

That is what stops the very skill that *installed* a use/receive watcher from immediately tripping
it. `tick_all_effects_durations` (`scripts/effect_storage_component.gd:309`) clears `waiting`,
`fresh_stack` and `triggered` on **every** effect at the end of every turn, so the suppression lasts
exactly one turn and the once-per-turn latches reset.

## One-shot and once-per-turn latches

| Field | Meaning |
|---|---|
| `triggered` | set by a payload; most firing sites `continue` past a `triggered` effect. Reset every turn by `tick_all_effects_durations`. Effectively **once per turn**. |
| `trigger_once` + `triggerable()` | permanent one-shot (`scripts/effect_component.gd:123`) |
| `remove_once_triggered` | `trigger_check` removes just this effect (name + type + user) |
| `full_remove_once_triggered` | `trigger_check` removes **everything** named after the source ability |
| `stacks` on a reflect | `-1` = permanent, otherwise a consumable charge count |
| `ability_only` | a `DAMAGE_RECEIVE_TRIGGER` with this set skips effect-sourced damage entirely (`:1300`) |

Note `check_damage_taken_triggers` has its `if eff.triggered: continue` **commented out** — damage
receive triggers deliberately fire on every hit in a turn.

Several firing sites also skip on `stealth_check(eff)` — a STEALTH effect on the actor makes their
skills not trip the enemy's watchers, for the types listed in `EffectType.stealthable_triggers()`.

## Announcing an invisible trigger

An `IGNORE_SKILL` charge or a silent counter has no visible tell, so on consume the convention is to
emit feedback the way every counter does:

- `Effect.counter_notification_effect(src)` — "was countered by X", applied to the **attacker**
  (`add_hostile_effect(..., bypassing = true)`)
- `Effect.skill_ignored_notification_effect(src)` — the same render path but worded for a skill that
  was *ignored* rather than countered
- `Effect.invisible_expiration_effect(src)` — "X has ended", applied to the holder

For real `COUNTER_RECEIVE` effects there are three shared helpers on `Ability`:
`default_counter_trigger` (notify + consume), `default_persistent_counter_trigger` (notify, do not
consume), and `default_counter_timeout` used as a `wrapup_func` (emits the "has ended" notice when a
counter times out unfired — remember `CONSUMED` endings skip `wrapup_func`, only `CANCELLED` runs it).

## Reflect is a trigger that rewrites the attacker's targeter

`REFLECT_RECEIVE` deserves its own warning because it does not work like anything else.
`Character.reflect_check` fires the first matching reflect's `trigger.check(context)` and returns
true — but **`execute_ability` ignores that return** and still runs `ability.execute()`. Reflection
therefore works *entirely* by the trigger callback **mutating the caster's targeter**
(`attacker.targeter.targets` / `.main_target`); `execute()` then hits whatever the targeter now
holds. `effect.mag == -1` means bounce to the attacker; a `Character` in `mag` means guardian
redirect to that character. Details and the AoE re-aim rules are in
[[Targeting and Main Target]] and [[Traps That Have Bitten Us]].

## Measuring trigger timing

> [!warning] `end_of_turn_effect_handling()` ends the turn **and** fires the next turn's
> start-of-turn triggers
> Sampling HP after it attributes a heal to the wrong turn — that mistake made a broken Cowardice
> look correct. Walk one boundary at a time, print the acting side and every effect's duration at
> each step, and assert the **offsets**, not the count.

> [!warning] Probe trap — phantom same-turn ticks
> The ticking queue is built at turn *start*. A test that casts a skill and then calls
> `get_ticking_effect_information()` for the same side manufactures a tick no real match can
> produce. End the cast turn with a bare `start_round_loop()` (no gather), then emulate turns
> normally.

More on running these probes at all in [[Verification Playbook]].

## Related

- [[Effects and Durations]] — the duration arithmetic these triggers consume
- [[Damage Pipeline]] — where `check_damage_dealt_triggers` / `check_damage_taken_triggers` sit
- [[The Turn Pipeline]] — turn boundaries and the execution-order package
- [[Cleanse Silence and Effect Removal]] — why `cleansable` keys off a trigger's duration
- [[Adding a Playable Character]] — the kit-building checklist
