---
tags: [area/engine, type/reference]
---

# Effects and Durations

Every piece of persistent battle state — a stun, a shield, a DoT, a passive's bookkeeping brand — is
an `Effect`. `Effect` is a **Godot Node** (`scripts/effect_component.gd`, instantiated from
`components/effect_component.tscn` by ~70 static factory functions), so it has a lifetime, a parent,
and a signal surface. Almost every subtle bug in this engine traces back to one of three things:
the duration arithmetic, the identity key `add_effect` dedups on, or which of the four removal
paths you used.

## The duration model

> [!danger] Duration is not the player-facing turn count
> `duration` ticks down at the **end of every player's turn — both teams'**.
> `battle_manager.end_of_turn_effect_handling()` (`new multiplayer/battle_manager.gd:1316`) calls
> `tick_durations()` (`:1302`), which walks **all** characters and runs
> `effects.tick_all_effects_durations()`. So one full round of play = **2 decrements**.

```
player turn ends   -> every effect on every character: duration -= 1
enemy turn ends    -> every effect on every character: duration -= 1
```

| Ability text | Internal `duration` | Why |
|---|---|---|
| "for 1 turn" (a debuff/buff on someone else) | `2` | your turn + their turn |
| "for 2 turns" | `4` | ×2 |
| "for N turns" | `2N` | ×2 |
| "this skill is replaced for N turns" (you interact with it on **your own** turn) | `2N + 1` | cast turn + N full rounds, so it survives to your next turn |
| permanent | `-1` | `tick_effect()` returns early on `-1` and never expires |
| "extend by 1 turn" | `duration += 2` | precedent: `abilities/crona6.gd` |

`tick_effect` (`scripts/effect_component.gd:1311`) is the whole mechanism — subtract 1, emit
`effect_updated`, and call `end_effect()` at `<= 0`. There is no per-effect tick rate; `-1` is the
only escape.

> [!warning] Trap
> Implementing a kit with raw turn counts produces a build where *everything is half as long as the
> text says*. This is the single most common first-pass error on a new character (the entire Toji
> kit shipped that way first: stun 2→4, invuln 1→2, a `+= 1` extension that was a literal no-op).
> Translate every player-facing number before you write it, and grep a shipped ability with the same
> shape to calibrate.

Damage-over-time is worse, because a ticking effect **cannot fire on the turn it is planted** — see
[[Trigger Types]] for the full explanation and the `immediate + duration 2K-1` recipe.

Banished characters are the one exception to the "everything ticks" rule: `tick_durations` ticks
only their `BANISH` effects plus anything flagged `tick_during_banish`
(`new multiplayer/battle_manager.gd:1306-1313`).

## Effect identity: `effect_name()` and the merge key

```gdscript
func effect_name():
    if name_override != "":
        return name_override
    if effect_type == EffectType.Type.ERZA_ARMOR:
        return mag
    return source.ability_name
```
`scripts/effect_component.gd:1276`

An effect is **named after the ability that created it**. `set_source(ability)` is what supplies
that name — and it also sets `user = source.user` and the tooltip image
(`scripts/effect_component.gd:1293`). `Ability.apply_hostile` / `apply_allied`
(`abilities/scripts/ability_component.gd:863`, `:870`) call `set_source(self)` for you;
`Character.add_allied_effect` / `add_hostile_effect` do **not**. An effect applied the raw way
without `set_source` reaches the wire nameless and will crash `effect_name()` on a null source.

`EffectStorageComponent.add_effect` dedups on the triple **`(effect_name(), effect_type, user)`**
(`scripts/effect_storage_component.gd:31`, via `has_effect` at `:67`):

| Existing match found | Flag on the existing effect | Behaviour |
|---|---|---|
| yes | `stackable` | merge: `mag += incoming.mag` if `stack_mag`, `stacks += incoming.stack_count()`; the **incoming node is `queue_free`d** (`:43`) |
| yes | `refresh` | remove the old, store the new |
| yes | neither | **store a second, duplicate effect** |
| no | — | store |

> [!danger] Two effects from one ability collide
> If one ability applies **two effects of the same type** to the same user, they share a name and
> silently merge (or duplicate). Set `name_override` on one of them. `abilities/frieza2.gd` does
> exactly this: its Shield-decay counter is a `MARK` sourced from Nova Strike with `user == Frieza`,
> the same triple as the shield bookkeeping, so it carries
> `m.name_override = COUNTER`. Mavis's Fairy Star Strategy hit the same collision.

> [!warning] The silent-duplicate branch is a real bug source
> A permanent trigger is neither `stackable` nor `refresh`, so re-casting the skill that installs it
> stores a **second** copy and every hit accrues twice, compounding per recast. This is what bit
> `abilities/ryohei4.gd` — the fix was to gate `extra_usable` on the **trigger**, not on the
> companion mark. See [[Traps That Have Bitten Us]].

Conversely, effects that must share one stack counter must share one `set_source` — a counter built
with `set_source(self)` in one ability and `set_source(base_abilities[N])` in another produces two
differently-named marks that never merge.

`unique_render_id` is the *display*-only escape hatch: both clients cluster a character's effects by
`(effect_name(), unique_render_id)` (`scripts/effect_storage_component.gd:297`,
`webclient/app/app.js` `effectClusters`), so giving a reactive's consequences a non-zero id splits
them into their own tooltip panel without touching any lookup.

## Visibility: `invisible` vs `system` vs `display_system`

Three orthogonal flags, routinely confused.

| Flag | Serialized to the wire? | Who sees it | Also does |
|---|---|---|---|
| *(none)* | yes | both players | — |
| `invisible` | yes | **only the caster's side** (plus Toph / Kurotsuchi sensing) | — |
| `system` | **no** — stripped entirely | neither player | survives the death cleanse when paired with `remove_on_death = false`; excluded from the end-turn reorder preview |
| `system` + `display_system` | yes | both players | keeps all of `system`'s survival + ordering semantics |

`system` was doing two unrelated jobs — cleanse/death survival *and* hiding — and
`display_system` (`scripts/effect_component.gd:56`) exists to split them. The owner's rule:

> Only effects that are hidden information, or are not helpful to either player to know, should be
> hidden from either player.

A passive's per-enemy brand changes how the opponent should play; that is information both sides are
entitled to. Set `display_system = true` alongside `system = true`.

> [!warning] Trap — eight filter sites must agree
> Miss one and `_validate_snapshot_drift` `push_warning`s "effect missing in live" every single turn.
> - `battle_manager._serialize_wire_team` (`:2374`) — the only producer of `snapshot.sides[].team[].effects`
> - `battle_manager.log_effect_applied` / `log_effect_expired` (`:1953`, `:1960`)
> - `battle_manager._serialize_effects_for_hash` (`:2105`)
> - `battle_manager._serialize_execution_preview` (`:2211`) — the draggable end-turn reorder list
> - `battle_manager._validate_team` drift check (`:3111`)
> - `effect_storage_component.get_effect_clusters` (`:295`)
> - `training/bot_observation.gd` `effect_visible` — defined as human parity, so it follows the same rule
> - `webclient/app/app.js` `effectClusters` — plus `scripts/display_effect.gd` must mirror the field
>   or the passive client loses it

> [!tip] `system` + `display_system` on a ticking effect is deliberate, not contradictory
> The reorder preview is *player-authored* — the client sends the dragged order back — so a visible
> ticking step could be dragged ahead of the player's own skills. `system` keeps it out of the
> preview (and a ticking key the client never sends is appended **last**), `display_system` puts it
> on screen. `abilities/frieza2.gd:65` needs both, because Nova Strike's text promises "at the end
> of his next turn".

> [!warning] Un-hiding an effect exposes stock descriptions
> A factory's canned text may be a lie that nobody noticed while it was hidden —
> `Effect.redirect_effect(0.0, …)` renders "…will redirect 0.0% of damage taken". Override
> `effect.description` before flipping the flag.

## `cleansable` — set by the factory, not by you

`cleansable` defaults to `true` (`scripts/effect_component.gd:63`) and is the **only** gate the
cleanse functions read. A few factories override it:

| Factory | Default `cleansable` |
|---|---|
| `trigger_effect(trig, type, dur, desc)` | **`dur >= 0`** — finite trigger = outcome (cleanse it), permanent = machinery (protect it) |
| `empty(dur, desc)` | `false` — an install/anchor marker |
| `ability_swap_effect` / `portrait_change_effect` / `color_change_effect` / `disguise` | `false` — transformation/identity state |
| `delay_target_marker`, `delayed_skill_eff`, `xanxus_storage_effect` | `false` |
| **everything else, including `mark`, `shield_effect`, `barrier_effect`** | `true` |

The design rule, from the owner: *"cleanse what re-earns, protect what stripping permanently kills."*

> [!danger] The cleansable pair desync
> `trigger_effect` auto-protects a permanent trigger. `Effect.mark` does **not** touch `cleansable`.
> Pair a `dur = -1` trigger with a plain `Effect.mark` accumulator and a buff-strip
> (`cleanse_all_ally_effects`, which reaches a character's own self-applied buffs) splits them: the
> trigger survives and immediately dereferences a mark that is gone. That is the deployed crash
> `Invalid access to property or key 'mag' on a base object of type 'Nil'` at `abilities/ryohei4.gd`.
> `Effect.empty` desyncs the *other* way (protected EMPTY, cleansable MARK).
> Audit every permanent-trigger + counter pair, and null-guard by **rebuilding the counter at zero**.

Full treatment of the cleanse machinery is in [[Cleanse Silence and Effect Removal]].

## Death and revival

`get_all_death_cleansable_effects(user)` (`scripts/effect_storage_component.gd:143`) returns
`effect.user == user and (not effect.system or effect.remove_on_death)`. `remove_on_death` defaults
to **`true`** (`scripts/effect_component.gd:57`), so:

```gdscript
eff.system = true
eff.remove_on_death = false   # system ALONE is not enough
```

is the *only* combination that survives its caster's death. `startup_passives` runs at battle start
only and nothing re-installs a passive, so a revived character whose machinery lacked
`remove_on_death = false` silently loses the passive for the rest of the match.
`abilities/death5.gd` is the shipped precedent.

`Character.cleanse_death_effects()` (`scripts/character_component.gd:1912`) does **two** sweeps:

1. every character loses effects whose `user` is the dying character; then
2. the dying character loses every `cleansable` effect **on them**, whoever applied it — so a revive
   comes back clean rather than stuck under an enemy's `HEALTH_CAP`.

> [!warning] Two death-cleanse corollaries
> - An effect the dying character places on an **ally** during its own on-death trigger is erased
>   milliseconds later. Either make it `system` (invisible), or apply it with the ally as the
>   effect's `user` (`add_allied_effect(ctx, ally, ally, eff)`) — then it survives and stays visible,
>   and you recover the origin via `eff.source.user`.
> - The **inverse**: a debuff whose `user` is the *killer* lingers on the victim's corpse.
>   `deadEnemy.has_effect(name, TYPE, attacker)` still returns it. Any "is my debuff still out
>   there?" poll must skip dead holders.

## Removal paths — pick the right one

| Call | Fires `wrapup_func` | Fires `check_effect_breaking` | Emits `effect_removed` |
|---|---|---|---|
| `erase_effect(eff)` | no | no | **yes** |
| `consume_effect(eff)` → `end_effect(CONSUMED)` | **no** | no | yes |
| `eff.end_effect(CANCELLED)` (also: natural expiry via `tick_effect`) | yes | no | yes |
| `character.shatter_shields/​shatter_barrier(breaker)` | yes | **yes** | yes |
| `dispel_with_teardown(eff, owner, breaker)` (all three cleanse fns) | yes (or the shatter mirror for SHIELD/BARRIER) | yes for SHIELD/BARRIER | yes |
| `full_remove_effect_by_name` / `clear_non_system_effects` | no | no | **no** — bare `.filter()` |

> [!danger] Never raw-`erase_effect` a Shield or Nullify
> `check_effect_breaking` (`scripts/character_component.gd:873`) is where `break_vow` (Mash),
> `gain_shield_break` (Jupiter), `break_hero` (Jaden), Metal Armor and Madoka's Soul Gem corruption
> live — **not** in the shield's own `wrapup_func`. Use `shatter_shields` / `shatter_barrier`, which
> set `eff.breaker`, run the break hooks, and **return the summed magnitude broken**. A raw erase
> leaks every companion effect that rode the wrapup. Reference impl: `abilities/squalo2.gd`,
> `abilities/semiramis3.gd`.

> [!warning] A shield's `wrapup_func` fires on break **and** on unbroken expiry
> `end_effect(CANCELLED)` runs it on natural expiry with `breaker` still null. A wrapup that means
> "expired *unbroken*" must early-out on `context.effect.breaker != null` (fixed in
> `abilities/cell3.gd`).

### The `effect_removed` hook

`character.effects.effect_removed` (emitted synchronously inside `erase_effect`,
`scripts/effect_storage_component.gd:196`) is the uniform "this effect is gone" signal. It fires for
explicit removal, for stack-exhaustion, and for natural expiry
(`tick_effect` → `end_effect` → `effect_expired` → `erase_effect`). Since cleanse was rewritten to
route through `dispel_with_teardown`, it fires for cleanse too — the two remaining bypasses are the
`.filter()`-based `full_remove_effect_by_name` and `clear_non_system_effects`.

The **restore-on-removal** pattern ("this effect cannot be removed or expire", Gasai Yuno's
Breakdown) hangs off it: connect once per holder, filter to your `effect_type` + `effect_name()`,
gate on the active condition, re-grant at the original duration. It is not re-entrant (re-granting
emits `effect_added`) and is safe inside tick/consume loops because those iterate a copy.
To *allow* consume while *blocking* expiry you need an explicit flag around the consuming loop —
and it must be a **`static var`**, because one holder's signal fires every connected watcher and in
a mirror match an instance flag wouldn't gate the other instance's handler.

## Effects are Nodes: parenting and freeing

`_store_effect` (`scripts/effect_storage_component.gd:59`) `add_child`s the effect into the storage
so the match subtree's cascade-free reclaims it. Before that fix the server orphaned **every** effect
it ever created — 478k orphan nodes after one active day.

The other half of the contract is the **rejected** effect. `add_allied_effect` / `add_hostile_effect`
(`scripts/character_component.gd:2073`, `:2085`) build the effect *before* the legality check, so a
blocked application leaves a parentless node nothing will ever free:

```gdscript
static func _free_unapplied_effect(effect):
    if effect != null and is_instance_valid(effect) and effect.get_parent() == null:
        effect.queue_free()
```
`scripts/character_component.gd:2107`

Always `queue_free`, never `free()` — the creating ability may still write fields on the node later
in the same frame. Same reasoning in the stackable-merge branch of `add_effect`. See
[[Node Lifecycle and Orphans]].

## Application side effects

`Character.apply_effect` (`scripts/character_component.gd:156`) is more than a store. It sets
`user`/`target`, then branches by type to fire the mission triggers and reactive hooks: STUN runs
`on_stun_received` (which can *reject* the effect outright), the Xanxus wrath counter,
`check_stun_triggers`, `check_stun_received_triggers` and `check_cancels`; INVULN fires the
hostile INVULN watchers **before** the invuln is added (otherwise the Piercing punish they deal
would be blocked by the very invuln it reacts to); a `BLEED`-typed effect triggers Rakko's shatter.

`apply_effect` is reachable only through the two `add_*_effect` chokepoints, or by calling it
directly — which deliberately bypasses `shrug_off_type`, invuln, and the ignore-skill gate. That
direct call is the correct route for a passive's **internal bookkeeping brand** on an enemy, which
should not be droppable by the target's defensive kit.

## Where to go next

- [[Trigger Types]] — the trigger effect types, the ticking engine, and per-turn timing
- [[Damage Pipeline]] — `resolve_damage` vs `resolve_effect_damage` and the mitigation ladder
- [[Cleanse Silence and Effect Removal]] — the cleanse functions in full
- [[The Turn Pipeline]] — where `end_of_turn_effect_handling` sits in a turn
- [[Adding a Playable Character]] — the checklist these rules feed into
