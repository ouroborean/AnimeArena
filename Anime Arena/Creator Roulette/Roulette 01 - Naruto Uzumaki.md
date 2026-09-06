---
tags: [area/playbook, type/reference]
---

# Roulette 01 - Naruto Uzumaki

**Draw:** `draw 104/174 -> naruto` — `secrets.randbelow`, recorded before any script was opened.
**Universe:** Naruto · **Gate:** `always` (ungated) · **Abilities:** 4, no passive, no hidden slots.

> [!danger] Verdict: **Blocked** — 4 of 9 mechanics unreachable
> Naruto is the flagship starter: four skills, no passive, no transform, no hidden swap-in. If the
> simplest kit in the game cannot be authored, the palette is thinner than a top-down survey suggests.


> [!danger] CORRECTION (run 04) — this page overstated the gap
> **`stun` is already in the palette**, fully wired: `block_schema.gd:58` defines it with a `classes`
> field, and `block_runner.gd:271` calls `Effect.stun_effect(dur, classes)`. So do `silence` and
> `vulnerability`. My original scout of the schema used a truncated `sort -u | head -60`, which cut
> the effect table off partway, and three runs were built on that incomplete list.
>
> What is *actually* missing here is narrower — see the corrected note in the audit below.

---

## The kit

Read from `execute()`, not from `describe()` — see the warning below.

| # | Skill | Cost | CD | What it actually does |
|---|---|---|---|---|
| 1 | **Toad Kumite** | 1 Green, 1 White | 1 | 35 damage to one enemy; **+1 Random to the cost of that enemy's skills for 2 turns**; consumes Naruto's own *Sage Chakra Gather* mark if present |
| 2 | **Rasenshuriken** | 1 Green, 1 Blue | 2 | 40 damage to one enemy; **stuns them, excluding `Strategic` skills**, 1 turn; consumes the same mark |
| 3 | **Sage Chakra Gather** | 1 Random | 2 | Heals self 25; **gains 1 GREEN energy specifically**; gated on not already being marked |
| 4 | **Naruto Block** | 1 Random | 4 | `default_defend` — Invulnerable 1 turn |

> [!warning] The `describe()` strings are stale and describe a character that does not exist
> `naruto1.describe()` promises "20 damage… +5 per stack of Shadow Clones". The code deals a flat 35
> and applies a cost increase. `naruto2.describe()` promises a 2-turn DoT, a Shatter and a delayed full
> stun; the code deals 40 and applies one class-filtered stun. `naruto4.describe()` describes an
> HP-45 trigger, effect-stripping, and two ability swaps — the code is a bare `default_defend`.
> `split_desc()` (what the client actually renders) matches the code in all four cases, so players see
> the truth. The `describe()` bodies are dead text from an earlier design. See
> [[Changing Ability Text]] for why editing one without the other diverges.

---

## Live bug found by this run

> [!danger] *Sage Chakra Gather*'s self-lockout does not work
> `naruto3.split_desc()` says **"Cannot be used again until Naruto uses Toad Kumite or Rasenshuriken"**
> and `naruto3.extra_usable()` returns `not user.marked_by("Sage Chakra Gather")`. `naruto1` and
> `naruto2` both remove that mark.
>
> **Nothing ever applies it.** A repo-wide grep for the string finds exactly four references: the two
> removals, the one gate, and a tutorial line. `naruto3.execute()` heals and grants energy — it never
> marks.
>
> Effect: `extra_usable` is permanently true, so Sage Chakra Gather is usable on its plain 2-turn
> cooldown forever, and the stated restriction never binds. The two consume-branches in naruto1/naruto2
> are dead code.
>
> **Fix:** one line in `naruto3.execute()` — apply a permanent invisible self-mark named
> `"Sage Chakra Gather"`. Not done here; roulette reports, it does not patch.

---

## Mechanic audit

| Skill | Mechanic | Verdict | Notes |
|---|---|---|---|
| 1 | 35 damage, single target | **Buildable** | `{"op":"damage","amount":35,"to":"target"}` |
| 1 | +1 Random to target's skill **costs**, 2 turns | **Blocked** | No cost-modification block exists |
| 1, 2 | Remove one **named** effect from self | **Blocked** | `cleanse` takes only `to` — no name filter, so it strips everything rather than the one mark |
| 2 | 40 damage, single target | **Buildable** | |
| 2 | **Stun excluding `Strategic`** skills | **Blocked** (narrowly) | Stun IS buildable. `stun_effect(dur, class_targets, exclude_targets)` takes an *include* and an *exclude* list; the block passes only `classes` -> `class_targets`. Naruto uses `stun_effect(2, [], ["Strategic"])` — an **exclude** list. The gap is one missing field, not the effect. |
| 3 | Heal 25 self | **Buildable** | `{"op":"heal","amount":25,"to":"user"}` |
| 3 | Gain **1 GREEN** energy | **Blocked** | `gain_energy` calls `user.gain_random_energy()` — colour is not selectable |
| 3 | Usable only while unmarked | **Buildable** | `requires: [{"cond":"not_has_effect", …, "on":"user"}]` — `ScriptedAbility.requires` already gates `extra_usable` |
| 4 | Invulnerable 1 turn | **Buildable** | `{"op":"apply","effect":{"kind":"invulnerable","turns":1},"to":"user"}` |

Five buildable, four blocked. The blocked four are not exotic — they are a cost debuff, a stun, a
targeted removal and a colour choice.

---

## Proposed system A — Action Restriction

**The family.** One block that degrades an opponent's action economy, parameterised on *what* is
restricted and *which* of their skills it applies to.

> [!info] The family already exists in the engine; the palette just does not expose it
> `Effect.stun_effect(dur, class_targets, exclude_targets)` and
> `Effect.cost_mod_effect(mag, dur, colour, ability_targets)` are **already** parameterised on the
> filter axis. This is not new abstraction — it is surfacing the shape the engine was written with.
> Per [[Creator Roulette]]'s second trap, that is the honest scope: expose the axis, do not invent a
> framework on top of it.

```json
{ "op": "apply",
  "effect": {
    "kind": "restrict",
    "what": "usable",          // "usable" | "cost" | "cooldown"
    "amount": 1,               // ignored for "usable"; energy count / turns otherwise
    "colour": "random",        // "cost" only
    "filter": "exclude_class", // "all" | "only_class" | "exclude_class"
    "classes": ["Strategic"],
    "turns": 1
  },
  "to": "target" }
```

| `what` | Engine primitive | Named mechanic it reproduces |
|---|---|---|
| `usable` | `Effect.stun_effect` | Stun; class-filtered stun; a Silence-alike via `only_class` |
| `cost` | `Effect.cost_mod_effect` | Cost increase (Naruto 1), cost reduction on allies |
| `cooldown` | `Effect.cooldown_mod` / `paralyze_effect` | Cooldown extension; Paralyze as `amount: 0` freeze |

**Reach — measured.** Abilities calling these factories, by distinct character:

| Factory | Abilities | Characters |
|---|---|---|
| `stun_effect` | 104 | 88 |
| `cost_mod_effect` | 49 | 36 |
| `cooldown_mod` | 13 | 9 |
| `paralyze_effect` | 5 | 5 |
| `cost_stun_effect` | 1 | 1 |
| **Union** | | **114 of 174 characters (66%)** |

**Validator limits.** `turns` ≤ 2 for `usable` (a 3-turn stun is a lost game); `amount` ≤ 2 for
`cost`; ≤ 2 for `cooldown`; at most **one** `restrict` per ability; `filter` classes drawn from a
fixed whitelist so an author cannot name a class that does not exist. The abuse case is a cheap,
no-cooldown, long-duration stun — priced by requiring cost ≥ 2 or cooldown ≥ 2 on any ability
carrying `what: "usable"`.

**Prose.** "Stuns the target for 1 turn (Strategic skills unaffected)." / "Increases the cost of the
target's skills by 1 Random for 2 turns." One clause each.

**Bot story.** `TAG_CONTROL` for `usable` and `cooldown`; `cost` is closer to `TAG_CONTROL` than
anything else in the existing 7 bits. No `bot_damage_hint()` contribution.

**Engine cost.** `block_schema.gd` (one kind + fields), `block_validator.gd` (limits + class
whitelist), `block_runner.gd` (one `_build_effect` arm dispatching on `what`), editor UI. **No engine
change** — every factory exists.

---

## Proposed system B — Filtered effect removal

**The gap.** `cleanse` today takes only `to`. Naruto needs "remove *this one named mark* from
myself" and gets "remove everything" instead.

```json
{ "op": "cleanse",
  "to": "user",
  "scope": "own",        // "own" | "hostile" | "any"   (default "hostile" = today's behaviour)
  "name": "Sage Chakra", // omit = all, matching today
  "count": 1 }           // omit = unlimited
```

Backwards compatible: omitting the new fields reproduces current behaviour exactly.

**Reach.** 75 of 174 characters (43%) call `remove_effect` / `consume_effect` / `erase_effect`.
Not all need the name filter, but the self-consuming-mark pattern — spend a resource you built up —
is one of the most common shapes in the roster and is currently unauthorable.

**Validator limits.** `name` matched against the author's *own* declared effect names plus a
whitelist; `count` ≤ 3. The abuse case is a one-cost skill that strips an entire enemy kit, priced
the same way any buff-strip is.

**Bot story.** No new bit; removal is already covered by existing scoring.

---

## Not a system — specific-colour energy

`gain_energy` calls `user.gain_random_energy()`. Naruto 3 needs a *named* colour
(`gain_bonus_energy(Energy.Type.GREEN)`).

This is **a parameter on an existing block**, not a family, and calling it a system would be exactly
the inflation [[Creator Roulette]] warns against:

```json
{ "op": "gain_energy", "amount": 1, "colour": "green" }   // omit colour = random, as today
```

**Reach:** 8 of 174 characters (5%). Small, cheap, and honest about being small.

---

## Reach summary

| Proposal | Characters served | Share of roster | Difficulty |
|---|---|---|---|
| **A — Action Restriction** | 114 | 66% | moderate — no engine work |
| **B — Filtered removal** | 75 | 43% | trivial — extend one block |
| **C — Energy colour** | 8 | 5% | trivial — one field |

---

## Verdict for the roadmap

All three belong **early**. None needs new engine primitives — every factory already exists and is
already parameterised; this is purely palette exposure, which is the cheapest kind of Creator work
there is.

System A alone moves the Creator from "cannot express two thirds of the roster's control mechanics"
to "can". It should be the next thing built, ahead of anything in the later phases of
[[Creator Roadmap]], because 66% reach for no engine change is the best ratio on the board.

Separately: fix Naruto's missing mark, and either delete or correct the four stale `describe()`
bodies.

---

Related: [[Creator Roulette]] · [[What Cannot Be Built Yet]] · [[Creator Roadmap]] ·
[[Block Palette Reference]] · [[Cleanse Silence and Effect Removal]] · [[Cooldowns and Energy]]
