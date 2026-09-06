---
tags: [area/playbook, type/reference]
---

# Roulette 08 - Semiramis

**Draw:** `draw 131/174 -> semiramis` — recorded before any script was opened.
**Universe:** Fate · **Gate:** `semiramis_unlock` · **Abilities:** 5 (3 visible actives, 1 self-buff,
1 passive; no hidden swap-in slots).
**Verdict:** **Blocked** — 26 mechanics: **10 buildable, 3 approximable, 13 blocked**. Skills 1 and 4
are authorable exactly. Skills 2, 3 and 5 each lose their defining clause, and they lose it to three
*different* gaps that one skill (semiramis3) chains together.

> [!info] Checked against the ledger first, as the process page requires
> This run adds a **Runs served** tick to three existing entries — **Payload addressing** (third
> sighting), **Trigger-hook coverage** / `on_ticking` (third), **Defence destruction**'s report
> sub-row (second) — and proposes **one** system, which is not a new invention either: *"damage that
> scales off live state"* is already in the process page's recurring-mechanics table as **still
> missing**. Run 08 measures it for the first time (**43/174**), gives it a shape, and moves it into
> the proposed-system ledger.
>
> The two candidates the brief asked about are adjudicated below and **neither is a system**.
> **Banish** is an `OPS` row (5/174) with a genuine safety problem. **State conditions** does not
> hold together as one thing: it **splits**, and the split absorbs most of it into the proposed
> system, leaving a handful of `CONDITIONS` rows behind.

---

## The kit

`Energy.Type` is `GREEN=0, BLUE=1, WHITE=2, RED=3, RANDOM=4`, so the `abilities_data.json` cost keys
below read directly as an authored `"cost"` dictionary.

| # | Skill | Cost | CD | Target | What it actually does (from the script) |
|---|---|---|---|---|---|
| 1 | **Chains of the First Poisoner** | 1 White | 1 | one enemy | 20 Affliction · stun that enemy's **Helpful and Strategic** skills for 1 turn |
| 2 | **Mystical Beast - Hydra** | 1 White, 1 Random | 3 | all enemies | 10 Affliction now + a raw-5 Affliction DoT · a `TICKING_TRIGGER` that, **on its final tick only**, stuns the holder · an `END_OF_TURN_TRIGGER` that lets the holder **cancel the whole package by ending a turn Invulnerable** |
| 3 | **Arrogant King's Poison** | 1 White, 2 Random | 3 | all enemies | Permanent stacking 5 Affliction DoT (applied invuln-bypassing) · **shatters shields, strips every Invulnerability and every heal-over-time, counts them**, then deals `5 + 5×count` and applies `count` further stacks · targets **through** invulnerability |
| 4 | **Scales of the Sacred Fish** | 1 Random | 4 | self | `default_defend` — self-Invulnerable for 1 turn |
| 5 | **Hanging Gardens of Babylon** | — | 0 | self | **Passive.** Semiramis **starts the match banished** (3 or 4 engine ticks, chosen from turn order); a cleanse-proof `START_OF_TURN_TRIGGER` that ticks *through* the banish returns her with **25 permanent Shield** and **1 random energy** |

> [!note] `describe()` was not read as evidence anywhere in this audit
> Per the owner's standing rule, `describe()` bodies are irrelevant — only `split_desc()` is the
> skill contract. Every "what it actually does" above comes from the executable body; `split_desc()`
> is quoted only where a fidelity claim needs the contract it has to satisfy.

---

## Mechanic audit

| Skill | Mechanic | Verdict | Notes |
|---|---|---|---|
| 1 | 20 Affliction to one enemy | **Buildable** | `{"op":"damage","to":"target","amount":20,"damage_type":"AFFLICTION"}` — `Character.resolve_damage` with the same context `_op_damage` builds |
| 1 | Class-filtered stun (Helpful + Strategic) for 1 turn | **Buildable** | `{"kind":"stun","turns":1,"classes":["Helpful","Strategic"]}`. `turns_to_duration(1) == 2` == the script's literal `Effect.stun_effect(2, …)`; `stun` is in `_is_hostile_effect`, so it takes the same `add_hostile_effect` path. **Full JSON below.** One validator hole found on exactly this shape — see [Rows and fields](#not-systems--rows-fields-and-a-validator-hole) |
| 2 | Immediate 10 Affliction to every enemy | **Buildable** | `target: "all_enemies"` on the ability + `to: "target"` on the block. Deliberately **not** `to: "all_enemies"` — the pool selectors carry the ledger's live AoE-ignores-Invulnerability defect |
| 2 | Affliction DoT, engine duration 5 | **Buildable** | Needs the raw `ticks` hatch: `turns_to_duration` can only make even numbers. `{"kind":"damage_over_time","amount":10,"damage_type":"AFFLICTION","ticks":5}`. The script's 4th argument `use_source_damage=false` is a confirmed dead field, so nothing is lost |
| 2 | `TICKING_TRIGGER` that fires **only on its final tick** | **Blocked** | Blocked twice over. `on_ticking` is not in `TRIGGERS` (the ledger's open row, 53/174) — *and* `last_turn_only`, the field that looks like the gate, is **inert on a trigger**. See [What blocks it §4](#4-payload-addressing-third-sighting--and-a-new-dead-field) |
| 2 | That final tick stuns **the holder** | **Blocked** | `semiramis2.gd:50` applies to `context['effect'].target`. Inside a payload there is no holder selector: `target` and `user` both resolve to Semiramis; `all_enemies` would stun the whole enemy team. **Payload addressing** |
| 2 | End-of-turn trigger that asks *"is this character Invulnerable?"* | **Blocked** | The hook is shipped (`on_turn_end`) and fires on the correct side. The **condition** is not: `CONDITIONS` matches effects by **name**, and invuln is named after whatever skill granted it |
| 2 | Cancel clause — remove the caster's named effect **from the holder** | **Blocked** | Three independent blockers: the addressing (above), the missing condition (above), and a semantic split — `_remove_matching` has **no user filter**, `full_remove_effect_by_name` filters on `user == eff.user`, so an authored `remove` would also strip a mirror-match Semiramis's identically-named Hydra |
| 3 | Permanent stackable per-stack Affliction DoT, applied invuln-**bypassing** | **Buildable** | All four flags (`stackable`, `per_stack`, `display_stacks`, `remove_on_death`) are universal and none is factory-owned by `damage_over_time`, so `_apply_universal_fields` writes all four. `turns: -1` validates; the op-level `bypassing` **is** `add_hostile_effect`'s 5th argument |
| 3 | Spread across all enemies | **Buildable** | As skill 2 |
| 3 | Shatter every Shield on each target | **Buildable** | `{"op":"break","what":"shield","to":"target"}` — `_op_break` calls the identical `t.shatter_shields(user)` |
| 3 | Targeting **through** invulnerability | **Blocked** | `default_hostile_target_function(user, battle, true)` drops the `not_invuln` clause in `Condition.can_hostile_target`. `ScriptedAbility.target()` hardcodes the 2-arg call and `ABILITY_FLAGS` does not expose the parameter — **run 06's already-recorded omission, 33/174**. Partial hatch: the `"Bypassing"` **class** is authorable and buys the ticking half, never the targeting half |
| 3 | Remove **every** Invulnerability on the target, whatever its name | **Blocked** | `remove` requires a non-empty `name` (validator and runner both bail); `cleanse` has no type axis at all. An author cannot name an opponent's invuln effects |
| 3 | Remove **every** heal-over-time on the target, whatever its name | **Blocked** | Same shape. The nearest authorable thing — `{"op":"cleanse","to":"target","scope":"own"}` — is a whole buff-strip with four real losses, so this is **Blocked**, not Approximable |
| 3 | **Count** what was removed | **Blocked** | Nothing in the palette reads a count into a value. `compare`.`alive_count` counts *characters* in a selection; `stacks_at_least` is hardcoded to `EffectType.Type.MARK`; a filtered selector is banned from a condition's `of`/`vs`/`on` slot |
| 3 | Damage of `5 + 5×count` | **Blocked** | `_validate_amount` rejects anything that is not `int`/`float`. There is no expression grammar and no variable namespace in a block tree — by design |
| 3 | Loop: apply `count` further stacks | **Blocked** | Consequence of the count, **not** of a missing repeat op: `stackable` + one `apply` carrying `"stacks": N` reaches the identical end state. See the qualification in [Reach](#reach) — that equivalence holds for stack-applying loops and **fails** for loops that deal N separate damage instances |
| 4 | `default_defend` — self-Invulnerable for 1 turn | **Buildable** | Byte-equivalent. `default_defend` is four lines: `invuln_effect(2)` + `set_source` + `add_allied_effect` on self; `{"kind":"invulnerable","turns":1}` maps to the same factory with the same defaults. **Full JSON below** |
| 4 | Bot hint `behavior_self_panic_button(context, 15, 1.3)` | **Approximable** | `ScriptedAbility.custom_behavior` emits the same helper for a self-target skill with `base_mod 20` and the default `panic_mod 1.0`. **Lost: the tuning only.** Recorded so a future run does not mistake generated bot hints for exact parity |
| 5 | Passive that runs once at battle start | **Buildable** | `startup_passives` executes every ability carrying the Passive class; the validator forces cooldown 0. **Gotcha:** `startup_passives` calls `execute()` **without** `target()`, so the targeter is empty — a passive's blocks must say `to: "user"` |
| 5 | Permanent (`-1`) 25 Shield on return | **Buildable** | `turns: -1` is explicitly in range and `spec_duration` returns `-1`; `_build_effect` calls `Effect.shield_effect(25, -1)`, literally `semiramis5.gd:60` |
| 5 | **Self-banish at the start of the battle** | **Blocked** | Not in `EFFECT_KINDS` — and not fixable with one `_build_effect` arm, because the engine reads the raw `Character.banished` **bool**, not the effect. See [§1](#1-banish-is-a-verb-not-an-effect-kind) |
| 5 | Delayed return payload — an effect that ticks *through* the banish and fires once | **Approximable** | Only meaningful once a banish op exists. `tick_during_banish` and `cleansable:false` are both live universal fields; the shipped last-tick gate is not authorable, but is **not needed** — while the holder is banished every selector resolves empty, so the payload silently no-ops. **Lost: discoverability.** The trick is invisible from the palette |
| 5 | Gain 1 random energy on return | **Approximable** | `_op_gain_energy` resolves **no targets** and never checks `_alive`, so inside a per-turn trigger it fires during the banish too. Guardable with `{"when":{"cond":"hp_above","value":0,"on":"user"}}`, which reads false while banished. **Lost: nothing behavioural**; the author needs a non-obvious idiom for parity with a one-line call |
| 5 | Four-way branch on turn order and team to pick the banish duration | **Blocked** | No condition reads turn order, turn number, acting side or team membership. **Do not propose it** — see [§5](#5-turn-order-awareness--measured-and-deliberately-not-proposed) |
| 5 | Startup-passive **ordering exemption** | **Blocked** | `battle_manager.gd:344-351` (and `:424-430` on the reconnect path) hardcode `path_name == "semiramis"` so her passive runs last. An authored `path_name` is the author's own id and can never match. Not a palette gap — an engine special case, and a concrete hazard for authored self-banish |

**Ten buildable, three approximable, thirteen blocked.** Skills 1 and 4 are authorable exactly.

### The two skills that *are* authorable, in full

```json
{
  "name": "Chains of the First Poisoner",
  "target": "enemy", "cooldown": 1, "cost": {"2": 1},
  "classes": ["Affliction", "Harmful", "Instant", "Damaging"],
  "blocks": [
    {"op": "damage", "to": "target", "amount": 20, "damage_type": "AFFLICTION"},
    {"op": "apply", "to": "target",
     "effect": {"kind": "stun", "turns": 1, "classes": ["Helpful", "Strategic"]}}
  ]
}
```

```json
{
  "name": "Scales of the Sacred Fish",
  "target": "self", "cooldown": 4, "cost": {"4": 1},
  "classes": ["Instant", "Strategic", "Energy"],
  "blocks": [
    {"op": "apply", "to": "user", "effect": {"kind": "invulnerable", "turns": 1}}
  ]
}
```

And what survives of skill 3 — a strictly weaker skill sharing only its first line, with the entire
orange-red clause of `split_desc()` gone:

```json
{
  "name": "Arrogant King's Poison",
  "target": "all_enemies", "cooldown": 3, "cost": {"2": 1, "4": 2},
  "classes": ["Affliction", "Harmful", "Instant", "Damaging", "Bypassing"],
  "blocks": [
    {"op": "apply", "to": "target", "bypassing": true,
     "effect": {"kind": "damage_over_time", "amount": 5, "damage_type": "AFFLICTION",
                "turns": -1, "stackable": true, "per_stack": true,
                "display_stacks": true, "remove_on_death": false}},
    {"op": "break", "what": "shield", "to": "target"},
    {"op": "damage", "to": "target", "amount": 5, "damage_type": "AFFLICTION"}
  ]
}
```

> [!warning] Written and hand-checked against the validator, **not executed**
> This was an analysis-only run: no headless probe, no file under `blocks/`, `abilities/` or the
> client touched. Every JSON above was walked against `block_validator.gd` by hand and every engine
> claim reasoned from the read source. Anything that would change behaviour needs the normal loop in
> [[Verification Playbook]] before it is believed.

---

## What blocks it

### 1. Banish is a **verb**, not an effect kind

`EFFECT_KINDS` has 20 rows and none of them is banish. The tempting read is "one more `_build_effect`
arm" — the process page's own inflation trap in reverse, and it is **wrong here**, because a banish
Effect is *inert*:

- `Effect.banish_effect(dur)` exists (`scripts/effect_component.gd:353`).
- Nothing in the engine reads that effect. `tick_durations`, `check_win_condition` /
  `check_lose_condition`, `end_of_turn_effect_handling`, `generate_team_energy`, every targeting
  helper in `abilities/scripts/ability_component.gd` and `BlockRunner._alive` all read the raw
  **`character.banished` bool**.
- Only `Character.banish_character()` (`scripts/character_component.gd:260-275`) writes that bool.
- `Character.is_banished()` (`:325-332`) — the one function that derives banishment from the effect —
  has **zero callers repo-wide**. Same shape as run 06's dead `Effect.trigger_check`.

So the palette row is an **`OPS` entry funnelling into `banish_character`**, not an `EFFECT_KINDS`
entry. Reach **5/174**.

> [!danger] The safety story comes before the factory: `banish all_enemies` is an instant win
> `check_win_condition` (`new multiplayer/battle_manager.gd:1787-1793`) returns true when every enemy
> is **`dead or banished`**, and `check_match_over` runs after *every executed step* mid-turn, not
> only at turn end. A banish of the shortest non-zero duration therefore ends the match as a Victory
> **before it can expire**. No magnitude or duration cap reaches this — the only bound that works is
> **forbidding pool selectors on the op outright**. The mirror is just as bad:
> `check_lose_condition` (`:1776-1785`) makes a whole-team self-banish an instant Defeat.
>
> **Reasoned, not probed:** `banish_character` sets `banish_target.banished = true` *unconditionally*
> at `:272`, **after** the `add_hostile_effect` at `:271` which can refuse (invulnerability,
> `can_apply_hostile_effect`) and free the effect. Only `shrug_off_type(BANISH)` short-circuits, at
> `:261`. If that reading is right, an invulnerable target is flagged banished until the next
> `tick_durations` clears it — and the mid-turn win check sees the flag first. This is a **live-engine
> question already reachable through `itachi2` and `myotismon3`**, independent of the Creator, and it
> is the first thing to probe if a banish op is ever built.

And there is a second, quieter problem that only bites *authored* content. `battle_manager.gd:344-351`
special-cases `path_name == "semiramis"` to run her passive **last**, because a banished character is
invisible to every selector and any teammate passive running after hers would silently skip her. An
`AuthoredCharacter`'s `path_name` is the author's own id and will never match that string. So the
hand-written banish gets an ordering guard for free that an authored one **cannot have**, and an
authored self-banish-at-start passive would break its own teammates' start-of-battle passives
depending on roster order — non-deterministically, from the author's point of view.

### 2. Nothing can read a number off live state — and semiramis3 needs it three times in one skill

`stack_count` in `semiramis3.gd:29-40` is an ordinary local integer, and it is the hinge of the whole
skill: it selects a damage amount *and* a repetition count. The palette has no place to put it.

- `compare`.`alive_count` counts **characters** in a resolved selection (`group.size()`), never
  effects, and every condition returns a **bool**.
- There is not even a boolean type-presence test to build a ladder out of: `has_effect` matches by
  **name**, and `stacks_at_least` is hardcoded to `EffectType.Type.MARK` (`block_runner.gd:216`) — so
  it cannot even read the stacks of a stacking DoT, which is what this very skill accumulates.
- The one composition that would have counted characters-by-predicate is explicitly banned: a
  **filtered selector may not appear in a condition's `of`/`vs`/`on` slot**
  (`block_validator.gd:493-500`), on purpose, to avoid an infinite regress.
- `_validate_amount` (`block_validator.gd:577-585`) rejects any `amount` that is not `int`/`float`.

This is the run's largest gap, measured at **43/174 (25%)**, and it is the proposed system below.

**Note what it also absorbs.** `break` cannot report what it destroyed — run 06's finding, hit again
here. `_op_break` discards the return value, but wiring it through would be *the wrong fix*:
`shatter_shields` / `shatter_barrier` return the summed **magnitude** broken
(`character_component.gd:1871-1891`), not a count. `blackwargreymon3.gd:22-27` already works around
this by calling `get_shield_effects().size()` **before** each shatter, and `semiramis3` counts in its
own loop. Both want *a readable count of effects of a type*, which is the system's first reading —
so the `break`-report sub-row should be **folded into it**, not built separately.

### 3. No condition asks about status — and `remove` cannot match by type alone

Two different holes, both hit by skill 2 and skill 3, and they are worth keeping apart.

**(a) The status question.** `semiramis2.gd:35` asks `Condition.is_invuln(enemy)`. `CONDITIONS` is
seven entries, and `has_effect` / `not_has_effect` route through `has_any_effect`, which compares
`effect_name()` **only** — and `effect_name()` falls back to the **source ability's name**, so an
invuln granted by an opponent's skill has no stable name to match. Not approximable: no name, no
stack, no HP reading and no `compare` shape answers it.

What the script actually asks is cheaper than it looks — `Condition.is_invuln(x)` with `ability=null`
short-circuits to two type scans (`character_component.gd:1672-1682`): false if any `DEF_NEGATE`,
true if any `INVULN`. **But the coarse form is the minority.** Of the six characters that branch on
invulnerability, three use the ability-agnostic form and three use `is_invuln(self)`, which walks
per-effect `class_targets` / `exclusion_targets` / `cost_color_required`. `abilities/frieza3.gd:53-55`
documents exactly why in a comment. A bare type scan answers three characters correctly and three
**wrongly** — class-filtered invuln, Toji's cost-colour-gated invuln and Bypassing skills all read as
"invulnerable" when they are not.

**(b) Type-alone removal.** `semiramis3.gd:33-40` strips every `INVULN` and every `HEALING` effect
regardless of name. The `remove` op **requires** a non-empty `name` (`block_validator.gd:249-253`,
`block_runner.gd:370-373`); `effect` is only ever a disambiguator. `cleanse` has no type axis at all.

The minimal change is genuinely minimal and needs no engine work: require `name` **or** `effect`
instead of `name`, and let `_remove_matching` skip the name comparison when `eff_name` is empty — ~4
runner lines, ~3 validator lines, one prose arm. Its safety story is the honest part: `remove`
deliberately carries **none** of the cleanse mechanic (no `cleansable` gate, no `IGNORE_CLEANSE`
bailout), and today the name requirement is what keeps that cleanse-proof power aimed at effects the
author can name. Type-alone removal makes it a universal, cleanse-proof strip of any effect family on
any character. The counterweight is that shipped kits already do exactly this — refusing it would be
an invented limit the game does not have — so the bound to borrow is `cleanse`'s existing `count`,
and the abuse case to name is **`remove effect: DAMAGE` erasing every DoT on the board in one block**.

### 4. Payload addressing, third sighting — and a new dead field

`semiramis2` needs two payloads to name **the character holding the effect**, and neither can.
`QueryContext.from_effect_end` sets `owner = effect.user` (the caster) and `target = effect.target`
(the holder); `BlockRunner._build_trigger` names its local `holder` but assigns it
`context.effect.user` — the caster — and `set_explicit_targets([context.owner])` makes the `target`
selector the caster too. So inside an `on_turn_end` payload planted on an enemy, `user == target ==
Semiramis`, and the holder is unreachable by any selector. Same `_build_trigger` binding as the
ledger's probed `on_damage_dealt` defect, degenerating harmlessly here instead of lethally.

**This is an existing ledger entry and gets a Runs served tick, not a re-proposal.**

> [!warning] New dead field, same class as run 06's `trigger_once`: `last_turn_only` is **DAMAGE-only**
> `last_turn_only` is advertised in `UNIVERSAL_EFFECT_FIELDS` (`block_schema.gd:219`) with the
> unqualified comment *"fires once, on its final tick"*. Its only two readers are
> `new multiplayer/battle_manager.gd:831` (inside `get_ticking_effects`' damage loop) and `:1234`,
> which sits **inside** `if effect.effect_type == EffectType.Type.DAMAGE:` at `:1231`. The
> `TICKING_TRIGGER` branch at `:1255-1263` never consults it, and neither does
> `check_end_of_turn_triggers`. An author who ticks it on a trigger gets a trigger that fires **every
> tick**. It only *looks* alive because `block_runner.gd:594-595` sets it itself for a `delayed`
> damage_over_time — the one kind where the engine does read it.
>
> **The corpus already distrusts it.** 8/174 set it; 5 on a DoT (works), **3 on a `TICKING_TRIGGER`
> where it does nothing** — `mavis1:24`, `lyserg5:26`, `yoh6:25` — and **all three hand-guard
> `duration != 1` in the callback anyway** (`mavis1:31`, `lyserg5:40`, `yoh6:30`). `semiramis2` skips
> the flag entirely and writes only the guard.
>
> **Consequence for the ledger:** the `on_ticking` row must ship **with** a one-line guard at
> `battle_manager.gd:1255` mirroring `:1234`, or the palette ships a checkbox that lies and the
> generated prose promises the opposite of what runs. That is a correctness fix in the battle
> manager, not palette work.

### 5. Turn-order awareness — measured, and deliberately **not** proposed

`semiramis5.gd:20-37` is a four-way branch on `battle.waiting_for_turn` and team membership that
collapses to *"3 if my side acts first, else 4"* (the `mod = 1` term is a constant in all four arms).
Nothing in `CONDITIONS` reads the turn number, the acting side, or which team the user is on.

**Do not propose a turn-parity condition.** `waiting_for_turn` reads 10/174; only **6/174** use it to
pick a duration or cooldown, and the fidelity it would buy here is one enemy turn:

> Durations tick at the end of **every** side's turn. Going first, Semiramis's turns are odd — `3` and
> `4` both return her for turn 5, so the branch changes nothing she can act on; it only decides
> whether she is untargetable during enemy turn 4. Going second her turns are even — `3` returns her
> for turn 4 (missing one of her turns), `4` for turn 6 (missing two). A **constant `ticks: 4`**
> satisfies the `split_desc()` contract ("begins the game banished for 2 turns") on **both** sides.

The right framing, though, is not "a missing condition". All six characters are correcting for **one
engine fact** — that "N of *my* turns" is 2N or 2N+1 depending on who acted first — and the palette
hardcodes that choice: `turns_to_duration` is 2N, `swap_turns_to_duration` is 2N+1, and the `ticks`
hatch is another constant. File it under **durations**, at 6/174, and leave it unbuilt.

---

## Proposed system: **Value reading**

The ledger's *"Damage that scales off live state"* row, promoted out of the recurring-mechanics table
with a shape and a first real measurement. **43/174 (25%)** — the biggest open number on the ledger
after `on_ticking`.

**The family, and why it is one.** Two independent axes, and every bucket in the reach taxonomy falls
out of their product:

| Axis | Values |
|---|---|
| **Reading** (what number is taken off live state) | `effect_count` (optionally keyed by type) · `effect_mag_sum` (keyed by type) · `stacks` (of a named effect) · `alive_count` · `hp` / `hp_percent` |
| **Consumer** (where the number goes) | a **`compare`.`value`** (the bool half — already shipped machinery) · an **amount form** `{"base": N, "per": <reading>, "each": M}` on any op that takes an `amount` |

Each reading is resolved against an ordinary selector, so nothing parallel is invented: the subject of
a reading is whatever `on`/`of` already means.

```json
{"op": "damage", "to": "target", "damage_type": "AFFLICTION",
 "amount": {"base": 5, "per": {"read": "effect_count", "effect": "SHIELD", "on": "target"}, "each": 5}}
```

```json
{"op": "apply", "to": "target",
 "effect": {"kind": "damage_over_time", "amount": 5, "turns": -1, "stackable": true,
            "stacks": {"read": "effect_count", "effect": "INVULN", "on": "target"}}}
```

```json
{"op": "apply", "to": "target", "when": {"cond": "compare", "value": "effect_count",
   "effect": "SHIELD", "of": "target", "op": "eq", "than": 0},
 "effect": {"kind": "stun", "turns": 1}}
```

The third is **boruto7** — *"stun only if nothing was shattered"* — which run 06 filed under
"`break` cannot report what it destroyed". It does not need `break` to return anything; it needs the
count to be readable **before** the break, which is exactly run 06's own invisible-mark latch idiom
generalised from a bool to a number.

**Against the seven-point bar.**

| # | Bar | This system |
|---|---|---|
| 1 | Family, not an effect | **Passes.** 5 readings × 2 consumers, and the two axes are genuinely independent — the bool half reuses `compare` unchanged, the scaling half is a new `amount` shape |
| 2 | Measured reach | **43/174 (25%)** hand-verified, four buckets, false-positive accounting in [Reach](#reach). Absorbs the `break`-report sub-row (4/174) and the type-presence predicate (7/174) |
| 3 | Composes | **Passes.** A reading's subject is an ordinary selector; the amount form is accepted wherever `_amount` already runs; nothing needs a new resolution path |
| 4 | Safety story | The `amount` form is clamped by the **existing** `LIMITS.max_amount` after resolution (the clamp moves from validate-time to resolve-time, which is where a computed number has to be checked anyway); `each` is bounded by `max_amount`; a reading used as `stacks` is clamped by `max_stacks`; a reading used as a repeat count is **not offered at all** — the loop is unnecessary (see below). **Abuse case:** `{"base":0,"per":{"read":"effect_count","on":"any_character"},"each":9999}` — resolve-time clamping is what stops it, not a validate-time literal check |
| 5 | Generates prose | **Passes, one clause:** *"deals 5 damage, plus 5 for each Shield the target has"*. That is how the shipped roster already describes it (`semiramis3`, `blackwargreymon3`, `madoka1`) |
| 6 | Bot story | `bot_damage_hint()` must resolve the reading at hint time or the bot systematically undervalues every scaling skill. This is the system's **one real cost beyond the palette** and the reason it is not a trivial row |
| 7 | Engine cost | `block_schema.gd`: a `READINGS` table + `COMPARE_VALUES` extension. `block_validator.gd`: an `_validate_amount` branch accepting the object form; the reading's `effect` reuses `immunity_effects()`. `block_runner.gd`: one `_read_value` resolver, `_amount` learns the object form, `_char_value` gains the new members. Editor: one "scaled amount" control. **No engine primitive missing** — `get_effects_by_type`, `stack_count()` and `.mag` are all shipped |

**What it does *not* need: a repeat-N op.** `effect_storage_component.gd:31-44` merges a
re-application into a stored stackable effect with `eff_match.stacks += effect.stack_count()`, so
**one** `apply` carrying a computed `stacks` reaches the identical end state as N applications. That
holds for the 8/174 whose loops apply a stack. It **fails** for the 7/174 whose loops deal N separate
`resolve_damage` instances — but collapsing those into one bigger hit is the process page's own
run-06 layered-damage trap, so the honest answer for that half is "still blocked, and correctly so
until a repeat op is designed on its own merits". Either way N is unwritable today, so the whole
18/174 rides on this system.

---

## Not systems — rows, fields and a validator hole

Each finding named plainly and priced, because inflating a missing enum row into a framework is the
same failure as proposing something character-shaped.

| Finding | **What it is** | Price | Reach |
|---|---|---|---|
| **Banish** | **an `OPS` row** — *not* an `EFFECT_KINDS` row | One `OPS` entry, one `_op_banish` calling `banish_character`, one **mandatory** validator rule forbidding pool selectors, one prose clause, one editor field. **Engine:** no new primitive, but the win-condition interaction and the `path_name == "semiramis"` ordering hack are real design work first | **5/174 (2.9%)** |
| **`remove` by type alone** | **a missing 4th axis** on the shipped *Filtered effect removal* row (scope × name × count → **+ type**) | ~3 validator lines (require `name` **or** `effect`), ~4 runner lines (skip the name compare when empty), one `_describe_remove` arm. No engine work | **8/174** — of the 14 who loop-and-remove by type, **6 still want a finer axis** the palette has nowhere (name, source object, or `damage_type` *inside* `DAMAGE`) |
| **Derived-status conditions** (`is_invulnerable`, `is_stunned`, `is_silenced`, `defence_broken`) | **`CONDITIONS` rows** on the shipped vocabulary | One `CONDITIONS` entry + one `_check_condition` arm + one prose arm each. **Must call the engine's own predicate** — `BlockRunner` already holds `ability`, so `Condition.is_invuln(candidate, runner.ability)` gives the fine form for free | invuln branches **6/174**; the whole named-status family **~14/174** |
| **`last_turn_only` on a trigger** | **a documentation fix + a one-line guard** | Correct the comment at `block_schema.gd:219`; add the `duration != 1` guard at `battle_manager.gd:1255`. **Gated to ship with `on_ticking`** | 3/174 shipped abilities already set it where it is inert |
| **`tick_during_banish`** | **a live schema row with one user and no verb** | Delete it or document it as inert, exactly like `trigger_once` — the palette exposes banish's *accessory* while withholding banish | **1/174** (`semiramis5`) |
| **`stun`.`classes` unvalidated** | **a one-line validator hole**, found on this run's own Buildable | `block_validator.gd:324-325` validates `exclude_classes` and never `classes`. A typo'd `["Helpfull"]` passes, reaches `stun_effect`'s `ability_targets`, and `character_component.gd:1663-1664` then indexes a missing Dictionary key — a per-check GDScript runtime error, log-and-continue. Fix: append `_validate_classes(spec.get("classes", []))` to the same match arm | the class-filtered stun itself: **19/174** |

### Adjudicating the brief's two candidates

**Banish: a row, and a low-priority one.** 5/174, two shapes (self-banish-and-return with a payload;
hostile removal). It fails point 2 of the bar as a system and passes comfortably as a row — but
unlike every other row this run found, it is **not** free: the win-condition interaction is a design
problem that has to be solved before the factory is wired, and the ordering hack means a self-banish
passive is hazardous for authored content in a way it is not for Semiramis. Build it when the palette
is next opened, with the pool-selector ban written first.

**State conditions: not one system — it splits, and the split is not the one run 06 implied.**

Run 06 found "the same shape from a different angle" in `boruto7`. Re-read, `boruto7.gd:19-24` does
**not** test for a type: it reads `shattered += target.shatter_shields(user)` and branches on
`shattered == 0`. That is a *number*, not a *status*. Following that through:

- The **counting** half — "does this character hold any effect of type X", "how many", "how much
  magnitude" — is **the value-reading system**. `has_effect_type` is just `effect_count >= 1`, and
  `boruto7`'s question is `effect_count == 0`. Building a separate type-presence condition would ship
  a bool that the system then has to duplicate as a number three months later.
- The **derived-status** half — "is Invulnerable", "is Stunned" — cannot be a count, because the
  engine's own answer walks class filters, exclusion lists and cost colours. It is a handful of
  `CONDITIONS` rows calling the shipped predicates.

So the answer to the brief is: **they are the same *question shape* and two different *builds*, and
neither one is a new system.** Saying "one system" would have merged a condition-vocabulary row with a
value-returning problem, and the value-returning problem is the thing that actually has reach.

> [!warning] The cheap fix is the one that will be over-claimed
> A bare `INVULN` type-scan predicate is ~6 lines and looks like it closes the invulnerability
> question. It answers **3/174 correctly and 3/174 wrongly**. If a future run writes "approximable"
> for an invulnerability branch on the strength of a type scan, it must name the loss: class-filtered
> invuln, Toji's cost-colour-gated invuln, and Bypassing skills all read as "invulnerable" when they
> are not.
>
> And **reach is not the only bar**: an author cannot *apply* isolate, banish, blind, barrier,
> channel-cancel or control-cancel, so a condition reading those states only ever reads an
> **opponent's** — and only against the handful of shipped characters that grant it. That knocks real
> value off both the status rows and the type-alone-removal row even though the counts are honest.

---

## Reach

Roster frame verified at 174 (`char_name_list()`), every count intersected with it.

```bash
python -c "import io,re; s=io.open('scripts/character_database.gd',encoding='utf-8').read(); \
  i=s.index('static func char_name_list()'); \
  print('\n'.join(sorted(re.findall(r'\"([a-z0-9_]+)\"', s[i:s.index(']',i)]))))" > chars.txt   # 174
cd abilities && grep -lE '<PATTERN>' *.gd | sed 's#\.gd$##; s#[0-9]*$##' | sort -u \
  | comm -12 - ../chars.txt | wc -l
```

| Gap | Characters | Pattern | Note |
|---|---|---|---|
| **Value reading** (magnitude / count off live state) | **43 (25%)** | hand-built, see below | Four buckets. **No single regex reproduces it** |
| — bucket (c): stack / mark-mag read | **23** | `.stacks` / `.mag` / `stack_count()` in a magnitude | The sharpest case: the palette **stores** the number and **tests** it and cannot **read** it |
| — bucket (a): count of effects | **7** | `<var> += 1` in a `get_effects_by_type` loop | `semiramis3`, `inosuke3`, `madoka1`, `hashirama5`, `tamaki1`/`5`, `blackwargreymon3`, `yamamoto5` |
| — bucket (b): sum of effect magnitudes | **7** | `+= eff.mag` | `ace1`/`3`, `rob2`, `power3`/`4`, `tatsumaki2`, `arthur1`, `mash1`, `kaiba5` |
| — bucket (d): count of characters by predicate | **6** | `len(<filtered list>)` | `saitama7`, `tanjiro5`, `nezuko2`, `ichibe2`, `ichigo1`, `byakuya7` |
| repeat-N loops (rides on the above) | **18** | `for i in <var>` | 8 apply a stack (collapsible via `stacks`), **7 deal N separate instances** (not collapsible — layered-damage trap), 2 grant energy, 1 bumps cooldowns |
| **`remove` by type alone** | **8** | `full_remove_effect_by_type\(` **+** the hand-rolled loop | 4 use the direct engine API (`adam3`, `ichibe5`, `kurotsuchi4`, `rengoku4`), 3 the bare loop (`inosuke3`, `semiramis3`, `yugi5`), 1 type+own-user (`misaka5`/`6`) |
| **Banish** | **5 (2.9%)** | `banish_character\(` | `ban`, `itachi`, `kurotsuchi`, `myotismon`, `semiramis`. `Effect.banish_effect(` = **0/174** in `abilities/` |
| **Derived-status conditions** | **6** invuln branches · **~14** whole family | `is_invuln`, `is_stunned`, `is_silenced`, `def_broken`, `has_stuns`, `blind_check` | Split 3 coarse / 3 fine on invuln |
| **Turn-order awareness** | **6** | `waiting_for_turn` (duration/cooldown uses only) | `semiramis5`, `ban6`, `kurotsuchi4`, `machinedramon5`, `soul5`, `tsubaki5`. `current_turn_number` 3/174; `went_second` **0/174** |
| **`last_turn_only`** | **8** set it · **3** where it is inert | `last_turn_only\s*=\s*true` | Inert users: `lyserg5`, `mavis1`, `yoh6` — all three hand-guard it anyway |
| **`tick_during_banish`** | **1** | `tick_during_banish` | `semiramis5` only |
| `break` return-value readers | **2** | consumption of `shatter_*`'s return | `boruto7`, `squalo2` (mission bookkeeping). **Run 06's number confirmed.** 4/174 need the *information*, out of 9/174 who shatter at all |
| invuln-**bypass targeting** (run 06's row) | **33** | `default_hostile_target_function\([^)]*, true` | **Reproduced exactly** — the run's best stability check on the method |

> [!warning] Three numbers moved, and two of them moved **against this run's own first pass**
> The measurement pass was run adversarially against the audit and corrected it three times. The
> discipline the process page asks for is recording that, not tidying it away.
>
> | Number | Audit said | Measured | Why |
> |---|---|---|---|
> | Value reading | 22/174 | **43/174** | The audit grepped the `<var> += 1` counter idiom. **Most kits never write a counter** — they read `.stacks`/`.mag` inline (`base_damage + 5 * eff.stacks`). Bucket (c) alone is 23 |
> | `remove` by type | 4/174 | **8/174** | The audit measured only the hand-rolled loop and **missed `full_remove_effect_by_type()`**, a direct engine API with 4 more roster users |
> | Turn-order | 3/174 | **6/174** | The audit said all three uses are banish-duration corrections. **Three of the six have no banish in them** (`machinedramon5` sizes a ticking trigger; `soul5`/`tsubaki5` pick a cooldown). The verdict survives; the reasoning did not |
>
> **False-positive accounting.** The bare structural sweep for a non-literal magnitude reads
> **98/174** — 56% character-level FP, because `mod_damage` is usually a static two-way branch on a
> mark, which `group` + `has_effect` already expresses. `orihime3` was counted and then **dropped**
> on inspection (`shield.mag` where the mag was a literal 25 — a latch read, not live-state scaling):
> 44 → 43. Never quote a `banish` word-grep either: the string appears in 87/174 characters, a **94%
> FP rate**, because almost all of them are `not (character.dead or character.banished)` filters.

> [!danger] A new measurement-hygiene failure mode: **attribute by enclosing function**
> `custom_behavior` is the **bot-scoring** hook, and an authored character gets its bot behaviour
> *generated* from its blocks — so a predicate appearing only there is not evidence of a palette gap
> at all. `is_isolated` reads **13/174** raw and **1/174** as a gameplay branch (**92% FP**): eight of
> the thirteen are `custom_behavior` bot hints, one is a comment, three are alive-filters. `is_invuln`
> reads 40/174 raw and 6/174 as a branch, the bulk being target-eligibility filters hand-re-implementing
> the invuln drop. The shell form is
> `awk '/^func /{f=$2} /PATTERN/{print FILENAME, f}'`. Every state-predicate grep in this family also
> carries a **comment** false positive — the run-07 `stack_mag` trap, firing three more times
> (`frieza3:53`, `astolfo4:4`, `yoruichi5:16`, `yubel6:26`).

> [!info] Two numbers measured with a different pattern and deliberately **not** written into the ledger
> A broad hand-removal grep reads 112/174 against the ledger's 71/174 for *Filtered effect removal*,
> and `Effect.counter_effect(` reads 31/174 against the ledger's 40/174 for *Counters*. Both
> differences are **pattern width**, not drift. Overwriting a ledger number with a number from a
> different grep is the exact error runs 02 and 03 were discarded for. Likewise `TICKING_TRIGGER`
> reads 54/174 here against the ledger's 53 — flagged, not corrected.

---

## Verdict for the roadmap

1. **The `on_ticking` row must not ship alone, and now there are *two* reasons.** Run 06's:
   `TICKING` dispatch goes through `QueryContext.from_effect_end`, so a payload's `target` resolves to
   the caster. Run 08's: `last_turn_only` is **inert on a trigger**, so the editor's most natural
   "fires once, at the end" checkbox would silently do nothing while the generated prose promised it.
   Both are part of **Payload addressing**, still the ledger's top open system.
2. **Value reading → the ledger's second open system**, [[Creator Roadmap]]'s palette phase.
   **43/174**, no missing engine primitive, and it absorbs three things previously tracked separately:
   the `break`-report sub-row, the type-presence predicate, and the repeat-N half of `semiramis3`.
   Its one non-trivial cost is the **bot hint**, which must resolve a reading or bots undervalue every
   scaling skill.
3. **`remove` by type → an axis on the shipped *Filtered effect removal* row.** 8/174, ~7 lines, no
   engine work. Ship it with the `count` bound borrowed from `cleanse`.
4. **Derived-status conditions → `CONDITIONS` rows**, ~14/174 as a family, and **only** in the form
   that calls the engine's predicate. Behind the system above.
5. **Banish → an `OPS` row, low priority, safety rule first.** 5/174. Do not build it as an
   `EFFECT_KINDS` arm; do not build it at all until the pool-selector ban and the
   `banish_character` refusal question are settled.
6. **Do not build:** turn-order conditions (6/174, and a constant reproduces the contract),
   `tick_during_banish` as it stands (1/174, no verb to modify), a repeat-N op (the 8 collapsible
   cases already work; the 7 non-collapsible ones need their own design).
7. **Free correctness fixes:** the `stun`.`classes` validator hole (one line), the `last_turn_only`
   comment (one line), and the `battle_manager.gd:1255` guard (one line, gated to `on_ticking`).

> [!info] What run 08 says about the through-line
> Run 06's through-line — *the palette can hold state and cannot reliably point at anybody* — is
> confirmed a third time by `semiramis2` and **is now incomplete**. Semiramis's hardest skill is not
> blocked on *who*: `semiramis3` names its targets perfectly well. It is blocked on **how many** —
> strip, count, scale — and that question is now the largest measured gap in the corpus at 43/174,
> larger than any addressing number.
>
> "What" is still not the gap, and Semiramis is unusually good evidence for that: **every effect in
> her kit is a shipped effect kind except banish, and banish's factory has existed all along.** Eight
> runs in, the Creator's shortfall is *surfacing*, not *capability* — and the two open questions are
> **"who"** (Payload addressing) and **"how many"** (Value reading).
>
> The other thing this run says: `semiramis3` is unbuildable not because any single row is missing but
> because it **chains three of them** — strip by type, count the result, scale off the count. A
> palette that ships the removal axis without the counting system still leaves that skill Blocked.

---

Related: [[Creator Roulette]] · [[Roulette 01 - Naruto Uzumaki]] · [[Roulette 02 - Death the Kid]] ·
[[Roulette 03 - Sailor Mercury]] · [[Roulette 04 - Superbi Squalo]] · [[Roulette 05 - Shiro]] ·
[[Roulette 06 - Boruto Uzumaki]] · [[Roulette 07 - Levi Ackerman]] · [[Block Palette Reference]] ·
[[Creator Roadmap]] · [[What Cannot Be Built Yet]] · [[Trigger Types]] · [[Effects and Durations]] ·
[[Cleanse Silence and Effect Removal]] · [[Targeting and Main Target]] · [[Damage Pipeline]] ·
[[Bots and Training]] · [[Verification Playbook]] · [[Hard Rules and Guardrails]]
