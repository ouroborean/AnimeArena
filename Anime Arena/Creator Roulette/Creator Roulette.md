---
tags: [area/playbook, type/howto]
---

# Creator Roulette

A recurring robustness exercise for [[The Creator]]. Draw a **random playable character**, ask
honestly whether their kit could be rebuilt in the block editor as it stands, and where it could not,
design the **open-ended system** that would make it possible — never a special case for that one
character.

The point is not to grade characters. It is to let a random sample tell us where the palette is thin,
instead of us guessing. [[What Cannot Be Built Yet]] was written by surveying the engine top-down;
roulette attacks the same question bottom-up, one real kit at a time, and will surface gaps a
top-down survey rationalises away.

> [!info] The full top-down survey now exists — check it before proposing
> [[Creator Gap Analysis]] (2026-08-03) measures the palette against **all 174 roster characters at
> once** rather than one draw at a time: **7/174 fully expressible today**, a **150/174 ceiling**, a
> cumulative-coverage curve for every proposed item, and an explicit do-not-build tier. It absorbed
> runs 06–08's open ledger entries and **corrected two of them** — Payload addressing must ship as
> **two** selectors (run 06 bound `holder` to the wrong field), and ticking is an **effect kind**,
> not an `on_ticking` row.
>
> This does **not** retire roulette. A run's job is unchanged: a bottom-up draw still catches what a
> survey rationalises away, and a finding that matches a Gap Analysis section is **evidence for its
> priority**, recorded as another row in "Runs served". But check the Gap Analysis's §5 (*What should
> not be built*) before proposing — five items in there look like gaps and are not, and two of them
> are in the census a future run will grep.

> [!tip] The governing rule
> A run fails when it proposes something shaped like the *character* instead of the *mechanic*.
>
> Bad: "add a block that makes every third use of this skill hit all enemies", which describes Frieza's
> Death Beam and nothing else. Good: "authored abilities need **per-skill persistent state** — a
> counter the ability owns, readable by conditions and resettable by its own blocks — which yields
> every-Nth-use, charge-up, escalating-damage and combo-window designs, and serves N other kits."
>
> Note the counter-example, because it cuts the other way: **not every gap is a system.** Some are
> just factories the palette has not exposed — see the tip under [[#The audit]]. Proposing a
> "framework" where one `_build_effect` arm would do is the same failure wearing a nicer coat.

---

## The sampling frame

**174 characters.** Verified: `char_name_list()` in `scripts/character_database.gd` and
`webclient/app/roster.json` contain *identical* sets — 174 each, zero difference in either direction.
Either is authoritative; there is no third list to reconcile.

**Gated is still playable.** A `gate` field (`"frieza_unlock"`, `"omnimon_unlock"`) is an *unlock
condition*, not an exclusion. Frieza is gated and is a fully shipped character. Only `"always"` means
ungated.

**Excluded** are characters with ability scripts that no list references — orphans from removed or
never-finished work. Verified examples: `kakashi` (scripts exist, in neither list — removed from the
roster in a recent commit), `uryuu` (same), `bulbasaur` (no scripts at all).

> [!warning] One correction to the brief
> `omnimon` was named as an example of an excluded character, but it is **in both lists** with
> `gate: "omnimon_unlock"` — an ordinary gated character, exactly like Frieza. It stays in the frame.
> If the intent was to exclude gated characters too, that halves the frame and should be an explicit
> decision — say so and I will re-scope.

```bash
python -c "import io,json,re; s=io.open('scripts/character_database.gd',encoding='utf-8').read(); i=s.index('static func char_name_list()'); print(len(re.findall(r'\"([a-z0-9_]+)\"', s[i:s.index(']',i)])))"
```

---

## The draw

Honesty here is the whole value of the exercise. A roulette I can steer is a roulette that only ever
lands on characters I already know are buildable.

1. **Draw before reading.** The character is named, and the raw draw recorded, *before* any of their
   ability scripts are opened. The page states the draw first.
2. **Use entropy I do not control.** `secrets.randbelow` over the sorted frame, output pasted verbatim.
3. **No re-rolls.** A boring result is a result: "this character is fully buildable today" is
   real evidence about coverage, and gets a short page rather than a re-draw. The only legitimate
   re-draw is a character already covered by an earlier run, and the superseded draw is still recorded.

```bash
python -c "import secrets,io,re; s=io.open('scripts/character_database.gd',encoding='utf-8').read(); i=s.index('static func char_name_list()'); n=sorted(re.findall(r'\"([a-z0-9_]+)\"', s[i:s.index(']',i)])); k=secrets.randbelow(len(n)); print('draw %d/%d -> %s' % (k, len(n), n[k]))"
```

---

## The audit

For the drawn character, read **every** ability script — including passives and hidden swap-in slots,
which is where the un-buildable mechanics usually hide.

Decompose each skill into discrete **mechanics**, then classify each one:

| Verdict | Meaning |
| --- | --- |
| **Buildable** | Expressible with today's palette at full fidelity. Cite the blocks. |
| **Approximable** | A block combination gets close but loses something real. State exactly what is lost — this is the most interesting verdict and the easiest to wave through dishonestly. |
| **Blocked** | No combination reaches it. Name the specific missing capability. |

Then the whole character gets one of: **Fully buildable** / **Buildable with fidelity loss** /
**Blocked**, with the blocking mechanics listed.

> [!warning] Trap: the flattering approximation
> Before writing "approximable", name the block list that does it and check it against
> [[Block Palette Reference]] and the reactive-payload limits. If you cannot write the JSON, the
> verdict is **Blocked**. A mark is not a substitute for a status effect: blocks only run inside the
> authoring character's own skills, so nothing an author writes gates an *opponent's* action.

> [!tip] The opposite trap: inflating a missing effect into a "system"
> Most control effects are **not** deep design problems — they are effect factories the palette simply
> has not exposed yet. `Effect.stun_effect(dur, class_targets, exclude_targets)` has the same
> signature shape as `Effect.invuln_effect`, which the Creator **already ships**, and `_op_apply`
> already builds and applies hostile effects generically. Adding Stun is one `_build_effect` match
> arm, one schema entry and one validator limit.
>
> So the design bar below is a filter against *band-aids*, not a demand that every gap become a
> framework. When the honest answer is "expose this factory the same way the existing ones are
> exposed", say that. Point 1 is satisfied by an effect *family* only where one genuinely exists
> (durations, escape conditions, immunity classes) — not by inventing abstraction for its own sake.

Mechanics worth checking every time, because they recur — see [[What Cannot Be Built Yet]].
**This list was rewritten in run 06:** most of it had shipped and was still being audited as missing.

| Mechanic | Status |
| --- | --- |
| Control effects (stun / silence / paralyze / taunt) | **shipped** as effect kinds. Isolate and banish are still missing. Run 08: **banish is an `OPS` row, not an `EFFECT_KINDS` row** — the engine reads the raw `Character.banished` bool and `is_banished()` has zero callers, so a `_build_effect` arm would build an inert effect. **5/174**, and its validator rule (no pool selectors) has to be designed *before* the factory is wired, because `banish all_enemies` is an instant Victory |
| Ability swaps and transforms | **shipped** (`swap`). Reading *which* skill is in a slot is not |
| Cost and cooldown modification | **shipped** (`cost_change`, `cooldown_change`), with named-skill and colour filters. Run 07: *swapping* one colour **for** another (COLOR_CHANGE) is a different mechanic and is **not** exposed — `cost_change` only adds/subtracts, and the obvious `−1/+1` pair diverges whenever the colour is already 0 or the cost is not exactly 1 |
| Counters and reflects | `counter` **shipped**; reflect is not |
| **Main-target-vs-splash** | primitive still missing, but **approximable** since run 06 via the marker-exclusion idiom — with five named losses. Do not audit it as flatly blocked |
| Damage that scales off live state | still missing — **run 08 measured it at 43/174 (25%) and promoted it to the system ledger as *Value reading***. Do not re-audit it as an unmeasured row |
| Per-team resource pools | still missing |
| Usage gating beyond a cooldown | `requires` conditions **shipped**; `max_uses` is not |
| **Which trigger hook a payload hangs on, and who it can name** | the run-06 gap: `on_ticking` absent, no selector for the effect's holder |

---

## The design bar

A proposed system has to clear **all** of these. Any it fails, redesign it.

1. **It is a family, not an effect.** Parameterised along at least two independent axes, so that
   several named mechanics fall out of one block rather than one mechanic being hardcoded.
2. **Measured reach.** Grep the roster and state how many *other* characters the system unlocks or
   improves, with real counts. A system serving one character is a band-aid by definition.
3. **It composes.** Works with existing selectors, conditions, `group`, and nested reactive payloads
   — not a parallel mechanism with its own rules.
4. **It has a safety story.** Concrete validator limits (magnitude, duration, stacking, how many per
   ability) and the abuse case they prevent. Balance guards, not moral ones: the bar is "can a player
   build something degenerate", not "is this effect scary". Check [[Creator Roadmap]] for the few
   genuinely deferred items and why.
5. **It generates prose.** `split_desc()` is auto-derived, so a new block must produce readable
   English. If its behaviour cannot be described in one clause, it is too complex for a player to
   reason about.
6. **It has a bot story.** Which `bot_tags` bit, and whether `bot_damage_hint()` needs to see it.
   Otherwise bots play the authored character blind — see [[Bots and Training]].
7. **It states its engine cost.** Which of `blocks/block_schema.gd`, `block_validator.gd`,
   `block_runner.gd` and the editor UI change, and whether any *engine* primitive is missing (some
   mechanics need work in `scripts/effect_component.gd` first).

---

## Page template

Each run becomes `Creator Roulette/Roulette NN - <Character>.md`, tagged
`[area/playbook, type/reference]`, following this shape:

```markdown
# Roulette NN - <Character Name>

**Draw:** <raw command output>       **Universe:** ...   **Gate:** ...
**Verdict:** Fully buildable | Buildable with fidelity loss | Blocked

## The kit
One line per skill: what it actually does, from the script.

## Mechanic audit
| Skill | Mechanic | Verdict | Notes |

## What blocks it
Per blocked mechanic: what it needs, and why no block combination reaches it.

## Proposed system: <name>
The family, its axes, the JSON shape, validator limits, reach (measured),
prose generation, bot tags, engine cost. Against the seven-point bar.

## Reach
Which other roster characters this unlocks — measured, with the grep.

## Verdict for the roadmap
Which phase of [[Creator Roadmap]] this belongs in, or why it should not be built.
```

---

## Run ledger

| # | Character | Universe | Verdict | System proposed |
| --- | --- | --- | --- | --- |
| [[Roulette 01 - Naruto Uzumaki]] | Naruto Uzumaki | Naruto | **Blocked** (4/9 mechanics) | Action Restriction · Filtered removal · (energy colour) |
| [[Roulette 02 - Death the Kid]] | Death the Kid | Soul Eater | **Blocked** (7/10 mechanics) | Ability Swap · Relational conditions · (on_skill_used trigger) |
| [[Roulette 03 - Sailor Mercury]] | Sailor Mercury | Sailor Moon | **Buildable with fidelity loss** (6/11 buildable) | Counters · *(3rd hit on Action Restriction)* |
| [[Roulette 04 - Superbi Squalo]] | Superbi Squalo | Katekyo Hitman Reborn | **Buildable with fidelity loss** (6/9 buildable) | Defence destruction · `bypassing` field · **corrected runs 01-03** |
| [[Roulette 05 - Shiro]] | Shiro | Deadman Wonderland | **Blocked** (6/13 buildable) | **Stacks as a resource** · Channels · (taunt, effect-immunity, boost filter) |
| [[Roulette 06 - Boruto Uzumaki]] | Uzumaki Boruto | Naruto | **Blocked** (15/31 buildable, 9 approximable) | **Payload addressing** · (`on_ticking` row → system D) · **re-measured the whole ledger** |
| [[Roulette 07 - Levi Ackerman]] | Levi Ackerman | Attack on Titan | **Buildable with fidelity loss** (11/15 buildable, 1 approximable) | **none** — two rows and a field · second hit on Payload addressing · **probed a live `on_damage_dealt` defect** · *self-authored kit* |
| [[Roulette 08 - Semiramis]] | Semiramis | Fate | **Blocked** (10/26 buildable, 3 approximable, 13 blocked) | **Value reading** *(promoted from the recurring table, first measured at 43/174)* · third hit on Payload addressing · banish adjudicated as an **`OPS` row**, state conditions **split** |
| [[Roulette 09 - Saitama]] | Saitama | One Punch Man | **Fully buildable** *(after this run built 2 systems; 4/6 exact as drawn, 2 near-misses)* | **`dead_count` reading** · **counter/reflect `exclude` class-filter** — BOTH BUILT this run · the whole 6-skill kit was then **authored as block JSON and proven** (real `validate_character` 0 errors, headless battle 41/0) · first run against a *complete* Creator |
| [[Roulette 10 - LadyDevimon]] | LadyDevimon | Digimon | **Fully buildable** *(after this run built 1 system; 4/5 exact as drawn, 1 near-miss)* | **Signed + damage-type-filterable `damage_boost`** (hostile weaken + include/exclude damage types) — BUILT this run, and the fix surfaced & killed an **inverted `HOSTILE_BY_SIGN` polarity bug** (a negative weaken was routing allied, bypassing invuln) · full 5-skill kit **authored & proven** (validate 0 errors, headless 39/0) |
| [[Roulette 11 - Nonon Jakuzure]] | Nonon Jakuzure | Kill la Kill | **Fully buildable** *(after this run built 2 systems; 3/5 exact as drawn, 2 near-misses)* | **Damage-type-filtered `vulnerability`** (reuse of R10's filter machinery) · **`bypass_when`** — per-candidate conditional invuln-bypass TARGETING, the first conditional targeting-reach primitive · the adversarial pass also caught a **stale `damage_boost` hostility oracle** R10 left in `creator_hardening_a2a4` · full 5-skill kit **authored & proven** (validate 0 errors, headless 35/0) |

## Proposed-system ledger

Systems accumulate across runs. Before proposing a new one, check whether an existing entry already
covers the mechanic — a second run landing on the same need is **evidence for that system's
priority**, recorded as another row in "Runs served", not a new proposal.

> [!danger] Statuses corrected in run 06 — most of this table had already SHIPPED
> Eight of the ten original rows still read "proposed" for systems that are live in
> `blocks/block_schema.gd` today. Run 06 hit three of them (`break`, `swap`, `cost_change.skills`) as
> *working* palette entries while auditing a character, which is how the drift was caught. Reach
> numbers were re-measured at the same time with the roster intersection below — **two were
> inflated, two were under-counted**. The page says the ledger gets amended rather than defended.

| System | Axes | Runs served | Reach (re-measured, run 06) | Status |
| --- | --- | --- | --- | --- |
| **Payload addressing** | role (`holder` / tripper / applier) × hook | 06, 07, **08** | **29/174 floor — 65/174 loose** *(run 08 sub-measure: **13/174** write an explicit `context['effect'].target` holder reference inside a callback, + 4/174 deriving the acting team — a ≥17/174 floor by two independent idioms)* | **proposed** — the ledger's **first** open system; ships with the `on_ticking` row or the row ships broken. Run 07 hit it twice (`on_kill` binding + the **probed** `on_damage_dealt` defect); run 08 hit it a third time — `semiramis2` plants two payloads on an enemy and neither can name the holder |
| **Value reading** *(new, run 08 — promoted from the recurring-mechanics table, not invented)* | reading (`effect_count` / `effect_mag_sum` / `stacks` / `alive_count` / `hp` / **`dead_count`**) × consumer (a `compare` value · an `{"base","per","each"}` amount form) | 08, **09** | **43/174 (25%)** — buckets: stack/mark read 23, effect count 7, magnitude sum 7, character count 6 · run-09 sub-measure: **`dead_count` 4/174** | **proposed → partly SHIPPED (run 09).** Largest measured gap in the corpus; no engine primitive missing. **Absorbs three previously separate items:** `break`'s report sub-row (the return is a *magnitude*, not a count, so wiring it through is the wrong fix), the type-presence predicate (`effect_count >= 1`), and the repeat-N half of `semiramis3`. Its one real cost beyond the palette is **`bot_damage_hint()`**, which must resolve a reading or bots undervalue every scaling skill. **Run 09 shipped the `dead_count` member** (counts the fallen of a team scope, straight off the roster — the one count no live selector can spell, since every other read folds `_resolve_targets` which drops the dead); reach a tight 4/174, closes `saitama7` |
| **Channels** | break condition × carried effects | 05 | **18/174 (10%)** *(was 15)* | **proposed** — the only other genuinely unbuilt row; build the cancel list from APPLIED effects (known crash shape) |
| **Action Restriction** *(scope reduced, run 04)* | cost × cooldown × **exclude-class** filter × named-skill filter | 01, 02, 03 | 127/174 gross — **retire this figure** | **mostly shipped** — stun / silence / paralyze / taunt / `cost_change` / `cooldown_change` are all live kinds. Net remainder is the exclude-class filter and `ignore_skill` only |
| **Stacks as a resource** | declare × add × spend × read × max | 05 | **42/174 (24%)** *(was 81 — halved)* | **shipped** — `mark`.`stacks`/`max`/`show_stacks` + `remove` with a stack count. ⚠ the 81 propagated into `block_schema.gd:103-104`; correct that comment |
| **Ability Swap** | slot × replacement × duration × revert condition | 02, 06 | **74/174 (43%)** *(was 82 — non-roster stems)* | **shipped** — the `swap` kind + `spec_swap_duration`. Open sub-row: `slot_holds`, the *read* half (4/174) |
| **Filtered effect removal** | scope × name × count **(× type — run 08)** | 01, **08** | 71/174 (41%) | **shipped** — `cleanse` (name/scope/count) + the `remove` op. Open sub-row from run 08: **a 4th axis, TYPE**. `remove` requires a non-empty `name`, so "strip every Invulnerability on the target" is unauthorable. **8/174**, ~7 lines (require `name` OR `effect`), no engine work; borrow `cleanse`'s `count` as the bound, because `remove` deliberately carries none of the cleanse mechanic. 6/174 more want a *finer* axis (source object, or `damage_type` inside `DAMAGE`) that this does not reach |
| **Conditional targeting reach** *(new, run 11)* | any eligibility condition × the per-candidate invuln-bypass flag | **11** | **8/174** (crona, ganta, gasai, maka, minene, nonon, omnimon, tamaki) | **shipped (run 11)** — `bypass_when`, a condition on the Layer-1 target object evaluated PER CANDIDATE (through the same `check_condition_public` as `only`), so "bypass invuln only against enemies in state X" is authorable. Layer-1 previously computed one all-or-nothing bypass for the whole ability. Absent = byte-identical; no engine primitive missing. Closes `nonon3`'s mark-gated bypass targeting |
| **Damage-type-filtered `vulnerability`** *(new, run 11 — extends R10's filter family)* | damage-type (include / exclude) | **11** | **5/174** (ganta, gunha, korra, kurotsuchi, nonon) | **shipped (run 11)** — `vulnerability` gains `include_types`/`exclude_types` wired to `vulnerability_effect`'s existing `class_targets`/`exclusion_targets`, REUSING R10's `damage_boost` helpers (editor is data-driven, so no app.js change). No sign axis (vulnerability is always hostile+positive). Closes `nonon1` |
| **Damage-dealt modification** *(widened run 10)* | sign (boost / **weaken**) × damage-type (**include / exclude**) | **10** | **≈26/174** (19 hostile-weaken + 19 type-filtered) | **shipped (run 10)** — `damage_boost` was allied-only & unfiltered; run 10 made it signed (negative = a HOSTILE weaken, via `SIGN_HOSTILE_WHEN_NEGATIVE` — added after the adversarial pass caught the first cut routing a negative weaken ALLIED, bypassing invuln/shrug-off) + `include_types`/`exclude_types` wired to `damage_mod_effect`'s existing `class_targets`/`exclusion_targets` (both damage-type lists; `type_targets` is dead). Closes `ladydevimon3`; no engine primitive missing |
| **Counters** | scope × **exclude-class** × charges × visibility × payload | 03, **09** | 40/174 (23%) | **shipped** — the `counter` kind + `COUNTER_SCOPES`. **Run 09 added the `exclude` class-filter** to `counter` AND `reflect` (the inclusion `scope` is a disjunction and could not *subtract* a class; the engine's `counter_effect(…, exclude_types)` arg was hardcoded `[]`). Absent ⇒ `[]` ⇒ byte-identical to before. Reach **≈22/174** counters/reflects that exclude a class (adam, mash, nel, saber, tanjiro, rengoku, … saitama); closes `saitama4`'s "Harmful except Strategic" and is a first hit on `reflect` |
| **Relational conditions** | measured value × comparison × selector | 02, **08** | **35/174 (20%)** *(was 49)* | **shipped** — `compare` + `COMPARE_VALUES`. Open sub-row from run 08: **derived-status predicates** (`is_invulnerable` / `is_stunned` / `is_silenced` / `defence_broken`) — `CONDITIONS` matches effects by NAME and `effect_name()` falls back to the granting ability, so "is this character Invulnerable" is unaskable. **~14/174 as a family, 6/174 for invuln branches.** Must call the engine predicate (`Condition.is_invuln(candidate, runner.ability)` — BlockRunner already holds `ability`); a bare INVULN type-scan answers 3/174 right and 3/174 **wrong**. The *counting* half of this shape is not here — it belongs to **Value reading** |
| **Defence destruction** | shield / barrier × selector | 04, 06, **08** | 9/174 (5%) | **shipped** — the `break` op + `BREAK_TARGETS`; boruto7 uses it. ~~Open sub-row: `break` cannot *report* what it destroyed (2/174)~~ — **run 08 re-scoped it**: 2/174 confirmed as return-value readers, but `shatter_shields`/`shatter_barrier` return the summed **MAGNITUDE**, not a count (`character_component.gd:1871-1891`), so `blackwargreymon3` and `semiramis3` both count *before* shattering and wiring the return through would give them the wrong number. **Folded into Value reading**, not a separate build |
| *Energy colour* | colour | 01, **07** | **25/174 (14%)** *(was 8 — tripled)* | **shipped** — `COST_COLOURS` / `GAIN_COLOURS`. Still a field, not a system. Open sub-rows from run 07: **COLOR_CHANGE** (swap one colour *for* another, `Effect.color_change_effect`) **8/174**, one `EFFECT_KINDS` row + one `_build_effect` arm, no engine work; and **`refresh`** 15/174 gross / 11/174 load-bearing — **do not build**, it buys nothing for the mechanic that raised it |
| *Trigger-hook coverage* (run 02's system D) | — | 02, 06, 07, **08** | **`on_ticking` 53/174 (30%)** · `on_harmful_used` 15/174 · **`on_kill` 2/174** | `on_skill_used` **shipped**; **`on_ticking` is the open row** — the most-used hook in the corpus, while `on_turn_start` (7/174) shipped. Run 07's `on_kill` is a sub-row at **2/174** (one of the two is the run's own self-authored kit) and is **ergonomics only** — the shipped `on_death` row already reaches the mechanic (`check_death_triggers` sets `owner = killer`, `character_component.gd:1459-1466`, and runs before the death cleanse), probed 12/12. Run 07 first called this Blocked; it is Approximable. **Run 08 adds a second gate on `on_ticking`:** `last_turn_only` is **inert on a trigger** (below), so the row must ship with the `battle_manager.gd:1255` guard or the editor's obvious "fires once, at the end" checkbox does nothing while the prose promises it |

**Boundaries found** (not backlog items):

| Boundary | Run | Why |
| --- | --- | --- |
| Cross-character passives that drive another character's skills | 02 | Kid's *Partners: Liz and Patty* reaches into the Thompson sisters' ability list and cooldowns. Authors cannot name or drive skills they do not own — a deliberate property of the authoring model, not a missing block. |

> [!success] Already buildable — check a mechanic against these before proposing anything
> **Run 03 — own-state branching.** Mark yourself, branch other skills on that mark: `has_effect` /
> `not_has_effect` on `"user"` plus a `group` per branch. **77/174 characters (44%)** use it.
>
> **Run 06 — the invisible-mark latch.** `apply` + `when` and `remove` both run inside one
> `execute()`, so an author can **snapshot any expressible condition before a mutating op** and
> consume it after, with no value-returning op and without reordering the visible effects. That
> answers the whole "but the test has to happen before the break" class of problems.
>
> **Run 06 — marker exclusion.** A `to: "any_enemy"` + `not_has_effect` pair means "every enemy
> except the marked one", because a filtered selector's `when` is evaluated per candidate. That
> reaches main-target-vs-splash today, at the cost of five named fidelity losses.

> [!warning] Trap found in run 06: the *layered* main-vs-splash workaround
> "Deal 10 to `all_enemies`, then 10 more to `target`" looks equivalent to "20 to the primary, 10 to
> the rest". It is not: the main target takes **two** `resolve_damage` calls, so reduction, the
> minimum-damage floor and any boost apply twice, receive-triggers fire twice, and shields absorb per
> instance. It also cannot express "same damage, different rider" (`mash2`). If a run reports
> main-vs-splash as approximable it must specify the **marker** form.

> [!info] The through-line, rewritten after run 06
> **Superseded:** "the palette handles one-shot effects well and persistent state not at all" was
> true through run 05 and is now **out of date** — `stacks`, `swap`, `counter` and `compare` all
> shipped, which is exactly the shortfall it described.
>
> **Run 06's, still true and now hit three times:** the palette can hold state and **cannot reliably
> point at anybody** except the caster and whoever just acted. Boruto's kit is entirely persistent
> state and every piece of the *state* machinery was present; what blocked him was **addressing and
> timing inside a payload** — which hook fires, and who the payload can name once it does. `holder`,
> `main_target` and `on_ticking` are all the same question, "who / which / when".
>
> **Run 08 says that is now INCOMPLETE, and adds the second half.** Semiramis's hardest skill is not
> blocked on *who* — `semiramis3` names its targets perfectly well. It is blocked on **how many**:
> strip, count, scale. The palette has no way to read a number off live state and put it anywhere, and
> that gap measures **43/174**, larger than any addressing number in the ledger. `has_effect_type`,
> which run 06 filed under "which", turns out to belong here: it is `effect_count >= 1`.
>
> **So weigh new proposals against two questions, not one: "who" (Payload addressing) and "how many"
> (Value reading).** "What" is still not the gap, and Semiramis is unusually clean evidence: every
> effect in her kit is a shipped effect kind except banish, and banish's factory has existed all
> along. Eight runs in, the Creator's shortfall is **surfacing**, not **capability** — see the ledger
> note below, which run 08 also confirms with no exceptions.

> [!danger] The palette was misread for three runs — check the table, do not grep it
> Runs 01-03 treated `stun` as missing. It is in `EFFECT_KINDS`, wired to
> `Effect.stun_effect(dur, classes, exclude_classes)`, alongside `silence` and `vulnerability`. The
> cause was a `sort -u | head -60` scout that truncated the effect table.
>
> **Before any run, read `blocks/block_schema.gd` in full** — all of it, not just the effect table.
> As of run 06 that is 20 `EFFECT_KINDS`, 8 `OPS`, 7 `CONDITIONS`, 7 `SELECTORS` + 3
> `FILTERED_SELECTORS`, 7 `TRIGGERS`, 24 `UNIVERSAL_EFFECT_FIELDS`, plus `COUNTER_SCOPES`,
> `COST_COLOURS`, `BREAK_TARGETS` and `LIMITS`. 471 lines, and the comments carry the reasoning.
> Then read `block_validator.gd` for what it **rejects** and `block_runner.gd` for what it
> **actually does** — the schema is not the whole truth (see the next callout). Never infer the
> palette from a grep.

> [!warning] A kind in the schema can still be unreachable — check the reader, not the entry
> Run 06 found that **`trigger_once`** is advertised in `UNIVERSAL_EFFECT_FIELDS` and does
> **nothing**: its only reader, `Effect.trigger_check` (`scripts/effect_component.gd:123-131`), has
> zero callers repo-wide, and `Effect.triggered` is never set true by the engine. An author who ticks
> "trigger once" gets a trigger that fires every time. An "approximable" verdict whose JSON leans on
> a field like that is a **Blocked** verdict.
>
> The rule cuts both ways, and run 06 broke it on its first attempt: it also called
> `remove_once_triggered` and `full_remove_once_triggered` dead. They are **live** —
> `scripts/character_component.gd:1677-1679` consumes an `IGNORE_DAMAGE` effect the first time it
> blocks, so a one-shot damage negate *is* authorable (`kurapika4.gd` ships it). Grepping for a
> field's *name* found the schema entry and missed the reader. Grep for the reader.
>
> **Run 08 found a third variant, and it is the nastiest: a field that is live for ONE kind and inert
> for every other.** `last_turn_only` ("fires once, on its final tick", `block_schema.gd:219`) has
> exactly two readers, `new multiplayer/battle_manager.gd:831` and `:1234` — and `:1234` sits *inside*
> `if effect.effect_type == EffectType.Type.DAMAGE:` at `:1231`. The `TICKING_TRIGGER` branch at
> `:1255-1263` never consults it. It looks alive because `block_runner.gd:594-595` sets it itself for
> a `delayed` DoT. **The corpus already distrusts it:** 8/174 set it, 3 of those on a
> `TICKING_TRIGGER` where it does nothing (`mavis1`, `lyserg5`, `yoh6`) — and all three hand-guard
> `duration != 1` in the callback anyway. Check the reader's *enclosing branch*, not just that a
> reader exists.
>
> **And the mirror of the `trigger_once` finding, measured in run 08:** `trigger_once = true` is set
> by **0/174** shipped abilities, so removing the dead row costs nothing; `remove_once_triggered =
> true` is **1/174** (`kurapika`), confirming run 06's correction.

> [!danger] Authored AoE damage ignores Invulnerability — a live defect (run 06)
> `BlockRunner._filtered_pool` returns the raw team filtered only by `_alive`
> (`block_runner.gd:156-176`), while a shipped script's `targeter.targets` was already stripped of
> invulnerable enemies by `_drop_invuln_targets` (`battle_manager.gd:1150-1175`) — and
> `Character.resolve_damage` never checks invulnerability itself. **Probed, not reasoned:** an
> invulnerable enemy took a full-strength hit from exactly what a `damage` op runs
> (`HP 100 -> 80`).
>
> So `damage` to `target` respects Invulnerability, `damage` to `all_enemies` / `any_enemy` /
> `random_enemy` does **not**, and `apply` does (via `can_apply_hostile_effect`). Any two-block
> authored skill beats a core defensive mechanic today. **This is a fix, not a feature** — treat it
> as ahead of new palette work, and do not quote the marker-exclusion idiom as pool-identical to a
> shipped AoE until it lands.

> [!danger] An `on_damage_dealt` payload hits its own holder, and re-enters until he dies (run 07)
> The second shipped-palette defect, and this one is **probed, not reasoned** (7/7 assertions).
> `check_damage_dealt_triggers` runs on the **dealer** with the victim in `context.target`
> (`character_component.gd:692`, `:1261`), while `BlockRunner._build_trigger` binds the payload's
> `target` selector to `context.owner` — the dealer. Measured:
>
> | Authored payload | What happened |
> |---|---|
> | `apply` a mark `to: "target"` | the **holder** was marked; the character actually damaged was not |
> | `damage 10` `to: "target"` | the holder damaged **himself**, which re-fired the same hook — `HP 100 -> 0` from a 10-damage payload |
>
> The generated prose ("when they deal damage") promises the opposite. Four of the seven shipped
> hooks bind correctly; three are self-held and harmlessly degenerate; **`on_damage_dealt` is
> wrong**, and it is a player-reachable self-kill in two blocks. It is part of **Payload
> addressing**'s `_build_trigger` change, not a separate item.

> [!warning] A wrong comment in `block_schema.gd` that a future run must not inherit (run 07)
> `block_schema.gd:266-268` excludes the whole `MISSION_TRIGGER_*` family from `immunity_effects()`
> as "mission/achievement bookkeeping hooks, not battle effects a character could meaningfully
> resist or would ever hand-remove". **Both halves are false.** Of the 26 enum members, **15 are
> dispatched by battle code** in `scripts/character_component.gd` and run every battle regardless of
> missions; **three are core gameplay on shipped characters** — `ON_KILL` (`levi5`), `ON_STUN`
> (`horohoro4`, which also *reads it back as a usability gate*) and `ON_INVULN` (`nel3`, applied
> **hostile** to every enemy, so `shrug_off_type` genuinely applies). The other 11 have no dispatcher
> at all. The exclusion should key on "has no dispatcher", not on the name prefix — the same mistake
> the file's own comment records having made once before with the nine-name whitelist.
>
> **Do not inflate it:** the measured reach of fixing it is **0/174** (nothing immunises against one
> today, and `remove` already matches by name without the type). It is a ~10-line
> correctness-and-comment fix whose value is preventing the next wrong inference, and it costs
> editing two green probes that currently assert the exclusion as desired behaviour.

> [!warning] Measurement hygiene — and the one step that was missing
> Two runs produced inflated reach numbers from loose greps over the 1,020-file `abilities/` corpus
> (run 02: 118/174; run 03: 141/174). Both were discarded. Prefer a grep for the specific
> `Effect.<factory>(` call over anything structural, and state the tight number.
>
> Run 06 found the *other* half of the problem: a filename stem is not a roster character.
> **Always intersect with the 174-name roster** — that alone moved Ability Swap from 82 to 74, and it
> is why the numbers in the ledger above changed without any code changing.
>
> ```bash
> sed -n '5,178p' scripts/character_database.gd | sed 's/[\t",]//g' | awk 'NF' | sort > chars.txt
> cd abilities && grep -l '<PATTERN>' *.gd | sed 's#\.gd$##; s#[0-9]*$##' | sort -u \
>   | comm -12 - ../chars.txt | wc -l
> ```
>
> The stems that keep sneaking in: `jinwoo{blue,green,red,white}` (one roster entry's summon forms),
> `{genos,natsu,noelle,zoro}temp`, `old`, `lizandpattyold`, `vessel`, `kakashi`, `uryu`.
>
> Also state a **false-positive rate** when a number comes from a structural grep. Run 06's two
> highest raw counts both collapsed on inspection: `wrapup_func` read 64/174 but 44 of those assign
> only the cosmetic engine default (**69% FP**, corrected to 20), and `context['target']` read 65/174
> but half were self-held payloads the `user` selector already reaches (corrected to a 29 floor).
>
> **Run 07 adds two more failure modes, both of which moved a number DOWN.** (a) A bare `-1`
> argument is not necessarily a duration: `cost_mod_effect(-1, dur, …)` passes it as the *magnitude*
> and `reflect_effect(…, -1, …)` as the *target* or *count*, so "permanent duration" read 129/174
> naively and **127/174** against a per-factory duration-position table (5.7% call-site FP).
> (b) **Grep for the assignment, not the name** — `grep -l stack_mag` reads 27/174, but three of the
> hits are `stack_mag = false` and two comments, one of which literally says *"stack_mag is
> deliberately NOT set"*. Tight is **25/174**. A grep that counts a comment denying a field as a use
> of it is the same class of error as grepping the schema instead of the reader.
>
> **Run 08 adds two more, and one of them moved a number UP — the first time that has happened.**
>
> (c) **Attribute by ENCLOSING FUNCTION, or every state-predicate number is wrong.**
> `custom_behavior` is the bot-scoring hook, and an authored character gets its bot behaviour
> *generated* from its blocks — so a predicate appearing only there is **not evidence of a palette
> gap at all**. `is_isolated` reads **13/174** raw and **1/174** as a gameplay branch (**92% FP**:
> eight `custom_behavior` hints, one comment, three alive-filters). `is_invuln` reads 40/174 raw and
> **6/174** as a branch, the bulk being target-eligibility filters hand-re-implementing the invuln
> drop. The tool is `awk '/^func /{f=$2} /PATTERN/{print FILENAME, f}'`.
>
> (d) **An idiom-shaped grep can UNDER-count as badly as a structural one over-counts.** Run 08's
> audit measured "damage scaled off live state" at 22/174 by grepping the `<var> += 1` counter
> idiom. The real figure is **43/174**: most shipped kits never write a counter, they read
> `.stacks`/`.mag` inline (`base_damage + 5 * eff.stacks`). No single regex reproduces it — the
> counter idiom finds three of the four buckets, the inline idiom finds the fourth, and the bare
> structural sweep reads 98/174 at **56% FP**. When the buckets disagree, the method is *parse the
> call, trace the argument, then open every survivor* — and say so.
>
> Two more run-08 corrections in the same spirit, both of which found the earlier pass had measured a
> narrower thing than it claimed: `remove`-by-type read 4/174 because the sweep missed the engine's
> own `full_remove_effect_by_type()` API (real: **8/174**), and turn-order awareness read 3/174 with
> the claim "all three are banish-duration corrections" — it is **6/174** and three of them have no
> banish in them. Also: never quote a `banish` word-grep. The string appears in **87/174**
> characters, a **94% FP rate**, because almost all of them are `not (character.dead or
> character.banished)` target filters; the tight pattern is `banish_character\(` at **5/174**.

> [!info] Ledger note — confirmed, five runs later
> Run 01 needed no new engine primitives at all: every factory already existed, already parameterised
> on the axis the palette failed to expose. **Run 06 lands in the same place for every one of its
> findings** — the `TICKING_TRIGGER` hook is an enum row, invuln-bypass targeting is an argument that
> has always been there, the type condition reuses a derivation the palette already ships, and even
> the proposed system needs no engine work because `QueryContext.target` is set on every hook today.
> The Creator's gap is **surfacing**, not **capability**. Treat any proposal that claims otherwise
> with suspicion, and check the engine call site before believing it.
>
> One striking illustration: `ABILITY_FLAGS` exposes `accurate`, which **zero** shipped abilities
> set, and withholds the invulnerability-bypass targeting parameter that **33 of 174** use. (Run 08
> re-measured that 33 independently and reproduced it **exactly** — the best available check that the
> roster-intersection method is stable.)
>
> **Run 08 confirms the note again, with one honest exception and one new illustration.** Every gap
> it found needs no engine primitive: `banish_character`, `get_effects_by_type`, `stack_count()`,
> `Condition.is_invuln` and `full_remove_effect_by_type` all ship today. The **exception** is that
> "no missing primitive" is not the same as "no engine work": a banish op needs the win-condition
> safety rule designed first (`banish all_enemies` is an instant Victory), and the `on_ticking` row
> needs a one-line guard at `battle_manager.gd:1255`. The new illustration is the mirror of the
> `accurate` one — `tick_during_banish` is exposed as a universal field with **1/174** users, while
> the verb it modifies is not exposed at all.

---

## What this will probably involve

Speculation, to be corrected by contact with real draws.

**Most draws will be Blocked, and early runs will pile onto a few systems.** The palette is 6 ops and
13 effect kinds against an engine with 90+ effect types. Control effects and ability swaps are so
common in the roster that the first several runs will likely all need one or both. That is a useful
signal about ordering, not a reason to stop drawing — but it means the *proposed-system ledger*
matters more than any single page, and runs 4-10 will be more valuable than runs 1-3.

**The interesting runs are the near-misses.** A character who is 90% buildable and fails on one
clause tells us more than one who needs six new systems. Expect to spend the most effort on the
Approximable verdicts, where the temptation to declare victory is strongest.

**Very few characters should be ruled un-authorable.** Instant kill, execution and ability copying
are ordinary in-game outcomes and belong in the Creator like anything else — an earlier draft of these
notes wrongly called them unsafe. The remaining "no"s are narrow and technical: skill copy needs an
identity fix first (`Effect.copy_effect` reads a script path an authored ability does not have), and
Toga's name-driven disguise is not worth the surface. If a run wants to conclude "cannot be
authored", the burden is on the run to show a real blocker rather than a squeamish one.

**Preparation this needs:**
- A fast way to dump a character's full kit — every script, plus the `abilities_data.json` rows for
  costs, cooldowns, classes and target types. The audit is only as good as its reading of the kit.
- A reach-measuring grep per proposed mechanic, so point 2 of the bar is a number and not a feeling.
- Familiarity with the current palette limits, or "approximable" claims drift out of date as the
  Creator grows. Re-read [[Block Palette Reference]] at the start of each run; a mechanic blocked in
  run 2 may be buildable by run 7.
- Willingness to record an unflattering result. If a run shows a system proposed earlier was the
  wrong shape, the ledger gets amended rather than defended.

**Verification, when a proposal is actually built:** the normal loop in [[Verification Playbook]] —
a headless probe under `training/tests/`, then revert the change by hand and confirm the probe fails.
Never `git checkout`/`restore`/`reset`/`stash`; see [[Hard Rules and Guardrails]].

---

Related: [[The Creator]] · [[Block Palette Reference]] · [[Creator Gap Analysis]] ·
[[What Cannot Be Built Yet]] · [[Ticking and Passives]] ·
[[Creator Roadmap]] · [[Adding a Playable Character]]
