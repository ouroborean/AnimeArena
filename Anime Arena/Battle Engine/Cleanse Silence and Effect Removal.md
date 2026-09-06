---
tags: [area/engine, type/reference]
---

# Cleanse Silence and Effect Removal

Three separate mechanisms live in this note because they are constantly mistaken for each other:

- **Cleanse** removes effects. Gated per-effect by `cleansable`.
- **Silence** removes *usability*. It no longer touches effects at all.
- **Effect removal** is a family of five code paths that fire different subsets of teardown hooks.
  Picking the wrong one leaks paired state.

## Removal paths and what each one fires

| Call | `wrapup_func` | break hooks (`check_effect_breaking`) | `effect_expired` | `effect_removed` |
| --- | --- | --- | --- | --- |
| `erase_effect(eff)` | no | no | no | **yes** |
| `consume_effect(eff)` → `end_effect(CONSUMED)` | no | no | yes → erase | yes |
| `end_effect(CANCELLED)` | **yes** | no | yes → erase | yes |
| `shatter_shields` / `shatter_barrier` | yes (via break hook) | **yes** | yes → erase | yes |
| `dispel_with_teardown` (cleanse) | yes | yes, for SHIELD/BARRIER | yes → erase | yes |
| `clear_non_system_effects` (bare `.filter()`) | no | no | no | **no** |

`end_effect` only runs the wrapup on `CANCELLED` (`scripts/effect_component.gd:1331-1336`):

```gdscript
func end_effect(ending_type = EndingType.Type.CANCELLED):
	var context = QueryContext.from_effect_end(self)
	if ending_type == EndingType.Type.CANCELLED:
		wrapup_func.call(context)
	effect_expired.emit(self)
```

`effect_expired` is connected to `erase_effect` at `add_effect` time
(`scripts/effect_storage_component.gd:27-30`), which is what makes the chain terminate in
`effect_removed`.

> [!warning] Trap
> Never `erase_effect` a SHIELD or BARRIER. Use `character.shatter_shields(breaker)` /
> `shatter_barrier(breaker)` (`scripts/character_component.gd:1835-1855`): they set `eff.breaker`,
> run `check_effect_breaking` (`:873-887` — Madoka Soul Gem corruption, Metal Armor blind cleanup,
> Jupiter's `gain_shield_break`, Mash's `break_vow`, Jaden's `break_hero`), zero the magnitude,
> consume, and return the total magnitude broken. Many characters hang companion cleanup off a
> shield's `wrapup_func`; a raw erase leaks all of it. To size a "+N per shield removed" formula,
> read `get_shield_effects().size()` **before** shattering.

> [!info]
> A shield's `wrapup_func` fires on **break and on unbroken expiry**. If your wrapup means "expired
> without being broken", early-out on `context.effect.breaker != null` (`QueryContext.from_effect_end`
> exposes the effect as `context.effect`).

## Cleanse

### The helper names are inverted from intuition

`scripts/effect_storage_component.gd`:

| Function | Removes | Called by |
| --- | --- | --- |
| `cleanse_all_enemy_effects(character, by)` `:108` | the **hostile** effects sitting on `character` | self-cleanses ("removes all enemy effects from this character") |
| `cleanse_all_ally_effects(character, by)` `:128` | `character`'s **own / allied** effects | enemy **buff-strips** |
| `cleanse_hostile_afflictions(character, by)` `:172` | hostile effects whose source ability has the `Affliction` class | partial cleanses |

"Enemy" and "ally" name the *effects*, not the target. Read the call site twice.

The filter is one line each:

```gdscript
for eff in _effects:
	if not (character in eff.user.team.characters) and eff.cleansable:
		to_remove.append(eff)
```

All three bail entirely if the holder carries an `IGNORE_CLEANSE` effect, and all three iterate a
**snapshot** — `dispel_with_teardown` mutates `_effects`, and break hooks can add and remove further
effects mid-loop. The return value is `to_remove.size()` (the count actually stripped);
`abilities/natsu4.gd` scales its heal and stacks off it.

### The design rule

> **"Cleanse what re-earns, protect what stripping permanently kills."**

- **Cleansable**: temporary buffs/debuffs, DoTs, reactive debuffs, and re-accumulating stacks whose
  protected generator will rebuild them.
- **`cleansable = false`**: generator triggers and installers, transformations, mode/anchor state,
  install-once immunities that never re-earn, self-detriment death-clocks, permanent innate buffs.

There is no type whitelist any more. An older model gated on
`eff.effect_type in EffectType.silenced_effects()`, which excluded Isolate, Curse, DoTs, marks and
triggers — "cleanse SOME". `EffectType.silenced_effects()` (`scripts/types/effect_type.gd:137`) is now
**dead code**: the only reference left in the repo is a comment in `effect_storage_component.gd:114`.

### Where `cleansable` comes from

| Factory | Default | Reason |
| --- | --- | --- |
| base `Effect` (`scripts/effect_component.gd:63`) | `true` | anything that does not opt out is a gameplay outcome |
| `Effect.trigger_effect` (`:192-201`) | **`dur >= 0`** | finite trigger = DoT/temp reactive = outcome; permanent trigger = passive machinery |
| `Effect.empty` (`:1157-1160`) | `false` | EMPTY is an anchor/description marker |
| `Effect.mark` (`:1169`) | *(untouched → `true`)* | |
| transform factories (ability swap, portrait change, colour change, disguise) | `false` | a cleanse must not revert a transformation |

### The pair-desync trap

> [!danger] Never do this
> Do not pair a **permanent `trigger_effect`** with a plain **`Effect.mark`** accumulator and assume
> they live and die together. `trigger_effect(-1)` sets `cleansable = false`; `Effect.mark(-1)` never
> touches the flag and inherits `true`. A buff-strip takes the mark and leaves the trigger, which
> then fires against a missing accumulator.

This was a deployed crash. `abilities/inuyasha3.gd:30-31` strips a target and deals damage on the
*very next line*:

```gdscript
target.effects.cleanse_all_ally_effects(target, user)   # user = breaker
Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
```

which detonated Ryohei's To the Extreme!! counter with
`Invalid access to property or key 'mag' on a base object of type 'Nil'`. The fix
(`abilities/ryohei4.gd:52-72`) rebuilds the mark **at zero** rather than bailing — the strip fairly
took the earned stacks, but a permanent passive has to keep counting:

```gdscript
var mark = ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei)
if mark == null:
	var qc = QueryContext.from_game_state(ryohei, ryohei.battle)
	Character.add_allied_effect(qc, ryohei, ryohei, _build_mark(0))
	mark = ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei)
	if mark == null:
		return
```

Two further defects rode along, both from gating `extra_usable` on the **mark** instead of the
trigger: after a strip the skill re-enabled, and a recast stored a *second* permanent trigger (it is
neither `stackable` nor `refresh`, so `add_effect` falls through to storing a duplicate) so every hit
accrued twice; and a different skill creating a same-named mark locked the passive out for the match.
`abilities/ryohei4.gd:103` now gates on the trigger.

`Effect.empty` desyncs the *other* way — the EMPTY survives a strip while a paired cleansable MARK
does not, leaving a stale stack count that a consumer reads.

> [!tip]
> GDScript runtime errors of this class **log and continue** — they do not abort the function. The
> symptom is a dead passive plus stderr spam, not a crash, so a probe cannot self-assert it. The
> regression signal is grepping stderr for the message.

### Cleanse runs full teardown (this is newer than most people think)

`dispel_with_teardown` (`scripts/effect_storage_component.gd:93-106`):

```gdscript
eff.breaker = breaker
if eff.effect_type == EffectType.Type.SHIELD or eff.effect_type == EffectType.Type.BARRIER:
	owner.check_effect_breaking(eff)   # mirror shatter_shields exactly
	eff.mag = 0
	consume_effect(eff)
else:
	eff.end_effect(EndingType.Type.CANCELLED)
```

Before this, the cleanse functions dropped effects with a bare `_effects.filter(...)` — no wrapup, no
break hooks, no signals. The reported symptom: Inuyasha's Iron Reaver stripped Mash's cleansable
permanent "A Knight That Protects" SHIELD and left the protected ally **permanently invulnerable**,
because `break_vow` is wired into `check_effect_breaking`, not into the shield's own `wrapup_func`.

Consequences worth internalising:

- The optional `by` breaker is threaded from the buff-strip call sites (`inuyasha3`, `ichibe5`,
  `tsubaki6`, `death1`) so whoever strips a shield eats its punish hook. `break_vow` null-guards
  `effect.breaker`, so an unattributed cleanse still breaks the vow without the punish mark.
- **`effect_removed` now fires for cleanse** of non-shield effects (via `end_effect(CANCELLED)` →
  `effect_expired` → `erase_effect`). Older notes that say "cleanse bypasses `erase_effect`" describe
  the pre-fix code. `clear_non_system_effects` (`:160-170`) still uses a bare `.filter()` and fires
  nothing — that one really does bypass the hook.
- `shield_effect` / `barrier` inherit the global `cleansable = true`. The `dur >= 0` auto-rule lives
  **only** inside `trigger_effect`, so a permanent shield is still strippable.

### Death cleanse

`Character.cleanse_death_effects` (`scripts/character_component.gd:1912-1923`) does two things, both
with raw `erase_effect` (so **no** wrapup, **no** break hooks):

```gdscript
for character in battle.all_characters():
	for effect in character.effects.get_all_death_cleansable_effects(self):
		character.effects.erase_effect(effect)
for effect in effects._effects.duplicate():
	if effect.cleansable:
		effects.erase_effect(effect)
```

Step 1 strips effects the dying character **cast onto anyone**, filtered by
`get_all_death_cleansable_effects` = `effect.user == dying and (not effect.system or effect.remove_on_death)`.
Step 2 strips every cleansable effect **on the corpse**, so a revive comes back clean rather than
stuck under an enemy's health cap.

> [!warning] Trap
> An effect a dying character places on an **ally** during its own on-death trigger is erased
> milliseconds later by step 1. `remove_on_death = false` does **not** save it — that flag only
> protects `system` effects. Two ways out: set `system = true` (survives but is invisible; pair with
> `display_system = true` to keep it on the wire), or apply it with the **ally** as the effect's
> `user` so `user != dying`, recovering the origin character via `eff.source.user`.
>
> The inverse also holds: a debuff whose `user` is the *killer* is not among the dead character's own
> effects and **lingers on the corpse**. Any "is my debuff still out there?" poll must skip dead
> holders (`if not c.dead and c.has_effect(...)`); banished holders are not dead and should still
> count.
>
> You also cannot apply an effect *to* the dying character inside its own on-death trigger —
> `can_apply_allied_effect` requires `is_alive(target)`. Use a flag on the ability instance.

See [[Node Lifecycle and Orphans]] for what happens to the Node objects behind all this, and
[[Effects and Durations]] for the duration model the ticking side uses.

## Silence v2: a pure usability gate

Silence used to block effect *application* at `Character.add_allied_effect` /
`add_hostile_effect`. That model was far too strong and **has been removed** — both bails are gone
and the functions now carry only an explanatory comment
(`scripts/character_component.gd:2073-2094`).

**Silence now means: "non-damaging skills cannot be used."** A Damaging skill a silenced character
*can* still use applies its effects completely normally.

`abilities/scripts/ability_component.gd:471-472`:

```gdscript
func is_silenced_out(user) -> bool:
	return user.is_silenced() and not classes.get("Damaging", false)
```

Called from **both** `usable()` (`:495`) and `authoritative_usable()` (`:527`) — the latter is what
the server ships as the `usable` flag on the wire (`new multiplayer/battle_manager.gd:2316`), so the
client greys the skill with no client-side logic at all.

> [!info] Why it deliberately does not route through `is_stunned()`
> Silence must ignore every stun escape hatch: the `stunnable` flag (the Unstunnable class),
> `shrug_off_type(STUN)`, a stun's `exclusion_targets` / `ability_targets` class filters
> (`scripts/character_component.gd:1603-1631`), and Erza's Clear Heart Clothing. Silence keeps its
> own counterplay — `is_silenced()` (`:1737-1743`) honours `shrug_off_type(SILENCE)`.

`classes.get("Damaging", false)` rather than `classes["Damaging"]`: an `Ability` whose dict predates
the key must read false, not crash.

### The "Damaging" class

The axis is **timing**, not certainty and not primary purpose:

- **Damaging** = a damage sink reachable from `execute()`, directly or via a same-file helper it
  calls. Conditional-on-board-state damage still counts. **Immediate hit plus a DoT is Damaging**
  (`squalo1`, `tokoyami1`).
- **Not Damaging** = damage that lands later with no on-use hit: DoTs alone, ticking / reactive /
  counter / on-death triggers (`meliodas2` Full Counter, `yamamoto2` Utsuhi Ame), damage inside a
  lambda *defined* in `execute()`, or `execute_attempt()` alone (an execution is not damage).

454 of the 1090 entries in `abilities_data.json` carry it today (it was 440 when the class was first
swept in; characters have been added since). It is **player-visible** — it ships in the client's
`ability_info.json` and renders in the "Classes:" line, so the sync invariant is plain equality
between client and server class arrays. See [[Changing Ability Text]].

> [!warning] Trap
> `hashirama1` / `hashirama2` are **hand-overridden** to Damaging. They call `resolve_damage`
> unconditionally, but `hashirama5`'s passive applies a permanent self-delay and `battle_manager`
> returns before `execute()` when a skill is delayed — so the automatic classifier scored them
> non-Damaging and left a silenced Hashirama with *zero* usable skills. `chrome` and `yubel` are
> genuine full lockouts (0 Damaging skills, pure support kits) — correct per the rule, never ruled on
> as desirable.

## Reading cost before a self-cleanse

Some skills grant a bonus **"if this skill costs at least 1 Random energy"** — implemented as
`cost()[Energy.Type.RANDOM] >= 1`. Base costs never contain Random, so this is true only when an
enemy has taxed the caster with a `+Random` `COST_MOD` (Crona, Gallantmon, BlackWarGreymon). It is an
**anti-cost-increase** design: taxing the character powers up their kit.

> [!warning] Trap
> If the same ability *also* self-cleanses, read the cost **first** — the cleanse strips the enemy's
> `COST_MOD` and the conditional can never fire afterwards. `abilities/death1.gd:27-29`:
>
> ```gdscript
> var strip_buffs = cost()[Energy.Type.RANDOM] >= 1
> # ...
> user.effects.cleanse_all_enemy_effects(user)
> ```

Details of what `cost()` resolves are in [[Cooldowns and Energy]].

Related: [[Effects and Durations]], [[Trigger Types]], [[Damage Pipeline]],
[[Targeting and Main Target]], [[Traps That Have Bitten Us]], [[Adding a Playable Character]].
