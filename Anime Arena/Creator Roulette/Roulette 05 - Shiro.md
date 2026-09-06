---
tags: [area/playbook, type/reference]
---

# Roulette 05 - Shiro

**Draw:** `draw 136/174 -> shiro` — `secrets.randbelow`, recorded before any script was opened.
**Universe:** Deadman Wonderland · **Abilities:** 5 (3 damaging, 1 channel, 1 passive).

> [!danger] Verdict: **Blocked** — and the first draw blocked on a *resource*, not on effects
> Shiro's three damaging skills form a rock-paper-scissors cycle: each one checks whether the other
> two are "armed", buffs itself against them, and spends a stack of a shared counter to lengthen the
> window. The palette can express the cycle. It cannot express the **counter**.

---

> [!tip] Palette read in full before auditing (run-04 rule)
> `EFFECT_KINDS` — 13 entries, `REACTIVE_TRIGGERS` — 6, conditions — 6, selectors — 7. Read directly
> from `blocks/block_schema.gd`, not grepped. That immediately changed two verdicts below:
> `silence` and `vulnerability` are both **shipped**, so shiro1's Silence and shiro4's
> self-Vulnerability are buildable today.

---

## The kit

| # | Skill | CD | What it does |
|---|---|---|---|
| 1 | **Shiro Kick** | 0 | 15 damage; **if Mascot Rush is armed**, also Silences the target; **if Shiro Rampage is armed**, grants herself immunity to Stun *and* Silence; arms itself and boosts the *other two* skills by 10 |
| 2 | **Mascot Rush** | 0 | Same shape, different cross-references |
| 3 | **Shiro Rampage** | 0 | Same shape again |
| 4 | **Ganta Fight Song** | 3 | **Channeled**: permanent Taunt on the whole enemy team, +5 Vulnerability on herself, and a ticking trigger granting **1 Ganta Fever stack per turn** — all three ending together if the channel breaks |
| 5 | **Ganta Fever** | — | Passive: every damaging skill **consumes one Ganta Fever stack** to extend its buff window from 3 to 7 |

The whole character is one economy: skill 4 pays HP-safety to bank stacks, skills 1-3 spend them.

---

## Mechanic audit

| Skill | Mechanic | Verdict | Notes |
|---|---|---|---|
| 1-3 | Damage | **Buildable** | |
| 1-3 | **Check whether another of my own skills is armed** | **Buildable** | `has_effect` takes `name` + `on`; Shiro's marks are named after the skills. The rock-paper-scissors *logic* works today. |
| 1 | Silence the target | **Buildable** | `silence` is in the palette |
| 1 | Grant self **immunity to Stun and Silence** | **Blocked** | `ignore_effect_effect(dur, EffectType)` — no block kind |
| 1-3 | Arm self with a mark | **Buildable** | `mark` |
| 1-3 | **+10 damage to two specifically named skills** | **Blocked** (narrowly) | `damage_boost` → `damage_mod_effect`, but its fields are `amount`, `turns` only. The engine factory takes an ability-name filter; the block does not pass one. |
| 1-3, 5 | **Duration computed from a stack count, consuming the stack** | **Blocked** | Durations are literals in the schema. No dynamic value, no stack spend. |
| 4 | Permanent **Taunt** on all enemies | **Blocked** | No taunt kind |
| 4 | +5 **Vulnerability** on self, permanent | **Buildable** | `vulnerability` is shipped; `turns: -1` is allowed |
| 4 | **Channel** — all three effects end together when it breaks | **Blocked** | No channel concept |
| 4 | Ticking trigger granting a stack per turn | **Blocked** | Depends on stacks |
| 4 | Stackable, stack-displaying mark | **Blocked** | `mark` has `turns` and `text` only |

Six buildable, seven blocked.

---

## Proposed system H — Stacks as a resource

The headline gap, and the one that makes Shiro Shiro.

> [!danger] This also fixes a dead condition
> `stacks_at_least` is **already in the palette** (`block_schema.gd:44`) and is **unreachable**:
> `Effect.mark()` never sets `stackable`, and the storage merge keys off the stored effect's flag, so
> an authored mark can never hold more than one stack. The condition can never be true. Shipping
> stacks turns an existing dead feature on.

```json
// declare a counter
{ "op": "apply",
  "effect": { "kind": "counter", "name": "Fever", "turns": -1, "max": 5, "text": "…" },
  "to": "user" }

// add to it
{ "op": "stack", "name": "Fever", "delta": 1, "to": "user" }

// spend it — the block only runs if the stack is there
{ "op": "group",
  "cond": { "cond": "stacks_at_least", "name": "Fever", "value": 1, "on": "user" },
  "blocks": [ { "op": "stack", "name": "Fever", "delta": -1, "to": "user" },
              { "op": "apply", "effect": { "kind": "damage_boost", "amount": 10, "turns": 4 }, "to": "user" } ] }
```

**Axes:** declare × add × spend × read (the existing condition) × a `max` ceiling. Those four verbs
give charge-up skills, combo counters, resource ultimates, escalating passives and consume-on-use
payoffs — the whole "bank it then spend it" design space.

**Reach — measured:**

| Pattern | Abilities | Characters |
|---|---|---|
| Sets `stackable = true` | 116 | 81 |
| Reads `stack_count()` / `.stacks` | 101 | 57 |
| Calls `consume_stack()` | 4 | 4 |
| **Union** | 140 | **81 of 174 (47%)** |

**Validator limits.** `max` ≤ 10; one `counter` declaration per character (not per ability); `delta`
in −3..+3; a spend must be inside a `group` guarded by `stacks_at_least`, so an author cannot spend
what they do not have. The abuse case is an unbounded counter feeding an unbounded boost — the `max`
ceiling and the existing `damage_boost` magnitude cap handle it together.

**Prose.** "Gains 1 stack of Fever." / "Consumes 1 stack of Fever to…" **Bot:** the counter should
surface in `BotObservation` the way other marks do, or bots will spend nothing.

**Engine cost.** Small but **not zero** — the only run so far to need engine work. `Effect.mark()`
must accept a `stackable` flag (or the runner must set it after construction, which is how
hand-written abilities do it: `mark.stackable = true; mark.display_stacks = true`). Everything else
is existing API.

---

## Proposed system I — Channels

shiro4 applies three effects that must **live and die together**, ending if she acts again or is
stunned.

```json
{ "op": "apply",
  "effect": { "kind": "channel", "breaks_on": ["acts", "stunned"],
              "then": [ …the effects the channel owns… ] },
  "to": "user" }
```

**Axes:** what breaks it × what it carries (an ordinary nested block list, like `reactive.then`).

**Reach — measured:** `channel_cancel` / `control_cancel` appear in 16 abilities across **15
characters (9%)**.

> [!warning] Build this one carefully — it has a known crash shape
> The 17 shipped channel abilities all append effects to their cancel list **before** applying them,
> so a rejected or merged application leaves a freed node in `cancel_effects`. That produced a live
> "previously freed" crash, fixed engine-side in `Character._end_cancel_effects`. An authored channel
> must build its list from **applied** effects only. See [[Node Lifecycle and Orphans]].

---

## Smaller gaps this run confirms

| Gap | Reach | Note |
|---|---|---|
| `damage_boost` **named-skill filter** | 47 chars (27%) | One field. The factory already takes it. |
| **Taunt** | 15 chars (9%) | An ordinary effect kind — `Effect.taunt_effect(dur, user)` |
| **Effect-type immunity** (`ignore_effect_effect`) | 18 chars (10%) | "Immune to Stun for 2 turns" |

---

## Reach summary

| Proposal | Characters | Share | Engine work |
|---|---|---|---|
| **H — Stacks as a resource** | 81 | **47%** | small (a `stackable` flag) |
| `damage_boost` named filter | 47 | 27% | none |
| Effect-type immunity | 18 | 10% | none |
| **I — Channels** | 15 | 9% | none |
| Taunt | 15 | 9% | none |

---

## Verdict for the roadmap

**Stacks is the biggest single lever found in five runs** measured by characters served (81), and it
is the first proposal that turns on an *existing dead feature* rather than only adding one. It also
changes what "buildable" means for earlier runs: Frieza's every-3rd-use counter (the example used in
[[Creator Roulette]]'s governing rule) is a stacks problem, and so is Ryohei's To The Extreme.

Five runs in, the palette's shape is clear. It handles **one-shot effects on characters** well and
**state that persists and accumulates** not at all. Every deep block so far — Kid's relational
conditions, Mercury's counters, Shiro's stacks — is a variant of "the Creator cannot remember
anything between casts except a binary mark".

---

Related: [[Creator Roulette]] · [[Roulette 01 - Naruto Uzumaki]] · [[Roulette 02 - Death the Kid]] ·
[[Roulette 03 - Sailor Mercury]] · [[Roulette 04 - Superbi Squalo]] · [[Block Palette Reference]] ·
[[What Cannot Be Built Yet]] · [[Node Lifecycle and Orphans]] · [[Effects and Durations]]
