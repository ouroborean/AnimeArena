---
tags: [area/playbook, type/reference]
---

# Roulette 03 - Sailor Mercury

**Draw:** `draw 95/174 -> mercury` — `secrets.randbelow`, recorded before any script was opened.
**Universe:** Sailor Moon · **Abilities:** 4, no passive, no hidden slots.

> [!success] Verdict: **Buildable with fidelity loss** — the first run that is not Blocked outright
> Mercury's *identity* — an Empower state machine where every skill reads one self-mark — is
> **already authorable today**. What she loses is the payloads those branches carry: a Paralyze, two
> cooldown manipulations and a Counter.

---

## The kit

Every skill checks `marked_by("Shabon Spray")`. That single mark is the whole character.

| # | Skill | CD | Base | While **Empowered** |
|---|---|---|---|---|
| 1 | **Shabon Spray** | 0 | 15 damage; applies the Empower mark (1 turn); silently cuts Shine Aqua Illusion's cooldown by 3 | deals **25** instead |
| 2 | **Shabon Spray Freeze** | 2 | 20 damage + **Paralyze 2 turns** | also **+1 to the target's cooldowns** |
| 3 | **Mercury Aqua Mirage** | 2 | Invisible **Counter**: the first enemy to use a Harmful skill on the target is countered and takes 15 | may target **any ally**, not just herself |
| 4 | **Shine Aqua Illusion** | 4 | Invulnerable 1 turn | cooldown reduced by 3 (via skill 1's hidden `cooldown_mod`) |

---

## Mechanic audit

| Skill | Mechanic | Verdict | Notes |
|---|---|---|---|
| 1, 2, 3, 4 | **Branch on an own self-mark** | **Buildable** | `has_effect` / `not_has_effect` conditions on `"user"`, one `group` per branch. This is the character's core loop and it works today. |
| 1 | 15 / 25 damage | **Buildable** | Two conditional `group`s |
| 1 | Apply the Empower mark, 1 turn | **Buildable** | `apply` → `mark`, `turns: 1` |
| 1 | Reduce **a named own skill's** cooldown by 3 | **Blocked** | System A (run 01), `filter: "named"` axis |
| 2 | 20 damage | **Buildable** | |
| 2 | **Paralyze 2 turns** | **Blocked** | System A, `what: "cooldown"` at magnitude 0 |
| 2 | **+1 to the target's cooldowns** | **Blocked** | System A, `what: "cooldown"` |
| 3 | **Counter** an incoming Harmful skill | **Blocked** | *New.* Not a reactive — see below |
| 3 | Invisible effect | **Buildable** | The runner already supports invisible marks |
| 3 | Empowered version **retargets** (self → any ally) | **Blocked** | `target_mode` is fixed per authored ability |
| 4 | Invulnerable 1 turn | **Buildable** | |

Six buildable, five blocked — and crucially, the buildable six include the state machine itself.

> [!success] The first positive structural finding of the exercise
> Runs 01 and 02 only found holes. Mercury shows the palette *can* already express a
> stance/empower loop: mark yourself, branch every other skill on that mark, let the mark expire.
> **163 abilities across 77 characters (44% of the roster)** call `marked_by()` to vary their own
> behaviour, and that whole pattern is authorable now. That is a real coverage win worth knowing about
> before adding anything.

---

## Proposed system F — Counters

The one genuinely new capability this run demands.

> [!info] A counter is not a reactive, and the difference is the whole point
> The Creator's reactives (`on_damage_received`, `on_harmful_received`, …) fire **after** the enemy's
> skill resolves. A **counter** intercepts it: the incoming skill is *cancelled*, the attacker may be
> punished, and the engine treats the exchange as never having landed. `Effect.counter_effect` +
> `default_counter_trigger` is a distinct machine from `Effect.trigger_effect`, with its own
> `wrapup_func` timeout. Adding an `on_countered` reactive would not produce a counter.

```json
{ "op": "apply",
  "effect": {
    "kind": "counter",
    "scope": "harmful",     // "harmful" | "damaging" | "any"
    "turns": 1,
    "charges": 1,           // how many incoming skills it eats
    "invisible": true,
    "then": [ { "op": "damage", "amount": 15, "to": "target" } ]
  },
  "to": "user" }
```

**Axes:** what it intercepts (`scope`) × how many times (`charges`) × visibility × the punish payload
(`then`, an ordinary nested block list, exactly like the reactive block already uses).

**Reach — measured:**

| Factory | Abilities | Characters |
|---|---|---|
| `counter_effect` | 37 | 33 |
| `reflect_effect` | 10 | 10 |
| **Union** | 46 | **42 of 174 (24%)** |

**Validator limits.** `charges` ≤ 1 and `turns` ≤ 1 to start — a multi-charge, multi-turn counter is
a hard lock on an opponent's offence. `then` inherits the reactive payload cap
(`max_reactive_then_blocks`). Require a cooldown ≥ 2 on any ability carrying one.

**Why `then` is safe here but reflect payloads are not.** [[What Cannot Be Built Yet]] rules out
author-written *reflect* payloads because reflection mutates the attacker's targeter, with the
`ALL` vs `ALL_FACTION` trap and bypass-aware re-validation. A counter does not re-aim anything — it
cancels and optionally damages the attacker, who is already a known single character. The payload is
just blocks pointed at one target.

**Prose:** "The first enemy to use a Harmful skill on her is countered and takes 15 damage."
**Bot:** `TAG_REACTIVE`, plus `bot_damage_hint()` should see the `then` damage.
**Engine cost:** none — `counter_effect`, `default_counter_trigger` and `default_counter_timeout` all
exist and are used by 37 abilities.

---

## Not a system — per-branch retargeting

Mercury 3 targets *herself* normally and *any ally* while Empowered. Authored abilities have one
static `target_mode`.

The honest fix is a field, not a machine: let `target_mode` be widened by a condition, or simply let
authors declare the *wider* mode and gate the effect with a `requires` condition — which is already
possible and costs nothing. Recorded as a **fidelity loss an author can work around**, not a gap.

> [!warning] A measurement I threw away
> My grep for "abilities whose `target()` branches" returned **651 abilities / 141 characters (81%)**.
> That is nonsense — the pattern matches any `func target()` followed by any `if` within 300
> characters, which is nearly every file in `abilities/`. Second time this exercise has produced an
> inflated union (see [[Roulette 02 - Death the Kid]]); loose greps over a 1,020-file corpus flatter
> whatever you are arguing for. Only the tight counts above are used.

---

## Reach summary

| Proposal | Characters | Share | New in this run |
|---|---|---|---|
| **F — Counters** | 42 | 24% | ✅ |
| *A — Action Restriction* (run 01) | 114 | 66% | **third hit** — paralyze, hostile cooldown, named-skill cooldown cut |
| *Own-state branching* | 77 | 44% | ✅ **already buildable** |

---

## Verdict for the roadmap

**Action Restriction is now confirmed three runs running**, and Mercury exercises three different
faces of it in one kit — Paralyze, a hostile cooldown increase, and a *self*, *negative*,
*named-skill* cooldown reduction. That last one specifically validates the `filter: "named"` axis
proposed in run 01: without it, Mercury 1's hidden interaction with Mercury 4 cannot exist. Whatever
doubt remained about building System A first is gone.

**Counters** should follow the swap work from run 02. 24% reach, no engine cost, and it closes the
last big *reactive-shaped* hole.

And the good news is worth stating plainly: the Creator can already build a stance character. It just
cannot yet arm one.

---

Related: [[Creator Roulette]] · [[Roulette 01 - Naruto Uzumaki]] · [[Roulette 02 - Death the Kid]] ·
[[What Cannot Be Built Yet]] · [[Creator Roadmap]] · [[Trigger Types]] · [[Cooldowns and Energy]]
