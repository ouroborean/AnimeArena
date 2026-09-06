---
tags: [area/systems, type/reference]
---

# Creator Gap Analysis

The top-down survey the [[Creator Roulette]] process page has been asking for: **every mechanic the
shipped roster uses that the block palette cannot express**, measured against all 174 roster
characters at once rather than one draw at a time.

[[What Cannot Be Built Yet]] surveys effect *factories*. [[Ticking and Passives]] surveys the two
mechanics that are not factories. This note surveys the **whole corpus** and answers a different
question: not "which factories are missing" but **"how much of the game can a player build, and what
is the shortest path to more of it"**.

Read [[Block Palette Reference]] for what ships today. [[Creator Roadmap]] (rewritten 2026-08-03)
is the implementation plan built from §6 here, with the verified corrections folded in — payload
addressing pulled early as two selectors, the cheap tier at ~217 unique-axis hits, and a
~146–147/174 ceiling.

> [!info] Measurement method used throughout
> Corpus: **953 ability files** in `abilities/` whose filename stem (basename minus trailing digits)
> intersects the **174-name roster** in `deploy/roster.json` — verified identical to
> `char_name_list()` in `scripts/character_database.gd`, zero difference in either direction. The
> other 67 files belong to 20 orphan stems and are excluded. Plus all 174 `character/<name>.gd`.
>
> The canonical pipeline for every reach figure:
> ```bash
> cd abilities && grep -l '<PATTERN>' *.gd \
>   | sed 's#\.gd$##; s#[0-9]*$##' | sort -u | comm -12 - chars.txt | wc -l
> ```
> `chars.txt` is the 174 `path_name`s, **CRLF-stripped** — the raw file breaks `comm` silently and
> reports 0 for every row, which is how a naive run of this pipeline produces an all-zero table.
>
> **Count the FACTORY CALL, not the `EffectType.Type.X` token.** A type whose factory names it is
> invisible to a token grep. This corrects roughly a dozen figures in the frame this note started
> from — see §5.4.
>
> Where a number is an estimate, a structural heuristic, or a floor rather than a tight grep, it is
> **said inline**. Where a claim is read from the code rather than observed in a probe, that is said
> too.

---

## 1 — The headline

**7 of 174 roster characters (4%) are fully expressible in the Creator today.**

They are `gojo`, `lucy`, `naruto`, `rengoku`, `saturn`, `shinoa`, `squalo`.

The mean roster character is blocked on **3.51 independent systems**:

| Blockers on one character | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Characters | **7** | 15 | 27 | 42 | 38 | 18 | 15 | 12 |

That overlap is the single most important fact in this note, and it is what makes per-item reach a
misleading way to plan. Building the **fourteen cheapest items** in this document — every `field`,
`enum-row` and `op`, a combined **244 character-hits** of reach — moves full expressibility from
**7 to 17 / 174**. The Simple Effect Table, at 95/174 the largest raw reach number here, then adds
**+13**. The curve is violently back-loaded: two systems deliver 94 of the remaining 143.

| Step | System | Reach | Fully expressible | Δ | ≤1 gap left |
|---:|---|---:|---:|---:|---:|
| 0 | *(today)* | — | **7** | — | 22 |
| 1–14 | every field / enum-row / op (§2) | 244 hits | **17** | +10 | 56 |
| 15 | Simple Effect Table (§2.1) | 95 | **30** | +13 | 91 |
| 16 | `recurring` (§3.2) | 55 | **38** | +8 | 109 |
| 17 | Payload addressing (§3.1) | 66 | **56** | +18 | 143 |
| 18 | Target eligibility (§4.2) | 64 | **90** | **+34** | 171 |
| 19 | Value reading (§3.3) | 63 | **150** | **+60** | 174 |
| — | *the do-not-build tier (§5)* | 24 | *174* | — | — |

> [!success] The softer metric is the one to manage against
> "Fully expressible" is a cliff. **"At most one gap remaining"** — the roulette's own *buildable
> with fidelity loss* verdict — is smooth: **22 → 56 → 91 → 109 → 143 → 171 → 174**. A player does
> not need a bit-perfect Toji; they need a character that plays like the one in their head. That
> column is what the cheap tier actually buys.

**The ceiling is 150/174 (86%).** The residue of **24 characters (14%)** is homogeneous: every one
is blocked *only* on the do-not-build tier — engine branches keyed on a hardcoded `path_name` (12
characters) or on one of 40 hardcoded effect **names**, plus `SKILL_COPY` (blocked on an identity
bug, not a design one) and five one-character effect types. No palette row reaches any of them,
because they are properties of the **engine reading a name**, not of the authoring model. §5.3
names them.

> [!warning] What the 7/174 baseline is and is not
> It is an **upper bound**, produced by a structural detector over 20 blocker tags. A character with
> zero *detected* blockers may still carry one the detector does not model (notably `extra_usable`
> shapes beyond `requires`, main-target-vs-splash, and `and_targeter`). It is also **conservative in
> the other direction**: three tags were deliberately excluded from the blocker set — the
> source/type query axis (107/174, a Creator collision hazard rather than a shipped-character
> blocker), `call_unique` hubs (7/174, inlineable), and a non-empty `character/<name>.gd` (28/174,
> reachable via a Passive). Including all three drops the baseline from 7 to 4 and **does not change
> the shape of the curve at all**, which is the part any decision rests on. Quote the shape, not the
> 7.

---

## 2 — Common patterns, easily covered

The cheap bulk. Everything in this section is a schema entry plus a `BlockRunner` case — the
[[Creator Roulette]] page's own definition of "expose this factory the way the existing ones are
exposed". None of it needs a new concept, and none should be inflated into a framework.

### 2.1 The Simple Effect Table — one `_build_effect` arm plus N data rows

**Reach: 95/174 (55%)** — the largest single number in this document.

Twenty-two of the "long tail" effect types are produced by a factory whose *entire body* is
`effect_type = X; mag = n; set_duration(d); description = <string>`. Verified by reading every one:
`scripts/effect_component.gd:163` stealth · `:171` immortality · `:179` health_cap · `:240`
sharpshooter · `:344` false_stun · `:426` ignore_healing · `:434` ignore_cleanse · `:442`
damage_cap · `:451` damage_cap_receive · `:460` no_boost · `:554` portrait_change · `:625` dodge ·
`:646` ignore_non_damage · `:981` barrier · `:1043` def_negate · `:1062` percent_dr · `:1141`
heal_cut · `:1163` empty · `:1200` isolate, plus `delay_eff` `:1071` and `delay_receive_eff`.

Nearly all take only scalars and string lists — but **not one** is too strong: `Effect.redirect_effect` stores a live `Character` in `character_target`, which is exactly the kind of argument an authored spec cannot supply. Read the factory before assuming a kind is a pure-data row. `Effect.from(eff_type, kwargs)`
(`scripts/effect_component.gd:895`) already constructs exactly this shape generically — five shipped
abilities use it (`abilities/gilgamesh2.gd:28`, `gilgamesh3.gd:24`, `nagisa5.gd:17`,
`sayaka3.gd:19`). And the one thing that could have blocked a generic arm does not: `wrapup_func`,
`shield_func`, `barrier_func`, `redirect_func` and `conditional_func` are all engine-defaulted at
`scripts/effect_component.gd:41-45`. `barrier_effect` never sets `barrier_func`, yet
`scripts/character_component.gd:860` calls it successfully off the default.

| Member | Reach | Grep (`Effect.<factory>(`) |
|---|---:|---|
| `IGNORE_NON_DAMAGE` | **21/174** | `ignore_non_damage_effect` |
| `PORTRAIT_CHANGE` | **19/174** | `portrait_change_effect` — *hold back, see below* |
| `TARGET_CHANGE` | **16/174** | `target_change_effect` |
| `ISOLATE` | **12/174** | `isolate` |
| `BLIND` | **11/174** | `blind_effect` |
| `IMMORTALITY` | 9/174 | `immortality_effect` |
| `BARRIER` (Nullify) | 9/174 | `barrier_effect` |
| `DAMAGE_CAP` | 6/174 | `damage_cap` |
| `DELAY` | 6/174 | `delay_eff` |
| `IGNORE_COUNTER` | 5/174 | `ignore_counter_effect` |
| `IGNORE_HEALING` | 5/174 | `ignore_healing` |
| `DAMAGE_REDIRECT` | 3/174 | `redirect_effect` — *fraction-typed, see the risk* |
| `STEALTH` | 2/174 | `stealth_effect` |
| `PERCENT_DR` · `HEAL_CUT` · `HEALTH_CAP` · `DAMAGE_CAP_RECEIVE` · `HEALING_RECEIVED_MOD` · `IGNORE_CLEANSE` · `IGNORE_SKILL` · `NO_BOOST` · `DODGE_CHANCE` · `SHARPSHOOTER` · `FALSE_STUN` · `DELAY_RECEIVE` | 1/174 each | *table lines, not projects* |
| `CHAIN_NULLIFY` · `DAMAGE_REVERSE` | 1/174 each | no factory at all — only `Effect.from` |

**Cost:** a `const SIMPLE_EFFECTS` table in `blocks/block_schema.gd` plus **one** `_build_effect`
arm calling `Effect.from(EffectType.Type[row.type], {})` and letting the existing universal pass
write `mag`/duration/flags. Every subsequent type is one **table line and zero code**, because
`blocks/block_validator.gd:289-302` already derives the allowed-field set from `EFFECT_KINDS` and
`_apply_universal_fields` is already kind-agnostic by design (`blocks/block_runner.gd:493-499` says
so in its own comment).

Three things the table must carry that the schema does not have today:

1. **`hostile`, as data.** `BlockRunner._is_hostile_effect` (`blocks/block_runner.gd:547-561`) is a
   literal seven-name list (`damage_over_time, stun, silence, vulnerability, destructible_break,
   paralyze, taunt`) plus the two signed kinds. Anything not in it routes through
   `Character.add_allied_effect`, skipping `is_ignoring_skill`, `shrug_off_type` and
   `can_apply_hostile_effect`. A table-driven Isolate or Blind that forgets to declare hostility
   lands on an invulnerable, skill-ignoring enemy that **no hand-written kit could reach**.
2. **A `mag` normalisation.** The corpus ships **three incompatible percentage conventions**.
   `PERCENT_DR`'s mag is the percent *removed* (`damage *= (100.0 - dr.mag)/100.0`,
   `scripts/character_component.gd:982`); `HEAL_CUT`'s is the percent *retained*
   (`mod_healing = int(mod_healing * (heal_cut.mag/100.0))`, `:1052`) while its own factory
   description at `scripts/effect_component.gd:1148` claims the opposite; `DAMAGE_NULLIFICATION` and
   `DAMAGE_REDIRECT` use a 0..1 **float** that `_amount`'s `clampi(int(v), …)`
   (`blocks/block_runner.gd:727`) cannot even represent. `abilities/jack2.gd:25` passes 50 to
   `heal_cut` — the one value where both readings coincide, which is why the drift has never
   surfaced. **Write the table's prose from the reader, never from the factory's own string.**
3. **A per-row `LIMITS` column, designed at the same time as the table.** Isolate and
   `IGNORE_NON_DAMAGE` are invisible in the damage math, so authors will underprice them: a
   permanent `all_enemies` isolate deletes healing, shields, cleanse and every ally-targeted buff for
   an entire match. `IMMORTALITY` is worse — `is_immortal()` (`scripts/character_component.gd:1806`)
   consults **no exclusion list at all**, so a permanent one is strictly worse than the
   already-documented permanent-invuln soft-lock, which at least answers to `DEF_NEGATE`.

> [!warning] Hold `PORTRAIT_CHANGE` back — it is blocked on the asset pipeline, not the palette
> The palette half is one table line and the `base_abilities` filter at
> `new multiplayer/battle_manager.gd:2422` is already satisfied by a `ScriptedAbility`. But
> `alt_portraits` is an `@export var` array (`scripts/character_component.gd:25`) populated only by
> hand-written `.tscn` scenes, and `AuthoredAssets` has exactly **one** portrait slot. Wiring the row
> now ships a kind whose only legal magnitude is out of range. Sequence it with tasks #72/#73.

### 2.2 One-field extensions to already-shipped kinds

| Item | Mechanic | Reach | Cost |
|---|---|---:|---|
| **`counter`.`on: outgoing`** | a counter planted on an ENEMY that cancels the next skill *they* use | **15/174** | one field switching the hardcoded `COUNTER_RECEIVE` at `blocks/block_runner.gd:689` — **plus** adding `counter` to `_is_hostile_effect` |
| **`cost_change`.`mode`** | `add` (today) / `set` (absolute replacement) / `swap` (colour-for-colour) | **27/174** (19 `cost_change_effect` + 8 `color_change_effect`) | a third value on an existing axis; `skills` and `colour` already exist and are already validated (`blocks/block_validator.gd:331-335`) |
| **presence conditions `.effect`** | `has_effect` / `not_has_effect` / `stacks_at_least` keyed on name **+ EffectType** | **27/174** hard blockers | three `args` entries, one shared `_check_condition` branch; the vocabulary is already derived by `BlockSchema.immunity_effects()` and `remove` already takes exactly this field |
| **presence conditions `.by`** | `mine` / `any` — whose effect is it | 107/174 use the source-scoped form | ships **with** `.effect` or it is inert — see below |
| **`bypass_invuln`** (shipped as **`bypassing`**) | the targeting helpers' 3rd parameter — `ScriptedAbility.target` now passes it from the `Bypassing` class | **33/174** constant-only, **39/174** including expression forms | one argument on two calls at `blocks/scripted_ability.gd:53-65` |
| **`trigger`.`scope`** | gate a payload on the triggering skill's CLASS (or name) | **32/174** structural, **20/174** by the tight alias-tracking scan | reuses `COUNTER_SCOPES` (`blocks/block_schema.gd:242-258`) verbatim |
| **ability-level `channel`** | `control` / `channel` — everything this skill applied ends when I am stunned/sealed/killed | **15/174** | an accumulator in `BlockRunner.run` + one flag. **Refutes [[What Cannot Be Built Yet]] §1.7** — see §2.5 |

> [!danger] `.effect` and `.by` must ship together, or `.by` is inert
> The engine's scoped query is the 3-arg `has_effect(name, type, user)`
> (`scripts/effect_storage_component.gd:67-71`). There is **no name+user-without-type entry point**.
> A `by` field with no `effect` field has nothing to call and would silently fall back to the
> type-blind path — exactly the `trigger_once` failure mode the roulette ledger already records
> twice.
>
> The same change fixes two more things and therefore **subsumes** them: the ledger's `slot_holds`
> sub-row becomes `{"cond":"has_effect","name":"<swapped-in skill>","effect":"ABILITY_SWAP",
> "on":"user"}`, which is exactly what all **6/174** shipped kits write (broly, gallantmon, kaiba,
> kurotsuchi, yamamoto, yuno — raising the ledger's recorded 4/174 to 6 and then closing it); and
> `stacks_at_least`'s hardcoded `EffectType.Type.MARK` (`blocks/block_runner.gd:216`) becomes an
> argument, which is what `stackable` being universal always promised.

### 2.3 Plain enum rows

| Row | Mechanic | Reach | Note |
|---|---|---:|---|
| `on_hp_changed` | `HEALTH_CHANGE_TRIGGER` — fires on **every** HP change, heals included | **11/174** | the **only** hook correct today without payload addressing: 10 of 11 are self-held |
| `on_stunned` | `STUN_RECEIVED_TRIGGER`, from inside `apply_effect:206` when `not shrug_off_type(STUN)` | 4/174 | 3 of 4 are ally-held → wants `holder` |
| `on_skill_received` | `ACTION_RECEIVE_TRIGGER` — the unfiltered superset of the shipped `on_harmful_received` | 3/174 | 3 of 3 are enemy-held → wants `holder` |
| `on_healing_given` | `HEALING_GIVEN_TRIGGER` | 1/174 | a band-aid alone; take it as a free rider with Value reading |
| `reflect` kind | re-aim an incoming Harmful skill | **11/174** | **cheaper than the shipped `counter`** — see §2.4 |
| `banish` op | `Character.banish_character` | 5/174 | already adjudicated by [[Roulette 08 - Semiramis]] as an `OPS` row, not an effect kind |

`on_hp_changed`'s threshold-latch idiom is **fully authorable today** without a new axis:
`when: {"cond":"hp_below","value":50,"on":"user"}` guards the payload, and
`{"op":"remove","name":"…","effect":"HEALTH_CHANGE_TRIGGER","to":"user"}` disarms it — the exact call
`abilities/arthur4.gd:46`, `nezuko5.gd:24` and `eren3.gd:97` make from inside their own payloads, so
removing an effect from within its own trigger is a proven-safe shape.

### 2.4 `reflect` is an effect kind with a *fixed* payload

`reflect_check` (`scripts/character_component.gd:372`) walks `REFLECT_USE` on the caster
(`:387-393`) then `REFLECT_RECEIVE` on each of the caster's targets (`:397-403`), gated by the same
`Condition.action_countered` counters use. The payload **mutates** `attacker.targeter.targets` in
place and its return value is discarded (`abilities/scripts/ability_component.gd:375-406`).

Every shipped use passes the *same* engine-provided callable, and exactly **two** destinations exist
across the whole corpus: `-1` = bounce at the attacker (`abilities/gallantmon1.gd:31`, `king4.gd:20`,
`marco3.gd:19`, `rob8.gd:24`) and the applier = guardian redirect (`eren2.gd:13`, `kitara2.gd:15`,
`mash4.gd:25`, `saber3.gd:20`, `tamaki4.gd:19`, `stark1.gd:31`). `class_targets` is `["Harmful"]` in
10/10 sites.

```json
{"kind": "reflect", "scope": "harmful", "destination": "attacker", "charges": 1, "turns": 2}
```

`destination` is a two-value enum, not a live `Character`, so JSON carries it fine. This satisfies
[[What Cannot Be Built Yet]]'s own rule — *"its payload must be a fixed engine-provided callable,
never author-supplied blocks"* — **by construction** rather than as a restriction the validator has
to police. Both re-aim traps that rule was written for (a common AoE being `TargetType.ALL(2)` not
`ALL_FACTION(1)`, and re-validating against `extra_targetable` + bypass-aware invuln) are already
handled inside `reflect_retarget_to_team` (`abilities/scripts/ability_component.gd:418-433`).

### 2.5 Channels are one flag, not "labelled effects"

[[What Cannot Be Built Yet]] §1.7 says control/channel cancel *"needs a new concept, labelled
effects"*. **Refuted by reading all 16 shipped call sites.** Every single one accumulates a local
`cancels = []` of *every* effect that `execute()` applied and passes the whole list —
`abilities/gray6.gd:19-44` (a DoT, a shield, a `TICKING_TRIGGER` and a mark), `shiro4.gd:21-38`,
`maka3.gd:25-53`, `madoka2.gd:20-51`, `nonon3.gd:20-43`, `venus3.gd:25-53`. **Zero are selective.**

So it is one ability-level field — `"channel": "control" | "channel"` — plus an accumulator in
`BlockRunner.run` that collects each effect handed to `add_*_effect` during one run and applies the
cancel to the user at the end. No block-level ids, no per-effect labels, no new selector. The two
variants differ only by which *other* mechanic breaks them. The known crash shape is already
half-solved on the read side: a rejected application is `queue_free`'d by `_free_unapplied_effect`
and a merged one is absorbed by the storage component, so the accumulator must check
`is_instance_valid` — exactly what `_end_cancel_effects` (`scripts/character_component.gd:290-292`)
already does.

**Reach 15/174** — `Effect.control_cancel(` 8 + `Effect.channel_cancel(` 7, roster-intersected.
`abilities/mavis4.gd:39` is a *comment* and must not be counted. This is the tight factory number and
it corrects the ledger's Channels row of 18/174.

### 2.6 Two ops

| Op | Mechanic | Reach | Shape |
|---|---|---:|---|
| **`adjust`** | reach inside an effect already on the board | **40/174** | `{"op":"adjust","name":…,"effect":…,"to":…,"turns":+N \| "stacks":±N \| "mag":±N}` |
| **`repeat`** | a loop count, constant or state-driven | **20/174** | `{"op":"repeat","times":<int\|reading>,"blocks":[…]}` |

`adjust` reuses `remove`'s addressing *exactly*, because `_op_remove`
(`blocks/block_runner.gd:397-432`) already solved the hard parts: match on `effect_name()` not on
`source.ability_name`, collect-before-mutate because teardown reorders the list, and
one-instance-only for a partial spend. Keep the **delta** form only; a `set` form invites unbounded
ramps. `turns` must go through `BlockSchema.turns_to_duration`'s 2N convention, because `+= 2` for
"one more turn" is the single most-repeated comment in the corpus (`character/toji.gd:113-121`,
`abilities/uzui5.gd:27`, `character/madoka.gd:31`).

`repeat` is a `group` with a count, so it composes rather than special-cases. Two hard requirements,
both precedented: `_count_blocks` **must** recurse into `blocks` (the validator already does this for
`group`, `blocks/block_validator.gd:180-181`) or the 40-block ceiling is trivially multiplied; and
`times` needs its own limit independent of `max_amount`. **Repeating a hit is not one bigger hit** —
shields absorb per instance, damage reduction and the minimum-damage floor apply per instance, and
receive-triggers fire per instance — so `repeat` and a scaled amount are two mechanics, not two
spellings of one. Shipped: `abilities/jupiter3.gd:29` `range(antenna.stacks)`, `natsu4.gd:24`
`range(hostile_effect_count)`, `hisoka1.gd:41` `range(stacks)`, `gilgamesh1.gd:31` `range(gates)`.

---

## 3 — Complex patterns needing special handling

Four systems and two hardening items. Each is measured, each composes with the existing palette, and
each states the abuse case its limits prevent.

### 3.1 Payload addressing — **two** selectors, not one

**Reach: 66/174** (structural map — the union of characters that dereference
`context['effect'].target` by hand inside a gameplay callback, and characters that install a
trigger-family effect via `add_hostile_effect`). The tight direct-idiom floor is **10/174**
(byakuya, death, gatomon, jeanne, koro, machinedramon, mami, pegasus, ryohei, semiramis). The ledger
records this system at a 29/174 floor / 65/174 loose; this is its **fourth** hit.

`BlockRunner._build_trigger` (`blocks/block_runner.gd:706-716`) binds exactly two things: the
payload's acting `user` := `context.effect.user` (the **applier**, misnamed `holder` in the local
variable) and the payload's `target` selector := `context.owner` via `set_explicit_targets`, read at
`:99`. **`context.target` is never read by `BlockRunner` on any path.** The character an effect is
*attached to* has no name.

| Hook | `QueryContext` ctor | `context.owner` | `context.target` | `context.effect.target` |
|---|---|---|---|---|
| `on_ticking` (TICKING) | `from_effect_end` | applier | **holder** | **holder** |
| `on_turn_start` / `on_turn_end` | `from_effect_end` | applier | **holder** | **holder** |
| `on_harmful_received` / `on_damage_received` | `from_trigger_source` | attacker | holder | **holder** |
| `on_skill_used` | `from_trigger_source` | the user (= holder) | holder | **holder** |
| `on_stunned` / `on_skill_received` | `from_trigger_source` | the actor | holder | **holder** |
| `on_death` | `from_effect_end`, owner **overwritten to the killer** (`scripts/character_component.gd:1501`) | killer | holder | **holder** |
| `on_damage_dealt` | `from_trigger_source` | the dealer (= holder) | **the VICTIM** | **holder** |
| `on_healing_given` | `from_trigger_source` | the healer (= holder) | **the HEALED** | **holder** |

`context.effect.target` is the holder on **15 of 15** rows without exception, because
`Character.apply_effect` calls `effect.set_target(target)` unconditionally
(`scripts/character_component.gd:177`). `context.target` is the holder on 13 of 15.

> [!danger] Correction to the ledger: [[Roulette 06 - Boruto Uzumaki]]'s system J binds the wrong field
> Run 06 defines `holder := context.target`. Verified: that is correct on 13 hooks and **newly wrong
> on the two where the roles diverge** — `check_damage_dealt_triggers(damage_source, target, …)`
> passes the *victim* as `qtarget` (`scripts/character_component.gd:1297`) and
> `check_healing_given_triggers` is invoked as `healer.check_healing_given_triggers(source, self,
> healing)` (`:1098`, dispatcher at `:1348`), passing the *healed*. One of those two is the hook
> [[Roulette 07 - Levi Ackerman]] already **probed** as a player-reachable self-kill.
>
> Ship it as **two** rows.

```json
{"op": "apply", "to": "user", "effect": {
  "kind": "trigger", "trigger": "on_ticking", "turns": 3,
  "then": [ {"op": "damage", "amount": 10, "to": "holder"} ]
}}
```

```json
{"kind": "trigger", "trigger": "on_damage_dealt",
 "then": [ {"op": "apply", "to": "affected", "effect": {"kind": "vulnerability", "amount": 10, "turns": 2}} ]}
```

- **`holder`** := `context.effect.target` — universally the bearer.
- **`affected`** := `context.target` — the event's *patient*, the character the event happened *to*.
  This is what makes `on_damage_dealt`'s "hurt whoever I just hit" reachable, which run 06 listed as
  a motivating mechanic and which the `context.target` binding would have delivered only by
  accident.

**Composition.** Two arms in `_resolve_targets`, two extra stashes alongside the existing
`set_explicit_targets` in `_build_trigger` and `_build_counter`. Both are ordinary selectors
everywhere a selector is legal *inside a payload*, so they compose with `when`, `group`, and every
op without special-casing. **No engine primitive is missing.**

**Validator limits and the abuse case.** Legal only inside a `then` payload — thread the
`in_reactive` flag [[Creator Roadmap]] specifies (Phase B). Resolves to at most one character.
Returns `[]` when the character is dead or invalid, and **never** falls back to the caster. The
abuse case the last rule prevents is the run-07 defect in reverse: a silent fallback turns "damage
the holder" into "damage myself" the moment the holder dies mid-payload.

**Prose.** One noun each — *"the character carrying this effect"* / *"the character it happened
to"*. Both fit the existing `_describe_selector` shape.

**Bot.** No new tag. `bot_damage_hint` already ignores payload contents; a payload that finally aims
correctly changes nothing it reads.

> [!warning] Do NOT solve this with a pool-and-filter selector
> The information lives in the `QueryContext` the payload closure already receives and discards. The
> run-08 workaround — a filtered `any_enemy` + `has_effect` on the trigger's own name — reaches the
> holder **set**, consumes the block's only `when`, requires the author to know which side the effect
> sits on, and collides with a second caster's identically-named effect. Adding an
> `attacker`-flavoured *selector* row would make that workaround look sanctioned and would give two
> systems one name.

### 3.2 `recurring` — ticking as an effect KIND, not a `TRIGGERS` row

**Reach: 55/174 (32%)**, 119 refs — **larger than every hook already in the palette**
(`ACTION_USE_TRIGGER` 43, `HARMFUL_RECEIVE_TRIGGER` 30, `DAMAGE_RECEIVE_TRIGGER` 21,
`END_OF_TURN_TRIGGER` 14, `START_OF_TURN_TRIGGER` 8, by the identical grep).

The obvious build is an `on_ticking` row in `TRIGGERS` next to `on_turn_end`. That implies a parity
the engine does not have. `TICKING_TRIGGER` has five properties `END_OF_TURN_TRIGGER` does not, and a
hook name can carry none of them:

1. **It occupies a player-reorderable execution slot.** `get_ticking_effect_information`
   (`new multiplayer/battle_manager.gd:785`) keys groups `3,4,5…`, merged with the acting team's
   skill keys `0-2` into `execution_order` (`:736-740`) and returned as the player's chosen
   `true_execution_order` (`:750`).
2. **The tick set is frozen at `:1622`, before `start_round_loop()` at `:1640`** — so a ticker
   cannot fire on the turn it is planted. That is the whole hand-coded "manual first instance +
   duration 2K−1" idiom, documented in place at `abilities/fern3.gd:72-79` and `stark3.gd:53-58`.
3. **It is scoped by the effect's USER's side** (`if effect.user in team`,
   `new multiplayer/battle_manager.gd:826-841`) while turn-end triggers are scoped by the
   *holder's*. An enemy-planted ticker fires on **your** turn.
4. **Four cancellation gates turn-end has none of** (`execute_ticking_effect`, `:1222-1263`): holder
   dead/banished `:1223`; `effect.source.classes["Action"] and effect.user.is_stunned(…)` `:1225`;
   holder isolate for a friendly tick `:1256-1258`; holder invuln for a hostile tick unless
   `Bypassing`/`bypassing` `:1259-1261`.
5. **`last_turn_only` is inert on it.**

```json
{"op": "apply", "to": "target", "effect": {
  "kind": "recurring", "turns": 3, "first": "now", "stops_when_stunned": false,
  "then": [ {"op": "damage", "amount": 10, "to": "holder", "damage_type": "AFFLICTION"} ]
}}
```

Two axes justify the shape, and neither can live on a hook name:

- **`first`: `now` | `next`.** `now` runs the payload once at cast **and** sets engine duration
  2K−1; `next` sets 2K. This folds the manual-first-instance idiom every kit hand-codes, and it is
  the difference between the generated prose being true and being a turn off.
- **`stops_when_stunned`** writes the ability-level `Action` class. That class has **exactly one
  reader in the entire repo** — `new multiplayer/battle_manager.gd:1225` — so it *means* "my ticking
  effects stop while I am stunned" and nothing else. It is whitelisted by `_validate_classes`,
  shipped to the client, and rendered as a tickable chip in the editor where today it does nothing.
  The moment ticking is authorable, ticking that chip silently halves an effect's uptime against any
  stun, with no prose and no validator message — the same defect shape as the `Bypassing` class
  already recorded in the vault. Surface it here and drop the bare chip.

**Composition.** A sibling of `counter`/`trigger` with a nested `then` list, so `when`, `group`,
nesting depth and the block ceiling all apply unchanged. `bypassing`, `system`/`display_system`, the
stacking fields and `remove_on_death` are already universal and need nothing new. **Engine cost:
none** — the enum row already has a dispatcher, a wire encoding, a client tile and a reorder slot.

**Validator limits and the abuse case.** `stops_when_stunned` is **ability-scoped** (the gate reads
`effect.source.classes`), so a skill carrying two `recurring` effects cannot make one
stun-cancellable and the other not — reject that combination rather than resolving it silently. The
real abuse case is the pairing: a permanent (`turns: -1`) enemy-held ticker whose payload damages
`holder` is per-round damage forever for one cast, and `execute_ticking_effect` applies **no
magnitude bound of its own**. Worse, the only counterplay is holder-side and side-dependent
(`:1256-1261`), so an author who also sets the universal `bypassing` field removes it. **Cap the
duration of a hostile-placed recurring trigger.**

**Prose.** One `_describe_effect` arm — and it must say **"each turn"** meaning the *author's* turn,
not the holder's.

**Bot.** `TAG_REACTIVE` + `_derive_tags(then)`, and `bot_damage_hint` must count *amount × turns* or
the v3 policy values every ticking payout at zero. See [[Bots and Training]].

> [!warning] Two prerequisites, both confirmed
> **(a) The 16–18 hostile-install characters need §3.1 first.** `from_effect_end` sets
> `owner = effect.user`, so an enemy-held payload's `target` resolves to the caster and the effect
> fires backwards. The other ~35 of the 55 are self-or-ally installs where today's binding is already
> correct — so the editor may offer the self form ahead of `holder`, which is why this row can sit
> *before* addressing in a roadmap and still be honest.
>
> **(b) `last_turn_only` needs a TWO-site fix.** `new multiplayer/battle_manager.gd:831` is the
> **collector** — `get_ticking_effects` filters DAMAGE effects on
> `(not effect.last_turn_only or effect.duration == 1)`, and the `TICKING_TRIGGER` loop three lines
> below at `:838-840` has no such filter. `:1234` is the **executor**, inside the
> `if effect.effect_type == EffectType.Type.DAMAGE:` branch opened at `:1231`; the `TICKING_TRIGGER`
> branch at `:1255-1263` never consults it. Fix both, or a "fires once, at the end" effect appears as
> a phantom draggable tile in the reorder panel every turn for its whole duration and does nothing
> when dragged.

### 3.3 Value reading — turning live state into a number

**Reach: 63/174** by my structural parser; **57/174** by an independent per-field survey;
**41–43/174** for the damage-only subset, which [[Roulette 08 - Semiramis]] promoted to the ledger at
43/174. Treat **57–63/174** as the band and **41–43/174** as the settled damage-only figure. This is
the ledger's second open system and its **third independent measurement**.

Every authored magnitude, duration and count is a compile-time literal: `BlockRunner._amount` is
`clampi(int(v), 0, max_amount)` (`blocks/block_runner.gd:727-728`) and `_validate_amount` rejects
non-numbers (`blocks/block_validator.gd:577-585`).

The shipped shapes, measured: a **count of matching things** (`abilities/mars1.gd` heals
`base + 5 × ofuda_stacks` over every Ofuda-marked character on the board; `tanjiro5` scales off dead
characters; `semiramis3` counts HEALING effects before stripping them); a **stack count**
(`hisoka1.gd:41`, `jupiter3.gd:29`); an effect's **`mag`** (`madoka4.gd:48`, `soul4.gd:33`); **HP**
(`frankenstein3`, `ganta2`, `sayaka5`, `yoh4`); the **energy pool** (`fern1`, `nel5`); another
effect's remaining **duration** (`koro2.gd:28`, `jaden3.gd:53`).

The consumer shape the corpus actually wants is **not an expression language**:

```json
{"op": "damage", "to": "all_enemies",
 "amount": {"base": 15, "per": 5, "cap": 45,
            "each": {"read": "stacks", "name": "Ofuda", "effect": "MARK", "of": "all_enemies"}}}
```

`base + M × count` by itself reproduces `mars1`, `tanjiro5`, `semiramis3`, `ganta1`, `nezuko2`,
`saitama7` and `tamaki1` verbatim. The `<reading>` node is a **closed enum** mirroring `compare`'s
shape so the palette has one way to say "how many":
`{"read": "stacks"|"effect_count"|"alive_count"|"hp"|"missing_hp"|"energy"|"duration", "of": <selector>, "name": …, "effect": …}`.

**Composition — four constraints, all measured.**

1. The **same** reading node must be usable as a `compare` value. `alive_count` already lives in
   `COMPARE_VALUES` (`blocks/block_schema.gd:88`) and must become a `read` rather than being
   duplicated, or the palette grows two incompatible ways to ask "how many".
2. `effect_count` **must** apply the `display_system` visibility filter (eight sites must agree) or
   it leaks hidden state as a *magnitude* — worse than a boolean, which leaks a bit — and trips the
   per-turn drift validator.
3. `mag` and `stack_mag` are already in `UNIVERSAL_EFFECT_FIELDS` (`blocks/block_schema.gd:199-201`)
   with **no reader anywhere**, so today an author can write a number they can never look at.
   Closing that asymmetry is the same build. With `adjust` (§2.6) shipped alongside, `stacks`
   becomes a genuine read/write register — the two are one build in two parts.
4. `_clamp_stacks` is mark-gated (`blocks/block_runner.gd:488-491`) and its ceiling comes from
   `storage["block_max_stacks"]`, written **only** in the mark branch (`:590`). Generalising the read
   before the write pins every non-mark stack at the `_stack_ceiling` default of 1 (`:543`).

**Validator limits and the abuse case.** A mandatory `cap` on the `per` term. The abuse case is not
the reading itself — it is the product: `repeat` with a reading `times` over a `damage` block with a
reading `amount` is a **quadratic in one skill**, and neither the per-block `max_amount` clamp nor
the 40-block ceiling observes it. Bound the *product* (amount × maximum resolvable targets × repeat
count) in one place rather than per new row.

**Prose.** *"Deals 15 damage plus 5 per Ofuda on the board, up to 45."* One clause; readable.

**Bot.** The single largest non-palette cost in this document, and **not optional**:
`ScriptedAbility._block_damage` reads `int(b.get("amount", 0))` (`blocks/scripted_ability.gd:493`)
and an object-form amount scores as **zero**. The v3 policy would never select any scaling skill on
an authored character, and a character whose best skill is invisible to the bot cannot be practised
against.

### 3.4 Engine re-validation of non-`target` selector pools — a **correctness fix**

**Reach: 100% of authored content** that uses any selector other than `to: "target"`. The
counterparty measure on the shipped side: **40/174** roster characters read `is_invuln(`, all of
which an authored AoE currently ignores.

`to: "target"` reads `user.targeter.targets` live (`blocks/block_runner.gd:99`), a list that by the
time `ability.execute` runs (`new multiplayer/battle_manager.gd:1208`) has already survived
`countered()` (`:1204`), `_drop_invuln_targets` (`:1205`), `reflect_check` and `accuracy_check`
(`:1206-1207`). **Every other selector builds its own list from the raw team arrays**
(`blocks/block_runner.gd:106-131`, `:156-167`) and inherits none of it.

Verified: the three resolution-time paths have no gate of their own. `Character.resolve_damage`
(`scripts/character_component.gd:2147-2164`) checks `is_ignoring_skill` and `is_ignoring_damage` and
**never `is_invuln`**. `shatter_shields` / `shatter_barrier` (`:1871-1891`) check nothing.
`cleanse_all_enemy_effects` (`scripts/effect_storage_component.gd:108-126`) is gated only on
`IGNORE_CLEANSE` and the per-effect `cleansable`. Only `apply` is safe, because `_op_apply` routes
hostile kinds through `Character.add_hostile_effect` → `can_apply_hostile_effect` (`:2131`). `heal`
is safe by luck — `resolve_healing` checks `is_isolated`.

**So an authored skill with `to: all_enemies` and op `damage`, `break`, `cleanse` or `remove` beats
invulnerability today, for four ops.** The ledger's run-06 callout probed the `damage` half; the
other three are the same hole.

**The fix** is one helper in `_resolve_targets`: after building a pool that did **not** come from
`user.targeter.targets`, drop any candidate for whom
`Condition.can_hostile_target(user, c, ability, bypassing).satisfied(ctx)` (hostile pools) or
`can_allied_target(user, c, bypassing)` (allied pools) is false. `BlockRunner` already holds `ability`
and builds a `QueryContext` (`_ctx`, `:72-73`), so this is a per-candidate call with no new state.
Author opt-out is a single **`bypassing: true`** — **the same field name and meaning as §4's**, so
one concept has one word. (It shipped briefly as `pierce`; that name collides with
`DamageType.Type.PIERCING`, which ignores damage REDUCTION, not invulnerability —
`scripts/character_component.gd:699`, `:834`. `bypassing` is the engine's own word for this, and
the ability CLASS spelled the same way is now wired to it: it is the default for every pool check
and for `ScriptedAbility.target`'s helper calls, overridable per block in both directions.)

There is a second consequence worth stating on its own: an authored "hit each marked enemy" written
as `to: any_enemy` is today **uncounterable and unreflectable**, whereas the 26 shipped characters
that do the same thing via a filtered `target()` are fully counterable, because their filtered
characters end up in `targeter.targets` and therefore inside the interception pipeline. §4 fixes
that half.

> [!danger] This is a nerf to already-approved content, and it cannot be opt-in
> Every authored AoE that has already been approved gets weaker against invulnerable defenders the
> day this lands. That has to be an owner decision and a patch-note line, not a silent correction —
> same shape as the documented per-target-`when` nerf. But it must not ship as a flag the way
> `per_target` can: *"my AoE respects invulnerability"* is not something an author should have to
> remember to tick, and leaving it off by default keeps the two halves of the palette (`apply` vs
> `damage`) disagreeing about the same rule. **Ship it before any new pool or pick vocabulary** —
> every widening added on top of an unvalidated pool multiplies the defect.

### 3.5 Passive-specific validator rules

**Reach: 91/174** roster characters carry a Passive (93 Passive-classed abilities), and **100% of
authored passives** hit the first rule on the editor's default path.

A Passive is an ordinary `Ability` whose `execute()` is called once for every character on both
teams at battle start — `Character.startup_passives` (`scripts/character_component.gd:320-323`) —
and never again. No cooldown, no cost, no `target()`, no `extra_usable`, no re-run on revive. Three
consequences the validator does not know about:

1. **Blocks with no explicit `to` do nothing at all.** `_block_targets` defaults `to` to `"target"`
   (`blocks/block_runner.gd:83-84`); `"target"` reads `user.targeter.targets` (`:99`); that is a bare
   `var targets: Array` (`scripts/targeter_component.gd:4`), empty at battle start. And the editor
   seeds `CREATOR_BLANK_ABILITY` with `blocks:[{op:"damage", amount:15, damage_type:"NORMAL"}]` and
   **no `to`** (`webclient/app/app.js:5148`). Tick *Passive* on a fresh skill and you get a
   validated, approvable, **wholly inert** ability whose generated prose promises 15 damage.
2. **A Passive is a free cast with no balance lever**, so the already-recorded `turns:-1`
   stun/invuln soft-locks are strictly worse there than on an active skill. This is the one place
   where *two different duration caps* is the correct answer rather than an inconsistency.
3. **Passives never re-run on revive** (`abilities/fern5.gd:67`, `stark5.gd:50-53`), so authored
   passive machinery needs `system: true` **and** `remove_on_death: false` to survive a death — and
   nothing in the editor says so.

**Cost: validator-only.** No schema change, no engine work. When an ability's `classes` contains
`Passive`: require an explicit `to` on every block whose op takes one, and reject `to: "target"`
outright with a message that says why. Pair it with the editor seeding `to: "user"` the moment
*Passive* is ticked. This is a restriction the **game** has — there is no target at battle start —
so it does not invent a limit. Flag `to: "all_enemies"` on a Passive for review rather than banning
it: 14 of the 93 shipped passives *do* plant hostile effects.

> [!warning] Read from code, not probed
> The empty-target chain is verified line by line but never observed. It is one headless test —
> an authored Passive with a default-`to` damage block — and it should be run before this rule is
> written into the validator's error text.

### 3.6 Reserved-name hardening — ahead of all new palette work

**Reach: every authored character**, and it is reachable **today** with the shipped `mark` kind. No
new row required.

The engine hardcodes **12 roster `path_name`s** (`emiyaarcher, erza, esdeath, frieren, hawkmon,
inuyasha, minene, muichiro, rakko, semiramis, tokoyami, toph`) and **40 distinct effect NAMES**
across the damage pipeline, targeting, energy generation and death handling. Three of them sit in a
row and each **returns before damage is applied**, at `scripts/character_component.gd:581-606`:

- `marked_by("Nirvana")` — converts the dealer's outgoing damage into Nullify on itself, deals none.
- `target.marked_by("Plasmantle")` — converts incoming Harmful damage into Shield, takes none.
- `target.marked_by("Blood Spear")` — converts all non-Bleed incoming damage into next-turn Bleed.

`marked_by(name)` is `has_effect(name, MARK, null)` (`:1168-1169`) — **any** mark of that name from
**any** source. `effect_name()` falls back to the source ability's name, and `name_override` is a
free-text universal field (`blocks/block_schema.gd:209`).
`AuthoredRegistry.validate_character` (`blocks/authored_registry.gd:185-272`) checks the id prefix,
name lengths and duplicate names among the author's **own** skills — never against the shipped
corpus. **An authored ability named `Plasmantle` that permanently self-marks takes zero Harmful
damage, in two blocks.**

**Cost: one `if`**, the same class of check as the existing duplicate-name error: reject any
`ability.name` or `name_override` colliding with a reserved list.

> [!warning] Do not ship a list of 40 names because 40 names were found
> Three branches are checked and confirmed abusable (Nirvana, Plasmantle, Blood Spear). The other 37
> need the same per-branch read before the list is sized; some will be unreachable from an authored
> mark and should not be on it. `NAGISA_DR` is the same shape one level down — both readers key on
> `target.has_effect("Natural Assassin", …)` (`scripts/character_component.gd:692`, `:828`).

---

## 4 — The selector system

The owner asked for this specifically: *"customizable selector blocks for targets that resolve a set
of conditions down to a character reference(s)."* It is the right instinct, and the measurement says
it is the **highest-marginal-unlock palette item in the document (+34 characters)**. But it has to be
built as **two layers**, because this engine resolves targets in **three stages** and the Creator can
only touch two of them, badly.

### 4.1 The three stages, and where the palette sits

| Stage | What it does | Where | What the Creator has |
|---|---|---|---|
| **1 — Eligibility** | `Ability.target()` does not *choose* anyone; it **flags** characters via `check_hostile_target` / `check_allied_target` (`abilities/scripts/ability_component.gd:849-873`). The server re-runs it every snapshot to ship `special_targets` (`new multiplayer/battle_manager.gd:2387`, `:2453-2472`) and the client refuses a tap when that set is empty (`webclient/app/app.js:1447`). | `func target(user, battle)` | a **six-valued string** (`blocks/scripted_ability.gd:53-65`) with no predicate at all |
| **2 — The pick** | exactly one character is clicked; `TargeterComponent.add_target` makes the **first** entry `main_target` (`scripts/targeter_component.gd:26-29`) | client | nothing |
| **3 — Fan-out** | `target_type()` plus the `and_targeter` / `and_target` splash predicate expand the list (`new multiplayer/battle_manager.gd:1876-1879`; `webclient/app/app.js:1450-1462` human, `scripts/player_component.gd:1268-1284` bot) | engine | the **same** six-valued string — `Ability._target_type_from_mode` (`abilities/scripts/ability_component.gd:147-152`) reads `all_enemies` as **both** the pool and the fan-out |
| *(4 — resolution)* | `SELECTORS` / `FILTERED_SELECTORS` (`blocks/block_runner.gd:89-167`) | inside `execute()` | everything the Creator has — **after all three stages are over** |

That last row is the whole problem. The palette's only selector vocabulary lives one stage too late,
which is why it inherits none of the interception pipeline (§3.4) and why `and_targeter` is
live-but-inert.

### 4.2 Layer 1 — the eligibility object

**Reach: 64/174** need a real predicate or a state-dependent mode; **88/174** ship a `target()` the
six modes cannot reproduce at all (the difference is the 33 that need only a constant
`bypass_invuln`; 9 characters need both). An independent extraction in a separate pass read 85/174
for the same population — call it **85–88/174**, and 64/174 for the predicate half specifically.

```json
{"name": "Death Chaser", "target": {
   "mode": "enemy", "shape": "one",
   "only": [{"cond": "has_effect", "name": "Death Chaser", "effect": "MARK", "by": "mine"}],
   "bypass_invuln": false, "exclude_self": false, "include_dead": false
}}
```

**Worked against real shipped skills.** Each of these is a `target()` body that exists today.

| Shipped skill | What it does | The eligibility object |
|---|---|---|
| `abilities/cooler5.gd:53-54` — `default_hostile_target_function(user, battle, false, "Death Chaser")` | only Death-Chaser-marked enemies light up | `{"mode":"enemy","only":[{"cond":"has_effect","name":"Death Chaser","effect":"MARK","by":"mine"}]}` |
| `abilities/mars1.gd:45-48` — the same call on **both** factions with `"Ofuda"` | any Ofuda-marked character, either side | `{"mode":"everyone","only":[{"cond":"has_effect","name":"Ofuda","effect":"MARK","by":"mine"}]}` |
| `abilities/alphonse2.gd:51-56` — loops `battle.all_characters()`, skips anyone already carrying `"Weapon Alchemy"` as a `DAMAGE_DEALT_TRIGGER` | allies who do **not** already have it | `{"mode":"ally","only":[{"cond":"not_has_effect","name":"Weapon Alchemy","effect":"DAMAGE_DEALT_TRIGGER","by":"mine"}]}` |
| `abilities/astolfo3.gd:29-35` — skips allies still holding `CASSEUR` as `IGNORE_SKILL` | *"cannot be used on a target already affected"* | `{"mode":"ally","only":[{"cond":"not_has_effect","name":"Casseur de Logistille","effect":"IGNORE_SKILL","by":"mine"}]}` |
| `abilities/hisoka6.gd:51-68` — scans the enemy team for the minimum HP, then flags **every** enemy tied at it | execute the weakest | `{"mode":"enemy","shape":"one","pick":"lowest","measure":"hp"}` (ties included — see below) |
| `abilities/jeanne4.gd:39-47` — `set_targeted()` on **dead** allies, `check_allied_target` on living ones | revive | `{"mode":"ally","include_dead":true}` |

`mode` and `shape` **must be split**, and today they are not: `_target_type_from_mode` reads
`all_enemies` as both the pool and the fan-out, so *"pick any one character on either board"* — the
`jeanne4` / `mars4` / `nezuko2` shape — is unreachable. Splitting them is the enabling move and it is
one function.

`only` **reuses the existing `CONDITIONS` vocabulary**, and `BlockRunner._check_condition` already
takes a per-candidate `subject` argument (`blocks/block_runner.gd:189`). So `ScriptedAbility.target`
becomes: walk `battle.all_characters()`, evaluate `only` with that candidate as subject, call
`check_hostile_target` / `check_allied_target` on the survivors — **byte-identical** to what the 64
shipped overrides do. There is nothing new to validate.

**Everything downstream is inherited free**, because it all keys off the flags `target()` sets:
counters, reflect, taunt, blind, `_drop_invuln_targets`, AoE expansion, and the client's *"no valid
targets"* refusal at `webclient/app/app.js:1447`. That last one **retires seven characters'
hand-duplicated logic**: `cooler5`'s `target()` predicate is written a second time inside its
`extra_usable` (`abilities/cooler5.gd:41-46`) purely because the engine has no link between them.
Same pair in `frieza5`, `saitama5`, `nezuko2`, `lyserg1/2`, `toji5`, `horohoro2`.

**`bypass_invuln`** is the third parameter of the two helpers
(`abilities/scripts/ability_component.gd:857`, `:863`). One argument covers **33/174** outright.
**RESOLVED — the trap is closed.** It used to be true that `ScriptedAbility.target` never passed it
and that the `Bypassing` class was read only by `_skill_pierces_invuln` (`:442-458`, for reflect
re-aiming) and the ticking guard (`new multiplayer/battle_manager.gd:1232`, `:1260`), never by the
targeting path — so the editor offered a chip that did nothing an author would read it to mean.
`ScriptedAbility.target` now reads `classes.get("Bypassing")` and passes it as the helpers' third
argument, and `BlockRunner._bypass_gate` uses the same class as the default for every re-validated
block pool, so targeting and execution agree. What is still open for Phase F is only the
**per-ability** override (a Bypassing-less skill whose targeting alone reaches through), which the
selector object mounts as its own `bypassing` field — the per-BLOCK one already exists.

> [!warning] Correction to [[What Cannot Be Built Yet]] §3.4 — `mark_req` is 7/174, not "73 abilities"
> The tight grep for the fourth argument —
> `default_(hostile|allied)_target_function\(user, ?battle, ?(true|false), ?[^)]+\)` — is **11 files
> over 7 roster characters**: `akame`, `cooler`, `diane`, `lyserg`, `mami`, `mars`, `tsubaki`. (An
> independent pass read 9/174 by also counting `death`, whose gate is a hand-rolled loop rather than
> the parameter.) Call it **7–9/174**. Anything ordering the roadmap off 73 is ordering off a ~9x
> inflation of the same kind the hygiene rules already warn about. The same page's §2.3 figure of 109
> non-trivial `extra_usable` bodies, by contrast, reproduces here at 105 and can be trusted.
>
> This does **not** weaken the eligibility case — it relocates it. `mark_req` is the *cheap half* of
> a mechanic whose real reach is the 64/174 predicate population, and it is the reason the object
> form should carry `only` rather than a dedicated `target_requires` string.

**`exclude_self` already half-ships**: `default_allied_target_function` honours `selfless`
(`abilities/scripts/ability_component.gd:865-866`) and `selfless` is already in `ABILITY_FLAGS`
(`blocks/block_validator.gd:36`) and already written through
(`blocks/authored_character.gd:83`). It just has no editor affordance.

**Validator limits and the abuse case.**

1. **`chance` must be rejected inside `only` and `also_hit`.** `target()` is re-run from at least
   four independent sites per turn — `_compute_special_targets`
   (`new multiplayer/battle_manager.gd:2453`), `_drop_invuln_targets` (`:1162`),
   `_skill_pierces_invuln` (`abilities/scripts/ability_component.gd:450`), `_v3_execute`
   (`scripts/player_component.gd:1272`) — and `and_target` from four more. A re-rolled predicate
   answers differently at each, so the client's highlighted set, the server's drop-filter and the
   bot's AoE expansion would disagree about who was hit. It stays legal in a block's `when`, which is
   evaluated exactly once.
2. **Bound `amount × maximum resolvable targets`.** `LIMITS.max_amount` is per damage **block**;
   `shape` multiplies at targeting time. A 100-damage block widened to a faction is 300.
3. **Widening `shape` needs its own guard.** Narrowing and ally-side changes are free.

**Prose.** One clause appended to the target line: *"Can only be used on enemies you have marked with
Death Chaser."* `_describe_filter` already generates exactly this sentence for the filtered
selectors, so the generator is written.

**Bot.** `custom_behavior` branches on the flat `target_mode` string
(`blocks/scripted_ability.gd:493-530`); an object-shaped `target` falls through the match to the
single-target branch. This must land with **one** update to that scorer, shared with §3.3 and §2.6 —
not three.

> [!warning] This layer is presentation and fairness, NOT enforcement
> `components/match.gd:591-597` bounds-checks submitted `target_idxs` against the character count and
> **nothing else**, and `process_turn_package` (`new multiplayer/battle_manager.gd:1580-1587`) applies
> them verbatim with no `target()` re-run and no AoE re-expansion. Only `_drop_invuln_targets` prunes
> afterwards, and only for invulnerability. So describe layer 1 as *what the player is shown and what
> the bot obeys*. The enforceable version is layer 2.

### 4.3 Layer 2 — the block selector object: POOL × WHERE × PICK × ORDER

The owner's phrasing — *"resolve a set of conditions down to a character reference(s)"* — is exactly
this layer. Generalise a block's `to` from a fixed name to the four axes the shipped roster actually
varies.

```json
{"op": "damage", "amount": 20, "when": {"cond": "hp_below", "value": 40, "on": "user"},
 "to": {"pool": "enemies",
        "where": [{"cond": "has_effect", "name": "Fracture", "effect": "MARK", "by": "mine"},
                  {"cond": "hp_above", "value": 20}],
        "pick": "all", "order": "clicked_first", "bypassing": false}}
```

- **POOL** — `target` (default, engine-validated, unchanged), `main_target`, `other_targets`, `user`,
  `allies`, `other_allies`, `enemies`, `everyone`, `dead_allies`.
- **WHERE** — a **list** of per-candidate predicates, AND-ed.
- **PICK** — `all` / `random` (+`count`) / `lowest` / `highest` (+`measure`).
- **ORDER** — `pool` / `clicked_first`.

**This is the fix for the `when`-consumption defect.** Today a filtered selector *consumes the
block's only `when`*: `_block_targets` hands `b.when` straight to `_resolve_filtered`
(`blocks/block_runner.gd:83-84`), `_is_filtered_block` (`:78-79`) exists solely to flag it, and the
validator rejects the combination. So an author gets **either** an all-or-nothing gate **or** a
per-candidate filter, never both, and exactly one predicate either way.

Moving the per-candidate filter into its own `where` field makes `when` mean what it means
everywhere else. The JSON above reads unambiguously: *"**if** the user is below 40 HP, damage **each**
enemy carrying my Fracture **and** above 20 HP."* And the desugaring is exact —
`any_enemy` + `when` **is** `{"pool":"enemies","where":[<that when>]}` — so the special case at
`_run_block:54` and `_is_filtered_block:78-79` **disappears** rather than being papered over. Keep
the ten existing string selectors as sugar; they are in saved `authored/*.json` on disk and are
re-validated on every load, which is the same reason `KIND_ALIASES` exists
(`blocks/block_schema.gd:147-149`).

**Composition with §3.4 is mandatory, not optional:** any pool that did not come from
`user.targeter.targets` must run the engine's own `can_hostile_target` / `can_allied_target`, with
`bypassing` as the single opt-out — the same word as layer 1, and the same word the engine uses.

**Target ORDER and `main_target`.** This is not cosmetic and it is the axis most likely to be
forgotten.

`TargeterComponent.add_target` makes the first character it receives `main_target`
(`scripts/targeter_component.gd:26-29`), and the client leads its list with the clicked character
precisely because of that (`webclient/app/app.js:1454-1462`) — the trap already recorded in
[[Targeting and Main Target]]. Downstream, **targets are damaged in list order**, so a death
mid-list fires on-death triggers and consumes seeded RNG before later entries are touched. Death
order is observable.

`_filtered_pool` (`blocks/block_runner.gd:156-167`) already hard-codes *"own team then enemy team"*
for `any_character`, with no override. Shipping more pools without an explicit `order` means the
answer to *"who dies first"* is whatever the array-concatenation order happened to be —
reproducible, but arbitrary and undocumented. `clicked_first` is the only ordering under which a
`main_target`-aware block agrees with what the player clicked.

**Two more rules the shipped corpus dictates.**

- **`pick: random` must be Fisher–Yates over `battle.roll`**, to stay bit-reproducible for replays
  and the differential fixture, and it must sample **without replacement**. Today three
  `random_enemy` blocks can all hit the same enemy — `_resolve_targets` (`:118-131`) is a single roll
  with no memory.
- **`pick: lowest` must include ties by default**, because the single shipped example does:
  `abilities/hisoka6.gd:64-68` flags *every* enemy at the minimum HP.

**Reach, honestly stated.** The `pick: random` axis is real (**38/174** characters call
`battle.roll`); `pool: main_target` / `other_targets` is the ledger's existing main-vs-splash row (9
abilities split, 21 files reference `main_target`); `pick: lowest` is **1/174** and earns its place
only as one enum value in a row that `all` and `random` already justify. **`where` compound is
unmeasurable as a grep** — the shipped form is a multi-clause `if` — but every one of the 64
eligibility characters that needs two clauses needs it here too. Say that rather than manufacturing a
number.

> [!tip] Two layers, one vocabulary
> `only` (stage 1) and `where` (stage 3) are the **same condition list** evaluated with the same
> per-candidate subject binding. `bypass_invuln` (stage 1) and `bypassing` (stage 3) are the same
> concept. That is what makes this a system rather than two features: an author learns one predicate
> language and uses it in the two places targets are decided.

---

## 5 — What should not be built

Being explicit about the ceiling is part of the deliverable. A palette row wired to a mechanic the
engine does not honour is **worse than no row**, because the generated prose promises behaviour that
will never happen.

### 5.1 Rows that look like gaps and are not

| Item | Reach | Why not |
|---|---:|---|
| **`on_harmful_used`** | 14/174 | A strictly *weaker* duplicate of the shipped `on_skill_used`. `check_ability_use_triggers` builds its `ACTION_USE_TRIGGER` context as `from_trigger_source(ability, eff, self)` (`scripts/character_component.gd:1390`) — **the used Ability is in `context.source`**. It then calls `check_harmful_use_triggers` only when `ability.classes["Harmful"]` (`:1395`), and *that* dispatcher uses `from_effect_end(eff)` (`:1433`), where `source` is the trigger effect and the ability **is not in the context at all**. **CORRECTED — the containment claim was false.** Only **3 of the 14 also use `ACTION_USE_TRIGGER`**; 11 do not (`adam, chrome, death, ganta, gohan, hisoka, king, nagisa, shinra, tamaki, yuno`). Those 11 are NOT already served. The do-not-build verdict survives anyway, but on the CAPABILITY argument alone, not on set containment: `on_skill_used` carries the used Ability in its context and `HARMFUL_USE_TRIGGER` does not, so adding the row would ship the weaker hook. The 11 are served by putting the event-class filter (§2.2) on `on_skill_used` — which means §2.2 is load-bearing for them, not merely convenient. |
| **`on_helpful_used` / `on_helpful_received`** | **0/174** | Live dispatchers (`:1436`, `:1464`) with zero shipped consumers, both confirmed zero by grep. |
| **`EMPTY` as an effect kind** | 11/174 | `Effect.empty` (`scripts/effect_component.gd:1163-1173`) is `Effect.mark` with a different type constant and `cleansable = false` hardcoded, and it has **zero engine readers**. `mark` + the universal `cleansable: false` is behaviourally identical for anything an author can express — and the one difference runs the *wrong* way: `shrug_off_type` (`:1637`) exempts `MARK` from `IGNORE_NON_DAMAGE` but not `EMPTY`, so an `EMPTY` is strictly **more** fragile. |
| **`slot_holds` condition** | 6/174 | Subsumed by the `.effect` axis (§2.2). A dedicated slot-index condition would have to re-derive `BlockValidator.moveset_order` at runtime and would drift from it. |
| **Per-character state variables** | 2/174 | See §5.2. |

### 5.2 Per-character state variables — the measured "no"

The Creator should **not** grow a per-character variable, and the number is why. Of 174 roster
`character/<name>.gd` files, **28** carry non-boilerplate code but **exactly 2** declare a state
variable: `character/yuji.gd:7` and `character/toji.gd:7`. The obvious counter-examples do not use
one — madoka/mami/sayaka's corruption count is `mag` on the Soul Gem MARK
(`character/madoka.gd:29-33`), and `XANXUS_STORAGE` is a nine-key Dictionary on an *effect's* generic
`storage` field (`character/xanxus.gd:60-104`).

The 28 files split into three **procedure** patterns, two of which are already reachable:

- **Startup-installed permanent machinery** (toji, stark, vegeta, saitama, zenitsu, alphamon,
  gallantmon, jinwoo, impmon, yuno, gon, uraraka) — reachable **today** via a Passive whose blocks
  apply `system: true, remove_on_death: false, turns: -1` triggers to `user`, because
  `Character.startup_passives` calls every Passive's `execute()` at battle start.
- **`call_unique` subroutine hubs** — **7/174**. Shared *code*, not shared state; inlineable under
  the 40-block ceiling.
- **Engine-callback targets** (`call_unique("mash","break_vow")`, `call_unique("jaden","break_hero")`)
  — engine hooks with no effect-type row. Stays closed.

The reason, not just the count: an **effect-borne register beats a node var on every axis this engine
cares about** — wire serialisation, rendering, cleanse scoping, death-cleanse, source attribution and
merge-on-(name, type, user) are all properties of `Effect` and **none** is a property of a node var.
That is exactly why `character/toji.gd:62-90` needs hand-written `is_instance_valid` discipline and
`abilities/toji5.gd` has to defensively `user.get("xslash_hits")`.

The one genuine exception is **shape, not storage**: `xslash_hits` is `{enemy: [distinct skill
names]}`, which no scalar encodes. But it decomposes into one invisible per-skill mark applied to the
target by each skill plus *"count the distinct marks on this enemy"* — i.e. it is a **Value-reading
consumer**, not a storage tier. **Build value reading; do not build character variables.**

> [!note] Flagged as opinion
> The measurement is 2/174. The recommendation is a judgement on top of it. Someone could reasonably
> argue the 2/174 is low *because* hand-writing makes an effect-borne register easy and a node var
> awkward, and that authored content has the opposite ergonomics. The counter is the six properties
> above: a Creator-side variable would need all of them re-implemented before it did anything a
> `mark` does not already do.

### 5.3 The bespoke residue — this IS the 14% ceiling

**24/174 characters** remain blocked after building all nineteen buildable items, and every one is
blocked *only* on this tier: `adam, emiya, emiyaarcher, erza, esdeath, frieren, hawkmon, hisoka,
impmon, inuyasha, mavis, minene, muichiro, nagisa, rakko, renamon, rimuru, semiramis, shokuhou, toga,
tokoyami, toph, tsubaki, xanxus`.

| Type | Reach | Why it cannot be exposed |
|---|---:|---|
| `XANXUS_STORAGE` | 1/174 | Six readers, all calling `eff.user.wrath_check(…)` — a method that exists at exactly one place in the repo (`character/xanxus.gd:55`). The same effect on an `AuthoredCharacter` calls a method that does not exist. |
| `NAGISA_DR` | 1/174 | Both readers key on the effect **name** (`scripts/character_component.gd:692`, `:828`). An authored copy does nothing unless the author writes `name_override: "Natural Assassin"` — at which point they hijack Nagisa's mechanic. |
| `DISGUISE` | 1/174 | `Effect.disguise(target_path)` stores a path **string** in `mag`, which `scripts/character_component.gd:355` feeds to `load("res://character/" + name + ".tscn").instantiate()`. An author-supplied string reaching `load()` is precisely the boundary the block system exists to hold. |
| `ERZA_ARMOR`, `HISOKA_HEALTH_FREEZE` | 1/174 each | Produced only by their own `character/*.gd`; store a String in `mag`. |
| **12 engine-hardcoded `path_name`s** | 12/174 | The rule is a branch in the engine reading a name. No palette row reaches it. |
| **`SKILL_COPY`** | **8/174** | *A good mechanic blocked by a bug, not a design.* See below. |

**The general boundary**, extending the one [[Roulette 02 - Death the Kid]] recorded: rules read
**generically off an effect TYPE** are ordinary effects and belong in the Creator — that is the whole
Simple Effect Table. Rules read by the **opponent's** ability, or by a hardcoded name/path branch,
are a property of the *authoring model*, not a missing block: an author's blocks only ever run inside
their own skills.

**`SKILL_COPY` is the one worth engine work later.** At 8/174 (`adam, emiya, impmon, mavis, renamon,
rimuru, shokuhou, tsubaki`) it is well above band-aid territory, and the owner's 2026-07-31 ruling
already stands that copying is an ordinary game outcome, not a safety refusal. But
`Effect.copy_effect` (`scripts/effect_component.gd:591-606`) derives the copied skill's identity from
`copied_skill.get_script().get_path()` via a `substr`, and **every** authored skill's script path is
`res://blocks/scripted_ability.gd` — so the key is garbage, `from_database` returns null, and the
**very next line** null-derefs in a live match. The fix is in `scripts/effect_component.gd`. Nothing
in the block layer should be built first.

### 5.4 Four types in the uncovered census are DEAD in the engine

Verified by grepping the **reader**, then the reader's enclosing branch, then for a **roster
producer**:

| Type | Status |
|---|---|
| `DAMAGE_NEGATE` | Repo-wide it appears on four lines: the enum row (`scripts/types/effect_type.gd:14`), a list membership at `:159`, and `abilities/nobara4.gd:32`/`:67`. **Zero producers, zero readers.** Nobara scans for a type nothing can create. |
| `HEALING_MOD` | `Effect.healing_mod_effect` (`scripts/effect_component.gd:563`) has **zero callers** repo-wide and the type has **zero readers**. The healing modifiers that actually run are `HEALING_RECEIVED_MOD` (1/174) and `HEAL_CUT` (1/174). |
| `DAMAGE_NULLIFICATION` | Live readers (`scripts/character_component.gd:847-853`) but its only producer is `abilities/kakashi2.gd` — a confirmed non-roster orphan. **0/174.** |
| `REFLECT_USE` | Live reader (`:387`) and **zero producers**: all ten `Effect.reflect_effect(` sites pass `REFLECT_RECEIVE`. |

Also fully dead enum rows (zero references outside `effect_type.gd`): `UNIQUE`, `PAYLOAD_SWAP`,
`CURSE`, `DELAY_TICK_TRIGGER`, `HEALING_RECEIVED_TRIGGER`. Reader-only with no producer:
`MISS_CHANCE`, `PRIMARY_STAT_MOD`, `STUN_IMMUNITY`.

> [!danger] The rule this adds to the hygiene list
> **Grep for the READER, then check the reader's enclosing branch, then check that something on the
> ROSTER produces it.** This is now the fifth instance of the same pattern — the dead `trigger_once`
> field, the dead `Effect.banish_effect`, `last_turn_only` being live for exactly one kind, the
> `MISSION_TRIGGER` name-prefix exclusion, and this set. Two of the four above are in the uncovered
> census and **will be re-proposed** by a future run unless the reason is written down.

Related census correction: `abilities/nobara4.gd:29-50` enumerates **22** effect types in a scan
list, inflating every one of them by +1 character; for seven, nobara is the **only** hit. That single
file accounts for the entire "≈20 more at one character each" tail of any token-based ranking.

---

## 6 — The sequenced roadmap

Driven by the cumulative curve in §1, not by per-item reach. The ordering principle the measurement
argues for:

> [!tip] The scheduling insight
> **There is no cheap subset that completes characters.** The cheap tier is worth building — it is
> what makes the two big systems land *on* a character rather than beside one, and it moves the
> "≤1 gap" count from 22 to 56 — but any roadmap that sequences purely by per-item reach and defers
> **Target eligibility** and **Value reading** will spend a lot of engine work and report a
> single-digit change in the only number that means *"this character is authorable"*.

### Phase A — correctness and hardening (before any new capability)

| # | Item | Why first |
|---:|---|---|
| A1 | **Reserved-name blocklist** (§3.6) | A live hole, reachable today with the shipped `mark` kind. One `if`. Every new effect kind widens the surface it protects. |
| A2 | **Engine re-validation of non-`target` pools** (§3.4) | Four ops currently beat invulnerability. Every new POOL or PICK added on top multiplies the defect. **Needs an owner decision** — it nerfs approved content. |
| A3 | **Passive validator rules** (§3.5) | The editor's default blank ability produces an inert Passive. Validator-only. Probe the empty-target chain first. |
| A4 | **`_is_hostile_effect` becomes data** (§2.1) | A prerequisite for the Simple Effect Table, and for `counter.on` (§2.2). Do not defer it into the table's change. |
| A5 | **Retire or wire `and_targeter`** | `blocks/block_validator.gd:36` exposes it, `blocks/authored_character.gd:83` assigns it, and `Ability.and_target` returns false (`abilities/scripts/ability_component.gd:829-830`). An authored `all_enemies` skill with the flag ticked hits everyone when a human plays it and **only the clicked target** when a bot does (`scripts/player_component.gd:1274-1281` vs `webclient/app/app.js:1450-1462`). |

### Phase B — the cheap tier (fields, enum rows, ops)

Fourteen items, 244 character-hits, **7 → 17** fully expressible and **22 → 56** at ≤1 gap.

`bypass_invuln` (33) · `trigger.scope` (32) · `cost_change.mode` (27) · presence `.effect` + `.by`
(27 hard) · `counter.on` (15) · `channel` flag (15) · `adjust` op (40) · `repeat` op, constant form
(20) · `reflect` kind (11) · `on_hp_changed` (11) · `banish` op (5) · `on_stunned` (4) ·
`on_skill_received` (3) · `on_healing_given` (1).

Order within the phase barely matters; the two constraints are that `.effect` and `.by` ship
together, and that `counter.on` ships with A4.

### Phase C — the Simple Effect Table

**+13 → 30 fully expressible, 91 at ≤1 gap.** One arm, N table lines, and a `LIMITS` column designed
with it. **Hold `PORTRAIT_CHANGE` back** for the asset pipeline (tasks #72/#73).

### Phase D — `recurring`

**+8 → 38, 109 at ≤1 gap.** Ships with the two-site `last_turn_only` fix and the `Action`-class
surfacing. **Dependency:** the editor must not offer the *hostile install* until Phase E lands —
about 16 of the 55 characters need `holder` and would otherwise fire backwards. The other ~35 are
correct today.

### Phase E — Payload addressing

**+18 → 56, 143 at ≤1 gap.** The single highest-leverage structural item: two selectors unblock
`recurring`'s hostile half, `on_stunned`, `on_skill_received`, `on_healing_given` **and fix** the
already-shipped `on_damage_dealt` (a probed defect) plus both turn hooks — **seven hooks, one
change**. Ship as `holder` + `affected`, not run 06's single binding.

### Phase F — Target eligibility (layer 1) and the selector object (layer 2)

**+34 → 90, 171 at ≤1 gap.** The largest palette unlock in the document. Layer 2 requires A2. Both
layers require **one** update to `bot_damage_hint` / `custom_behavior`, shared with Phase G.

### Phase G — Value reading

**+60 → 150, 174 at ≤1 gap.** The largest single jump, and the last buildable item. `repeat.times`
takes a reading for free once this lands. Its `cap` and the product-bound (§3.3) are not optional.

### Dependency graph, compressed

```
A1 reserved names ─┐
A4 hostility data ─┼─> C Simple Effect Table
A2 pool re-validation ──> F layer 2 (block selector object)
A3 passive rules   ─┘

E payload addressing ──> D recurring (hostile half only)
                     └─> on_stunned / on_skill_received / on_healing_given
                     └─> fixes on_damage_dealt, on_turn_start, on_turn_end

G value reading ──> repeat.times (the state-driven half of B's constant repeat)
                └─> the `xslash_hits` shape (§5.2), NOT a character variable

one bot-scorer update covers: F (object `target`), G (object `amount`),
                              B `repeat`, D `recurring` (amount x turns)
```

### Cross-cutting hazards to carry through every phase

1. **Per-hook lies.** Four separate controls proposed here are meaningful on some hooks and inert on
   others: `once` (12 dispatchers honour `Effect.triggered`; TICKING, `STUN_RECEIVED`, counters,
   reflects and `DAMAGE_RECEIVE` — where the guard is *commented out* at
   `scripts/character_component.gd:1334-1335` — do not); `last_turn_only`; `trigger.scope`;
   `bypassing` (three different things with one name). Each must be **rejected by the validator** on
   the hooks that ignore it, and the prose must not promise it there. The palette already ships the
   miniature version of this error: the **dead** `trigger_once` is offered
   (`blocks/block_schema.gd:220`) and the **live** `Effect.triggered` is classified as engine
   bookkeeping (`:174-177`) even though three shipped abilities write it as a deliberate author latch
   (`abilities/machinedramon3.gd:43-47`, `frieza2.gd:100-102`, `frieza3.gd:49`).
2. **`on_hp_changed` has no re-entrancy brake.** `check_health_change_triggers` fires from
   `receive_damage` (`scripts/character_component.gd:518`) and the healing path (`:1099`). A payload
   that damages the **holder** re-enters its own trigger, with only `if eff.triggered: continue`
   (`:1320`) as a guard — a field no block can write. Same shape as the run-07 probed
   `on_damage_dealt` self-kill but reachable **without** the mis-binding, because a payload that
   legitimately aims at `holder` is exactly the one that recurses. **Probe it** with run 07's
   two-block payload, self-held, before Phase B ships this row.
3. **Do not wire `COUNTER_USE` from the obvious names.** `check_counter_use_effects`
   (`scripts/character_component.gd:1515`) and `check_counter_receive_effects` (`:1521`) have **zero
   callers repo-wide**. The live path is `countered()` at `:406`, whose loop at `:420-428` walks the
   *acting* character's own `COUNTER_USE` effects and whose return cancels the skill at
   `new multiplayer/battle_manager.gd:1204`. Grepping `check_counter_*` wires a no-op that passes a
   smoke test, because the shipped `counter` kind already works through the real path.
4. **One measurement bucket is genuinely unstable and must be quoted as a band.** The "a count
   reaches a magnitude" shape inside Value reading reads **7/174** under the tightest hand-verified
   rule (an explicit `+= 1` counter in a loop whose variable appears in the amount expression),
   **24/174** when a parser traces any route, and **45/174** under a loose `+=` sweep — because
   damage accumulators look identical to counters. Quote 7 for the counter idiom and 24 for
   "traceable by any route". Never 45.

---

## See also

[[The Creator]] · [[Block Palette Reference]] · [[What Cannot Be Built Yet]] ·
[[Ticking and Passives]] · [[Creator Roadmap]] · [[Creator Roulette]] ·
[[Roulette 02 - Death the Kid]] · [[Roulette 05 - Shiro]] · [[Roulette 06 - Boruto Uzumaki]] ·
[[Roulette 07 - Levi Ackerman]] · [[Roulette 08 - Semiramis]] ·
[[Trigger Types]] · [[Targeting and Main Target]] · [[Effects and Durations]] ·
[[Damage Pipeline]] · [[Cleanse Silence and Effect Removal]] · [[Cooldowns and Energy]] ·
[[Bots and Training]] · [[Server Authority Model]] · [[Verification Playbook]] ·
[[Traps That Have Bitten Us]] · [[Hard Rules and Guardrails]]
