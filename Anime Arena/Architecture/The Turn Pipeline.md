---
tags: [area/architecture, type/reference]
---

# The Turn Pipeline

This is the single most load-bearing ordering in the codebase. Nearly every "why did my ability do
nothing / do it twice / do it a turn late" bug traces to a misreading of it. Read this before
writing any ability that touches turn boundaries.

Everything below happens inside the server's shadow `BattleManager`
(`new multiplayer/battle_manager.gd`); see [[Server Authority Model]] for how it gets there.

## The order, exactly

```
submit_turn_input
  └── Match.validate_input                       # match.gd:478 — reject or pass
  └── Match.apply_input                          # match.gd:573 — canonical → legacy frame
        └── BattleManager.receive_turn_package
              └── process_turn_package            # battle_manager.gd:1505
                    1. resolve acting team + team_mod (0 for p1, 3 for p2)
                    2. generate_team_energy(acting team)      [unless already latched]
                    3. apply the bundled energy exchange
                    4. STAGE each action: pay cost, set used_ability, add targets in order
                    5. drain the pool from random_history → ENERGY_SPENT
                    6. ★ SNAPSHOT the ticking effects  ← get_ticking_effect_information
                    7. true_execution_order = player's order, filtered, + missing ticks appended LAST
                    8. start_round_loop()
                          └── execution loop: pop each step, execute, check_match_over
                                └── end_of_turn_effect_handling()      # :1316
                                      a. turn_ended_event
                                      b. dead/banished cleanup for ALL characters
                                      c. ACTING TEAM ONLY, per character:
                                           advance_cooldowns()
                                           check_end_of_turn_triggers()
                                      d. tick_durations()   ← ALL characters
                                      e. turn_over()                    # :609
                                            └── check_start_of_turn_triggers
                                                  ← BOTH teams
                                            └── start_new_turn() / wait_for_turn()
```

## 1. The ticking snapshot is taken BEFORE any ability runs

`process_turn_package` stages every action (paying costs, setting `used_ability`, wiring targets) but
executes **nothing**. Only then:

```gdscript
var ticking_information = get_ticking_effect_information(team_mod == 3)   # :1601
for key in ticking_information.keys():
    ticking_information[key].sort_custom(func (a, b): return a.twin_priority < b.twin_priority)
    execution_order[key] = ticking_information[key]
```

The board is frozen at submission time. Consequences you will hit:

> [!warning] A ticking effect applied this turn does NOT tick this turn
> Apply a DoT, a HoT, or a `TICKING_TRIGGER` during turn N and it was not in the snapshot taken at
> the top of turn N — so it produces zero instances on the turn it lands. "Deal 15/turn for 2 turns"
> is therefore **an immediate manual `resolve_damage` + a duration-3 DoT**, not a duration-4 DoT.
> Lengthening the window instead of dealing the first instance by hand produces a skill that starts
> late and overstays. The rule is "recurring effects never fire on the turn they're cast" — see
> [[Effects and Durations]].

> [!warning] Probe trap
> Because the queue is built at turn *start*, a headless test that casts a skill and then calls
> `get_ticking_effect_information` for the same side manufactures a phantom same-turn tick no real
> match can produce. End the cast turn with a bare `start_round_loop()` (no gather), then emulate
> turns normally. Cost several hours of chasing a non-existent engine bug. See
> [[Verification Playbook]].

### Which effects make the snapshot

`get_ticking_effects(character, is_enemy)` (`:821`) walks four buckets and gates every one on
`effect.user in team`, where `team` is the **acting** side:

| Bucket | Extra condition |
|---|---|
| `get_damage_effects()` | `not effect.last_turn_only or effect.duration == 1` |
| `get_healing_effects()` | — |
| `get_ticking_triggers()` | — |
| `get_delayed_skills()` | `effect.duration == 1` |

So a DoT ticks on its **applier's** turns only — every *other* duration decrement, since durations
tick on both sides' turns. A `last_turn_only` damage effect fires exactly once, at duration 1.

`get_ticking_effect_information` (`:782`) then allocates ids: a counter starting at **3**, walking
the acting team first and then the opposing team, grouping effects whose
`[source.ability_name, effect_type, id]` triple matches into one step. That grouping is why two
copies of the same DoT resolve as a single batch. The client sees these ids `+ 3` (so `>= 6`) to keep
them clear of canonical character indices 0–5.

## 2. `execution_order` is player-authored

The player drags the turn's steps into whatever order they want in the End-Turn modal, and the server
honours it. That list arrives as `package['execution_order']` and is assigned straight to
`true_execution_order` — then sanitized:

```gdscript
true_execution_order = package['execution_order']
true_execution_order = true_execution_order.filter(
    func(e): return e in execution_order            # drop client entries the server doesn't know
)
for key in ticking_information.keys():
    if key not in true_execution_order:
        true_execution_order.append(key)            # ← missing ticks go to the BACK
```
`new multiplayer/battle_manager.gd:1605-1616`

Two rules fall out:

1. **Unknown keys are dropped, not rejected.** Passive clients build their ticking ids from
   *display* effects, which can group differently from the server's real effects. Rather than fail
   the turn, the server discards anything it doesn't recognize.
2. **Anything the client omitted is appended LAST.** Nothing is ever silently skipped, but an
   omitted tick resolves after every step the player did specify. If a client bug drops a tick from
   the list, the symptom is "my poison resolved after his heal", not "my poison vanished".

The preview the client drags is baked into every snapshot by `_serialize_execution_preview()`
(`:2199`), computed with the *exact* `get_ticking_effect_information(waiting_for_turn)` the apply
path will use, on the same frozen board — so each `order_id` the client sends back maps to the
identical `execution_order` key at resolution time.

> [!tip] Hidden machinery must not surface as a draggable tile
> `_serialize_execution_preview` skips `first.system and not first.display_system`. Without that
> guard, invisible per-turn machinery (Minene's Explosives Detonator incrementer) appeared in the
> reorder modal as a phantom tile with no matching on-board effect. Execution is unaffected — it
> reads `_effects` directly. If a per-turn effect *should* be visible to the player, make it
> non-`system` and it correctly appears both on-board and in the preview. See
> [[Effects and Durations]].

## 3. The execution loop

```gdscript
func _execution_loop_step_sync():          # battle_manager.gd:968 — the shadow path
    while len(true_execution_order) > 0:
        var action_id = true_execution_order.pop_front()
        …                                   # int/float key coercion (JSON floats vs GDScript ints)
        var executable = execution_order[action_id]
        execute_step(executable)
        if check_match_over(): return       # ← end_of_turn_effect_handling is SKIPPED
    end_of_turn_effect_handling()
```

`execute_step` (`:1126`) dispatches: an `Ability` → `execute_ability`; an `Array` → re-sort by
`twin_priority` and `execute_ticking_effect` each member.

> [!warning] The shadow MUST run synchronously
> `execution_loop_step` (`:961`) forks on `shadow_mode`. The async variant paces animations with
> `await`; if the shadow yielded mid-turn, `apply_input → recorder drain → _broadcast_turn_result`
> would fire after only the first action's events were recorded and the rest would be lost. The
> async path additionally carries a 30 s watchdog (`PLAYBACK_WATCHDOG_TIMEOUT`) because Godot
> swallows errors raised inside coroutines, which would otherwise freeze playback forever.

A match that ends mid-loop returns early and **never runs end-of-turn handling** — no cooldown
advance, no duration tick. That's intentional; the match is over.

Before each queued ability resolves, `_drop_invuln_targets` (`:1147`) re-runs the skill's own
`target()` to see who it can still legally hit *right now* and drops hostile targets that became
invulnerable since the skill was queued (e.g. by an earlier action this turn). If every target is
dropped the skill fizzles and `execute()` is skipped, because abilities that dereference
`main_target` would crash on an empty targeter. See [[Targeting and Main Target]].

## 4. End of turn

```gdscript
func end_of_turn_effect_handling():                       # :1316
    turn_ended_event.emit(current_turn_number)
    reset_character_targeted()
    var team = player.team.characters
    if waiting_for_turn:
        team = enemy.team.characters                      # the ACTING side
    for character in all_characters():                    # ← everyone
        if not is_instance_valid(character.battle): continue   # stale cross-match ref guard
        if character.dead or character.banished:
            character.check_cancels()
            if not character.banished:
                character.effects.clear_non_system_effects(character)
    for character in team:                                # ← ACTING TEAM ONLY
        if not (character.dead or character.banished):
            character.moveset.advance_cooldowns(character)
            character.check_end_of_turn_triggers(self)
    tick_durations()                                      # ← everyone again
    turn_over()
```

Three different scopes in twelve lines. Getting them confused is the classic bug:

| Step | Scope |
|---|---|
| dead/banished cleanup | **all** characters |
| `advance_cooldowns` | **acting team only** |
| `check_end_of_turn_triggers` | **acting team only** |
| `tick_durations` | **all** characters |
| `check_start_of_turn_triggers` (in `turn_over`) | **both teams** |

> [!warning] END_OF_TURN_TRIGGER is team-gated; START_OF_TURN_TRIGGER is not
> An `END_OF_TURN_TRIGGER` on a character only fires on that character's own team's turns, for free.
> A `START_OF_TURN_TRIGGER` fires for **every** character at **every** transition and has no built-in
> gate — if you want "at the start of my team's turn", you must write the gate yourself. And you
> cannot write it as `if battle.waiting_for_turn` (see below).

`advance_cooldowns` runs **before** `check_end_of_turn_triggers` in the same per-character loop. That
matters for any end-of-turn trigger that reads or writes `cooldown_remaining`: it sees the
already-decremented value.

> [!info] The cooldown +1
> `Ability.start_cooldown()` writes `cooldown + 1 + cooldown_mod`, and this very
> `advance_cooldowns` takes the extra 1 back at the end of the same turn — so a freshly-used skill
> settles on exactly its printed cooldown. The +1 is bookkeeping for that decrement, not a turn of
> progress. `PARALYZE` blocks exactly that decrement and nothing else, which used to strand the +1
> (every skill settled one turn high; a cooldown-0 skill came back unusable) when a *reactive*
> Paralyze landed between `start_cooldown` (`:1190`) and `check_ability_use_triggers` (`:1206`). It
> is now solved with a turn stamp, `Ability.cooldown_started_turn`. See [[Cooldowns and Energy]].

`tick_durations()` (`:1302`) decrements every effect on every non-banished character; a banished
character only ticks its `BANISH` effects plus anything flagged `tick_during_banish`. It runs through
`EffectStorage.tick_all_effects_durations` (`scripts/effect_storage_component.gd:309`), which also
resets each effect's `waiting`, `fresh_stack` and `triggered` flags — that `triggered` reset is what
re-arms the `if eff.triggered: continue` guard in `check_start_of_turn_triggers` /
`check_end_of_turn_triggers` (`scripts/character_component.gd:1443-1457`) for the next turn.

> [!warning] Durations tick on EVERY player's turn
> `duration` is not the player-facing turn count. A "1 turn" effect is `duration 2`; "2 turns" is
> `duration 4`; extending "by 1 turn" is `duration += 2`. A skill you interact with on your own turn
> ("this skill is replaced for 1 turn") is `duration 3`. A skill *swap* for N turns is `2N + 1`.
> Full model in [[Effects and Durations]].

## 5. Turn hand-off

```gdscript
func turn_over():                                    # :609
    action_order = []
    if check_match_over(): return
    reset_character_targeted()
    if waiting_for_turn:
        start_new_turn()                             # p2 just acted → back to p1
    else:
        waiting_for_turn = true                      # ← set BEFORE the triggers fire
        for character in enemy.team.characters:
            character.check_start_of_turn_triggers(self)
        for character in player.team.characters:
            character.check_start_of_turn_triggers(self)
        wait_for_turn()
```

`start_new_turn` (`:521`) mirrors it: bump `current_turn_number`, emit `TURN_STARTED`, set
`waiting_for_turn = false`, then fire `check_start_of_turn_triggers` for **player's team then
enemy's team**, then generate the player side's energy, then clear `execution_order`, refresh every
character, `gamestate = OPEN`.

> [!danger] `waiting_for_turn` is a SIDE flag, not "my team"
> It tracks the `battle.player` (side 1) vs `battle.enemy` (side 2) split, and it is deliberately set
> **before** the start-of-turn triggers fire. A passive that wants "is it MY team's turn?" and writes
> `if battle.waiting_for_turn` is only correct when its owner is player 1 — for the second player the
> check is inverted and fires on the opponent's turn. It looks like "works in bot matches, broken vs
> players", because in bot games the human is always side 1.
>
> The correct idiom, valid for either seat:
> ```gdscript
> var acting_team = battle.enemy.team if battle.waiting_for_turn else battle.player.team
> if not me in acting_team.characters:
>     return
> ```
> Found and fixed in `abilities/mavis5.gd` (Fairy Star Strategy): it was marking allies on the
> opponent's turn for a player-2 Mavis, so her team could never act to trigger it.
>
> And do **not** reuse that gate on a `TICKING_TRIGGER` — the ticking engine already gates by
> `effect.user in acting_team`, so adding the manual gate breaks it. See [[Trigger Types]].

## 6. The first turn is asymmetric

`start_battle` (`:266`) ends with:

```gdscript
if not first:
    went_second = true
    waiting_for_turn = true
    if not passive:                       # fire BOTH teams' start-of-turn triggers here
        for character in enemy.team.characters:  character.check_start_of_turn_triggers(self)
        for character in player.team.characters: character.check_start_of_turn_triggers(self)
    wait_for_turn()
else:
    start_new_turn(true)
```

That explicit trigger pass in the `not first` branch is a **fix**, not decoration. `wait_for_turn()`
fires no triggers of its own, so a `START_OF_TURN` passive belonging to the first-acting *enemy* side
was silently skipped on turn 1 only — symptom: "no mark on my first turn, but only sometimes, only
when I go first". Keep this symmetry if you ever add first-turn turn-flow logic.

`start_new_turn(true)` also takes the special first-turn energy branch: instead of per-character
generation it rolls a single random colour (`generate_team_energy`, `:1347`).

## What breaks when the ordering is misread

| Misreading | Symptom |
|---|---|
| "my DoT ticks the turn I apply it" | one fewer instance than the description promises, every time |
| "end-of-turn triggers fire for everyone" | an enemy-side trigger appears to fire on alternate turns only |
| "`waiting_for_turn` means my team" | works in bot matches, fires on the wrong turn in PvP as player 2 |
| "extending by 1 turn is `+= 1`" | a no-op — durations are even, so `+= 1` gets eaten by the next tick |
| "the client's execution_order is advisory" | reordering a turn genuinely changes outcomes; it is authoritative |
| "a tick I omit is skipped" | it isn't — it resolves last, after every explicit step |
| "cooldowns advance for both teams" | a skill looks stuck on cooldown for a turn longer than printed |
| "match-end still runs end-of-turn" | it doesn't — durations and cooldowns freeze at the final state |

Related: [[Effects and Durations]], [[Trigger Types]], [[Cooldowns and Energy]],
[[Targeting and Main Target]], [[Damage Pipeline]], [[Server Authority Model]],
[[Traps That Have Bitten Us]].
