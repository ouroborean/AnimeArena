---
tags: [area/playbook, type/reference]
---

# Roulette 04 - Superbi Squalo

**Draw:** `draw 139/174 -> squalo` — `secrets.randbelow`, recorded before any script was opened.
**Universe:** Katekyo Hitman Reborn · **Abilities:** 4, no passive, no hidden slots.

> [!success] Verdict: **Buildable with fidelity loss** — the closest to authorable yet
> Three of four skills are fully expressible today. One is not, for a reason worth one small block.

---

> [!danger] This run corrects a mistake that ran through runs 01-03
> **`stun`, `silence` and `vulnerability` have been in the palette the whole time.**
>
> | Kind | Schema | Runner |
> |---|---|---|
> | `stun` | `block_schema.gd:58` — fields `turns`, `classes` | `block_runner.gd:271` → `Effect.stun_effect(dur, classes)` |
> | `silence` | `block_schema.gd:64` | `block_runner.gd:283` → `Effect.silence_effect(dur)` |
> | `vulnerability` | `block_schema.gd:62` | `block_runner.gd:279` → `Effect.vulnerability_effect(amount, dur)` |
>
> **How it happened.** My first scout of the Creator ran
> `grep -oE '"[a-z_]+"' blocks/block_schema.gd | sort -u | head -60`. Sorted and truncated at 60, it
> cut the effect table off partway and never showed these. I built a mental model on that list and did
> not re-verify it for three runs — while, in run 03, writing a warning about exactly this class of
> error.
>
> **The complete `EFFECT_KINDS` table is 13 entries** (`block_schema.gd:53-67`): `mark`,
> `damage_over_time`, `heal_over_time`, `shield`, `stun`, `invulnerable`, `ignore_damage`,
> `damage_reduction`, `vulnerability`, `damage_boost`, `silence`, `destructible_break`, `reactive`.
>
> Runs 01 and 02 have been amended in place. What survives of **System A — Action Restriction** is
> genuinely smaller: `cost` and `cooldown` manipulation (neither is in the table), Paralyze, and the
> **exclude-class** filter axis. The `usable` axis is already shipped.

---

## The kit

| # | Skill | CD | What it does |
|---|---|---|---|
| 1 | **Zanna di Squalo** | 2 | 15 Piercing now, then 15 Piercing per turn for 3 turns — applied **bypassing** invulnerability |
| 2 | **Scontro di Squalo** | 0 | Destroys **all Nullify on himself** and **all Shield on the target**, then 20 Piercing |
| 3 | **Squalo Grande Pioggia** | 1 | 35 Piercing + **permanent** Shatter |
| 4 | **Squalo Parry** | 4 | Invulnerable 1 turn |

---

## Mechanic audit

| Skill | Mechanic | Verdict | Notes |
|---|---|---|---|
| 1 | 15 Piercing immediate | **Buildable** | `damage` takes `damage_type`; `PIERCING` is in `DAMAGE_TYPES` |
| 1 | 15 Piercing/turn for 3 turns | **Buildable** | `damage_over_time` with `damage_type` |
| 1 | Applied **bypassing** invulnerability | **Blocked** | The `bypassing` argument to `add_hostile_effect` is not exposed |
| 2 | Destroy all **Shield** on the target | **Blocked** | *New* — see below |
| 2 | Destroy all **Nullify/Barrier** on self | **Blocked** | Same |
| 2 | 20 Piercing | **Buildable** | |
| 3 | 35 Piercing | **Buildable** | |
| 3 | **Permanent** Shatter | **Buildable** | `destructible_break` → `def_negate`; the validator explicitly allows `turns: -1` (`block_validator.gd:190`) |
| 4 | Invulnerable 1 turn | **Buildable** | |

Six buildable, three blocked. Skills 3 and 4 are authorable **exactly**; skill 1 loses only its
bypass; skill 2 loses its identity.

---

## Proposed system G — Defence destruction

`cleanse` removes *effects*. It is not the same operation as destroying a Shield or a Barrier, and
using it as a substitute would be wrong in a way that matters.

> [!warning] Why this cannot be folded into `cleanse`
> Shields and Barriers must be torn down through `Character.shatter_shields()` /
> `shatter_barrier()`, which fire the **wrapup and contingent-cleanup hooks** those effects carry.
> Removing them with a generic effect-erase skips that teardown and leaves dependent state behind —
> a documented trap in [[Effects and Durations]]. A `cleanse` that happened to match a Shield by name
> would be the wrong call, silently.

```json
{ "op": "break",
  "what": "shield",   // "shield" | "barrier" | "both"
  "to": "target" }
```

**Axes:** which defence class × whose (any existing selector). Deliberately small — this is a verb,
not a family, and inflating it would be the error [[Creator Roulette]] warns about.

**Reach — measured:** `shatter_shields` / `shatter_barrier` appear in **11 abilities across 9
characters (5%)**.

That is low, and the honest reading is that **this is a small block, not a priority**. It earns its
place because it is a handful of lines over an existing engine call and because the alternative — an
author reaching for `cleanse` — produces a subtly broken character rather than an error.

**Prose:** "Destroys all Shield on the target." **Bot:** no new bit. **Engine cost:** none.

---

## Proposed field — `bypassing`

Squalo 1 lands its DoT through invulnerability. That is the `bypassing` **parameter** on
`add_hostile_effect`, not the `Bypassing` display class — a distinction [[Targeting and Main Target]]
records because ~19 shipped skills bypass without carrying the class.

```json
{ "op": "apply", "effect": { … }, "to": "target", "bypassing": true }
```

**Reach — measured:** 41 abilities across **32 characters (18%)** apply an effect with the bypass flag
set.

One boolean on `_op_apply`, passed through to the existing call. The validator should require a
cost or cooldown floor on any ability using it, since "ignores Invulnerable" is a strong keyword.

---

## Reach summary

| Proposal | Characters | Share | Difficulty |
|---|---|---|---|
| `bypassing` field | 32 | 18% | trivial — one boolean |
| **G — Defence destruction** | 9 | 5% | trivial — one verb |

Neither is a headline system. This run's value is the correction, not the proposals.

---

## Verdict for the roadmap

Squalo needs almost nothing: two small additions and he is authorable at full fidelity. He is the
first draw that would be *cheap* to unlock.

The larger lesson is about the exercise itself. Four runs in, the roadmap ordering has shifted twice
on new information — once when Action Restriction accumulated three hits, and now when a third of it
turned out to be already shipped. **The measured claims in these pages are worth more than the
prioritisation built on them**, and the prioritisation should be re-derived from the ledger rather
than inherited from any single run.

---

Related: [[Creator Roulette]] · [[Roulette 01 - Naruto Uzumaki]] · [[Roulette 02 - Death the Kid]] ·
[[Roulette 03 - Sailor Mercury]] · [[Block Palette Reference]] · [[What Cannot Be Built Yet]] ·
[[Effects and Durations]] · [[Targeting and Main Target]]
