---
tags: [area/playbook, type/reference]
---

# Roulette 02 - Death the Kid

**Draw:** `draw 69/174 -> kid` — `secrets.randbelow`, recorded before any script was opened.
**Universe:** Soul Eater · **Abilities:** 6 (4 active, 1 passive, 1 hidden swap-in).

> [!danger] Verdict: **Blocked** — and much further out of reach than [[Roulette 01 - Naruto Uzumaki]]
> Naruto was blocked on four ordinary effects. Kid is blocked on the *shape* of his kit: a symmetry
> condition comparing two other characters, a reactive the palette does not have, a stance swap, and a
> cross-character passive that reaches into another character's cooldowns.


> [!danger] CORRECTION (run 04) — this page overstated the gap
> **`stun` is already in the palette**, fully wired: `block_schema.gd:58` defines it with a `classes`
> field, and `block_runner.gd:271` calls `Effect.stun_effect(dur, classes)`. So do `silence` and
> `vulnerability`. My original scout of the schema used a truncated `sort -u | head -60`, which cut
> the effect table off partway, and three runs were built on that incomplete list.
>
> What is *actually* missing here is narrower — see the corrected note in the audit below.

---

## The kit

| # | Skill | Cost | CD | What it does |
|---|---|---|---|---|
| 1 | **Sanzu River Shot** | 1 Blue | 0 | 10 damage, **+15 if the target's living allies are not at equal HP** |
| 2 | **Fatal Error** | 1 Green | 0 | 20 damage; **stuns 1 turn if the target `was_countered`** |
| 3 | **Stable Resonance** | 1 Green, 1 Blue | 5 | `target_type: ALL` — allies get "heal 10 when you use a skill", enemies get "take 10 at end of turn **if you did not act**", 4 turns; **swaps this slot to Death Cannon** |
| 4 | **Death Slide** | 1 Random | 4 | Strategic self |
| 5 | **Partners: Liz and Patty** | — | — | Passive: using either Thompson sister's Transform on Kid **fires the other too, if it is off cooldown** |
| 6 | **Death Cannon** | 1 Green, 1 Blue, 1 Random | 2 | Hidden swap-in |

Kid's whole design is *symmetry* — his mechanics read the board's balance rather than a single target.
That is precisely what the block conditions cannot see.

---

## Mechanic audit

| Skill | Mechanic | Verdict | Notes |
|---|---|---|---|
| 1 | 10 base damage | **Buildable** | |
| 1 | +15 **if the target's two allies differ in HP** | **Blocked** | Conditions compare a selector against a *constant* (`hp_above` / `hp_below`). Nothing compares two characters to each other. |
| 2 | 20 damage | **Buildable** | |
| 2 | Stun if the target **was countered last turn** | **Blocked** (predicate only) | Kid uses a plain `stun_effect(2)` — **that half is buildable today**. Only the `was_countered` predicate is missing. |
| 3 | Split payload: allies vs enemies from one cast | **Buildable** | Two blocks with `to: "all_allies"` and `to: "all_enemies"` — the selectors already do this |
| 3 | Ally reactive: "heal when **you use a skill**" | **Blocked** | The 6 reactive triggers are damage-dealt/received, death, harmful-received, turn-start/end. There is no *action-use* trigger. |
| 3 | Enemy tick: damage **only if they did not act** | **Blocked** | No turn-state predicate (`acted`) |
| 3 | **Swap this slot to Death Cannon** for 4 turns | **Blocked** | No ability-swap block |
| 4 | Strategic self utility | **Buildable** | |
| 5 | Cross-character passive reaching another character's cooldowns | **Blocked** | Requires naming another character's ability and reading its cooldown state |
| 6 | Death Cannon as a hidden slot | **Blocked** | Depends on the swap above |

Three buildable, seven blocked — **corrected to four buildable, six blocked**: kid2's stun is authorable, only its condition is not.

---

## Proposed system C — Ability Swap (stance / transform)

The largest single gap in the roster, and untouched by run 01.

```json
{ "op": "apply",
  "effect": {
    "kind": "swap",
    "slot": 2,          // which of the author's own 4 slots is replaced
    "into": 5,          // index of one of the author's own HIDDEN skills
    "turns": 4,         // omit for permanent
    "revert_on": "none" // "none" | "hp_below" | "effect_lost"
  },
  "to": "user" }
```

**Axes:** which slot × which replacement × duration × revert condition. That yields transforms,
stances, one-shot follow-ups, "empowered next skill", and Kid's timed Death Cannon window.

**Constraint that makes it safe and authorable:** `into` may only reference the **author's own**
declared hidden skills, which the validator has already checked. No cross-character reference, so it
cannot become the skill-copy problem.

**Reach — measured:** `Effect.ability_swap_effect` appears in **111 abilities across 82 characters
(47% of the roster)**.

**Engine cost:** none — the factory exists. The one real subtlety is duration: a swap of "N turns" is
`2N+1`, not `2N` (see [[Effects and Durations]]), so the runner must convert rather than pass `turns`
through. Authors say "4 turns"; the block writes 9.

**Prose:** "Death Slide is replaced by Death Cannon for 4 turns." **Bot:** no new bit; the swapped-in
skill is scored on its own blocks.

---

## Proposed system D — Reactive trigger coverage

Not a new system — **more values in an existing enum**. The reactive block already exists with 6
triggers; the roster uses many more.

| Missing trigger | Engine type | Abilities | Characters |
|---|---|---|---|
| **on_skill_used** (this character acts) | `ACTION_USE_TRIGGER` | 67 | **45 (26%)** |

Kid 3 needs exactly this for the ally half. Adding trigger names to
`BlockSchema.reactive_trigger_id()` is a table entry each, with the existing nesting limits
unchanged.

> [!tip] Deliberately not inflated
> This is the run-01 lesson applied again: the reactive *machinery* is built and correct. What is
> missing is rows in a lookup table. Calling that a "system" would be the inflation
> [[Creator Roulette]] warns about.

---

## Proposed system E — Relational conditions

The genuinely new *design* idea in this run, and the one that makes Kid Kid.

Every current condition compares one selector to a **constant**. Kid compares characters **to each
other**.

```json
{ "cond": "compare",
  "left":  { "of": "target_allies", "value": "hp" },
  "op":    "all_equal",     // "all_equal" | "any_differ" | "gt" | "lt" | "eq"
  "right": null }            // a selector+value, or a constant, or null for group predicates
```

**Axes:** what is measured (`hp`, `hp_percent`, `alive_count`, `effect_count`, `energy`) × the
comparison (group-predicate or pairwise) × which characters (existing selectors).

That yields Kid 1's symmetry check, "if this ally is the most wounded", "if you have more living
characters than the enemy", "if the target has more effects than you" — a whole class of conditional
scaling the palette cannot currently reach.

**Reach — measured, and honestly narrower than it first looks.** My first grep unioned "any ability
that loops over `.characters`" and reported 118/174, which is a measurement artifact: that pattern
catches nearly every AoE. The defensible numbers are:

| Predicate | Abilities | Characters |
|---|---|---|
| Reads any character's HP for a decision | 70 | **49 (28%)** |
| Reads `acted` (did / did not act this turn) | 8 | 8 |
| Reads `was_countered` | 1 | 1 |
| Compares two characters' HP directly | 1 | **1 — only Kid** |

So: the *general* relational condition serves ~28% of the roster, while Kid's exact symmetry check is
unique to him. **Build the general form, not the symmetry check.** A `compare` block that only ever
answers "are these two HP values equal" would be the band-aid this process exists to prevent.

---

## Reach summary

| Proposal | Characters | Share | Difficulty | New in this run |
|---|---|---|---|---|
| **C — Ability swap** | 82 | 47% | moderate (duration conversion) | ✅ |
| **E — Relational conditions** | 49 | 28% | moderate | ✅ |
| **D — `on_skill_used` trigger** | 45 | 26% | trivial (table row) | ✅ |
| *A — Action Restriction* (run 01) | 114 | 66% | moderate | second hit (kid2) |

---

## Verdict for the roadmap

**Ability Swap is the second-biggest lever in the Creator**, behind only Action Restriction, and the
two together cover most of what makes roster characters feel distinct. Both need zero engine work.

Kid also produces the first honest **"cannot be authored"** of the exercise: his passive
(*Partners: Liz and Patty*) reaches into another character's ability list and cooldown state to fire
it. That is not a missing block — it is a cross-character coupling the authoring model deliberately
does not have, and exposing it would mean letting an author name and drive skills they do not own.
A Creator character can have a passive; it cannot have *that* passive. Recorded as a genuine boundary
rather than a backlog item.

---

Related: [[Creator Roulette]] · [[Roulette 01 - Naruto Uzumaki]] · [[What Cannot Be Built Yet]] ·
[[Creator Roadmap]] · [[Effects and Durations]] · [[Trigger Types]]
