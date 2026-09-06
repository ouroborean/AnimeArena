---
tags: [area/systems, type/reference]
---

# Block Palette Reference

The complete lookup for what an authored ability may contain. Source of truth:
`blocks/block_schema.gd` (the palette), `blocks/block_validator.gd` (the rules),
`blocks/block_runner.gd` (what actually happens). If this note and those files disagree, **the
files are right** — and this note is stale.

Context: [[The Creator]]. Gaps: [[What Cannot Be Built Yet]]. Plan: [[Creator Roadmap]].

---

## The shape of everything

A **character spec** is one JSON file under `authored/`:

```json
{
  "id": "auth_alice_1753900000",
  "name": "Ash Warden",
  "author": "alice",
  "status": "testing",
  "description": "A slow burner who trades safety for lingering damage.",
  "colors": [3, 0],
  "abilities": [ { /* ability */ }, ... ]
}
```

An **ability** is:

```json
{
  "name": "Cinder Lash",
  "target": "enemy",
  "cooldown": 1,
  "cost": {"3": 1},
  "classes": ["Physical", "Harmful", "Instant", "Damaging"],
  "requires": [ /* 0-4 conditions */ ],
  "text": "optional author flavour line",
  "icon": "ability1",
  "blocks": [ /* 1..40 blocks */ ]
}
```

A **block** is `{"op": <name>, ...the op's fields, "when": <condition>}`. `op` and `when` are legal
on every block; **any other key is a hard rejection**.

---

## 1. Ops — all eight

| op | fields | runtime default | primitive called |
|---|---|---|---|
| `damage` | `amount`, `damage_type`, `to`, `bypassing` | amount 0, type `NORMAL`, to `target` | `Character.resolve_damage(ctx, t, amount, dtype)` |
| `heal` | `amount`, `to` | amount 0, to `target` | `Character.resolve_healing(ctx, t, amount)` |
| `apply` | `effect`, `to`, `bypassing` | to `target` | `Character.add_hostile_effect` / `add_allied_effect` |
| `gain_energy` | `amount`, `colour` | 1, colour rolled | `user.gain_random_energy()` × n |
| `cleanse` | `to`, `name`, `scope`, `count`, `bypassing` | **to `user`**, scope `hostile` | `t.effects.cleanse_all_enemy_effects(t, user)` |
| `remove` | `name`, `effect`, `stacks`, `to`, `bypassing` | to `target`, stacks `all` | `remove_effect` / `consume_stack` |
| `break` | `what`, `to`, `bypassing` | what `shield`, to `target` | `t.shatter_shields` / `t.shatter_barrier` |
| `group` | `blocks` | — | none (a `when`-guarded bundle) |

> [!info] `bypassing` — one word, two layers
> On `damage` / `cleanse` / `remove` / `break` it is the opt-out from the **pool re-validation**
> those four ops run (`BlockRunner._legal_pool`): with it, a selector-built pool keeps candidates
> the targeting system would have refused — an invulnerable enemy, an isolated ally. On `apply` it
> is the third parameter of `Character.add_*_effect`: land this effect **through** the target's
> invulnerability. On the four pool ops the ability's **`Bypassing` class is the default** and this
> field overrides it in either direction; `apply` has no such default and reads only the field.
> None of the three is the effect's own universal `bypassing` (§ 2a), which means "keeps **ticking**
> through invulnerability", and none of them is `DamageType.Type.PIERCING`, which ignores damage
> **reduction**.

```json
{"op": "damage", "amount": 30, "damage_type": "PIERCING", "to": "target"}
{"op": "heal", "amount": 20, "to": "user"}
{"op": "gain_energy", "amount": 2}
{"op": "cleanse", "to": "user"}
{"op": "group", "when": {"cond": "hp_below", "value": 40}, "blocks": [ ... ]}
```

> [!warning] Trap — `cleanse` defaults to `user`, every other op defaults to `target`
> `block_runner.gd:198`. Writing `{"op":"cleanse"}` inside an enemy-targeted skill cleanses
> **yourself**, and the generated description will say so — read the preview.

Notes that bite:

- `damage` **short-circuits before resolving targets** when `amount <= 0` (`:173`). A 0-damage
  block is a no-op, not a 0-damage hit.
- `heal` stashes and faux-restores `user.used_ability` because `resolve_healing` reads it (`:184`).
  `damage` does **not** — see the Passive/reactive trap in [[The Creator]].
- `gain_energy` has **no `to`**. It always acts on the user; a `to` key is rejected as unexpected.
- `apply` builds a **fresh Effect per target** and aborts the whole loop if construction returns
  null (`:211`).

---

## 2. Effect kinds — all thirteen

Shape: `{"kind": <name>, ...the kind's factory fields, ...universal fields}`. The `fields` column
below is the **factory-specific** set — the arguments that drive the `Effect.*` call. On top of
them, `kind`, `damage_type`, `ticks` and the whole **universal field set** (§ 2a) are permitted on
**every** kind, so `damage_type` on a `shield` is accepted and silently ignored (only
`damage_over_time` reads it).

| kind | authored fields | `Effect` factory | hostile? |
|---|---|---|---|
| `mark` | `turns`, `text` | `Effect.mark(dur, text)` | no |
| `damage_over_time` | `amount`, `damage_type`, `turns`, `delayed` | `Effect.damage_effect(amount, type_id, dur)` | **yes** |
| `heal_over_time` | `amount`, `turns` | `Effect.healing_effect(amount, dur)` | no |
| `shield` | `amount`, `turns` | `Effect.shield_effect(amount, dur)` | no |
| `stun` | `turns`, `classes` | `Effect.stun_effect(dur, classes)` | **yes** |
| `invulnerable` | `turns`, `classes` | `Effect.invuln_effect(dur, classes)` | no |
| `ignore_damage` | `turns` | `Effect.ignore_damage_effect(dur)` | no |
| `damage_reduction` | `amount`, `turns` | `Effect.damage_reduction_effect(amount, dur)` | no |
| `vulnerability` | `amount`, `turns` | `Effect.vulnerability_effect(amount, dur)` | **yes** |
| `damage_boost` | `amount`, `turns` | `Effect.damage_mod_effect(amount, dur)` | no |
| `silence` | `turns` | `Effect.silence_effect(dur)` | **yes** |
| `destructible_break` | `turns` | `Effect.def_negate(dur)` | **yes** |
| `trigger` | `trigger`, `turns`, `text`, `then` | `Effect.trigger_effect(Trigger.always(payload), trig, dur, text)` | no |

> [!warning] Trap — the hostile set is exactly five kinds, hard-coded
> `_is_hostile_effect` (`block_runner.gd:223`) returns true only for
> `damage_over_time, stun, silence, vulnerability, destructible_break`.
> **Everything else — including `mark` — goes down `add_allied_effect` even when applied to an
> enemy.** That means an enemy-targeted `mark` does not respect shrug-off / `IGNORE_SKILL` gating
> the way a hostile application does.

`delayed` on a `damage_over_time` sets `last_turn_only = true` and uses the odd duration form: a
**single tick** N turns from now instead of a per-turn drip.

---

## 3. Duration — the conversion that catches everyone

`BlockSchema.turns_to_duration(turns, delayed)` (`block_schema.gd:129`):

```gdscript
if turns < 0:  return -1                   # permanent
if delayed:    return 2 * max(turns, 1) + 1
return 2 * max(turns, 1)
```

| Author writes | Engine duration | Meaning |
|---|---|---|
| `"turns": 1` | `2` | one of the holder's turns |
| `"turns": 3` | `6` | three turns |
| `"turns": -1` | `-1` | permanent, never expires |
| `"turns": 3, "delayed": true` | `7` | one hit, three turns from now |

Authors type **player turns**; the engine ticks every side's turn. This is the same arithmetic
described in [[Effects and Durations]] — the Creator does the conversion **for** you, so a spec
that says `"turns": 2` really is two turns. Do not pre-double.

---

## 4. Selectors

Resolved by `BlockRunner._resolve_targets` (`:72`). Every branch filters through `_alive()` =
not null, `is_instance_valid`, not `dead`, not `banished`.

| selector | resolves to |
|---|---|
| `target` | the skill's targets (`user.targeter.targets`) |
| `user` | the caster |
| `all_enemies` | every living enemy |
| `all_allies` | every living ally — **includes the user** |
| `other_allies` | team minus the user |
| `random_enemy` | one random living enemy, via seeded `battle.roll` |
| `random_ally` | one random living ally, via seeded `battle.roll` |

### Condition-filtered selectors

Legal as a block's `to` and **nowhere else** (a condition's own `on`/`of`/`vs` would need a
condition of its own to resolve). Each resolves to **every living member of the pool the
accompanying condition holds for**, evaluated **once per candidate** with that candidate as the
condition's subject. The `when` is **mandatory** — the only selector slot where it is.

| selector | resolves to |
|---|---|
| `any_enemy` | every living enemy the condition holds for |
| `any_ally` | every living ally (including the user) the condition holds for |
| `any_character` | every living character on either team the condition holds for |

```json
{"op": "damage", "amount": 10, "to": "any_enemy",
 "when": {"cond": "hp_below", "value": 50}}
```

The block-level `when` is normally a **gate** (asked once, all-or-nothing). Under one of these it
is a **filter** instead, and the runner does not also apply it as a gate. An explicit `on` inside
the condition still names a fixed selector — the same answer for every candidate, which is how
"hit each enemy, but only while the user is hurt" is phrased. `chance` rolls **per candidate**.

> [!info] `target` means something different inside a trigger payload
> In a trigger payload the original targeter is stale, so `target` is rebound to **whoever tripped
> the trigger** (`set_explicit_targets`).

Both random selectors go through `battle.roll`, which is the seeded generator — replays and the
differential fixture stay bit-reproducible.

---

## 5. Conditions — all six

Shape `{"cond": <key>, ...args}`. `on` defaults to `"user"`.

| cond | args | evaluates |
|---|---|---|
| `has_effect` | `name`, `on` | `t.has_any_effect(name)` |
| `not_has_effect` | `name`, `on` | true only if **no** listed character has it |
| `hp_below` | `value`, `on` | `t.health.hp < value` |
| `hp_above` | `value`, `on` | `t.health.hp > value` |
| `stacks_at_least` | `name`, `value`, `on` | MARK-typed effect's `stack_count() >= value` |
| `chance` | `percent` (1–100) | seeded `battle.roll(1,100) <= percent` |

> [!warning] Trap — `name` is the **ability name**, not the effect's `text`
> `Effect.effect_name()` returns `source.ability_name`. An effect applied by a skill called
> "Cinder Lash" is named `Cinder Lash` regardless of what its `text` field says. This is also why
> an author can only ever refer to **their own** marks.

> [!warning] Trap — conditions are ANY-of over the resolved set
> `_check_condition` resolves `on` to a **list** and returns true if *any* member matches (except
> `not_has_effect`, which is universal). So
> `{"op":"damage","to":"all_enemies","when":{"cond":"hp_below","value":40,"on":"all_enemies"}}`
> damages **every** enemy as soon as **one** is under 40. For per-target evaluation use the
> condition-filtered selectors (§ 4) — `to: "any_enemy"` asks the question once per candidate.

> [!info] Stacking is EMERGENT — there is no `stack` op
> `add_effect` merges a re-application into the stored effect whenever that effect's `stackable`
> is true and the two share a name, a type and a user. `stackable` is a **universal** effect field
> (§ 2a), so any kind can be a stacking resource; `mark` forces it on. Casting the skill again is
> what banks a stack, and `stacks_at_least` reads the result. Note that there is currently **no
> block that SPENDS a stack** — the old `stack` op's negative delta was the only one.

The **same vocabulary** gates usability: `requires` is an ALL-of list (max 4) checked in
`ScriptedAbility.extra_usable` via `check_condition_public`.

---

## 6. Triggers — the nested payload

> [!info] Renamed
> This effect kind was called `reactive`. Saved characters on disk still say so and still load:
> `BlockSchema.KIND_ALIASES` maps the old name to the new one on **read**. Nothing writes it.

| trigger | EffectType |
|---|---|
| `on_harmful_received` | `HARMFUL_RECEIVE_TRIGGER` |
| `on_damage_received` | `DAMAGE_RECEIVE_TRIGGER` |
| `on_damage_dealt` | `DAMAGE_DEALT_TRIGGER` |
| `on_turn_start` | `START_OF_TURN_TRIGGER` |
| `on_turn_end` | `END_OF_TURN_TRIGGER` |
| `on_death` | `ON_DEATH_TRIGGER` |

```json
{"op": "apply", "to": "user", "effect": {
  "kind": "trigger",
  "trigger": "on_harmful_received",
  "turns": 2,
  "text": "Retaliates against attackers.",
  "then": [ {"op": "damage", "amount": 12, "to": "target"} ]
}}
```

When the hook fires, `_build_trigger`'s payload:

1. reads `context.get("effect").user` as the **holder**; bails if invalid;
2. constructs a **fresh** `BlockRunner(owner_ability, holder.battle, holder)` — the acting user is
   the holder, so hostility and team selectors resolve from the holder's side;
3. `set_explicit_targets([context.get("owner")])` — the tripping character becomes `target`;
4. runs `then`.

`then` is an ordinary block list, so it may itself contain `apply`/`trigger`. It is bounded only
by the validator (nesting is charged double, see below). This is proven by
`training/tests/block_dsl_probe.gd` (PARITY 3): the trigger installs on the user and the payload
hits the attacker for 12.

> [!warning] Trap — trigger payloads carry the ORIGINAL caster as `effect.user`
> `_build_trigger` closes over `owner_ability`, so anything the payload applies is sourced to the
> ability, and hence to the original caster — even when the trigger sits on an ally.

> [!warning] Trap — a `damage` block in a payload can silently do nothing
> `resolve_damage` bails when the holder's `used_ability` is null. If the holder has not acted yet
> this match, the payload's damage is dropped. See [[The Creator]] → live correctness bugs.

---

## 7. Damage types

`NORMAL` · `PIERCING` · `AFFLICTION` · `BLEED` · `TRUE` · `PHYSICAL` · `ENERGY`.
Unknown → `NORMAL` at runtime, but rejected at validation. See [[Damage Pipeline]].

---

## 8. Every limit

### `BlockSchema.LIMITS`

| limit | value |
|---|---|
| `max_blocks_per_ability` | **40** |
| `max_nesting_depth` | **4** |
| `max_amount` | **500** |
| `max_turns` | **20** |
| `max_trigger_then_blocks` | **12** |

### Ability level (`validate_ability`)

| field | rule |
|---|---|
| `name` | required, non-empty after strip, ≤ 48 chars |
| `target` | `enemy` \| `ally` \| `self` \| `all_enemies` \| `all_allies` (default `enemy`) |
| `cooldown` | 0–10 |
| `cost` | object; each key parses 0–4 (4 = Random); each value 0–4; **sum ≤ 5** |
| `classes` | whitelist of 17 (below) |
| `requires` | Array, **≤ 4** conditions |
| `blocks` | Array, **non-empty**, counted total ≤ 40 |
| Passive | cooldown **must** be 0, **no** energy cost at all, `requires` **must** be empty |

`_count_blocks` counts each block **plus** the contents of `blocks` (groups) **plus** the contents
of `effect.then` (triggers), recursively — so a trigger's payload eats the same 40 budget.

### Depth accounting

Top-level blocks enter at depth 0. `group` children get `depth + 1`. **A `then` child gets
`depth + 2`** — "nesting is charged double here" — because trigger-in-trigger is the one shape
that could recurse without bound at runtime.

| shape | levels available |
|---|---|
| nested `group` | 5 (depths 0,1,2,3,4) |
| nested `trigger` | 3 (depths 0, 2, 4) |

### Effect level

| field | rule |
|---|---|
| `kind` | must be one of the 13 |
| any other key | must be a factory field of that kind, or `kind`/`damage_type`/`ticks`, or a universal field (§ 2a) |
| `turns` | **−1 (permanent) or 0–20** |
| `amount` | 0–500 |
| `damage_type` | whitelisted |
| `trigger`.`trigger` | must be known |
| `trigger`.`then` | non-empty Array, ≤ 12 blocks |

### The 17 classes

`Physical` · `Energy` · `Mental` · `Affliction` · `Strategic` · `Harmful` · `Helpful` · `Instant` ·
`Action` · `Control` · `Channeled` · `Uncounterable` · `Bypassing` · `Stealthed` · `Passive` ·
`Preserves Channel` · `Damaging`

> [!warning] Three of these currently lie
> `Bypassing` is **wired**: `ScriptedAbility.target` passes it as the targeting helpers' third
> argument, so a skill marked Bypassing can select an invulnerable enemy the way a shipped one
> does, and it is the **default** for every re-validated block's pool check (`damage`, `break`,
> `cleanse`, `remove`) — overridable per block with that block's own `bypassing` field, in both
> directions. It is also still what `_skill_pierces_invuln` reads when a multi-target skill is
> reflected back at its user.
> `Control`, `Channeled` and `Preserves Channel` have no engine effect for authored content — the
> cancel behaviour lives in `CONTROL_CANCEL` / `CHANNEL_CANCEL` effects the palette cannot build.
> The editor's chip row offers only 12 of the 17 anyway.

### Character level (`AuthoredRegistry.validate_character`)

| field | rule |
|---|---|
| `id` | begins `auth_`, length 8–40, charset `[A-Za-z0-9_]` |
| `name` | 1–32 chars after strip |
| `author` | required, non-empty (server always overwrites it) |
| `status` | `draft` \| `testing` \| `submitted` \| `approved` \| `rejected` |
| `description` | ≤ 500 chars |
| `colors` | Array of 1–4 entries, each 0–3 |
| `abilities` | Array of 1–5; names must be **unique**; **at most 1** Passive; **exactly 4** non-Passive actives |

> [!info] "A Passive doesn't take a slot"
> The battle UI gives every character exactly four skill slots
> (`MovesetComponent.display_abilities()` is a blind `[0..3]` slice), which is why
> `AuthoredCharacter._build_moveset` emits **actives first, Passive last**. Passives are found by
> class, not position.

### Asset limits (`blocks/authored_assets.gd`)

`MAX_BYTES` 262144 (256 KB) · `MAX_CHUNKS` 64 · `MAX_DIM` 1024 px either axis ·
`UPLOAD_TTL_MS` 120000 · `SLOTS` = `["portrait","ability1".."ability5"]`.

---

## 9. What gets rejected

Every rejection returns a human-readable string; `[]` means valid.

- unknown `op`, effect `kind`, selector, condition, damage type, class, or trigger hook
- **any unexpected key** on a block, effect or condition
- non-numeric or out-of-range magnitudes, durations, costs, cooldowns, percentages
- over-deep nesting; > 40 blocks; > 12 `then` blocks; empty `blocks`; empty `then`; empty `group`
- structural type errors (non-object spec/block/effect/condition; non-Array
  `blocks`/`requires`/`classes`/`colors`)
- character level: bad id shape or charset, missing author, unknown status, duplicate ability names,
  ≠ 4 actives, > 1 passive, illegal Passive cost/cooldown/`requires`

---

## 10. Worked example — one complete authored skill, annotated

A four-cost enemy-targeted skill that opens with a burst, leaves a bleed, sets up a retaliation
window, and hits harder against a wounded target. Every construct below is legal **today**.

```json
{
  "name": "Cinder Lash",
  "target": "enemy",
  "cooldown": 2,
  "cost": {"3": 1, "0": 1},
  "classes": ["Physical", "Harmful", "Instant", "Damaging"],
  "text": "A whip of banked embers.",
  "requires": [
    {"cond": "not_has_effect", "name": "Cinder Lash", "on": "target"}
  ],
  "icon": "ability1",
  "blocks": [
    {
      "op": "damage",
      "amount": 25,
      "damage_type": "PHYSICAL",
      "to": "target"
    },
    {
      "op": "apply",
      "to": "target",
      "effect": {
        "kind": "damage_over_time",
        "amount": 10,
        "damage_type": "BLEED",
        "turns": 2
      }
    },
    {
      "op": "group",
      "when": {"cond": "hp_below", "value": 50, "on": "target"},
      "blocks": [
        {"op": "damage", "amount": 15, "damage_type": "PIERCING", "to": "target"},
        {"op": "gain_energy", "amount": 1}
      ]
    },
    {
      "op": "apply",
      "to": "user",
      "effect": {
        "kind": "reactive",
        "trigger": "on_harmful_received",
        "turns": 1,
        "text": "Embers answer.",
        "then": [
          {"op": "damage", "amount": 8, "damage_type": "AFFLICTION", "to": "target"}
        ]
      }
    }
  ]
}
```

**Line by line:**

| Piece | What it does | Gotcha it is dodging |
|---|---|---|
| `"cost": {"3": 1, "0": 1}` | 1 Red + 1 Green, total 2 ≤ 5 | keys are **strings** of colour indices; a non-numeric key silently parses to 0 |
| `requires` | skill is unusable while the target already carries this skill's mark | `name` is the **ability name**, not the DoT's `text` |
| `"amount": 25, "PHYSICAL"` | goes through `resolve_damage`, so invuln / shields / counters all apply | a `damage` block with `amount: 0` is skipped entirely |
| DoT `"turns": 2` | engine duration **4** — the runner converts | do **not** write 4 |
| DoT is hostile | routes through `add_hostile_effect` | one of only five hostile kinds |
| `group` + `when` | the whole bundle is gated on one check | the guard is evaluated **once**, and `on: "target"` is any-of over the target list |
| `gain_energy` inside the group | acts on the **user**, always | it has no `to`; adding one is a rejection |
| reactive on `user` | 1 turn of retaliation; `target` inside `then` = the attacker | the payload's damage needs the holder to have acted at least once, or `used_ability` is null and it no-ops |
| block count | 1 + 1 + (1 group + 2 children) + (1 apply + 1 then-child) = **7** of 40 | `then` children count against the same budget |
| depth | group children at 1, `then` child at 2 | reactive nesting is charged **double** |

**Generated description** (what `split_desc()` produces, and therefore exactly what the editor
preview and the battle tooltip show):

```
A whip of banked embers.
Requires: Cinder Lash is absent            [dim grey]
Deals 25 Physical damage to the target
The target takes 10 Bleed damage per turn for 2 turns
If HP is below 50, Deals 15 Piercing damage to the target; Gains 1 random energy
For 1 turn when a harmful skill is used on them: Deals 8 Affliction damage to the target
```

**Bot damage hint**: `25 + (10 × 2) + 15 = 60`. Note it counts the guarded group's damage as if it
always fires and ignores the reactive entirely — `bot_damage_hint` is an upper-bound heuristic by
design.

---

## 11. Quick authoring checklist

- [ ] Exactly **4** non-Passive abilities, plus at most 1 Passive
- [ ] Every ability name unique within the character
- [ ] Passive: cooldown 0, zero cost, empty `requires` — and **no `damage` block** (it will no-op)
- [ ] `turns` in **player turns**; never pre-double
- [ ] `cleanse` needs an explicit `to` unless you really mean the user
- [ ] Anything referenced by `has_effect` / `not_has_effect` / `stacks_at_least` must be **one of
      this character's own ability names**
- [ ] A permanent (`turns: -1`) effect on a Passive will be wiped by a buff-strip or a revive
- [ ] Check the live preview — it is the real `split_desc()`, so if it reads wrong, it *is* wrong

---

## See also

[[The Creator]] · [[What Cannot Be Built Yet]] · [[Creator Roadmap]] ·
[[Effects and Durations]] · [[Trigger Types]] · [[Targeting and Main Target]] ·
[[Damage Pipeline]] · [[Cooldowns and Energy]] · [[Cleanse Silence and Effect Removal]]
