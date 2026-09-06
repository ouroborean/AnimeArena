---
tags: [area/playbook, type/reference]
---

# Roulette 06 - Boruto Uzumaki

**Draw:** `draw 15/174 -> boruto` — recorded before any script was opened.
**Universe:** Naruto · **Gate:** `boruto_unlock` · **Abilities:** 7 (4 visible, 1 passive, 2 hidden
swap-in).
**Verdict:** **Blocked** — 31 mechanics: **15 buildable, 9 approximable, 7 blocked**. Two whole
skills (boruto3, boruto7) contain a clause no block combination reaches.

> [!danger] The kit is a *rotation*, and the rotation runs on the one hook the palette skipped
> Boruto's passive re-rolls his third slot every turn between three Rasengans, two of which are
> hidden skills. The swap, the coin, the hidden targets and the slot bookkeeping are all reachable.
> What is not reachable is the **hook the passive hangs on**: `TICKING_TRIGGER`, the single most-used
> trigger type in the corpus (**53 of 174 characters**), is absent from `BlockSchema.TRIGGERS` while
> `START_OF_TURN_TRIGGER` (**7 of 174**) is present.

---

> [!tip] Palette read in full first (run-04 rule), and it moved four verdicts
> `blocks/block_schema.gd` read end to end — 20 `EFFECT_KINDS`, 8 `OPS`, 7 `CONDITIONS`, 7
> `SELECTORS` + 3 `FILTERED_SELECTORS`, 7 `TRIGGERS`, 24 `UNIVERSAL_EFFECT_FIELDS`, then
> `block_validator.gd` for what it rejects and `block_runner.gd` for what it actually does.
> That flipped **`break`** (boruto7's shield removal is a shipped op — run 04's own proposal),
> **`cost_change.skills`** (boruto2's three-named-skill discount is a shipped field), **`ticks`**
> (odd raw durations are authorable) and **`apply.bypassing`** (boruto7's stun bypass is a shipped
> op field) from "assumed missing" to buildable. Three of the six things I expected to block this
> character had already shipped.

---

## The kit

| # | Skill | Cost | CD | What it actually does (from the script) |
|---|---|---|---|---|
| 1 | **Karma Taijutsu** | 1 Random | 0 | 15 damage to one enemy; **if Boruto is marked by Boruto Shadow Clones**, also plants a 15-damage NORMAL DoT at raw duration 3 |
| 2 | **Boruto Shadow Clones** | 1 Random | 3 | Self: 30 Shield (8 ticks), a mark (9 ticks) that arms skill 1, and **−1 Random cost on three *named* skills** (9 ticks) |
| 3 | **Vanishing Rasengan** | 1 Blue, 1 Random | 1 | Marks *himself* (3 ticks) and plants an invisible **TICKING_TRIGGER on the enemy** (3 ticks) that next turn deals **25 Piercing effect damage** and stuns for 1 turn |
| 4 | **Thunderclap Arrow** | 1 Random | 3 | Invisible `HARMFUL_RECEIVE_TRIGGER` on self (2 ticks): the **enemy that triggers it** takes 15 Piercing effect damage, Boruto becomes Invulnerable for the rest of the turn. `wrapup_func = default_counter_timeout` |
| 5 | **Rasengan Specialist** | — | — | **Passive.** Permanent `TICKING_TRIGGER`: every turn, read which Rasengan is in slot 2, erase it from the list of three, `battle.roll(0,1)` over the remaining two, install a **duration-3 ability swap** |
| 6 | **Wind Release: Rasengan** *(hidden)* | 1 Blue, 1 Random | 0 | 20 Piercing to `targeter.main_target`, 10 Piercing to every **other** enemy |
| 7 | **Compression Rasengan** *(hidden)* | 1 Blue, 2 Random | 1 | `shatter_shields`, then 35 Piercing, **and if nothing was shattered** a bypassing 1-turn Stun. Targets **through invulnerability** (`default_hostile_target_function(user, battle, true)`) |

Skills 6 and 7 are never selected by the player — they arrive in slot 2 only because the passive put
them there. That is the shape the audit had to preserve.

---

## Mechanic audit

| Skill | Mechanic | Verdict | Notes |
|---|---|---|---|
| 1 | 15 damage to one enemy | **Buildable** | `{"op":"damage","to":"target","amount":15}` |
| 1 | DoT **only if the user is marked** | **Buildable** | `when: {has_effect, on: "user"}` on the `apply`. Must be written `"ticks": 3` — `turns_to_duration` is `2N` and can never be odd (`block_schema.gd:434-439`) |
| 1 | `marked_by(...)` = **name AND type** | **Approximable** | `has_effect` bottoms out in `has_any_effect(name)` — name only. boruto2 gives its Shield, Mark and Cost-Mod all the *same* `effect_name()`, so the authored guard also fires on the Shield. `name_override` is the in-palette fix |
| 2 | 30 Shield, raw 8 ticks | **Buildable** | Byte-identical factory call |
| 2 | Mark carrying tooltip text, raw 9 | **Approximable** | `BlockRunner` forces `mk.stackable = true` unconditionally (`block_runner.gd:585`); the script's mark is not stackable. Re-cast **merges and keeps the old expiry** instead of stacking a second, later-expiring mark. CD 3 vs a ~4.5-turn duration makes this reachable in ordinary play |
| 2 | −1 Random cost on **three named skills** | **Buildable** | `cost_change.skills` is a real name list, validated, threaded into `ability_targets`, matched by `ability_name` at `ability_component.gd:328`. Works even though two of the three are **hidden** skills |
| 2 | Three different raw durations from one cast | **Buildable** | Per-block `ticks`; no duration coupling in `_build_effect` |
| 3 | Self-mark announcing the shot | **Buildable** | `mark` + `ticks: 3` |
| 3 | **Recurring hook on an *enemy*** | **Blocked** | `TICKING_TRIGGER` is not in `TRIGGERS` (`block_schema.gd:286-294`). `on_turn_end` is **not** a substitute here — see below |
| 3 | One-shot delayed payload (damage **and** stun, next turn) | **Approximable** | Reachable as a 3-effect fuse held on the **caster** (JSON below). Loses: the player-chosen slot in `execution_order`; the ticking gates (invuln / isolate / stun cancellation); identity if two enemies are marked |
| 3 | Payload deals **effect** damage | **Blocked** | The only damage verb is `Character.resolve_damage` (`block_runner.gd:302`). `resolve_effect_damage` is a separate path with different hooks, a different `is_ignoring_damage` answer and no `minimum_damage` floor |
| 3 | Stun as part of the payload | **Buildable** | `stun` kind, hostile-routed; tick accounting matches exactly (end-of-turn triggers run *before* `tick_durations`) |
| 4 | Invisible `on_harmful_received` on self | **Buildable** | Same `Effect.trigger_effect` factory, same `waiting` self-application guard |
| 4 | Payload hits **the enemy that triggered it** | **Buildable** | **Not a gap** — `_build_trigger` binds `set_explicit_targets([context.owner])` (`block_runner.gd:706-716`), and for this hook `context.owner` is the attacker. Every thorns / counter-attack design is expressible |
| 4 | Invulnerable for the **rest of this turn** (raw 1) | **Buildable** | `ticks: 1`. Cosmetic only: generated prose `ceil()`s it back to "1 turn" |
| 4 | "The **first** time" — one-shot | **Approximable** | Only `trigger_once` is dead; `remove_once_triggered` / `full_remove_once_triggered` are live but only on `IGNORE_DAMAGE` (below). For a *trigger*, authored by having the payload `remove` its own effect by `name_override` |
| 4 | `wrapup_func = default_counter_timeout` | **Blocked** | Callables are excluded from the palette on purpose. Cosmetic here — it posts the invisible "has ended" pip — but it is the convention that tells an opponent a lapsed invisible reactive is gone |
| 5 | Passive installs a **permanent** hook | **Buildable** | `startup_passives` calls `execute()`; `turns: -1` validates; permanence also makes it cleanse-proof for free. Needs `system: true` + `remove_on_death: false` or a revive silently kills it |
| 5 | Cadence: once per round, on his own side's turn | **Approximable** | `on_turn_end` matches **because the effect sits on Boruto himself**. Loses: an isolated Boruto's ticking passive is skipped, the authored one keeps cycling. **Never** `on_turn_start` — it fires for both teams at both transitions, i.e. twice per round |
| 5 | Read **which ability is in slot 2** | **Approximable** | No condition reads a moveset slot. The tight workaround is a **shadow flag that *is* the swap** — `name_override` on the swap effect, read back with `has_effect`. Answers "is my swap installed", never "what is in slot 2" |
| 5 | Uniform coin over the two **not** equipped | **Approximable** | Exact **only because N = 2**. `chance` is per-block with no `else` and no shared roll, so two 50% blocks fire both 25% / neither 25%; the fix is a token. `percent` is an integer, so N = 3 needs 33.33 and is unreachable |
| 5 | Re-entry safety of a 3-state cycler | **Approximable** | Structural, and invisible until you write it: the transition graph is a 3-cycle, so **no branch ordering is safe** and there is no stop op. Costs a 5-block snapshot prologue + 3-block cleanup — **8 of 22 blocks** |
| 6 | 20 to the main target, 10 to the rest | **Approximable** | The **selector** is missing, the **mechanic** is reachable — see the marker-exclusion idiom below. Losses are named, and they are real |
| 7 | Remove all Shield | **Buildable** | The `break` op — run 04's proposal, **shipped** |
| 7 | 35 Piercing after the break | **Buildable** | Block order is execution order |
| 7 | Bypassing 1-turn Stun | **Buildable** | `apply.bypassing` is the add-effect parameter, correctly distinct from the universal `bypassing` field and from the "Bypassing" class |
| 7 | Preserve the order (test → break → damage → stun) | **Buildable** | Solved by an **invisible-mark latch**, without any value-returning op — general idiom, see below |
| 7 | Branch on whether the target held **any Shield** | **Blocked** | `has_effect` is name-only and shields are named after whatever ability made them. There is no type-based condition |
| 7 | `break` **reports** what it destroyed | **Blocked** | `_op_break` discards both returns; no op writes state a condition can read. (2/174 — the latch removes the need anyway) |
| 7 | Target **through invulnerability** | **Blocked** | The `bypassing` third argument of `default_hostile_target_function` is never passed by `ScriptedAbility.target()` and has no `ABILITY_FLAGS` entry. The "Bypassing" **class** is a display label |
| all | Address the character an effect is **sitting on** | **Blocked** | No selector for `context.target`. The headline gap — see the proposed system |

---

## What blocks it

### 1. `TICKING_TRIGGER` is absent, and `on_turn_end` only substitutes for a *self-held* effect

This is the qualifier that decides whether the substitution is honest, and it is easy to get wrong.

- `check_end_of_turn_triggers` runs only for characters on the **acting** team
  (`battle_manager.gd:1338-1341`). `get_ticking_effects` gathers an effect when its **`effect.user`**'s
  side acts (`:824-843`). For an effect Boruto puts on **himself** those are the same turn — boruto5
  substitutes cleanly. For an effect he puts on an **enemy** they are opposite turns, so boruto3's
  payload would land half a round late and hand the enemy a free turn.
- Worse, the payload's `target` selector is bound to `context.owner`, and `from_effect_end` sets
  `context.owner = effect.user` — **the caster**. So an author who places an end-of-turn trigger on an
  enemy and writes `{"op":"damage","to":"target"}` **damages himself**. Silently. That is a live
  footgun in the shipped palette, not a hypothetical.

See [[Trigger Types]], which already documents `TICKING_TRIGGER` as *the* convention for
per-turn effects and the gates `execute_ticking_effect` applies.

### 2. There is no selector for the character an effect is attached to

`_build_trigger` binds exactly two things into the payload runner: `holder = context.effect.user`
(the **applier**, which becomes `"user"`) and `context.owner` (which becomes `"target"`).
`context.target` — the character carrying the effect, the one the engine sets on every hook — has
**no name at all**. Consequences, per hook:

| Hook | `"target"` resolves to | Unreachable |
|---|---|---|
| `on_harmful_received`, `on_damage_received` | the attacker | the protected holder (fine for boruto4, blocking for an ally-placed thorns) |
| `on_death` | the **killer** | the corpse |
| `on_damage_dealt` | the **dealer** (self) | **whoever was just hit** |
| `on_turn_start`, `on_turn_end` | `effect.user` (the caster) | the enemy actually holding it |

### 3. `has_effect` cannot ask about an effect **type**

`has_effect` / `not_has_effect` bottom out in `has_any_effect(name)` — a bare `effect_name()` string
compare with no type argument. Shields are named after the ability that made them, so "does this
character have **any** Shield" is unaskable, and boruto7's whole conditional half is unwritable.
The engine's typed sibling `has_effect(name, type, user)` still requires a name.

### 4. One advertised universal field is dead (corrected)

> [!danger] This section originally claimed all THREE once-fields were dead. That was wrong, and it
> was wrong inside the very finding that tells future runs to check the reader rather than the schema
> entry. Corrected after an adversarial pass; the original claim is left visible here rather than
> quietly rewritten.

Only **`trigger_once`** is dead. Its sole reader, `Effect.trigger_check` / `triggerable`
(`effect_component.gd:123-131`), has zero callers repo-wide, and `Effect.triggered` is never set true
by the engine. An author who ticks "trigger once" gets a trigger that fires every time.

`remove_once_triggered` and `full_remove_once_triggered` are **LIVE** — read in `is_ignoring_damage`
(`scripts/character_component.gd:1677-1679`), where they consume an `IGNORE_DAMAGE` effect the first
time it blocks. Since `ignore_damage` is a shipped palette kind, **a one-shot damage negate is
authorable today**; `kurapika4.gd` ships that exact shape. Verified by reading the call site.

So the fix is narrow: wire `trigger_check` into the `check_*_triggers` loops, or drop `trigger_once`
alone.

---

## The two idioms this run found

Both are writable **today**, and neither is discoverable from the schema. They belong in
[[Block Palette Reference]].

### The invisible-mark latch — snapshot a condition before a mutating op

Because `apply` + `when` and `remove` both run inside one `execute()`, an author can capture any
condition the palette can express *before* a mutating block and consume it *after*, with no
value-returning op and no reordering of the visible effects. boruto7 restructured, 5 blocks:

```json
[
  {"op":"apply","to":"target",
   "when":{"cond":"not_has_effect_type","on":"target","effect":"SHIELD"},
   "effect":{"kind":"mark","ticks":1,"invisible":true,"system":true,"name_override":"Uncushioned"}},
  {"op":"break","what":"shield","to":"target"},
  {"op":"damage","to":"target","amount":35,"damage_type":"PIERCING"},
  {"op":"apply","to":"target","bypassing":true,
   "when":{"cond":"has_effect","on":"target","name":"Uncushioned"},
   "effect":{"kind":"stun","turns":1}},
  {"op":"remove","to":"target","name":"Uncushioned","effect":"MARK"}
]
```

Every construct here validates **except block 1's condition**, which is the missing type test. Drop
in `not_has_effect_type` and boruto7 is fully buildable apart from its targeting flag. The latch
costs nothing observable: `invisible` suppresses the log entry (`battle_manager.gd:1987`) and the
mark is removed in the same cast.

### The marker-exclusion idiom — main-target-vs-splash, today

> [!warning] This partially refutes a standing gap in [[Creator Roulette]]
> "Main-target-vs-splash differentiation" is listed as out of reach. The **primitive** is genuinely
> missing (no selector names the main target; none of the seven conditions tests identity;
> `main_target` appears in `blocks/` exactly once, as an *exclusion* note). The **mechanic** is not.

Author the skill **single**-target so `to: "target"` *is* the main target, stamp an
invisible+system marker on it, then use `to: "any_enemy"` + `not_has_effect` as "every enemy except
the main", then remove the marker. boruto6, 4 blocks:

```json
[
  {"op":"apply","to":"target",
   "effect":{"kind":"mark","ticks":1,"invisible":true,"system":true,"name_override":"Rasengan Focus"}},
  {"op":"damage","to":"target","amount":20,"damage_type":"PIERCING"},
  {"op":"damage","to":"any_enemy","amount":10,"damage_type":"PIERCING",
   "when":{"cond":"not_has_effect","name":"Rasengan Focus"}},
  {"op":"remove","to":"target","name":"Rasengan Focus","effect":"MARK"}
]
```

It works because a filtered selector's `when` is evaluated **per candidate with that candidate as the
subject** (`_resolve_filtered`, `block_runner.gd:143-154`), and because `_remove_matching` matches on
`effect_name()`, which honours `name_override`.

**What it loses, stated so nobody quotes it as solved:**

- The splash pool becomes `all_enemies`, not "the targets the targeter flagged" — **not** identical
  for boruto6 (see the invulnerability hole below), and wrong for any skill whose `target()` narrows
  the set.
- An enemy for whom `can_be_affected` is false never takes the marker, so if **that** enemy is the
  main target it silently drops into the splash bucket and takes 10 instead of 20. Favours the
  defender, and is invisible.
- **Bot fidelity degrades.** `custom_behavior` branches purely on `target_mode`
  (`scripted_ability.gd:512-533`), so forcing the skill single-target makes the bot score it as
  `behavior_single_target_damage` rather than the `behavior_hostile_splash_aoe` the script uses.
- Marker names are global. A second kit using the same name excludes the wrong enemies.
- It does **not** generalise to "the main target gets a *different effect*" the way a layered-damage
  workaround pretends to: `mash2` deals equal damage to everyone and taunts only the primary. The
  layered trick (`all_enemies` 10 then `target` 10) also double-resolves damage on the main target,
  so reduction, the minimum-damage floor, boosts and receive-triggers all apply **twice**. Use the
  marker form or nothing.

### The invulnerability hole — a live defect, not a missing feature

The pool-selector divergence above is not cosmetic, and it is the one finding in this run that is a
**bug in shipped code** rather than a gap in the palette.

`BlockRunner._filtered_pool` / `all_enemies` return the raw enemy team filtered only by `_alive`
(dead / banished) — `block_runner.gd:156-176`. A shipped script's pool is `user.targeter.targets`,
which `battle_manager._drop_invuln_targets` (`:1150-1175`) has **already stripped of invulnerable
enemies**. And `Character.resolve_damage` never checks invulnerability at all — only
`is_ignoring_skill` / `is_ignoring_damage`.

**Measured, not reasoned:** a throwaway probe made an enemy invulnerable via `Effect.invuln_effect`
(the same factory the palette's `invulnerable` kind uses), confirmed `is_invuln == true`, then ran
exactly what a `damage` op runs. It hit for full: `HP 100 -> 80  damage_landed=true`.

So the current state is inconsistent three ways:

| Authored form | Respects Invulnerability? | Why |
| --- | --- | --- |
| `damage` to `target` | **yes** | the targeter pool was pre-stripped upstream |
| `damage` to `all_enemies` / `any_enemy` / `random_enemy` | **NO** | raw team, `_alive` only, and `resolve_damage` has no invuln check |
| `apply` (any effect) | **yes** | `can_apply_hostile_effect` checks invuln (`block_runner.gd:552`) |

An author therefore gets an AoE that ignores a core defensive mechanic, while their single-target
damage and all their effects respect it. `grep -n invuln blocks/block_runner.gd` returns 8 hits and
every one is a comment or the `invulnerable` effect *kind* — there is no guard on the damage op.

This belongs in the roadmap as a **fix**, ahead of any new palette work: it is reachable by any
player today with a two-block skill, and it silently beats Invulnerability.

### And the fuse — boruto3's delayed payload, held on the caster

Validated by hand against the validator's structural rules (7 blocks of 40; payload depth 3 of 4;
`then` size 1 of 12):

```json
{"op":"apply","to":"user","effect":{
  "kind":"trigger","trigger":"on_turn_end","ticks":4,"invisible":true,
  "name_override":"Vanishing Rasengan (delayed)",
  "then":[{"op":"group","when":{"cond":"not_has_effect","name":"Rasengan Fuse","on":"user"},"blocks":[
    {"op":"damage","to":"any_enemy","when":{"cond":"has_effect","name":"Vanishing Rasengan"},
     "amount":25,"damage_type":"PIERCING"},
    {"op":"apply","to":"any_enemy","when":{"cond":"has_effect","name":"Vanishing Rasengan"},
     "effect":{"kind":"stun","ticks":2}},
    {"op":"remove","to":"user","name":"Vanishing Rasengan (delayed)"}]}]}}
```

…plus a 1-tick "Rasengan Fuse" mark on the user (so the trigger skips the turn it was planted) and a
named 3-tick mark on the enemy (so `any_enemy` can find it). It produces the right numbers on the
right turn. It is **not** the same skill: the real one is a scheduled entry in the turn's execution
order that the player can position, and it is cancelled by invulnerability, isolation and a stun on
the caster. The authored one runs last, unconditionally, and punches through all three.

---

## Proposed system J — Payload addressing

> [!info] Checked against the ledger first
> Nothing in the existing ledger covers this. Ability Swap, Counters, Stacks, Relational conditions,
> Filtered removal and Defence destruction have all **shipped**; Channels is unrelated. The closest
> neighbour is run 02's **system D, "Reactive trigger coverage"** — and that is deliberately *not*
> what this is: D is more rows in the hook enum (the `on_ticking` row below is D's, and run 06 is
> another run served by it). This is the *vocabulary inside* the payload, which no run has raised.
> It is the only finding in run 06 that is genuinely system-shaped.

**The family.** Inside a trigger or counter payload, name any participant of the event **by its role**
instead of by team. Today the runner binds exactly two roles and gives one of them a misleading name;
the third — the character the effect is attached to — has no name at all.

| Selector | Resolves to | Status today |
|---|---|---|
| `user` | `context.effect.user` — whoever applied the effect | shipped |
| `target` | `context.owner` — whoever tripped the hook | shipped, but means something different per hook |
| **`holder`** | `context.target` — the character carrying the effect | **missing** |

**Axes.** Role × hook. The two are independent: the same three role names resolve to three different
characters for each of the 7 (soon 8+) hooks, and that mapping is the engine's own, already computed
by `QueryContext` on every trigger path. Mechanics that fall out of the one addition:

- thorns / protection payloads placed on an **ally** (payload heals or shields the holder)
- `on_damage_dealt` → "hurt whoever I just hit" — currently unreachable at all
- `on_death` → "the corpse", not only the killer
- delayed and recurring payloads planted on an **enemy** (boruto3, and the enemy-held half of the
  `TICKING_TRIGGER` population)
- ally-held recurring buffs whose payload addresses the ally rather than the caster

**Against the seven-point bar:**

1. **Family, not effect.** Two independent axes (role × hook), five named mechanics above, and it is
   not an effect at all — it is vocabulary, so it multiplies with every kind and op the palette
   already has.
2. **Measured reach.** `29/174 (17%)` hand-verified floor, `65/174 (37%)` loose upper bound — the
   loose grep counts self-held payloads that `user` already reaches, so **publish the range, never a
   single figure**. It is additionally a **precondition** for the `TICKING_TRIGGER` row's 53/174:
   roughly half that population places the ticking effect on an enemy, and a ticking hook without a
   holder selector ships broken.
3. **It composes.** It is a selector. One arm in `_resolve_targets`; `to`, condition `on`/`of`/`vs`
   and the filtered selectors' subject resolution are untouched.
4. **Safety story.** A selector carries no magnitude, so every existing per-op limit still binds.
   New validator rules: `holder` is legal **only inside a `then` payload** — thread the same
   `in_reactive` flag [[Creator Roadmap]] Phase 6 already specifies for event vocabulary — and it
   resolves to at most one character, returning `[]` when dead or invalid and **never** falling back
   to the caster. The abuse case it *prevents* is today's: an enemy-placed `on_turn_end` payload
   whose `target` silently points home. The abuse case it *creates* arrives only with the ticking
   row — a permanent enemy-held trigger whose payload damages `holder` is an unbounded per-round DoT
   priced as one cast — so pair it with a duration cap on a hostile-placed recurring trigger, the
   same shape as the existing DoT limits.
5. **Prose.** One entry in `_describe_selector`: "the affected character". "Each turn, the affected
   character takes 25 Piercing damage and is stunned for 1 turn."
6. **Bot story.** **No new `bot_tags` bit.** `_derive_tags` already recurses into `then`
   (`scripted_ability.gd:477-483`) and `TAG_REACTIVE` is already set by the trigger itself, so a
   payload aimed at `holder` scores exactly as one aimed at `target`. One honest caveat to record:
   `bot_damage_hint()` never walks a payload at all today (`_block_damage` has no trigger arm), so
   payload damage scores 0 whichever selector it uses. This system adds no new blindness — it
   inherits an existing one, which is its own separate item.
7. **Engine cost.** **No engine primitive is missing.** `QueryContext.target` is already set on every
   hook (`query_context.gd:38-44`, `:52-62`). Changes: `block_schema.gd` (`SELECTORS` + a
   payload-only note), `block_validator.gd` (payload-scope check), `block_runner.gd`
   (`_resolve_targets` arm, and `_build_trigger` must stash `context.target` the way it already
   stashes `context.owner` via `set_explicit_targets`), `scripted_ability.gd`
   (`_describe_selector`), and one dropdown entry in the editor.

---

## Not systems — rows the palette has not surfaced

Per [[Creator Roulette]]'s opposite trap, these are factories and enum entries, not design problems.
Each is listed with what it actually costs.

| Row | Reach | Cost |
|---|---|---|
| **`on_ticking` trigger hook** *(run 02's system D, second run served)* | **53/174 (30%)** | One row in `TRIGGERS`, one arm in `trigger_hook_id`. **Must ship with system J** or the ~half of the population that places ticking on an enemy gets a hook whose payload cannot address the character it is attached to |
| **`bypassing` ability flag** (invuln-bypass **targeting**) | **33/174 (19%)** | One entry in `ABILITY_FLAGS`, one argument at `scripted_ability.gd:62/65`. The parameter has existed all along. Note the inversion: `accurate` **is** exposed and is set by **zero** shipped abilities |
| **`has_effect_type` / `not_has_effect_type`** | 11/174 (6%) | Two `CONDITIONS` rows, two arms in `_check_condition`, two prose lines — reusing `BlockSchema.immunity_effects()`, the derivation `effect_immunity.effect` and `remove.effect` already share |
| **`as_effect` on the `damage` op** | 62/174 (36%) *divergence*, not breakage | One flag routing to `resolve_effect_damage`. An authored payload still deals damage today; it just takes the ability path, with the `minimum_damage` floor, the `is_ignoring_skill` gate and the wrong interception hooks. **Do not quote 62 as blocked kits** |
| **`slot_holds` condition** | 4/174 (2%) | One condition row reading `get_active_abilities(t)[slot].ability_name`. Field-sized. Belongs **inside** the Ability Swap row as "the read half of swap" — same two axes |
| **`on_expire` payload** (declarative wrapup) | 20/174 (11%) custom · 49/174 cosmetic | A `then`-shaped block list on expiry. Callables are excluded from the palette for good reason; a **declarative** payload is not code-in-data and is the palette-shaped version |
| **`else` on `group`** | 6/174 (3%) | Already [[Creator Roadmap]] Phase 2. Run 06 is a second data point: without it, mutual exclusion needs a token effect, and exactly-uniform choose-one-of-N is reachable **only at N = 2** because `percent` is an integer |
| **`main_target` / `other_targets` selectors** | 12/174 (7%) | Already Phase 2. Run 06 downgrades this from Blocked to **Approximable** via the marker idiom, with five named losses |

---

## Reach

Roster baseline, and the step runs 02, 03 and 05 omitted:

```bash
sed -n '5,178p' scripts/character_database.gd | sed 's/[\t",]//g' | awk 'NF' | sort > chars.txt   # 174
cd abilities && grep -l '<PATTERN>' *.gd | sed 's#\.gd$##; s#[0-9]*$##' | sort -u \
  | comm -12 - ../chars.txt | wc -l
```

The `comm -12` intersection is what separates a tight number from an inflated one. The non-roster
stems that recur across every grep are `jinwoo{blue,green,red,white}` (one roster entry's pre-match
summon forms), `{genos,natsu,noelle,zoro}temp`, `old`, `lizandpattyold`, `vessel`, and the
de-rostered `kakashi` / `uryu`.

| Missing capability | Characters | Pattern |
|---|---|---|
| effect-damage path | **62 (36%)** | `Character\.resolve_effect_damage\(` |
| `TICKING_TRIGGER` hook | **53 (30%)** | `EffectType\.Type\.TICKING_TRIGGER` |
| invuln-bypass **targeting** | **33 (19%)** | `default_(hostile\|allied)_target_function\([^)]*, *true` |
| holder / `context.target` selector | **29 floor — 65 loose** | `context\[.target.\]` ∩ trigger-placed-on-another |
| custom `wrapup_func` body | **20 (11%)** | `wrapup_func *=` minus `default_counter_timeout` |
| `HARMFUL_USE_TRIGGER` hook | 15 (9%) | `EffectType\.Type\.HARMFUL_USE_TRIGGER` |
| `main_target` differentiation | 12 (7%) | reads only; the 8 files that **write** it are the reflect system |
| `has_effect_type` condition | 11 (6%) | hand-curated from `get_effects_by_type` control-flow sites |
| `HEALTH_CHANGE_TRIGGER` hook | 11 (6%) | |
| exclusive-random **outcome** branch | 6 (3%) | hand-classified; target-picks excluded |
| `STUN_RECEIVED_TRIGGER` | 5 (3%) | |
| `slot_holds` condition | 4 (2%) | hand-read from all 21 `get_active_abilities` sites |
| `break` reports what it destroyed | 2 (1%) | boruto7, squalo2 |
| `HEALING_GIVEN_TRIGGER` | 1 | sayaka only — **do not build** |
| 6 further hooks | **0 each** | `HELPFUL_USE`, `HELPFUL_RECEIVE`, `HEALING_RECEIVED`, `INVULN_RECEIVED`, `ABSORB`, `DELAY_TICK` |

> [!danger] The palette ships the #2 trigger hook and skips the #1
> Full census by roster reach: TICKING **53**, ACTION_USE **44**, HARMFUL_RECEIVE **30**,
> DAMAGE_RECEIVE **21**, HARMFUL_USE **15**, END_OF_TURN **15**, DAMAGE_DEALT **12**,
> HEALTH_CHANGE **11**, ON_DEATH **10**, START_OF_TURN **7**, STUN_RECEIVED **5**,
> ACTION_RECEIVE **3**, HEALING_GIVEN **1**, and six at zero. `TRIGGERS` ships seven of these —
> including START_OF_TURN at 7/174 — and omits TICKING at 53/174 and HARMFUL_USE at 15/174.
> Two enum rows would close 68/174 of the gap.

### Ledger re-measure — two rows were inflated, two were under-counted

Every ledger reach number was re-run with the intersection. This is the unflattering part.

| Ledger row | Ledger says | Re-measured | Note |
|---|---|---|---|
| Stacks as a resource | 81/174 (47%) | **42/174 (24%)** | **Halved.** The bad number has already propagated into shipped source: `block_schema.gd:103-104` justifies the `stacks` fields with "what 81 of the 174 shipped characters do" |
| Relational conditions | 49/174 | **35/174 (20%)** | |
| Ability Swap | 82/174 | **74/174 (43%)** | The 8-character gap is exactly the non-roster stems — the hygiene failure mode in its purest form |
| Filtered effect removal | 75/174 | 71/174 (41%) | |
| `on_skill_used` | 45/174 | 44/174 (25%) | confirmed |
| Counters | 42/174 | 40/174 (23%) | confirmed |
| Defence destruction | 9/174 | **9/174** | unchanged |
| Energy colour | 8/174 | **25/174 (14%)** | **Tripled** — under-counted. Still a field, not a system |
| Channels | 15/174 | **18/174 (10%)** | measured on the `Action` class in `abilities_data.json`, which is the real channel marker |
| Action Restriction | 114/174 gross | 127/174 gross | **Higher, and more misleading** — stun/silence/paralyze/taunt/cost/cooldown have all shipped. Retire the gross figure; the net is only the exclude-class filter and `ignore_skill` |

---

## Verdict for the roadmap

**Two rows and one small system, and they ship together or not at all.**

1. **`on_ticking` in `TRIGGERS`** — [[Creator Roadmap]] Phase 2 ("free wins"). One enum row for the
   most-used hook in the corpus. It is *not* a system and must not be written up as one.
2. **Payload addressing (`holder`)** — Phase 6, riding the `in_reactive` validator flag that phase
   already builds. Phase 2's row alone would ship a hook whose payload cannot address the character
   it is attached to, which is worse than not shipping it.
3. **`bypassing` in `ABILITY_FLAGS`** — Phase 2, and the cheapest 19% on the board. One argument.

Everything else this run found is a row in the table above or already on the roadmap.

> [!info] What run 06 says about the five-run through-line
> The old through-line — "the palette handles one-shot effects well and persistent state not at all"
> — was written before `stacks`, `swap`, `counter` and `compare` shipped. It no longer describes the
> palette. Boruto's kit is *entirely* persistent state (a permanent passive, a rotation, delayed
> payloads) and the state machinery is all present. What blocked him is **addressing and timing
> inside a payload**: which hook fires, and who the payload can name once it does. Six runs in, the
> palette can hold state and cannot reliably *point at anybody* except the caster and whoever just
> acted.

> [!warning] Nothing in this run was executed
> Every verdict is a static read of `block_schema.gd` / `block_validator.gd` / `block_runner.gd`
> against the engine call sites, plus a hand-port of the validator's structural rules over the JSON
> above and a simulation of the runner's evaluation order. No probe was run and no JSON was put
> through the real `BlockValidator`. Before any of these idioms is treated as proven — especially the
> cross-team `apply` of a marker through `add_allied_effect` — it needs the normal loop in
> [[Verification Playbook]].

---

Related: [[Creator Roulette]] · [[Roulette 01 - Naruto Uzumaki]] · [[Roulette 02 - Death the Kid]] ·
[[Roulette 03 - Sailor Mercury]] · [[Roulette 04 - Superbi Squalo]] · [[Roulette 05 - Shiro]] ·
[[Block Palette Reference]] · [[Creator Roadmap]] · [[What Cannot Be Built Yet]] ·
[[Trigger Types]] · [[Targeting and Main Target]] · [[Damage Pipeline]] · [[Effects and Durations]] ·
[[Bots and Training]]
