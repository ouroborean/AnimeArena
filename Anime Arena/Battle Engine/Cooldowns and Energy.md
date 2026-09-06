---
tags: [area/engine, type/reference]
---

# Cooldowns and Energy

The two resources that decide whether a skill can be used at all. Both are server-authoritative, both
are mirrored (not re-derived) on the web client, and both contain one piece of bookkeeping that looks
like an off-by-one until you know why it is there.

## Cooldowns

### start_cooldown always writes cooldown + 1

`abilities/scripts/ability_component.gd:607-639`:

```gdscript
cooldown_started_turn = -1
if user != null and is_instance_valid(user) and user.battle != null and is_instance_valid(user.battle):
	cooldown_started_turn = int(user.battle.current_turn_number)
cooldown_remaining = cooldown + 1 + cooldown_mod
```

The `+1` is **not** a turn of progress. `MovesetComponent.advance_cooldowns` runs for the *acting*
team at the end of that same turn (`new multiplayer/battle_manager.gd:1334-1337`, inside
`end_of_turn_effect_handling`) and takes it straight back off, so the skill settles on exactly its
printed cooldown. Mid-turn, a cooldown-0 skill correctly reads `1`.

`cooldown_mod` is the sum of the user's `COOLDOWN_MOD` effects, honouring `shrug_off_type` for
enemy-sourced mods, `per_stack`, and per-ability `ability_targets` filters
(`ability_component.gd:609-624`).

### Paralyze freezes the countdown, and only the countdown

`EffectType.Type.PARALYZE` (`Character.paralyzed()`, `scripts/character_component.gd:1826-1833`)
blocks exactly one thing: the decrement in `advance_cooldowns`. Not usability, not energy, not
targeting.

`scripts/moveset_component.gd:39-70`:

```gdscript
func advance_cooldowns(user):
	var paralyzed: bool = user.paralyzed()
	var checked_abilities = []
	for ability in base_abilities:
		checked_abilities.append(ability)
		_advance_one(ability, paralyzed)
	for ability in get_active_abilities(user):
		if not ability in checked_abilities:
			_advance_one(ability, paralyzed)

func _advance_one(ability, paralyzed: bool) -> void:
	if ability == null:
		return
	var owed: bool = int(ability.cooldown_started_turn) >= 0
	ability.cooldown_started_turn = -1
	if paralyzed and not owed:
		return
	if ability.cooldown_remaining > 0:
		ability.cooldown_remaining -= 1
```

Note it advances both `base_abilities` **and** `get_active_abilities(user)` (which resolves
ABILITY_SWAP and SKILL_COPY), deduplicated — a swapped-in skill still ticks down.

> [!warning] Trap
> The old code pre-compensated inside `start_cooldown` (`if user.paralyzed(): start_mod = 0`). That
> decision is made at `new multiplayer/battle_manager.gd:1190`, but reactive Paralyze sources
> (Yoruichi's Shunko: Gather, Rimuru's Gluttony counter) land from
> `check_ability_use_triggers()` at `:1206` — **later in the same action**. So a skill used into a
> mid-action Paralyze kept its `+1` and never got it back: every skill settled one turn above its
> printed cooldown, and a **cooldown-0 skill came back unusable**. Under a standing reactive
> Paralyze it compounded — a character who acts every turn never recovers any cooldown. The mirror
> case (paralyzed at `start_cooldown`, cleansed before end of turn) handed out a free
> `cooldown - 1`.

The fix stops guessing at stamp time and decides at decrement time.

> [!info] The test is "is there an UNRECLAIMED stamp", not "was it stamped this turn"
> Normally identical — the stamp is cleared by the advance at the end of the turn it was written.
> They diverge when that advance never ran, which `end_of_turn_effect_handling` skips for a dead or
> banished holder (`battle_manager.gd:1334-1337` iterates only living, non-banished characters). The
> `+1` is then still owed and is reclaimed by the first advance that does run — so a character who
> acts, dies mid-turn and is revived does not come back one turn short.

Both match-teardown loops reset the stamp alongside the countdown
(`new multiplayer/battle_manager.gd:1796-1797` and `:1808-1809`).

Regression-locked by `training/tests/cooldown_paralyze_probe.gd`, which covers all four quadrants
(Paralyze before / during / absent × used / not used this turn) and drives the **real** ordering:

```gdscript
ab.start_cooldown()
ab.execute(caster, m)
caster.check_ability_use_triggers(m, ab)
```

No cooldown or Paralyze test existed before this, which is why the bug shipped. See
[[Verification Playbook]].

### Abilities that bypass start_cooldown

> [!warning] Trap
> Four abilities hard-set *another* ability's `cooldown_remaining` with the `+1` baked in and never
> go through `start_cooldown`, so they keep the off-by-one under Paralyze:
> `abilities/soul5.gd:24-26`, `abilities/tsubaki5.gd:25-27`, `abilities/lizandpatty1.gd:39`,
> `abilities/lizandpatty2.gd:39`. `soul5` / `tsubaki5` also have a bespoke
> `waiting_for_turn`-dependent `= 4` branch that would need understanding before touching. Left
> deliberately unfixed.

`abilities/uranus2.gd:50-57` *overrides* `start_cooldown` and calls `super`, so it inherits the fix.

> [!warning] Trap
> That override's comment says it temporarily swaps the base `cooldown` field to 1 and restores it —
> but the code assigns `cooldown_remaining = 1` before calling `super.start_cooldown()`, which then
> overwrites it with `cooldown + 1 + cooldown_mod`. The `var saved = cooldown` / `cooldown = saved`
> round-trip is a no-op. Verified by reading the file; the intended 1-turn Lip-Rod cooldown does not
> appear to take effect.

### The usability gates

Two near-identical functions, and the difference matters:

| | `usable(user)` `ability_component.gd:475` | `authoritative_usable(user, ignore_energy)` `:512` |
| --- | --- | --- |
| Purpose | local/bot decision making | what the server ships to clients |
| Turn ownership (`waiting_for_turn`, `used_ability`, `waiting`) | checked | **not** checked |
| Energy affordability | always | skipped when `ignore_energy` |
| Passive-client short-circuit (`server_usable`) | yes | n/a |

Both check: delayed skill, `cooldown_remaining > 0`, `is_stunned(self) and stunnable`,
`is_silenced_out(user)` (see [[Cleanse Silence and Effect Removal]]), `banished`, the "Relinquished"
mark, any `MARK` with `skill_seal` set, and the ability's own `extra_usable(user)` override.

The wire ships `authoritative_usable(character, true)` —
`new multiplayer/battle_manager.gd:2316`:

```gdscript
"usable": bool(ability.authoritative_usable(character, true)),   # non-energy usability; clients check affordability themselves
```

> [!info] Why energy is excluded from the wire flag
> Each client tracks its own pool, **including a pending 2-for-1 exchange the server has not seen
> yet**. Baking affordability into the server flag wrongly disabled exchange-funded skills.

## Energy

### The pool

`components/energypool.gd` holds four storable colours and a fifth cost-only token:

```gdscript
var pool: Dictionary = { GREEN: 0, BLUE: 0, WHITE: 0, RED: 0 }
var promised_pool: Dictionary = { GREEN: 0, BLUE: 0, WHITE: 0, RED: 0, RANDOM: 0 }
```

`Energy.Type` is `GREEN=0, BLUE=1, WHITE=2, RED=3, RANDOM=4` (`scripts/types/energy.gd`).

> [!warning] Trap
> **RANDOM is a cost token, not a storable colour.** `pool` has no key `4`.
> `change_energy` deliberately `push_error`s and returns rather than auto-vivifying `pool[4]` into a
> fake negative bucket (`components/energypool.gd:130-132`). Anything that needs to spend RANDOM goes
> through `receive_generic_allocation_offer` (the client resolves random pips into specific colours)
> or `change_promised_energy`.

`promised_pool` is the *staged* spend for the turn in progress: `TeamComponent.pay_for_ability`
(`scripts/team_component.gd:65-67`) writes into `promised_pool`, not `pool`. `true_pool()` is
`pool - promised_pool` per colour; `total_available()` also subtracts the promised RANDOM.

### Affordability

`_can_afford_from` (`components/energypool.gd:82-92`) is the whole algorithm:

```gdscript
for energy_type in cost:
	var amount = cost[energy_type]
	if total < amount:
		return false
	if not energy_type == Energy.Type.RANDOM:
		if current_pool[energy_type] < amount:
			return false
		else:
			total -= amount
return true
```

Specific colours must exist in their own bucket **and** consume from the running total; a RANDOM cost
only has to fit in whatever total is left. Dictionary iteration order in GDScript is insertion order,
and costs are built `0..4`, so specific colours are always debited before RANDOM is measured.

`can_afford_after_exchange(cost, offer, request)` mirrors `accept_exchange`'s pool delta on a **copy**
(nothing is mutated) so a turn funded by a same-turn 2-for-1 trade validates —
`components/match.gd:556-564` passes `exchange_unapplied = true` only for the web/JSON path, because
the exchange is bundled in `submit_turn_input` and applied later in `apply_input`.

### Generation

`BattleManager.generate_team_energy` (`new multiplayer/battle_manager.gd:1347-1359`):

- **First turn**: one roll, one pip, for the team as a whole.
- **Every other turn**: one pip per character that is not `dead`, not `banished`, and not
  `sleepy_frieren()` — `Character.generate_energy` (`scripts/character_component.gd:405-409`) rolls
  `0..3` through the seeded `battle.roll`, so both sides reproduce it exactly
  ([[Server Authority Model]]).

`prepare_acting_energy_if_needed()` (`:1489-1501`) pre-generates the acting team's pool before
`Match.validate_input` runs, for the p2-first case where `process_turn_package` would otherwise be
the first thing to generate — without it the pool is empty at validation time and every action looks
unaffordable. `process_turn_package` consumes that latch on entry (`acting_energy_prepared`), and
skips generation entirely for `shadow_mode and team_mod == 0` — letting it run there would double the
acting team's energy and drift every hash.

### The drain is client-declared

`process_turn_package:1588`:

```gdscript
team.energy.receive_generic_allocation_offer(package['random_history'], true)
```

`random_history` / `energy_allocation` is `[[colour, count], ...]` in **specific colours only** and is
the sole source of truth for the turn's drain. The client builds it as specific costs plus the
manually placed RANDOM pips (`webclient/app/app.js:1523-1525`):

```js
const spec = specificTotals(), assign = S.randomAssign;
for (let c = 0; c < 4; c++) { const tot = spec[c] + (assign[c] || 0); if (tot > 0) energy_allocation.push([c, tot]); }
```

> [!warning] Trap
> Emitting the raw ability cost instead would leak the RANDOM key (`4`) onto the wire, and the
> passive client's `change_energy` / `lose_energy` replay would crash on `pool[4]`.
> `receive_generic_allocation_offer` also `int()`-coerces both element and count, because web clients
> send JSON where every number arrives as a float and the pool otherwise drifts to float values.

An older bug ran this drain only for `team_mod == 0`, so player 2's acting turn never drained the
shadow's `enemy.team` pool and `promised_pool` grew unbounded. It now always runs for the acting team.

### Client mirror

`webclient/app/app.js:1319-1418` is a small parallel model, not a re-implementation of the engine:

| Function | Behaviour |
| --- | --- |
| `myPool()` `:1323` | snapshot pool **with the pending exchange folded in** (−offer, +1 request) |
| `specificTotals()` / `randomTotal()` | per-colour and RANDOM totals across staged actions |
| `canAddAbility(ability)` `:1356` | per-colour fit **plus** total leftover capacity ≥ all RANDOM |
| `remainingPool()` | pool − specific − assigned RANDOM |
| `reconcileRandomAssign()` `:1369` | clamps and trims after any stage/unstage/exchange; **never auto-fills** — the player places every RANDOM pip |
| `canExchange()` `:1391` | port of `can_exchange()`: some colour has ≥2 free this turn; one exchange per turn (no `promised_pool` client-side) |
| `clearExchange()` `:1406` | **cancels every staged skill first** — queued skills were allowed to spend the traded colour, so an undo could otherwise drive a colour to −1 |

`submitTurn` refuses to send when any `remainingPool()` colour is negative, because the server drops a
rejected turn silently (there is a watchdog for that, `app.js:1494-1499`) and the UI would otherwise
lock up.

### Effective cost

`Ability.cost()` (`abilities/scripts/ability_component.gd:247-330`) returns the **resolved** cost dict
`{0..4}` = base `_cost`, then:

1. `COST_CHANGE` — replaces the entire cost (globally or for named `ability_targets`).
2. `COST_MOD` — adds/subtracts per colour, clamped at 0, `per_stack`-aware, honouring
   `shrug_off_type(COST_MOD)` for hostile sources.
3. `COLOR_CHANGE` — rewrites colours into other colours.

On a passive client it short-circuits to the server-serialized `server_cost` — a passive client has
no runtime `_effects`, so recomputing locally would silently return the base cost for anyone under a
cost effect. Inside `execute()` a bare `cost()` is correct and server-authoritative.

`cost()` also feeds two non-obvious consumers:

- **Toji's COST_STUN** — `is_stunned` treats a skill as stunned when its *resolved* cost pays a
  colour named by a `COST_STUN` effect (`scripts/character_component.gd:1616-1618`), so a `+1 Green`
  `COST_MOD` from Playful Cloud feeds straight in.
- **Toji's cost-colour INVULN** — `is_invuln` lets through only skills whose resolved cost pays
  `cost_color_required` (`:1652-1658`).
- The **"costs at least 1 Random"** conditional, covered in
  [[Cleanse Silence and Effect Removal]] (read it *before* any self-cleanse).

## Server-side validation

`Match.validate_input` (`components/match.gd:478-568`) re-derives everything from the shadow manager
before the turn is applied: sender seat, `char_idx` inside the sender's canonical range, character
alive, `ability_idx` within `get_active_abilities`, `cooldown_remaining == 0`,
`is_stunned(ability)`, target indices in bounds, and total cost affordable (post-exchange where
applicable). A rejected package is dropped without a reply.

Related: [[The Turn Pipeline]], [[Server Authority Model]], [[Effects and Durations]],
[[Targeting and Main Target]], [[Web Client Architecture]], [[Traps That Have Bitten Us]].
