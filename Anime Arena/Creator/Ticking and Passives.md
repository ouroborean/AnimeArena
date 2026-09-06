---
tags: [area/systems, type/reference]
---

# Ticking and Passives

A bottom-up survey of the two mechanics the top-down gap analysis never opened: the **ticking
execution slot** (`TICKING_TRIGGER`, the single most-used hook in the corpus) and the **Passive
class** (93 shipped abilities on 91 of the 174 roster characters).

[[What Cannot Be Built Yet]] surveys effect *factories*. Neither ticking nor passives appears in it,
because neither is a factory — ticking is a **place in the turn**, and a passive is a **moment at
which an ability runs**. That is exactly why they were missed, and exactly why they need their own
note.

Read [[Block Palette Reference]] for what ships today and [[Creator Roulette]] for the
proposed-system ledger this note feeds. Every number below is a roster-intersected count; the greps
are stated inline.

> [!info] Measurement method used throughout
> Ability filename stem → strip trailing digits → intersect with the 174-name roster
> (`deploy/roster.json`, verified identical to `character_database.char_name_list()`, zero
> difference in either direction). Comment-only lines are excluded from every count. Where a count
> is derived from a structural grep rather than a factory call, that is said and a false-positive
> rate is given.

---

## Summary — what this note adds, ranked

| # | Finding | Reach | Difficulty | Where |
|---:|---|---|---|---|
| 1 | **`recurring` effect kind** (ticking as an authorable kind, with `first: now/next` folding in the manual-first-instance idiom) | **54/174** — the most-used hook in the corpus | effect-kind; **no engine work** | §3.1 |
| 2 | **Condition-filtered `target`** — reuse `FILTERED_SELECTORS` in the ability's `target` slot | **60/174 (34%)** union | field | §5.3 |
| 3 | **Ticking's addressing split** — 35/174 of the row's reach needs no `holder`; 16/174 does | refines the ledger's #1 system | — | §1.5 |
| 4 | **Four missing trigger rows** (`HARMFUL_USE`, `HEALTH_CHANGE`, `STUN_RECEIVED`, `ACTION_RECEIVE`) — the reason polling watchers exist | 14 / 7 / 4 / 3 per 174 | enum-row (×3), system (`HEALTH_CHANGE`, needs a threshold) | §3.3 |
| 5 | **A Passive's blocks silently no-op** without an explicit `to` — and the editor's blank ability is exactly that shape | every authored passive | validator-only | §4.4 |
| 6 | **`last_turn_only` on a ticking effect needs a TWO-site fix**, not one | makes Shape C (5/174) a field | field | §3.2 |
| 7 | **The `Action` class is a ticking stun-gate with one reader**, exposed in the editor with no explanation | 18/174 carry it; 3 combine it with ticking | field | §1.4 |
| 8 | **Authored effect names are unvalidated against 54 engine-hardcoded names** — an ability named `Plasmantle` gets Arthur Boyle's rule | reachable in two blocks | validator-only | §5.1 |
| 9 | **Ceiling/scale rule effects** (`damage_cap`, `percent_dr`, `heal_cut`, `health_cap`, `damage_cap_receive`) are generic and belong in the Creator | 10/174 as a family | effect-kind | §5.2(a) |
| 10 | **Census correction** — the `EffectType.Type.X` grep over-counts (one 22-type scan list) and under-counts (factory-only sites); seven "1-character" types have **zero** real users | re-ranks the uncovered tail | — | Appendix |

---

# Part 1 — What ticking actually is

`TICKING_TRIGGER` is not "an end-of-turn trigger that repeats". It is a **fifth kind of action in
the turn**, sitting in the same ordered queue as the four skills a player can use. An author who
picks it is buying five properties at once, and four of them have no equivalent anywhere else in
the palette.

## 1.1 It occupies a player-orderable execution slot

`get_ticking_effect_information` (`new multiplayer/battle_manager.gd:785`) builds a dictionary keyed
`3, 4, 5, …`; `get_used_ability_information` (`:769`) keys the acting team's skills `0, 1, 2` (team
index). The two are merged into `execution_order` (`:736-740`), and the **player** returns the order
in `true_execution_order` (`:750-751`, wire round-trip at `:1626`). `_execution_loop_step_sync`
(`:971`) then pops that list and runs each entry — a skill or a batch of ticking effects — in the
order the player chose.

The client is served this list directly: `_serialize_execution_preview`
(`battle_manager.gd:2258-2293`) puts every ticking group into each snapshot as a draggable tile with
`order_id = key + 3`.

**Nothing else in the palette can reach this queue.** `on_turn_end` payloads run in
`end_of_turn_effect_handling` (`:1319-1344`), after the loop has completely drained, in fixed board
order, with no player input.

Three sub-properties fall out of it:

* **Grouping is by cast, not by target.** `origin = [source.ability_name, effect_type, effect.id]`
  (`:798`), and `effect.id` is only ever written as `effect.id = context.id`
  (`scripts/character_component.gd:2114`, `:2132`) — the *QueryContext's* instance id, which is one
  object per `execute()`. So an AoE that plants six ticking effects in one cast collapses into **one**
  draggable step, and two separate casts of the same skill are two steps.
* **Hidden ticks are un-reorderable but still fire.** `first.system and not first.display_system` is
  filtered out of the preview (`:2270-2271`) and is appended *last* by
  `process_turn_package` (`:1635-1637`). `frieza2.gd:56-61` documents relying on this: a
  player-draggable step could be moved ahead of Frieza's own skills and break the "at the end of his
  next turn" the skill promises.
* **Ties break on `twin_priority`** (`:1624`, default 3 at `scripts/effect_component.gd:99`).

## 1.2 It cannot fire on the turn it was planted

`get_ticking_effect_information` is called at `:1622`, `start_round_loop()` at `:1640` — the tick set
is **frozen before any ability in that turn executes**. An effect created inside an `execute()` is
not in the dictionary and will not run until the next time its side acts.

This is why the corpus's "N damage per turn for K turns" idiom is *an immediate manual hit plus
duration 2K−1*, not duration 2K. Documented at `abilities/fern3.gd:72-79` and
`abilities/stark3.gd:53-58`; the same shape is in `squalo1`, `death2.gd:31-38`.

> [!danger] This is the single most likely authoring bug in a future `on_ticking` row
> An author writes "deal 10 per turn for 3 turns", gets three ticks starting **next** turn, and the
> generated prose says the skill does something on the turn it is cast. Every hand-written kit
> compensates by hand. See §3.1 for the encapsulation that removes the trap.

## 1.3 Acting-team scoping is by the effect's USER, not its holder

`get_ticking_effects(character, is_enemy)` (`:824-846`) walks **both** teams' characters looking for
holders, but keeps an effect only when `effect.user in team`, where `team` is the **acting** side.

`check_end_of_turn_triggers` is the mirror image: `end_of_turn_effect_handling` iterates the acting
team's **characters** (`:1322-1324`, `:1337-1340`) and asks each for its own `END_OF_TURN_TRIGGER`s
— so a turn-end trigger fires when its **holder** is on the acting team.

| | fires when | so a payload planted on an enemy… |
|---|---|---|
| `TICKING_TRIGGER` | the effect's **user** is on the acting team | fires on **your** turn |
| `END_OF_TURN_TRIGGER` | the effect's **holder** is on the acting team | fires on **their** turn |

That is a real design axis, not an implementation detail. "Every turn, this enemy takes 10 and I
gain a stack" is a ticking effect; the same payload on `on_turn_end` resolves a half-turn later and
under the opponent's tempo.

## 1.4 It has four cancellation gates that `on_turn_end` does not

`execute_ticking_effect` (`:1222-1263`):

| Gate | Line | Applies to |
|---|---|---|
| holder is `dead` or `banished` | `:1223` | all ticking kinds |
| `effect.source.classes["Action"] and effect.user.is_stunned(effect.source)` | `:1225` | all ticking kinds |
| `effect.removed` | `:1227` | all ticking kinds |
| **friendly tick** (user on holder's team): holder `is_isolated()` | `:1256-1258` | `TICKING_TRIGGER` |
| **hostile tick**: holder `is_invuln(source)` unless `source.classes["Bypassing"]` or `effect.bypassing` | `:1259-1261` | `TICKING_TRIGGER` |

`check_end_of_turn_triggers` (`scripts/character_component.gd:1479-1485`) has **none** of them — its
only skip is `eff.triggered`, which the engine never sets (see the `trigger_once` callout in
[[Creator Roulette]]).

> [!warning] The `Action` class is a rule with exactly one reader, and it is this gate
> `classes["Action"]` is whitelisted by `_validate_classes` (via `Ability.CLASS_NAMES`,
> `block_validator.gd:169`), shipped to the client verbatim as
> `"classes": Ability.CLASS_NAMES` (`components/server_connection.gd:4380`) and rendered as a
> tickable chip at `webclient/app/app.js:5348`. Its **only** read anywhere in the engine is
> `battle_manager.gd:1225`. So the class means precisely "my ticking effects stop while I am
> stunned" — nothing else. 19 shipped abilities / **18 roster characters** carry it, and only **3**
> combine it with a ticking effect (`erza2`, `soul3`, `toph2`).
>
> Today ticking is unauthorable, so ticking `Action` in the editor does literally nothing. The
> moment an `on_ticking` row ships, ticking it silently halves the effect's uptime against any
> stun — with no prose, no tooltip and no validator message. This is the same defect shape as the
> `Bypassing` class (§3.7 of [[What Cannot Be Built Yet]]) and should be fixed in the same pass.
>
> It is also **ability-scoped, not effect-scoped** — the gate reads `effect.source.classes`, and
> `source` is the Ability. A skill that plants two ticking effects cannot make one stun-cancellable
> and the other not.

## 1.5 The payload's binding table

`QueryContext.from_effect_end` (`scripts/query_context.gd:38-50`) sets `owner = effect.user`
(the **caster**) and `target = effect.target` (the **holder**). `BlockRunner._build_trigger`
(`blocks/block_runner.gd:699-716`) reads `context.effect.user` for its acting user and
`context.owner` for its `target` selector — so under `from_effect_end` **both resolve to the
caster** and the holder is unreachable. This confirms the established finding and adds the exact
rows:

| Hook | dispatcher | `user` binds to | `target` selector binds to | holder reachable? |
|---|---|---|---|---|
| `TICKING_TRIGGER` | `battle_manager.gd:1262` (`from_effect_end`) | caster | **caster** | no |
| `END_OF_TURN_TRIGGER` | `character_component.gd:1484` (`from_effect_end`) | caster | **caster** | no |
| `START_OF_TURN_TRIGGER` | `:1492` (`from_effect_end`) | caster | **caster** | no |
| `ON_DEATH_TRIGGER` | `:1500-1501` (`from_effect_end`, then `owner = killer`) | caster | **the killer** | no |
| `HARMFUL_USE_TRIGGER` | `:1433` (`from_effect_end`) | caster | **caster** | no |
| `ACTION_USE_TRIGGER` | `:1390` (`from_trigger_source`) | caster | the acting character | n/a (same) |
| `HARMFUL_RECEIVE_TRIGGER` | `:1461` (`from_trigger_source`) | caster | the attacker | n/a |
| `DAMAGE_DEALT_TRIGGER` | `:1297` (`from_trigger_source`) | caster | **the dealer** (defect, run 07) | — |

> [!success] Two thirds of ticking's reach does NOT need Payload addressing
> Measured over every `Effect.trigger_effect(Trigger.always(fn), EffectType.Type.TICKING_TRIGGER, N)`
> construction site, classified by whether the effect is then handed to `add_hostile_effect` or
> `add_allied_effect`:
>
> | install | sites | roster characters |
> |---|---:|---:|
> | **self / ally** (caster **is** the holder — caster binding is correct) | 49 | **35 / 174** |
> | **hostile** (caster ≠ holder — needs `holder`) | 16 | **16 / 174** |
> | unresolved by the parser (`fern3`, `frieza2`, `mavis1`, `mavis4`, `ryohei3`) | 5 | 5 |
>
> The 16 are `akame, alphamon, boruto, byakuya, cooler, death, gogeta, hawkmon, mami, minene, rakko,
> semiramis, toga, toph, yamamoto, yuji`.
>
> This **refines** the ledger's "`on_ticking` ships with Payload addressing or it ships broken". The
> honest statement is: **35/174 of the row's reach is unblocked today; 16/174 is blocked**, and the
> blocked set is exactly the hostile-install shape. That is evidence for Payload addressing's
> priority *and* an argument that the row does not have to wait for it, provided the editor does not
> offer the hostile shape until it lands.

## 1.6 Ticking vs `on_turn_end`, side by side

| Property | `TICKING_TRIGGER` | `END_OF_TURN_TRIGGER` (shipped as `on_turn_end`) |
|---|---|---|
| when in the turn | inside the ordered action loop | after the loop drains, before durations tick |
| player can reorder it | **yes** (draggable tile) | no |
| shows in the tick panel | yes, unless `system && !display_system` | never |
| fires on the turn it is planted | **no** (set frozen at `:1622`) | yes |
| scoped by | the effect's **user**'s side | the **holder**'s side |
| cancelled by holder death/banish | yes | no |
| cancelled by caster stun | yes, **if** the source ability has the `Action` class | no |
| cancelled by holder invulnerability | yes, for hostile ticks, unless `bypassing` | no |
| cancelled by holder isolation | yes, for friendly ticks | no |
| `last_turn_only` honoured | **no** (see §3.2) | n/a |
| batching | same-cast effects resolve as one group | one call per holder |

---

# Part 2 — How ticking is actually used

**Reach.** 56/174 roster characters mention `TICKING_TRIGGER`; **54/174 construct one**
(53 of those via `Trigger.always`, one via a `Condition`-driven trigger). Grep:

```bash
# construct (multi-line aware — a bare one-line grep reads 43 and is WRONG,
# because most call sites put the duration on the following line):
#   Effect.trigger_effect( <trigger>, EffectType.Type.TICKING_TRIGGER, N
# then stem → strip trailing digits → intersect with the 174-name roster
```

For context, the same measurement across every hook, which is the input to §3.3:

| hook | sites | roster chars | in the palette? |
|---|---:|---:|:--:|
| **TICKING_TRIGGER** | 73 | **54** | ❌ |
| ACTION_USE_TRIGGER | 57 | 43 | ✅ |
| HARMFUL_RECEIVE_TRIGGER | 34 | 30 | ✅ |
| DAMAGE_RECEIVE_TRIGGER | 20 | 20 | ✅ |
| **HARMFUL_USE_TRIGGER** | 18 | **14** | ❌ |
| END_OF_TURN_TRIGGER | 16 | 14 | ✅ |
| DAMAGE_DEALT_TRIGGER | 14 | 12 | ✅ (binding defect) |
| ON_DEATH_TRIGGER | 11 | 10 | ✅ |
| START_OF_TURN_TRIGGER | 9 | 8 | ✅ |
| **HEALTH_CHANGE_TRIGGER** | 7 | **7** | ❌ |
| **STUN_RECEIVED_TRIGGER** | 5 | **4** | ❌ |
| **ACTION_RECEIVE_TRIGGER** | 4 | **3** | ❌ |

Ticking is the most-used hook in the corpus by both measures, and by a clear margin over the
seven that shipped.

70 construction sites parsed cleanly (2 more use a layout the parser misses). Durations: **29 sites
permanent (−1)**, 41 finite (`5`×20, `3`×13, `7`×5, `6`×2, `10`×1) — i.e. the mechanic is
overwhelmingly used either as a *permanent engine* or as a *3-turn window*.

The 70 sites fall into five shapes. Classification rule, applied in this priority order to the
**payload function body** (comments stripped), then hand-resolved for the 11 sites whose payload only
calls a private helper:

`C` a `duration ==/!=/> 1` guard → `E` a teardown (`erase_effect`/`consume_effect`) with no payout →
`D` a swap / a rewritten `description` Callable / an indexed `mag` → `B` a stack or `mag` increment
with no payout → `A` anything that damages, heals, shields, cleanses or grants energy.

| shape | sites | roster characters |
|---|---:|---:|
| **A** recurring payout | 41 | **33 / 174** |
| **B** resource generator | 13 | **12 / 174** |
| **E** polling watcher | 6 | **5 / 174** |
| **C** countdown to one payoff | 5 | **5 / 174** |
| **D** per-turn state refresh | 5 | **5 / 174** |

Characters appear in more than one row (Jaden runs A and B; Lyserg runs C and E), which is why the
character column does not sum to 54.

## Shape A — Recurring payout ("N damage / heal / shield / energy per turn") — 41 sites, **33/174**

The default reading of the mechanic, and the majority of it.

* `abilities/jaden2.gd:25` — Burstinatrix: 5 Affliction to all enemies each turn, duration 5.
* `abilities/stark3.gd:57` — 10 HP to Stark each turn, duration 5, with the manual first heal.
* `abilities/yuno3.gd:24` — 1 Blue energy per turn, duration 5.

Part of A is not a plain payout but a **per-turn re-application**: `abilities/jaden1.gd:29` +
`avian_tick` removes last turn's `DAMAGE_MOD` off every enemy and lays a fresh one, and
`abilities/toph2.gd:23` re-stuns its victim's Physical skills every tick. Same slot, but the
authored form is an `apply`, not a `damage`.

Sub-shape **A′ — random-target payout** (7 sites, 7/174): the payload rolls its own target each
tick, which is *not* the same as a fixed target chosen at cast. `abilities/asta4.gd:12`
(permanent, random enemy), `abilities/frieren7.gd:28` (2 random targets per tick),
`abilities/cell6.gd:22` (3 random hostiles per fire).

**Authorable today?** Partly. `damage_over_time` / `heal_over_time` already give per-turn damage and
healing through the `DAMAGE`/`HEALING` effect types, which occupy the *same* execution slot
(`get_ticking_effects:830-836`). What A adds over them is **any other payload** — shields, energy,
cleanses, marks, boosts — and per-tick re-rolled targets.

## Shape B — Resource generator ("gain 1 stack of X each turn") — 13 sites, **12/174**

A permanent, usually `system`, ticking effect whose only job is to advance a counter on a mark the
rest of the kit reads.

* `abilities/madoka5.gd:25-31` — Soul Gem corruption, permanent, `system + display_system +
  remove_on_death = false` so the ticker survives a revive while the mark it feeds is death-cleansed.
* `abilities/tokoyami5.gd:23-45` — Black Abyss: +1 `mag` per turn, **skipped** while stunned /
  silenced / blinded, and re-configures the kit at 3 stacks.
* `abilities/shiro4.gd:32`, `mami6.gd:30`, `sayaka5.gd:20`, `ryohei3.gd:26`, `toga5.gd:32`.

The dominant idiom is **not** an explicit counter: `shiro4`, `toga5`, `hawkmon1` and `toga2` all
re-apply a `stackable` MARK and let `add_effect`'s merge bank the stack — which is exactly the
"stacking is emergent" model the palette already ships (`block_schema.gd:105-107`). `minene5`'s
`detonator_turn_tick` is the same idiom aimed at an **enemy**, and its own comment names the
addressing problem verbatim: *"from_effect_end sets target = the marked enemy holding this trigger …
eff.user = the applier (Minene), not the holder"*.

**Authorable today?** No, and the gap is narrow: `apply` a `mark` with `stackable` + `max` from a
ticking payload is exactly the shipped stacks-as-a-resource system. Only the hook is missing.

## Shape C — Countdown to a single payoff ("after N turns, X happens") — 5 sites, **5/174**

A ticking effect that does nothing until `effect.duration == 1`, then fires once. The guard is
hand-written in the payload.

* `abilities/akame2.gd:26,33` — `if context['effect'].duration == 1: target.instant_kill(...)`.
* `abilities/semiramis2.gd:25` + `effect_expire_trigger` — `if duration > 1: return`, else stun.
* `abilities/mavis1.gd:19` + `fairy_law_resolve` — `if duration != 1: return`, then a board-wide
  35-damage / 25-heal split.
* also `yoh6`, `lyserg5`. Two near neighbours resolve the same design differently:
  `abilities/frieza2.gd:62` latches `eff.triggered` by hand and then `consume_effect`s itself, and
  `abilities/machinedramon5.gd:begin_sd_trigger` computes its duration from `waiting_for_turn` so
  the single firing lands on the correct side. Both are countdowns; neither can spell it as a
  duration.

**Authorable today?** The *damage-only* case is: `{"kind":"damage_over_time","delayed":true}` maps to
`last_turn_only` + duration 2N+1 (`block_runner.gd:594-595`). Anything else — a stun, a kill, a heal,
a board-wide split — is not.

## Shape D — Per-turn state refresh / re-roll — 5 sites, **5/174**

The tick does not pay out; it **re-configures the kit** for the coming turn.

* `abilities/boruto5.gd:17` — the 3rd slot swaps to a different random Rasengan every turn.
* `abilities/kurotsuchi5.gd:42` + `cycle_drugs` — the Drug slot rotates to a random other Drug skill.
* `abilities/megumi5.gd:18` + `ticking_trigger` — rolls a skill *class* and stores the **string** in
  `effect.mag`, which the rest of the kit reads.
* `abilities/koro1.gd:18` — picks an unused class out of an **Array** held in `effect.mag` and makes
  everyone invulnerable to it.
* also `tanjiro8` (each of the first three slots may swap to its alternate), `inuyasha5` (a counter
  that flips the character between "awakened" and "waning"). `muichiro3` is the borderline case —
  it adds +10% to a **separate** `DODGE_CHANCE` effect's `mag` each turn, which is D's mechanism
  (mutate somebody else's effect) with B's intent (ramp a resource).

**Note for the palette:** `mag` is untyped Variant in the engine. `megumi5` puts a `String` in it and
`koro1` puts an `Array`. `UNIVERSAL_EFFECT_FIELDS` declares it `"int"`
(`block_schema.gd:201`), the runner clamps it (`_universal_int`), and **nothing in the palette can
read it back**. So authored content can write a number into `mag` and never see it again.

## Shape E — Polling watcher (a per-turn `if`, because no hook exists) — 6 sites, **5/174**

The ticking slot used purely as a **clock** to re-evaluate a condition the engine has no trigger for.

* `abilities/jeanne1.gd:23-27` + `solo_survivor_check` — explicitly "per-turn polling backup.
  Catches 'no targetable ally' transitions that don't go through `die()`".
* `abilities/lyserg1.gd:64-70` + `check_big_ben` — installs a permanent watcher, guarded against
  double-install by `has_effect(name, TICKING_TRIGGER, user)`.
* `abilities/alphamon3.gd:23,49` — re-checks that the Shield it is attached to still exists and
  `erase_effect`s itself when it does not.
* also `jeanne2` (a permanent HP watcher installed alongside a permanent swap),
  `kurotsuchi5`, `rakko1` (a de-ramp watcher that lowers a Bleed's magnitude by 5 a turn and then
  removes it).

**This is the shape that matters most for the Creator**, because it is a *workaround for the
trigger-hook table being short*. Every one of these would be a first-class trigger in a richer
palette. It is also the shape most likely to be reinvented badly by an author (permanent + no
self-removal = a tile in the tick panel forever).

---

# Part 3 — Encapsulating ticking

## 3.1 Do not ship a bare `on_ticking` row — ship a `recurring` effect kind

The obvious move is one line in `TRIGGERS` and one in `trigger_hook_id`. That is **enum-row
difficulty** and it is the wrong shape, because it hands the author all five properties of §1 with
no vocabulary for any of them, and it walks straight into §1.2.

The encapsulation that fits the palette's own idiom (`counter` and `trigger` already own a nested
`then` list) is a sibling **effect kind**:

```json
{
  "op": "apply",
  "to": "user",
  "effect": {
    "kind": "recurring",
    "turns": 3,
    "first": "now",
    "then": [ {"op": "damage", "amount": 10, "to": "random_enemy"} ]
  }
}
```

Two axes, both grounded in the corpus:

* **`first`: `"now"` | `"next"`.** `"now"` runs `then` once immediately at cast **and** sets the
  engine duration to `2K − 1`; `"next"` sets `2K`. This folds the manual-first-instance idiom
  (`fern3`, `stark3`, `squalo1`, `death2`) into a field, and it is the difference between the
  generated prose being true and being off by a turn. `spec_duration` already has the precedent —
  `delayed` computes `2N+1` for exactly this class of reason.
* **`stops_when_stunned`: bool.** Sets the source ability's `Action` class. It has to be surfaced
  *somewhere*, and a per-effect checkbox that writes an ability-level class is more honest than an
  unexplained chip in the class row. The validator must reject the combination "two `recurring`
  effects on one ability with different `stops_when_stunned`", because the gate is ability-scoped
  (§1.4) and the two cannot disagree.

`bypassing` (hostile ticks through invulnerability) and `system`/`display_system` (hidden vs
draggable) are already **universal effect fields** and need nothing new — but the editor must
explain them here, because this is the only kind where they change *whether the effect runs at all*
rather than how it renders.

Everything else is free: `_is_hostile_effect` routing, the stacking fields, `remove_on_death`,
`tick_during_banish` (whose only shipped user, `abilities/semiramis5.gd:43`, is a
`START_OF_TURN_TRIGGER` on a self-banished character — a duration that has to keep counting while
its holder is off the board, which is the same problem a `recurring` effect has).

* **Prose.** `_describe_effect` gains one arm: *"Each turn for 3 turns: deals 10 damage to a random
  enemy"*, with *"starting immediately"* appended for `first: "now"`.
* **Bot tags.** `TAG_REACTIVE` plus `_derive_tags(then)`, identical to the `trigger` arm
  (`scripted_ability.gd:474-479`). `bot_damage_hint` should count `amount × turns` the way
  `_block_damage` already does for a non-delayed `damage_over_time` (`:501-503`), or the v3 policy
  values a 3-turn ticking payout at zero.
* **Safety.** The existing `max_trigger_then_blocks` (12) and `max_nesting_depth` bounds apply
  unchanged. The one new bound worth having is **permanent + `to: all_enemies` + a `damage`
  payload**, which is an unbounded AoE DoT with no cleanse answer if the mark is `cleansable: false`.
  That is a review-time flag, not a numeric limit.

**Engine cost:** none. `EffectType.Type.TICKING_TRIGGER` is an enum row that already has a
dispatcher, a wire encoding, a client tile and a bot-visible slot.

## 3.2 `last_turn_only` on a ticking effect is inert — and fixing it is a TWO-site change

Run 08 recorded the `battle_manager.gd:1234` reader as sitting inside the `DAMAGE` branch. It is
worse than that: there is a **second** site.

* `:831` — the *collector*. `get_ticking_effects` filters `DAMAGE` effects with
  `(not effect.last_turn_only or effect.duration == 1)`. The `TICKING_TRIGGER` loop at `:838-840`
  has no such filter.
* `:1234` — the *executor*, inside `if effect.effect_type == EffectType.Type.DAMAGE:` at `:1231`.

So honouring the flag for `TICKING_TRIGGER` needs **both**: `:1255` to skip the payload, and `:838`
to keep the effect out of the tick set — otherwise a "fires once at the end" effect appears as a
phantom draggable tile in the reorder panel **every turn** for its whole duration and does nothing
when the player drags it.

Three shipped abilities already set the flag on a `TICKING_TRIGGER` and hand-guard `duration != 1`
anyway (`mavis1`, `lyserg5`, `yoh6`), so honouring it is behaviour-neutral for the roster. That
makes Shape C (§2, 5/174) a **field**, not a system: `{"kind":"recurring","last_turn_only":true}`,
already spelled by the universal set.

## 3.3 Shape E deserves a different answer from shapes A–D

Polling watchers exist because the trigger table is short, not because authors want a clock. Shipping
`recurring` gives authors the clock and they will reinvent the watchers — permanently, visibly, and
one draggable tile each. The better answer for E is to **grow `TRIGGERS`**, and the census in Part 2
says which rows, all four of them enum rows with a live dispatcher: `HARMFUL_USE_TRIGGER` (**14/174**),
`HEALTH_CHANGE_TRIGGER` (**7/174** as a `trigger_effect`, 11/174 counting the characters who
hand-poll for it), `STUN_RECEIVED_TRIGGER` (**4/174**), `ACTION_RECEIVE_TRIGGER` (**3/174**).
`COUNTER_USE` (14/174 by factory call) is the fifth, but it is an interception rather than a hook and
belongs with the shipped `counter` kind's own axes.

`HEALTH_CHANGE_TRIGGER` is the standout: it is the second-most-common hook on shipped **passives**
(5 of 93) and it is the only one of the five that has a `Condition`-driven `Trigger` rather than
`Trigger.always` (`machinedramon5.gd`: `Trigger.from_condition(Condition.health_is(user, -1, 20),
…)`). Exposing it means exposing a *threshold*, which is a second axis and makes it a small system
rather than a row.

---

# Part 4 — Passives

## 4.1 What a Passive is in this engine

`Character.startup_passives(battle)` (`scripts/character_component.gd:320-323`):

```
for ability in moveset.abilities:
    if ability.classes["Passive"]:
        ability.execute(self, battle)
```

That is the whole mechanism. A Passive is an ordinary `Ability` whose `execute()` is called **once**,
for **every** character on **both** teams, at battle start (`battle_manager.gd:333-351`, `:429-431`,
`:500`), and never again.

Consequences, all load-bearing:

* `player` and `enemy` are already assigned (`:312`, `:319`), so both teams are enumerable.
* `targeter.targets` is `var targets: Array` (`scripts/targeter_component.gd:4`) — **empty**. There
  is no target.
* `cooldown`, `cost`, `target()`, `extra_usable()` and `custom_behavior()` are never consulted. The
  validator already encodes this: cooldown must be 0 (`block_validator.gd:96-97`), and it
  deliberately does **not** reject `cost` or `requires` because `cooler6` ships a Passive with a cost.
* It **never re-runs on revive** — documented at `abilities/fern5.gd:67`, `:100` and
  `abilities/stark5.gd:50-53`. A passive whose machinery is death-cleansed is gone for the match; the
  fix in shipped kits is `system = true` **and** `remove_on_death = false`.
* Passive count is unbounded (`authored_registry.gd:255-258`); `gatomon` and `aiohto` ship two.
* Ordering is board order, with one hardcoded exception: Semiramis starts last
  (`battle_manager.gd:343-351`).

## 4.2 Reach

**93 Passive-classed abilities on 91 of the 174 roster characters (52%).** Grep: entries in
`abilities_data.json` whose `classes` contains `"Passive"`, stem-intersected with the roster.
104 entries exist in total; 11 belong to orphan stems.

Effect factories called by those 93 files:

| factory | files | | factory | files |
|---|---:|---|---|---:|
| `trigger_effect` | 61 | | `damage_effect` | 5 |
| `mark` | 43 | | `damage_reduction_effect` | 4 |
| `damage_mod_effect` | 11 | | `color_change_effect` / `ignore_non_damage_effect` / `isolate` / `target_change_effect` | 3 each |
| `ability_swap_effect` | 8 | | `cost_change_effect` / `healing_effect` | 2 each |
| `cost_mod_effect` / `shield_effect` | 7 each | | 15 others | 1 each |
| `empty` / `ignore_effect_effect` / `portrait_change_effect` | 6 each | | | |

Trigger hooks used by passives (the count that matters for the palette):

| hook | passive files | in the palette? |
|---|---:|:--:|
| `ACTION_USE_TRIGGER` | 17 | ✅ `on_skill_used` |
| **`TICKING_TRIGGER`** | **12** | ❌ |
| `HARMFUL_RECEIVE_TRIGGER` | 9 | ✅ |
| `DAMAGE_RECEIVE_TRIGGER` | 8 | ✅ |
| `START_OF_TURN_TRIGGER` | 7 | ✅ |
| `DAMAGE_DEALT_TRIGGER` | 6 | ✅ (with the run-07 binding defect) |
| `ON_DEATH_TRIGGER` | 6 | ✅ |
| **`HEALTH_CHANGE_TRIGGER`** | **5** | ❌ |
| `END_OF_TURN_TRIGGER` | 5 | ✅ |
| **`HARMFUL_USE_TRIGGER`** | **4** | ❌ |
| `STUN_RECEIVED_TRIGGER` / `HEALING_GIVEN_TRIGGER` / `MISSION_TRIGGER_ON_KILL` | 1 each | ❌ |

Counted as distinct passive **files**, not references. Eight of the twelve hooks a passive can hang
on ship in `TRIGGERS`; the four that do not are the same four §3.3 asks for, plus ticking.

## 4.3 The five passive shapes

**S1 — Battle-start installer (permanent self-buff).** The simplest shape and the one the probe
already proves: `astolfo5` (DR + stun immunity), `uranus5`, `tsubaki5`, `gunha5`, `esdeath5`,
`neferpitou5`, `yuji5`, `saturn5`, `impmon5`, `alphamon5`, `ace5`, `yugi6`, `frieren5` (mark +
stealth), `nagisa5`, `usopp5`. **32 of 93** never call `trigger_effect` at all, which is the tight
upper bound on this shape.
**Authorable today — verified**, `training/tests/authored_character_probe.gd:96-97` asserts a
permanent 5 DR installed by an authored Passive.

**S2 — Trigger hub.** A permanent trigger (often several) on self, whose payload is the character's
real mechanic. **61 of 93** call `trigger_effect`. Examples: `power5` (`DAMAGE_RECEIVE_TRIGGER` →
heal for half the damage taken), `marco6`, `natsu5`, `bakugo6`, `soul5`, `luffy5`, `nel5`.
**Authorable today for 8 of the 13 hooks used**, subject to the payload-addressing limits — and,
for `on_damage_dealt`, subject to a live self-kill defect.

**S3 — Resource engine (ticking).** **12 of 93**: `boruto5`, `inuyasha5`, `kurotsuchi5`,
`machinedramon5`, `madoka5`, `mami6`, `megumi5`, `minene5`, `sayaka5`, `tanjiro8`, `toga5`,
`tokoyami5`. **Not authorable** — this is §3.1's entire case, and it is the second-largest passive
shape after the trigger hub.

**S4 — Declaration-only ("the passive slot as a description card").** `execute()` is empty (or a
bare `pass`); the rule lives in the sibling skills, in `character/<name>.gd`, or in the engine.
**13 of 93**: `aiohto6`, `allmight5`, `cell5`, `cooler6`, `edward5`, `gatomon9`, `gatomon14`,
`jupiter5`, `kid5`, `lizandpatty7`, `muichiro6`, `rakko5`, `rob9`.
`abilities/aiohto6.gd:16-18` states it outright: *"the kill reward is applied inside Now I'm Mad!
(ai2) … so this passive slot has no setup of its own."*
The related `Effect.empty(dur, desc)` (`scripts/effect_component.gd:1163-1173`) is a
`cleansable = false` description pip with no gameplay behaviour, used by **11 roster characters** and
6 passives. **Approximable today**: `{"kind":"mark","turns":-1,"cleansable":false,"text":"…"}`, which
differs only in that a `mark` is readable by `marked_by()`.

**S5 — Cross-team installer.** A passive that plants effects on the **opposing** team at battle
start: **14 of 93** call `add_hostile_effect` somewhere (`adam5`, `emiya7`, `emiyaarcher5`,
`gasai5`, `hashirama5`, `hibari5`, `jack5`, `king6`, `kurotsuchi5`, `ladydevimon5`, `minene5`,
`omnimon5`, `power5`, `uzui5`). **Authorable today**, and this is the one shape that deserves a
validator rule it does not have — see §4.5.

## 4.4 The silent no-op that will bite the first author

`ScriptedAbility.execute` → `BlockRunner.run(blocks)`; `_block_targets(b, "target")` defaults the
selector to `"target"`; `_resolve_targets("target")` reads `user.targeter.targets`, which at
`startup_passives` time is **empty**. So **every block in a Passive that does not set an explicit
`to` does nothing at all.**

The editor makes this the default path: `CREATOR_BLANK_ABILITY` (`webclient/app/app.js:5148`) seeds
`blocks: [{ op: "damage", amount: 15, damage_type: "NORMAL" }]` — no `to`. A player who ticks
"Passive" on a fresh skill gets a validated, approved, completely inert ability, and the generated
prose says *"Deals 15 damage to the target"*.

**Fix (validator-only, no engine work, no schema change):** when `classes` contains `"Passive"`,
require an explicit `to` on every block whose op takes one, and reject `to: "target"` outright with a
message that says why. This is a genuine restriction the *game* has — there is no target — so it does
not violate the no-invented-limits rule.

## 4.5 Two passive-specific safety rules the validator is missing

Both are consequences of "a Passive runs at battle start, unconditionally, for free".

1. **A Passive is a free cast of an arbitrary block tree.** Every balance lever the Creator has —
   cost, cooldown, `requires` — is *not consulted* for a Passive (§4.1). The soft-locks already
   recorded in [[What Cannot Be Built Yet]] (`"turns": -1` on `stun` / `invulnerable`) are strictly
   worse here: on an active skill they cost energy and a turn; on a Passive they cost nothing and
   land on turn zero. **Any duration cap for stun/invuln/silence/taunt must be tighter on a Passive
   than on an active skill**, and that is the one place where two different numbers is the correct
   answer rather than an inconsistency.
2. **`to: "all_enemies"` on a Passive is an unavoidable, un-counterable opener.** The opponent cannot
   respond, cleanse pre-emptively, or choose not to walk into it. 14 shipped passives do plant
   hostile effects, so banning it would be inventing a limit — but it is the correct trigger for a
   review flag.

---

# Part 5 — Passives that change a RULE

## 5.1 Where the rules actually live

Some passives do not apply an effect at all. Their mechanic is a **branch in the engine**, keyed on a
name. Census over `scripts/character_component.gd`, `new multiplayer/battle_manager.gd`,
`scripts/condition.gd`, `abilities/scripts/ability_component.gd`, `scripts/effect_component.gd` and
the remaining components, excluding comments:

* **12 roster characters are hardcoded by `path_name`:** `emiyaarcher, erza, esdeath, frieren,
  hawkmon, inuyasha, minene, muichiro, rakko, semiramis, tokoyami, toph`.
* **54 ability / effect NAMES are hardcoded** into the damage pipeline, targeting, energy generation
  and death handling — `Blood Spear`, `Nirvana`, `Plasmantle`, `Saturn Crystal`, `Silence Wall`,
  `Heavenly Intervention`, `Unexpected Beheading`, `Named Reconstitution`, `Wave Tracking`,
  `Sealed King`, `Crush Card Virus`, `Escape Diary`, `Zanni di Squalo`, `Rankyaku Gaicho`, … .

`character_component.gd:581-606` is the clearest example: three consecutive branches on
`marked_by("Nirvana")`, `target.marked_by("Plasmantle")` and `target.marked_by("Blood Spear")`, each
of which **returns before damage is applied**.

> [!danger] These branches key on the effect NAME, and authored names are unvalidated against them
> `marked_by(name)` is `has_effect(name, MARK, user)` with `user = null`
> (`character_component.gd:1168-1169`) — **any** MARK carrying that name, from any source. An
> effect's name is `effect_name()`, which falls back to the source ability's name, and
> `name_override` is a free-text universal field (`block_schema.gd:210`).
> `AuthoredRegistry.validate_character` (`blocks/authored_registry.gd:185-272`) checks the character
> `id` prefix, the name lengths and that no two of the author's **own** skills share a name. It does
> **not** check an authored ability or effect name against the shipped corpus.
>
> So an authored ability named `Plasmantle` that marks its own user permanently would route every
> incoming Harmful hit into Shield and take none (`:591-597`); one named `Nirvana` converts all
> outgoing damage into Nullify (`:581-587`). This is not the disguise-style code-execution boundary —
> it is an unintended *rules* collision — but it is reachable with two blocks and no exotic field.
>
> **The fix is a reserved-name list, and it is cheap:** the 54 names in the census above are a
> static set, and the check is one `if` in `validate_character` — the same class of check as the
> existing "two abilities are both named '%s'". It has to cover both `ability.name` and every
> `name_override`.

## 5.2 The honest answer: split the category in two

Rule-changers are not one thing. They divide cleanly by *who reads the rule*.

### (a) Rules the engine reads generically off an effect TYPE — these belong in the Creator

`get_damage_cap()` (`:526-534`), `get_damage_cap_receive()` (`:536-542`), the `PERCENT_DR` loop
(`:980-982`), the `HEAL_CUT` loop (`:1049-1052`, `:1059-1062`) and `check_damage_nullification`
(`:848-853`) are all **generic**: they walk every effect of a type, read `mag`, and respect
`shrug_off_type`. There is nothing bespoke about them. "Damage against this character is capped at
15" is an ordinary effect with a magnitude and a duration, and it is **enum-row difficulty** — one
`EFFECT_KINDS` entry and one `_build_effect` arm each, exactly like `vulnerability`.

Their real reach, measured by **factory call** (not by the type-name token — see the appendix):

| kind | factory | roster characters |
|---|---|---:|
| damage cap (dealt) | `Effect.damage_cap` | **6** — aang, blackwargreymon, ichibe, kaiba, ryuko, yugi |
| percent DR | `Effect.percent_dr` | 1 — ace |
| heal cut | `Effect.heal_cut` | 1 — jack |
| health cap | `Effect.health_cap_effect` | 1 — cooler |
| damage cap (received) | `Effect.damage_cap_receive` | 1 — yoh |

Small individually, but they are one **family** — "a multiplicative or ceiling modifier on a number
the engine already computes" — with two axes (which number, and cap-vs-scale). As a family that is
**10/174**, and it composes with everything already in the palette.

### (b) Rules read by the OPPONENT's ability — these do not belong in the Creator

"This character cannot be targeted by X" is not a property of the character. It is a decision made
inside the *attacker's* `target()`, at `Condition.can_hostile_target` time. The Creator's authoring
model is strictly per-ability and per-character: an author writes blocks that run inside **their own**
skills. Nothing they write can change how somebody else's skill chooses targets.

This is the same boundary [[Creator Roulette]] already recorded for Death the Kid ("cross-character
passives that drive another character's skills"), generalised. It is a **property of the model, not
a missing block**, and it should be stated as such rather than left on a backlog.

The measured size of the exception: **135 ability files / 86 roster characters (49%)** override
`target()` with something other than the three plain default calls. Broken down:

| shape | files | roster chars | reachable as data? |
|---|---:|---:|---|
| hand-rolled candidate loop (`check_hostile_target` inside a filtered `for`) | 48 | 36 | **yes** — this is the owner's "selector block" (§5.3) |
| `bypassing` flag only (aim at invulnerable enemies) | 41 | 33 | yes — an ability field, already flagged as §3.7 of [[What Cannot Be Built Yet]] |
| branch between default modes on own state | 28 | 20 | **yes** — a `when` over two `target` modes |
| `mark_req` on a default helper | 15 | 9 | yes — §3.4 of [[What Cannot Be Built Yet]] |
| other | 3 | 2 | mixed |

Note what this says: **the overwhelming majority of "targeting rules" are the caster's own rule about
who it may aim at**, which is authorable data. Only the tiny residue — "nobody may target me with a
Physical skill" — is the model boundary, and the engine expresses even that as an ordinary
`invuln_effect(dur, ["Physical"])` on the *defender*, which the palette already ships.

### 5.3 The owner's "customizable selector block", grounded

The 48-file / **36-character** hand-rolled candidate loop is the shape the owner described. It is
always the same code:

```gdscript
for character in battle.all_characters():
    if <predicate on character>:
        check_hostile_target(user, character, context)
```

* `abilities/alphonse3.gd` — `if not character.marked_by("Destruction Alchemy Strike", user)`
* `abilities/astolfo3.gd` — `if ally.has_effect(CASSEUR, EffectType.Type.IGNORE_SKILL, user): continue`
* `abilities/alphonse2.gd` — `if not character.effects.has_effect("Weapon Alchemy", DAMAGE_DEALT_TRIGGER, user)`

**The palette already has the predicate half.** `FILTERED_SELECTORS` (`any_enemy` / `any_ally` /
`any_character`) resolve *exactly* this — every living candidate for whom a condition holds, tested
once per candidate with that candidate as the subject (`block_runner.gd:143-167`). What they do
**not** do is feed `target()`: `ScriptedAbility.target` (`blocks/scripted_ability.gd:53-65`) branches
on the static `target_mode` string and calls one of three default helpers.

So the encapsulation is not a new concept — it is **reusing `FILTERED_SELECTORS` in the ability's
`target` slot**:

```json
{ "name": "Execute", "target": {"mode": "enemy", "only": {"cond": "has_effect", "name": "Fracture"}} }
```

`ScriptedAbility.target` walks `battle.all_characters()`, runs `BlockRunner._check_condition(only,
candidate)` per candidate, and calls `check_hostile_target` on the survivors. The condition
vocabulary, the per-candidate subject binding, the validator's `_validate_condition` and the prose
generator's `_describe_filter` are **all already written**. It is a **field**, not a system.

Two things it must get right:
* **`main_target` ordering.** `targeter.targets[0]` becomes `main_target`, and the client must lead
  the list with the clicked character (see [[Targeting and Main Target]]).
* **Usability.** `Ability.usable` must report "no valid targets" when the filter empties the list, or
  the skill is a clickable dead button. The engine already handles this for `mark_req`.

**Reach if built, measured as a union rather than a sum:** the hand-rolled loop (36), the
`mark_req` form it subsumes (9) and the branch-between-modes form it replaces with
`{"mode": …, "only": …}` (20) overlap, and the union is **60/174 (34%)**. That is the largest
single targeting number in either survey, and it is reached by a *field* on an existing structure
rather than a new system.

---

# Appendix — a census correction

The uncovered-effect-type census in the task frame was produced by grepping the token
`EffectType.Type.<NAME>`. That method has errors in **both** directions, and the tail of the ranking
is where they live.

**Over-count.** `abilities/nobara4.gd:29-50` enumerates **22 effect types in a scan list** (to answer
"is Nobara affected by any harmful non-damaging effect?"). Every one of those 22 types counts
`nobara` as a user. For **seven** of them, nobara is the *only* hit, so their true roster reach is
**zero**: `DAMAGE_NEGATE`, `DAMAGE_NULLIFICATION`, `HEALING_MOD`, `HEALTH_CAP`, `HEAL_CUT`,
`PARALYZE`, `REFLECT_USE`. Twelve more types are inflated by exactly +1 character.

**Under-count.** Most of the corpus never names an `EffectType` at all — it calls
`Effect.<factory>()`. Measured by factory call instead, the tail re-ranks substantially:

| type | frame (token grep) | factory-call reach | factory |
|---|---|---:|---|
| `TARGET_CHANGE` | 9 refs / 4 chars | **16/174** | `target_change_effect` |
| `IGNORE_NON_DAMAGE` | 16 / 4 | **21/174** | `ignore_non_damage_effect` |
| `PORTRAIT_CHANGE` | 7 / 3 | **19/174** | `portrait_change_effect` |
| `ISOLATE` | 3 / 2 | **12/174** | `isolate` |
| `BLIND` | 15 / 4 | **11/174** | `blind_effect` |
| `IMMORTALITY` | 3 / 2 | **9/174** | `immortality_effect` |
| `REFLECT_RECEIVE` | 13 / 11 | 10/174 | `reflect_effect` |
| `BARRIER` | 11 / 4 | 9/174 | `barrier_effect` |
| `DELAY` | 4 / 2 | 6/174 | `delay_eff` |
| `DAMAGE_CAP` | 5 / 2 | 6/174 | `damage_cap` |
| `CONTROL_CANCEL` | 4 / 2 | 8 + 7 (`channel_cancel`) | `control_cancel` |
| `DAMAGE_REDIRECT` | 4 / 2 | 3/174 | `redirect_effect` |
| `HEAL_CUT` / `HEALTH_CAP` / `PERCENT_DR` / `DAMAGE_CAP_RECEIVE` | 1 char each | 1 each (**different** characters: jack / cooler / ace / yoh — none of them nobara) | |
| `PARALYZE` | 1 char (**nobara only**) | 5/174 — gatomon, kurotsuchi, mercury, rimuru, yoruichi | `paralyze_effect` |
| `BANISH` | 1 char | **0** via `Effect.banish_effect`; the verb is `Character.banish_character` (5/174) | |

> [!warning] The rule this adds to the hygiene list
> **Count the factory call, not the enum token — and check whether the one hit is a scan list.** A
> file that enumerates twenty effect types to *ask a question about them* is not twenty users of
> twenty mechanics. `nobara4` alone accounts for the entire "≈20 more at ONE character each" tail of
> the frame's uncovered ranking.

---

## See also

[[What Cannot Be Built Yet]] · [[Block Palette Reference]] · [[Creator Roadmap]] ·
[[Creator Roulette]] · [[The Creator]] · [[Effects and Durations]] · [[Trigger Types]] ·
[[Targeting and Main Target]] · [[Traps That Have Bitten Us]]
