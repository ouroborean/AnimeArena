---
tags: [area/engine, type/reference]
---

# Targeting and Main Target

Targeting in this engine is two separate mechanisms that people constantly conflate:

1. **Who a skill is *allowed* to hit** — computed by running the ability's own `target()` function,
   which flags characters via `set_targeted()`. Server-authoritative; shipped to the web client as
   `special_targets`.
2. **Who a skill *is* hitting, and which of them is the primary** — the caster's
   `TargeterComponent`, a plain `targets: Array` plus a single `main_target` reference.

The second one has no explicit wire representation. **Order is the protocol.** That is the single
most surprising fact in this file and it caused a real shipped bug.

## TargeterComponent is 47 lines and does nothing clever

`scripts/targeter_component.gd` in full is a list, a pointer, and a `targeting` flag:

```gdscript
func add_target(target):
	if main_target == null:
		main_target = target
	targets.append(target)
```

`scripts/targeter_component.gd:26-29`. The **first** `add_target` call after a reset decides
`main_target` forever; every later call just appends. There is no "set primary" call on the human
path anywhere in `new multiplayer/battle_manager.gd`.

`remove_target` (`:14-20`) repoints `main_target` to `targets[0]` if the removed one was primary, and
to `null` if the list empties. `clear_targets` (`:22-24`) nulls it outright.

## The wire: target_idxs order IS "primary first"

`BattleManager.process_turn_package` walks the client's `target_idxs` in the order they arrived:

```gdscript
var target_indexes = action_set[2]
for target in target_indexes:
	if team_mod == 3:
		if target > 2:
			target -= 3
		else:
			target += 3
	char.targeter.add_target(all_characters()[target])
```

`new multiplayer/battle_manager.gd:1559-1566`. The `team_mod == 3` remap (canonical → the shadow
manager's local frame for player 2) is per-element and order-preserving, so it cannot reshuffle the
primary. See [[Server Authority Model]] for why the server rebuilds the turn from indices at all.

**22 ability files read `user.targeter.main_target`** to split a primary hit from splash. The idiom
is always the same shape — `abilities/gojo3.gd:17-21`:

```gdscript
for target in user.targeter.targets:
	if target == user.targeter.main_target:
		Character.resolve_damage(context, target, 45, DamageType.Type.PIERCING)
	else:
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
```

Same pattern in `abilities/tsunayoshi1.gd` (X-Burner), `abilities/korra7.gd`, `abilities/ace3.gd`,
`abilities/boruto6.gd`, `abilities/jupiter3.gd`, `abilities/mash2.gd`, `abilities/nonon5.gd`,
`abilities/xanxus2.gd`. Others dereference it directly and would crash on `null`
(`abilities/ganta3.gd:23` passes `main_target` straight into `resolve_damage`); several *reassign* it
temporarily inside a counter and restore it afterwards (`abilities/adam2.gd:34-44`,
`abilities/byakuya5.gd:51-61`, `abilities/gasai3.gd:38-47`).

> [!danger] Never do this
> Do not build an AoE `target_idxs` list by copying the server's `special_targets` array. It arrives
> in ascending canonical order, so the top character on the clicked side silently becomes the
> primary — every 45/15, 25/10, 40/20 skill resolves its big hit on the wrong target, with no error
> and no log line.

That is exactly what shipped. `pickTarget` used `t.special_targets.slice()`; the fix leads with the
clicked index (`webclient/app/app.js:1435-1450`):

```js
if (tt === 2) targets = [canonTarget].concat(t.special_targets.filter((idx) => idx !== canonTarget));
else if (tt === 1) targets = [canonTarget].concat(t.special_targets.filter((idx) => idx !== canonTarget && (idx < 3) === (canonTarget < 3)));
else targets = [canonTarget];
```

`tt` is `TargetType.Type` as an int: `0 SINGLE, 1 ALL_FACTION, 2 ALL, 3 COUNT, 4 SELF`
(`scripts/types/target_type.gd`). SINGLE/COUNT/SELF were never affected — they send one index.

Regression-locked by `battle: an AoE sends the CLICKED target first (it becomes the server's
main_target)` in `webclient/app/aa-tests.js:2101`. Reverting the fix fails it with
`expected [5,3,4], got [3,4,5]`.

### The bot path was always correct

Bots assign the pointer explicitly before expanding the AoE (`scripts/player_component.gd:869-883`):

```gdscript
character.targeter.targets = [primary_target]
character.targeter.main_target = primary_target
character.used_ability = chosen_ability
chosen_ability.target(character, battle)      # re-mark, so get_other_aoe_targets sees who is valid
```

then calls `battle.get_other_aoe_targets(...)`. So a bug that breaks every human AoE can look
perfectly fine in bot self-play — see [[Bots and Training]].

### get_other_aoe_targets

`new multiplayer/battle_manager.gd:1817-1820` fills in the non-primary targets from the currently
flagged (`.targeted`) characters:

```gdscript
for character in all_characters():
	if not (character in targeter.targeter.targets) and not character == main_target and character.targeted and (not faction_specific or not are_characters_hostile(character, main_target)) and (not and_check or targeter.used_ability.and_target(character)):
		targeter.targeter.add_target(character)
```

It **appends only**, so it can never steal the primary slot — which is why the in-engine commit path
(`scripts/character_component.gd:1994-2008`) sets `targeter.main_target = character` first and then
emits `request_aoe_targets`, wired to this function at `new multiplayer/battle_manager.gd:510`.
`faction_specific` implements ALL_FACTION; `and_check` is the `and_targeter` flag, an ability-level
"also drag in everyone matching `and_target()`".

## Which targets a skill may legally pick

`_compute_special_targets` (`new multiplayer/battle_manager.gd:2390-2409`) is the authoritative
answer. It runs the ability's real `target()` on real state and reports canonical indices:

```gdscript
for c in chars:
	saved_flags.append(c.targeted)
	c.targeted = false
ability.target(character, self)
# ...collect chars[i].targeted...
for i in range(chars.size()):
	chars[i].targeted = saved_flags[i]
```

The snapshot/restore is load-bearing: `target()` mutates `character.targeted` as a side effect, and
the server probes every ability of every character each snapshot (`:2324`). Without the restore, the
server's targeted state would permanently drift to whatever ability was serialized last.

It ships in the wire frame per ability alongside `target_type` and `usable`, because a passive client
has **no runtime `_effects`** and cannot evaluate invulnerability, isolation, marks, `mark_req`, or
`TARGET_CHANGE` locally ([[Web Client Architecture]]).

The default targeting helpers are on `Ability` (`abilities/scripts/ability_component.gd:803-819`):

```gdscript
func default_hostile_target_function(user, battle, bypassing=false, mark_req = null):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if mark_req == null or character.has_effect(mark_req, EffectType.Type.MARK, user):
			check_hostile_target(user, character, context, bypassing)
```

`check_hostile_target` calls `Condition.can_hostile_target(...).satisfied(context)` and flags on
success.

## Invulnerability bypass is a PARAMETER, not a class

`scripts/condition.gd:166-177`:

```gdscript
static func can_hostile_target(targeter, target, targeting_ability, bypassing=false) -> Condition:
	var not_invuln = Condition.is_not(Condition.is_invuln(target, targeting_ability))
	var conditions = [hostile, alive, extra]
	if not bypassing:
		conditions.append(not_invuln)
	return Condition.multi(conditions)
```

> [!warning] Trap
> `ability.classes["Bypassing"]` is the **wrong** test for "does this skill pierce invulnerability".
> Measured against `abilities_data.json` + the ability scripts: 35 abilities carry the class, 47 pass
> a truthy bypass argument to `default_hostile_target_function` / `check_hostile_target`, and
> **19 pass bypass with no class at all** — `bakugo2`, `blackstar3`, `ichibe5`, `itachi5`, `itachi7`,
> `kaiba6`, `kurotsuchi6`, `mavis6`, `mine3`, `orihime1`, `rob5`, `semiramis3`, `tamaki1`, `tamaki5`,
> `tatsumaki2`, `tatsumaki5`, `yubel2`, `yubel4`, `yuno7`.
>
> This holds for **hand-written** kits, where the flag is whatever that script's `target()` passes.
> **AUTHORED** abilities are the one place the class IS the flag: `ScriptedAbility.target` has no
> per-skill script to read it from, so it derives `bypassing` from `classes["Bypassing"]` and passes
> it to the helpers (and `BlockRunner` uses the same class as the default for its own target pools).
> Re-running `target()` therefore still gives the right answer for both kinds of ability — which is
> exactly why it, and not the class, remains the general test below.

`Character.is_invuln(ability)` (`scripts/character_component.gd:1636-1669`) likewise knows nothing
about the caller's bypass — it only evaluates the *defender's* INVULN effects, their `class_targets`
/ `exclusion_targets` filters, `DEF_NEGATE`, and Toji's cost-colour gate (`cost_color_required`,
see [[Cooldowns and Energy]] for why that reads the *effective* cost). Callers are expected to skip
it entirely for bypassing skills.

**The only correct way to ask "can this skill legally hit X right now" is to re-run its own
`target()`** — i.e. `_compute_special_targets`. That automatically respects bypass, class-filtered
invuln, `mark_req`, isolate, and every bespoke `target()` override.

## _drop_invuln_targets: the execution-time re-check

Targets are locked when a player queues a skill, but a *later* action in the same turn can make one
of them invulnerable — Death's Death Barrier grants team-invuln from a counter that fires during the
opponent's turn, after other enemies already aimed at the protected ally. Nothing downstream
re-checks: `Character.resolve_damage` does not consult `is_invuln`.

`new multiplayer/battle_manager.gd:1147-1170`, called from `execute_ability` at `:1202`, right after
the counter check and before reflect / accuracy / `execute()`:

```gdscript
var targetable := _compute_special_targets(ability, actor)
var kept := []
for target in actor.targeter.targets:
	if actor.is_hostile(target) and target.is_invuln(ability) and not (_canonical_index(target) in targetable):
		continue
	kept.append(target)
```

| Behaviour | Why |
| --- | --- |
| Hostile targets only | Invuln never blocks allied or self skills |
| Cheap pre-check first (`any_invuln`) | Skips the `target()` re-run in the overwhelmingly common case |
| Kept if still in `_compute_special_targets` | This is what makes bypassing skills keep their target |
| Repoints `main_target` if it was dropped | Otherwise the primary pointer dangles into a removed entry |
| **Returns `false` when every target was dropped** | ~22 abilities dereference `main_target` / `targets[0]` and would crash on an empty targeter |

On a full fizzle the caller skips `execute()` but still sets `char.acted = true` and plays the
animation — deliberately mirroring the `countered` branch, so the turn looks identical to the player.

## Other things that mutate the targeter after targeting

These run *between* target selection and `execute()`, so an ability must never assume its target list
is what the player picked:

- **Accuracy / dodge** — `Character.accuracy_check` (`scripts/character_component.gd:1813-1824`)
  calls `miss_check()`, which can `targeter.clear_targets()` outright, then removes each target that
  passes its own `dodge_check`. `ability.accurate` skips the whole thing.
- **Blind** — `execute_ability` calls `get_valid_random_targets(char)`
  (`new multiplayer/battle_manager.gd:1823-1838`) when `ability_blinded` is set; that clears the
  targeter, re-runs `target()`, rolls a random valid character, and assigns both `targets` and
  `main_target`. Blind is applied in `process_turn_package` (`:1568-1573`) and skipped for
  ALL / ALL_FACTION / SELF.
- **Reflect** — mutates the caster's targeter before `execute()` runs; the return value is ignored.
  See [[Trigger Types]].

## Client-side rules worth knowing

- `onAbilityTap` (`webclient/app/app.js:1420-1434`) never auto-targets, even for SELF: it always
  enters target selection so AoE highlighting is consistent. If `special_targets` is empty (every
  legal target is currently invulnerable) it refuses the cast with a message rather than staging a
  target-less action.
- `stage()` pushes `{char_idx, ability_idx, target_idxs, ability_name, cost}`; `submitTurn` maps that
  to `actions: [{char_idx, ability_idx, target_idxs}]` (`app.js:1531`) — `target_idxs` is the only
  place primary-ness is expressed.
- `Match.validate_input` (`components/match.gd:539-545`) range-checks each target index but
  deliberately does **not** validate them against `special_targets`; targeting legality is enforced
  by `_drop_invuln_targets` and by the abilities' own `target()` at execution.

Related: [[The Turn Pipeline]], [[Damage Pipeline]], [[Trigger Types]],
[[Cleanse Silence and Effect Removal]], [[Traps That Have Bitten Us]],
[[Verification Playbook]].
