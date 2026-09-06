---
tags: [area/playbook, type/reference]
---

# Roulette 09 - Saitama

**Draw:** `draw 125/174 -> saitama`       **Universe:** One Punch Man   **Gate:** `always` (ungated)
**Verdict (as drawn):** Buildable with fidelity loss (4/6 exact, 2 near-misses)
**Verdict (after this run built the two systems):** **Fully buildable — exact behavioral fidelity on all 6 skills**

This is the first run against a *complete* Creator (Phases A–G + owner rulings), and the first with a
standing instruction that the draw **should** be buildable. So it doubles as a completeness check, and
it earns its keep: a random draw found **two** real gaps a top-down survey had not flagged, both of them
the "surfacing, not capability" shape the ledger keeps predicting — the engine already had the primitive,
the palette had never exposed it. Both were built and the whole kit was then **authored as block-tree
JSON and proven** through the real `AuthoredRegistry.validate_character` (0 errors) and a headless battle
(`creator_saitama_spec_probe`: 41/0).

## The kit
Six abilities (`character_ability_counts.saitama = 5` visible/passive + `saitama7` hidden swap-in). Names
from `ability_info.json`; behaviour from the scripts (`split_desc` is the contract, `describe()` is stale).

- **Normal Punch** (`saitama1`, cd0, 2 Green, Harmful/Instant/Physical/Damaging): shatter one enemy's Shield, then 45 NORMAL to them.
- **Consecutive Normal Punches** (`saitama2`, cd2, 1 Green + 2 Random): shatter the enemy team's Shields, then 30 NORMAL to all.
- **Serious Series: Serious Table-Flip** (`saitama3`, cd6, 3 Random, Bypassing/Uncounterable): one skill hitting **both teams** — allies are cleansed of hostile effects and made Invulnerable 1 turn; enemies get Shattered (`def_negate`) 2 turns.
- **Serious Series: Serious Side-Hops** (`saitama4`, cd3, 1 Random, Invisible): an **invisible counter** of the first Harmful **non-Strategic** skill used on Saitama, 1 turn. On success: +1 Green energy, the attacker is marked, and this swaps to Serious Punch.
- **Serious Series: Serious Punch** (`saitama5`, cd0, 3 Green, Uncounterable): **instantly kills** the enemy marked by Side-Hops. Gated on that mark; targets the marked enemy.
- **Serious Series: Omni-Directional Serious Punch** (`saitama7`, hidden swap-in): shatter the enemy team's Shields, then **50 + 25 × (dead allies)** NORMAL to all. Uncounterable/unreflectable.

## Mechanic audit
Every "Buildable" row below is backed by JSON that **validates and runs** (not a hand-wave); the two
"Approximable" rows are what this run built out.

| Skill | Mechanic | Verdict | Notes / blocks |
| --- | --- | --- | --- |
| saitama1 | shatter target Shield | **Buildable** | `break {what:"shield", to:"target"}` |
| saitama1 | 45 single-target damage | **Buildable** | `damage {amount:45, damage_type:"NORMAL"}` |
| saitama2 | AoE shatter + 30 | **Buildable** | same two ops, `target:"all_enemies"` → `to:"target"` resolves to every enemy |
| saitama3 | one skill, **both teams** | **Buildable** | a `group` of per-block **pool** selectors — `to:"all_allies"` block(s) + a `to:"all_enemies"` block, each resolved independently of the click |
| saitama3 | ally cleanse of hostile effects | **Buildable** | `cleanse {to:"all_allies", scope:"hostile"}` |
| saitama3 | ally Invulnerable 1 turn | **Buildable** | `apply {to:"all_allies", effect:{kind:"invulnerable", turns:1}}` |
| saitama3 | enemy "Shattered" 2 turns | **Buildable** | `apply {to:"all_enemies", effect:{kind:"destructible_break"}}` (= `def_negate`) |
| saitama4 | invisible first-Harmful counter | **Buildable** | `apply {effect:{kind:"counter", scope:"harmful", on:"incoming", invisible:true, then:[…]}}` |
| saitama4 | payload: mark **the attacker** | **Buildable** | inside a counter `then`, `to:"target"` = the attacker (`_build_counter` `set_explicit_targets([context.owner])`) |
| saitama4 | payload: +1 Green energy | **Buildable** | `gain_energy {colour:"green", amount:1}` |
| saitama4 | payload: swap to Serious Punch | **Buildable** | `swap {slot, into}` inside the payload |
| saitama4 | counter **excludes** Strategic | **Approximable → BUILT** | inclusion `scope` couldn't subtract a class → added the `exclude` filter |
| saitama5 | usable only while the mark exists | **Buildable** | `requires:[{cond:"has_effect", name:…, effect:"MARK", by:"mine", on:"all_enemies"}]` |
| saitama5 | target the marked enemy | **Buildable** | Layer-1 target `{mode:"enemy", only:[has_effect MARK]}` |
| saitama5 | instant kill | **Buildable** | `execute {to:"target"}` with no `hp_below` |
| saitama7 | AoE shatter + base 50 | **Buildable** | `break` + scaling `damage` |
| saitama7 | **+25 per dead ally** | **Approximable → BUILT** | no reading counted the dead → added the `dead_count` reading |

**Adversarial checks that passed** (the easy places to wave a verdict through): the counter payload's
`to:"target"` genuinely reaches the attacker (`context.owner` is the countered attacker, matching
`saitama4.gd`'s `countered_target = context['owner']`); `saitama3` really is one skill hitting both teams
(each block's pool selector resolves its own population); the mark→kill coupling works with **zero**
`name_override`, because `Effect.effect_name()` falls back to the source ability name and `saitama4`'s name
*is* the mark the `has_effect` gate checks.

## What blocked it — two gaps

### Gap 1 — no reading counts the dead (`saitama7`)
A scaling `damage.amount` (`{base, per, each:<reading>}`) could only read
`READINGS = [stacks, effect_count, alive_count, hp, missing_hp, energy, duration, event]`. **None counts the
dead:** `alive_count` folds `_resolve_targets`, which drops dead/banished everywhere; the dead-keeping
`dead_allies` population lives only in `_legal_pool` (for a block `to`/`revive`), never in a reading's `of`,
and the validator additionally rejected it there. The only faithful reproduction inverts to
`base:100, per:-25, each:{read:"alive_count", of:"other_allies"}` — impossible (`per` is unsigned), and even
signed it would **hardcode a 3-character team** and **mis-count banished allies** (banished ≠ dead, but
`alive_count` drops both). A genuine near-miss.

### Gap 2 — counter/reflect can include a class but not exclude one (`saitama4`)
`saitama4` counters `["Harmful"]` **except** `["Strategic"]`. The engine's `Effect.counter_effect(…,
class_targets, exclude_types)` already takes an exclusion list (honored by `Condition.action_countered`),
but the block `counter` kind exposed only the inclusion `scope` (a disjunction — it can't subtract), and
`_build_counter` hardcoded `exclude_types = []`. Same limitation on `reflect`. So an authored Side-Hops would
**over-counter** Strategic skills the shipped one deliberately lets through — a fidelity loss that no
payload `when` can fix, because `countered()` cancels the skill *before* the payload runs. Proven in-probe
(a Harmful+Strategic skill was driven in and wrongly countered) before the fix.

## Systems built this run

Both are the ledger's recurring shape: **the engine primitive already existed; only the surfacing was
missing.** Neither is a Saitama special-case.

### `dead_count` reading (closes Gap 1)
A new `READINGS` member that counts the **fallen** members of the team named by `of`
(`all_allies` / `other_allies` / `all_enemies`), built straight off the roster (member counts iff
`is_instance_valid && c.dead && !c.banished` — the same predicate as the `dead_allies` revive pool), *not*
through `_resolve_targets` (which drops the dead). `saitama7` becomes
`{base:50, per:25, each:{read:"dead_count", of:"other_allies"}}` — exact, no team-size hardcode, banished
allies correctly excluded (a probe confirms 50 / 75 / 100 for 0 / 1 / 2 dead, and 75 when one of two dead is
banished).

- **Family (bar 1):** reading × team-scope, composes with the same `{base, per, each}` and `compare` shapes as every other reading.
- **Reach (bar 2):** **4/174** by a tight parse-and-read (the loose 24-file grep was ~83 % false positives — target-exclusion filters that scale off the *live* set). Small but real: two consumers (damage *and* energy-gain) across both team polarities.
- **Safety (bar 4):** naturally bounded by team size (≤ 2 other allies); no invented cap. Validator restricts `of` to the three pool scopes (a dead-count over a single/payload selector is a per-hook lie).
- **Prose (bar 5):** "plus 25 **per dead ally**" / "per dead enemy".
- **Engine cost (bar 7):** none — `c.dead`/`c.banished` and the `dead_allies` population already ship. Schema + runner + validator + prose + editor. Probe `creator_dead_count_probe` 20/0, hand-reversed (`c.dead`→`!c.dead` flips exactly the dead-count assertions).

### `exclude` class-filter on `counter` + `reflect` (closes Gap 2)
An optional `exclude` field mirroring `scope`: a scope-name/class-list mapped through the same
`counter_classes()` path to the exclusion argument the engine already reads. **Absent ⇒ `[]` ⇒ byte-for-byte
today's behavior** (a pure additive field; existing authored content and prose are untouched).

- **Family (bar 1):** applies to *both* reactive kinds; `scope` is the inclusion set, `exclude` subtracts from it.
- **Reach (bar 2):** **≈22/174** characters whose shipped counter/reflect excludes a class (adam, mash, nel, saber, tanjiro, rengoku, … saitama) by the exclusion-list signature — a floor pending per-call confirmation, but clearly a sizeable system, far past band-aid.
- **Safety (bar 4):** no new bound; a subtracted class only ever *narrows* what a counter catches.
- **Prose (bar 5):** "counters the first Harmful skill **(except Strategic)**" — guarded so the no-exclude clause is unchanged.
- **Engine cost (bar 7):** none — `counter_effect`/`reflect_effect` already take the exclusion arg. Schema (both kinds) + runner (both `_build_*`) + validator + prose + editor. Probe `creator_counter_exclude_probe` 27/0, hand-reversed on both kinds.

## The create-ability proof
The entire kit was authored as block-tree JSON (id `auth_zz_saitama_roulette`, a `ZZ_` throwaway), run
through the **real** `AuthoredRegistry.validate_character` (**0 errors**, direct + save/load round-trip),
built into an `AuthoredCharacter`, and cast in a headless battle: `saitama1` shatter+45; `saitama2` AoE
shatter+30; `saitama3` both-teams split; `saitama4` counter → attacker marked + Green gained + swap, and
(post-fix) a Harmful+Strategic skill correctly ignored; `saitama5` gated off pre-mark / on post-mark then
instant-kills; `saitama7` 50/75/100 by dead-ally count. `creator_saitama_spec_probe`: **41/0**.

**Residual losses (honest, cosmetic/data only):** `saitama7` is a hidden swap-in absent from
`abilities_data.json`, so its cost/cooldown are author-chosen (mirroring the Serious-Punch family), and its
mandatory scaling `cap` is set to `max_amount` (prose reads "up to 9999", never binds at any legal team
size). These are data-absence fills, not engine limitations.

## Verdict for the roadmap
Both systems shipped this run and both confirm the ledger's through-line one more time: the Creator's
shortfall is **surfacing, not capability**. `dead_count` is a **Value reading** extension (the run-08
system); the counter/reflect `exclude` filter is a new sub-row under **Counters** (and a first hit on
reflect). With them, Saitama is fully buildable at exact behavioral fidelity — the "should be buildable"
instruction is satisfied, and the two gaps are recorded rather than smoothed over.
