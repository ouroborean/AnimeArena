---
tags: [area/systems, type/reference]
---

# What Cannot Be Built Yet

A measured gap analysis of the block palette against the **1020-file `abilities/` corpus**. Every
usage count below was produced by grepping the real ability scripts; every "what blocks it" claim
names the file and line that does the blocking.

Read [[Block Palette Reference]] first for what *is* possible. [[Creator Roadmap]] turns this list
into an ordered plan. [[The Creator]] covers the safety model these gaps have to respect.

> [!warning] Superseded in three places by [[Creator Gap Analysis]] (2026-08-03)
> That note re-measures the same question against the **174-name roster** rather than the 1020-file
> corpus, which is a different denominator: a filename stem is not a character, and 67 of the 1020
> files belong to 20 orphan stems. Three specific amendments, each with the grep:
>
> - **§3.4 "73 abilities pass `mark_req`" is a ~9x inflation.** The tight fourth-argument grep is
>   **11 files / 7 roster characters** (akame, cooler, diane, lyserg, mami, mars, tsubaki).
> - **§1.7 "control/channel cancel needs a new concept, labelled effects" is refuted.** All 16
>   shipped call sites pass *every* effect the `execute()` applied; **none** is selective. It is one
>   ability-level flag plus an accumulator in `BlockRunner.run`.
> - **Count the FACTORY CALL, not the `EffectType.Type.X` token.** A type whose factory names it is
>   invisible to a token grep — `IGNORE_NON_DAMAGE` is 21/174, `PORTRAIT_CHANGE` 19/174,
>   `ISOLATE` 12/174. Four types in the uncovered census (`DAMAGE_NEGATE`, `HEALING_MOD`,
>   `DAMAGE_NULLIFICATION`, `REFLECT_USE`) are **dead in the engine** and must not get palette rows.
>
> §2.3's figure of 109 non-trivial `extra_usable` bodies reproduces independently at 105 and stands.
> Everything else on this page is unaffected; the two notes are complementary, not rivals — this one
> surveys effect *factories*, the Gap Analysis surveys *characters*.

> [!info] How to read this note
> **Roster impact** = how many of the 1020 ability files use the mechanic. **Difficulty** is the
> honest engineering estimate: `trivial` (a schema entry + a runner case), `moderate` (new
> validator concepts or a runner restructure), `hard` (needs a new concept in the palette or engine
> work). `unsafe` is no longer used as a category — see the corrected note at the end.

---

## Summary — every gap ranked

Ordered by roster impact. The **Signal** column is impact ÷ effort: `A` = build early, `B` = worth
it, `C` = niche, `X` = do not build.

| # | Gap | Theme | Roster impact | Difficulty | Signal |
|---:|---|---|---:|---|:--:|
| 1 | **Stacking marks & per-stack magnitude** | Economy | 114 files set `stackable`, 47 call `stack_count()` | moderate | **A** |
| 2 | **Ability swap / transformation** | Economy | **112 files / 158 sites** — the single most-used effect factory | hard | **A** |
| 3 | **Usage gating beyond effect presence (charges)** | Economy | 109 non-trivial `extra_usable` bodies | trivial | **A** |
| 4 | **Per-target conditional evaluation** | Targeting | 108 abilities branch per-target inside the loop | moderate | **A** |
| 5 | **Stun variants & escape hatches** | Control | 104 files / 112 sites `stun_effect` (~20 exclusion-form) | moderate | **B** |
| 6 | **State-scaled amounts** | Targeting | 86 files pass a state-derived amount | moderate | **A** |
| 7 | **Invulnerability variants** | Control | 77 files / 91 sites `invuln_effect` | moderate | **B** |
| 8 | **Cost modification (`COST_MOD`/`CHANGE`/`COLOR_CHANGE`)** | Economy | 74 files | moderate | **B** |
| 9 | **Mark-gated targeting** | Targeting | 73 abilities pass `mark_req` | trivial | **A** |
| 10 | **Either-faction targeting / `TargetType.ALL`** | Targeting | 73 abilities mark both factions | trivial | **A** |
| 11 | **Invuln-piercing targeting (`bypassing`)** | Targeting | 43 abilities | moderate | **B** |
| 12 | **Counters (`COUNTER_USE` / `COUNTER_RECEIVE`)** | Control | 38 files / 43 sites | moderate | **B** |
| 13 | **Cooldown modification & resets** | Economy | 17 `cooldown_mod` + 14 direct writes + 5 paralyze | moderate | **B** |
| 14 | **Alternate portraits (`PORTRAIT_CHANGE`)** | Economy | 25 files | moderate | **C** |
| 15 | **Taunt** | Control | 23 files / 24 sites | moderate | **B** |
| 16 | **Selfless ally skills (exclude the caster)** | Targeting | 20 abilities | trivial | **A** |
| 17 | **Target-type rewrite (`TARGET_CHANGE`)** | Targeting | 18 files | moderate | **C** |
| 18 | **Control / channel cancel** | Control | 11 + 7 = 18 files | hard | **B** |
| 19 | **Execute (kill below a threshold)** | Control | 17 files | moderate | **B** |
| 20 | **Instant kill / execution** | Control | 16 files | moderate | **A** |
| 21 | **Isolate (no Helpful skills)** | Control | 14 files | trivial | **A** |
| 22 | **Skill copy / steal (`SKILL_COPY`)** | Economy | 13 files | hard (identity fix first) | **B** |
| 23 | **Energy drain / steal** | Economy | 12 files drain, 4 read the pool | moderate | **B** |
| 24 | **Barrier / Nullify + deliberate shatter** | Control | 11 files `barrier_effect` | moderate | **B** |
| 25 | **Reflects (`REFLECT_USE`/`RECEIVE`)** | Control | 10 files | hard | **C** |
| 26 | **Immortality** | Control | 9 files | trivial | **B** |
| 27 | **Main-target vs splash differentiation** | Targeting | 9 abilities split, 21 reference `main_target` | trivial | **A** |
| 28 | **Reactive payloads can't read the event** | Targeting | 9 sites; 277 `trigger_effect` sites corpus-wide | moderate | **B** |
| 29 | **Colour-specific energy gain** | Economy | 8 files | trivial | **A** |
| 30 | **Delay (slow the enemy's skills)** | Control | 7 files `delay_eff` | moderate | **C** |
| 31 | **Banish** | Control | 5 abilities | moderate | **C** |
| 32 | **Paralyze (cooldown freeze)** | Control | 5 files | trivial | **B** |
| 33 | **Damage redirect** | Control | 4 files | moderate | **C** |
| 34 | **`and_targeter` conditional splash** | Targeting | 4 abilities | moderate | **C** |
| 35 | **Counting conditions (effects, allies alive)** | Targeting | 4 gates + 4 scaling sites | moderate | **B** |
| 36 | **Revive a dead ally** | Control | 3 sites | moderate | **B** |
| 37 | **Resource counters (`Effect.mag`)** | Economy | 3 `change_mag` + 7 mag-gated `extra_usable` | moderate | **B** |
| 38 | **Skill seal (deny one specific skill)** | Control | 2 files | moderate | **C** |
| 39 | **Disguise** | Economy | 2 files | not worth building | **X** |
| 40 | **Ignore-skill / full negation** | Control | 1 file (Astolfo) | hard | **C** |
| 41 | **Cost-colour condition ("if taxed")** | Targeting | 11 sites / 9 files | trivial | **B** |
| 42 | **if / else (exclusive branches)** | Targeting | 48 files call `battle.roll`; 11 cost-conditional sites | trivial | **A** |
| 43 | **Random N *distinct* targets** | Targeting | 48 `battle.roll` files; 33 multi-instance loops | trivial | **A** |
| 44 | **Conditionals have no editor UI** | Targeting | **0 authorable vs 6 implemented** | trivial (UI only) | **A+** |

> [!tip] The cheapest win on the whole board is #44
> The condition vocabulary is complete server-side and is already shipped to the client in the
> `authored_palette` reply. There is simply **no control that writes `b.when` or
> `ability.requires`**. `CREATOR_BLANK_ABILITY` seeds `requires: []` at `app.js:5133` and nothing
> ever touches it again. The only thing labelled "when" in the editor is the reactive **trigger**
> picker. Zero schema change, zero validator change, zero balance risk.

---

# Theme 1 — Control effects

Effects that take the opponent's turn away, protect a character, or end one. This is where the
palette's biggest *balance* landmines live, not just its biggest holes.

## 1.1 Stun variants and escape hatches — 104 files / 112 sites

`abilities/gray5.gd` · `abilities/toji4.gd` · `abilities/astolfo4.gd` · `abilities/maka6.gd` ·
`abilities/itachi6.gd`

The palette has `stun`, but only the plain and whitelist forms.
`BlockRunner._build_effect` calls `Effect.stun_effect(dur, _string_list(spec.classes))` with **two
arguments** — the third parameter `exclude_targets` is never passed, so the **exclusion form**
("all Non-Strategic skills are stunned", read at `scripts/character_component.gd:1618`) is
unreachable. That form is ~20 of the 112 sites, including 14 literal
`Effect.stun_effect(2, [], ["Strategic"])`.

Three siblings are also missing entirely: `Effect.ignore_effect_effect(dur, STUN)` — the
stun-immunity hatch `Character.get_stun_immunities` looks for (15 files) — `Effect.false_stun`, and
`Effect.cost_stun_effect` (Toji). And `ScriptedAbility` never assigns `stunnable`, so an authored
skill is always stunnable and can never be the Astolfo-style unstunnable skill (`"stunnable": false`
appears on 9 abilities in `abilities_data.json`).

> [!danger] This one is already a shipped soft-lock
> The current validator accepts `"turns": -1` on `stun`. A Passive containing
> `{"to":"all_enemies","kind":"stun","turns":-1}` wins the match on turn zero. A per-kind duration
> table is a **prerequisite**, not a nicety. Note also that the exclusion form is *stronger* than
> the whitelist form, not weaker — "Non-Strategic is stunned" hits three classes at once.

## 1.2 Invulnerability variants — 77 files / 91 sites

`abilities/toji3.gd` · `abilities/byakuya5.gd` · `abilities/mine2.gd` · `abilities/halibel3.gd` ·
`abilities/itachi4.gd`

Same shape as stun: `Effect.invuln_effect(dur, class_targets)` is called with two args, so
"invulnerable to Non-Strategic skills" (`character_component.gd:1660`) is unreachable (~9 sites).
`Effect.cost_invuln_effect` (cost-colour invuln, Toji) has no kind at all.

> [!danger] `"turns": -1` on `invulnerable` is accepted TODAY
> That produces an **unkillable character**. The only outs are the `Bypassing` class — which no
> authored skill can actually use for targeting — and `DEF_NEGATE`, which is in the palette but on
> the wrong side. This is a live soft-lock, not a hypothetical.

## 1.3 Counters — 38 files / 43 sites

`abilities/gallantmon1.gd` · `abilities/death4.gd` · `abilities/gogeta3.gd` ·
`abilities/gilgamesh2.gd` · `abilities/adam2.gd`

A counter is **not** a reactive and cannot be faked as one. `Character.countered(battle, ability)`
(`character_component.gd:372`) walks `COUNTER_USE`/`COUNTER_RECEIVE` and its **return value cancels
the incoming skill before it executes**. A reactive payload runs after the fact and returns nothing.
`Effect.counter_effect` also takes a `Condition`-driven `Trigger` plus `class_targets` /
`counter_exclude_types` consumed by `Condition.action_countered` (`scripts/condition.gd:247`) —
none of which the palette can construct.

Counter *immunity* is already available: the `Uncounterable` class is whitelisted and read at
`character_component.gd:378`.

**Why it's dangerous:** a counter deletes a skill *and* costs the attacker their whole action. A
permanent, class-unfiltered `COUNTER_RECEIVE` on a Passive would cancel every enemy skill for the
whole match. The corpus' own counters are almost all one-shot, duration-2 and class-filtered.

## 1.4 Reflects — 10 files

`abilities/yubel3.gd` · `abilities/adam2.gd` · `abilities/naruto5.gd` · `abilities/itachi3.gd`

Harder than counters. `Character.reflected()` fires a trigger that **mutates the caster's targeter
in place**; `execute()` then runs against the rewritten list and the trigger's return value is
ignored. Nothing in the palette can touch a targeter. `Effect.reflect_effect` also stores the
redirect destination in `mag` (a live `Character`, or `-1` for "bounce at the attacker") and a
count in `stacks`.

> [!warning] The blocker here is correctness, not balance
> Reflect re-aiming has two well-known traps: a common AoE is target type `ALL(2)`, **not**
> `ALL_FACTION(1)`, and the re-aimed targets must be re-validated against `extra_targetable` and
> bypass-aware invulnerability. If reflect is ever exposed, its payload must be a **fixed
> engine-provided callable**, never author-supplied blocks — even though it superficially looks
> like the counter case. See [[Targeting and Main Target]].

## 1.5 Taunt — 23 files / 24 sites

`abilities/gunha5.gd` · `abilities/allmight4.gd` · `abilities/eren2.gd` · `abilities/jack2.gd`

`Effect.taunt_effect(dur, user)` needs the applying character; `BlockRunner` has `user` in scope, so
the argument is available — there is simply no kind. `Character.resolve_taunt`
(`character_component.gd:1973`) strips every non-ally target off the victim's targeter and appends
the taunter.

> [!danger] The highest-risk trivial-to-implement item on the board
> Taunt + self-invulnerability on the same character is a **total team lockout**: every enemy skill
> is force-aimed at a target that cannot be hit. Invulnerable is *already* in the palette, so the
> combo becomes authorable the moment taunt lands, and no per-block limit can see across two
> abilities on the same character. Duration 1 + single-target + a review-time flag are the only
> real guards.

## 1.6 Barrier / Nullify and deliberate shatter — 11 files

`abilities/chrome1.gd` · `abilities/frieren2.gd` · `abilities/cell3.gd` · `abilities/asta1.gd` ·
`abilities/blackwargreymon3.gd`

Nullify is **not** a shield in the other direction — it sits on the other **character**.
`check_damage_against_shielding` reads the *receiver's* `SHIELD` effects;
`check_damage_against_barriers(source, damage, self)` is called with `self` = the **attacker**
inside `Character.deal_ability_damage` and reads the *dealer's* `BARRIER` effects. Nullify eats the
damage you **deal** — which is why every corpus site applies it with `add_hostile_effect`.

Separately, nothing can shatter defences. `Character.shatter_shields(breaker)` /
`shatter_barrier(breaker)` fire the effects' breaker/wrapup and contingent cleanup, and no op
reaches them. `destructible_break` maps only to `Effect.def_negate`, which sets a flag (and
suppresses the target's invuln at `is_invuln:1638`); it consumes nothing.

> [!warning] Authors will mis-price this because the name reassures them
> The generated description must say "the next N damage **this character deals** is absorbed" or
> every author will read Nullify as a shield.

## 1.7 Control / channel cancel — 18 files

`abilities/hashirama4.gd` · `abilities/gray7.gd` · `abilities/gray6.gd` · `abilities/genos3.gd` ·
`abilities/inuyasha5.gd` · `abilities/horohoro5.gd`

`Effect.control_cancel(dur, ability_name, cancel_effects)` and `channel_cancel(...)` take an **Array
of the live `Effect` nodes** created earlier in the same `execute()`, which `Character.check_cancels`
tears down when the holder is stunned, dies, or acts again. `_op_apply` builds each effect inline
and hands it straight to `add_*_effect` **without retaining a handle**. Expressing this needs a new
concept — *labelled effects* — not just a new kind.

> [!warning] Trap — this gap runs the WRONG WAY
> Control/channel cancel is a **self-imposed drawback**. Meanwhile the validator already whitelists
> `Control`, `Channeled` and `Preserves Channel`, and a repo-wide grep finds no engine read of
> `classes["Channeled"]` or `classes["Control"]`. So an author ticks the label today and ships an
> **uninterruptible** version of a skill that is balanced around being interruptible. Until labels
> exist, the honest move is to strip those three from `_validate_classes`.
>
> The engine-side hazard when it *is* built: an application that was rejected (invuln/dead/ignoring)
> is `queue_free`'d by `_free_unapplied_effect`, and one that merged into a stack is `queue_free`'d
> by the storage component — either leaves a dangling reference and "Invalid access to property
> removed on a previously freed object". Validate `is_instance_valid` before collecting. See
> [[Node Lifecycle and Orphans]].

## 1.8 Execute — 17 files

`abilities/killua3.gd` · `abilities/gon4.gd` · `abilities/cell3.gd` · `abilities/cooler1.gd`

`Character.execute_attempt(threshold, user, ability)` is a real primitive; there is just no op.
"Damage 500 when `hp_below` 20" is **not** equivalent — it is absorbed by shields, damage reduction,
`ignore_damage` and invuln, and it trips damage-received reactives. The condition half already
exists (`hp_below`); only the verb is missing.

## 1.9 Isolate — 14 files

`abilities/blackwargreymon3.gd` · `abilities/hisoka1.gd` · `abilities/esdeath5.gd`

`Effect.isolate` has no kind. `ISOLATE` is read by `Character.is_isolated()`
(`character_component.gd:1745`) and gates `Condition.is_helpable` / `can_allied_target` plus five
targeting helpers in `abilities/scripts/ability_component.gd`.

> [!warning] Invisible in the damage math, so authors under-price it
> Isolate is the hard counter to the entire support archetype. A permanent `all_enemies` isolate
> would delete healing, shields, cleanse and every ally-targeted buff from the opposing team for
> the whole match — strictly stronger than a team stun in a long game.

## 1.10 Immortality — 9 files

`abilities/ichibe5.gd` · `abilities/gunha5.gd` · `abilities/ban6.gd` · `abilities/alphonse4.gd`

`Effect.immortality_effect` has no kind. `IMMORTALITY` is consulted inside `die()` by
`Character.is_immortal()` (`character_component.gd:1770`) — **with no exclusion list at all**, so
unlike permanent invuln it cannot be answered by `DEF_NEGATE` or a Bypassing skill. A 1-turn cap
and a Passive ban are load-bearing, not conservative.

## 1.11 Delay — 7 files

`abilities/aang1.gd` · `abilities/hashirama5.gd` · `abilities/korra10.gd` ·
`abilities/kurotsuchi7.gd` · `abilities/natsu2.gd` · `abilities/soul3.gd`

`Effect.delay_eff` / `delay_receive_eff` / `delay_target_marker` / `delayed_skill_eff` all have no
kind.

> [!info] Partial coverage — only half of this is a gap
> A one-shot **delayed hit** is already expressible as
> `{"kind":"damage_over_time","delayed":true}`, which the runner turns into `last_turn_only` with
> duration `2N+1`. What cannot be expressed is delaying the **enemy's** skills. `DELAYED_SKILL`
> itself is engine-internal even for hand-written kits — `delay_execution` snapshots the caster's
> targeter, state `BlockRunner` never captures.

## 1.12 Banish — 5 abilities

`abilities/itachi2.gd` · `abilities/kurotsuchi4.gd` · `abilities/semiramis5.gd` ·
`abilities/ban6.gd` · `abilities/myotismon3.gd`

`Effect.banish_effect` exists but is never called from `abilities/` — the real entry point is the
**Character method** `Character.banish_character(...)` (`character_component.gd:234`), which builds
the effect, sets `banished = true`, emits `battle.character_banished` and calls `check_cancels()`.
Applying a raw `BANISH` effect through `apply` would set the effect but **never the flag or the
signal** — a silently broken half-banish. Compounding it, `_alive()` filters out banished
characters, so no authored block can even see one.

The safe half is **self**-banish (Ban, Kurotsuchi and Semiramis all banish themselves as an evasion
window). Hostile banish is temporary character-deletion with no cleanse answer. Note the corpus'
self-banishes all pass a `wrapup` return-trigger callable that the block layer cannot express.

## 1.13 Damage redirect — 4 files

`abilities/ichibe6.gd` · `abilities/allmight5.gd` · `abilities/alphonse4.gd`

`Effect.redirect_effect(mag, char_target, dur)` needs a **live `Character` reference** for
`char_target` (read by `check_damage_redirect` at `character_component.gd:963`), and the block layer
has no way to name or hold a character — selectors resolve to a fresh list at execution time and
`_op_apply` forgets it. `mag` is also a **float fraction**, which `_amount`'s int clamp cannot
represent.

Combo risk: redirect 100% of the team's damage onto one character and make that character
invulnerable (already in the palette) and the team takes zero damage.

## 1.14 Revive — 3 sites

`abilities/jeanne4.gd` · `abilities/madoka4.gd` · `abilities/ichibe6.gd`

> [!danger] Unreachable by construction, not merely unimplemented
> There is no revive helper in the engine — the corpus writes `target.dead = false` and restores HP
> directly. And `BlockRunner._resolve_targets` filters **every** selector through `_alive()`, which
> returns false for `c.dead` (`block_runner.gd:120`). An authored block cannot even **enumerate** a
> dead ally. Revive needs a new selector that deliberately skips the alive filter.

## 1.15 Skill seal — 2 files

`abilities/itachi5.gd` · `abilities/itachi7.gd`

`skill_seal` is a boolean field on a MARK, read in `Ability.usable` / `authoritative_usable`
(`ability_component.gd:504`), never set by the runner. There is also no way for a block to **name**
an enemy's abilities — `ability_targets` is never populated and no selector reaches an opposing
moveset. The Creator's only denial tools are `stun` (blocks everything) and `silence` (blocks all
non-Damaging skills).

> [!warning] Seal dodges every piece of stun counterplay
> `skill_seal` is explicitly **not** a stun, so stun-shrugging effects don't interact with it at
> all. Sealing an opponent's two best slots for two turns is strictly stronger than a stun of the
> same length against many kits.

## 1.16 Ignore-skill / full negation — 1 file

`abilities/astolfo3.gd`

Genuinely a one-character mechanic. `Character.is_ignoring_skill` latches the incoming skill's live
`QueryContext` object in `_casseur_ctx` so that **one** skill's damage and *all* of its hostile
effects are negated together. The latch keys on the live context object, not on ability identity, so
an authored source would work unmodified — only the effect kind is missing. Total negation beats
Shield, Barrier, damage reduction and damage caps simultaneously; the mandatory non-empty
`except_classes` (Physical pierces, in Astolfo's version) is the entire balance mechanism.

## 1.17 Instant kill / execution — 16 files — **BUILD IT**

`abilities/hisoka1.gd` and 15 others.

> [!danger] Never expose this
> `Character.instant_kill` bypasses HP, Shield, Barrier, damage reduction, `PERCENT_DR`,
> `DAMAGE_CAP` and every damage-type interaction at once — the only checks inside it are two
> hardcoded name lookups. No cost or cooldown makes "delete one character every N turns" safe, and
> the palette already has `chance` and `hp_below`, so an author trivially turns it into a
> guaranteed execute. `execute_attempt` (§1.8) is the bounded, reviewable version of the same
> desire; ship that instead.

---

# Theme 2 — Economy and kit

Energy, cooldowns, what skills a character *has*, and the resources that make a kit ramp.

## 2.1 Ability swap / transformation — 112 files / 158 sites

`abilities/gray5.gd` · `abilities/ichigo6.gd` · `abilities/hashirama3.gd` ·
`abilities/alphamon2.gd` · `abilities/jinwoo3.gd` · `abilities/alphonse1.gd` ·
`abilities/byakuya5.gd` · `abilities/cell5.gd`

**The single largest expressiveness gap in the corpus.** `Effect.ability_swap_effect` is the
most-used effect factory in this whole analysis — 11% of all ability files.

Blocked **twice over**:

1. **Palette.** No kind maps to `ability_swap_effect`; `Ability.swap_ability` / `swap_abilities`
   are equally unreachable. The effect's `mag` is a `Vector2(slot_swap_in, slot_replace)` indexing
   `moveset.base_abilities`.
2. **Content model.** `AuthoredRegistry.validate_character` hard-errors unless there are **exactly
   4** non-Passive abilities, so there is no fifth, hidden ability a swap could bring *in*. Every
   authored skill is already on the board.

Both `Character.apply_effect` and `MovesetComponent.get_active_abilities` drop a swap whose source
isn't in `base_abilities` — a `ScriptedAbility` satisfies that, so only the palette and the
4-ability rule are in the way.

> [!warning] Two traps waiting for whoever builds this
> **Duration idiom.** Swap durations in this engine are `2N + 1`, not `2N`. Using the plain
> `turns_to_duration` would silently end every authored transformation half a turn early — a
> correctness bug that would arrive as a balance complaint. See [[Effects and Durations]].
>
> **Hidden abilities dodge the budget.** They are invisible in char-select and the draft info
> panel, so a 1-cost transform carrying three 500-damage hidden skills passes every existing
> per-ability limit, because the limits are per **ability**, not per **character**. The generated
> description must print every hidden skill under a "Transforms into:" heading — `split_desc`
> already walks blocks, so that is free.

## 2.2 Stacking and per-stack magnitude — 114 files

`abilities/gilgamesh4.gd` · `abilities/shiro5.gd` · `abilities/aang3.gd` · `abilities/killua3.gd` ·
`abilities/frieza1.gd` · `abilities/ace2.gd` · `abilities/korra11.gd`

114 files set `stackable = true`, 111 set `display_stacks`, 45 use `per_stack`, 50 call
`stack_count()`, 5 call `consume_stack`, 3 call `change_mag`.

`BlockRunner._build_effect` never sets **any** of those fields, and
`EffectStorageComponent.add_effect` only merges when the **already-stored** effect is `stackable`;
otherwise the duplicate is stored as a *separate* effect with `stacks == 1`. `Effect.mark()` does
not set `stackable`.

> [!success] CLOSED — stacking shipped, and it is emergent
> `stackable`, `stacks`, `stack_mag`, `per_stack`, `display_stacks` and the rest are **universal
> effect fields** now: every kind accepts them, applied after the factory returns. Re-applying an
> effect is what banks a stack (`add_effect` merges on name + type + user), so there is no
> `stack` op and stacking is not a mark-only concept. `stacks_at_least` is live.
>
> STILL OPEN: nothing **spends** a stack. `Effect.consume_stack` has no block.

Balance note: `per_stack` scaling is how shipped kits get exponential — cost, cooldown *and* damage
all multiply by `stack_count` in the engine's own loops. Expose stacks as a **gate** and a
**consumable** before ever exposing them as a multiplier.

## 2.3 Limited-use charges — 109 non-trivial `extra_usable` bodies

`abilities/gilgamesh4.gd` · `abilities/ganta3.gd` · `abilities/hawkmon3.gd` ·
`abilities/ichibe5.gd` · `abilities/gatomon3.gd`

Of the 109: 88 gate on effect presence (which `requires` + `has_effect` **already models exactly**),
11 on stack counts, 7 on an effect's `mag`, 4 on ally alive/dead, 3 on HP, 3 on a resource mark.

> [!info] The once-per-match case is already expressible — this is not claimed as a gap
> Apply `{"kind":"mark","turns":-1}` to the user, and set
> `requires: [{"cond":"not_has_effect","name":"<this ability's own name>","on":"user"}]`.
> It works because `effect_name()` returns `source.ability_name` and `turns_to_duration(-1)` is
> permanent. **N charges** is what is unreachable, because there is no counter to increment and
> `stacks_at_least` is dead (§2.2).

## 2.4 Cost modification — 74 files

`abilities/allmight5.gd` · `abilities/crona2.gd` · `abilities/alphamon1.gd` ·
`abilities/uryu2.gd` · `abilities/boruto2.gd` · `abilities/gallantmon3.gd`

49 files use `cost_mod_effect`, 25 `cost_change_effect`, 10 `color_change_effect`. None is in
`EFFECT_KINDS` and `_build_effect` has no case, so all three factories are unreachable — even
though `Ability.cost()` already reads all three EffectTypes off the user. **The engine side is
fully wired; only the palette entry is missing.**

> [!warning] `ability_targets` is matched by ABILITY NAME
> Unchecked, an author could hard-code a *shipped* character's skill name and tax one specific
> opponent's kit. Any implementation must cross-check `skills` against this character's own ability
> names in `validate_character`.

Worst case if unguarded: a `cost_change` to `{}` (free skills) on the user for `-1` turns bypasses
every energy-based limit the Creator has. See [[Cooldowns and Energy]].

## 2.5 Cooldown modification and resets — ~36 files

`abilities/gogeta2.gd` · `abilities/erza4.gd` · `abilities/kurotsuchi8.gd` ·
`abilities/frankenstein2.gd` · `abilities/stark1.gd` · `abilities/jack4.gd`

17 files use `Effect.cooldown_mod`; 14 write `cooldown_remaining` directly (8 of them reset to 0);
5 use `paralyze_effect`. No effect kind, no op touches `cooldown_remaining`, and there is no field
that names a specific ability.

> [!danger] The load-bearing rule for whoever builds the direct form
> `battle_manager.gd` calls `ability.start_cooldown()` at **line 1190** and `execute()` at **line
> 1206**. A skill that resets *its own* cooldown would land **after** the cooldown was written and
> become **infinitely repeatable**. Any cooldown op must reject `skill` naming its own containing
> ability when `amount < 0`. It must also match by `ability_name`, **not** by index —
> `abilities/stark1.gd` documents exactly why (a copied or swapped skill runs from a caster whose
> slot 3 is a different skill).

## 2.6 Paralyze — 5 files

`abilities/yoruichi1.gd` · `abilities/rimuru2.gd` · `abilities/kurotsuchi8.gd` ·
`abilities/mercury2.gd` · `abilities/gatomon2.gd`

`Effect.paralyze_effect` has no kind, and `PARALYZE` is not reachable any other way —
`MovesetComponent.advance_cooldowns` reads `user.paralyzed()` which only walks PARALYZE effects.
Trivial to add.

Paralyze does not stop a skill being *used*; it freezes the countdown. The abuse is
Paralyze + Stun on the same target: a 2-turn stun on a 4-cooldown skill costs the victim 6 turns
instead of 4. The known `start_cooldown` +1 bookkeeping stamp is already handled inside
`_advance_one`, so an authored paralyze inherits that fix for free.

## 2.7 Energy drain / steal — 12 files

`abilities/kurapika5.gd` · `abilities/uraraka1.gd` · `abilities/toph1.gd` ·
`abilities/machinedramon1.gd` · `abilities/kuroko1.gd` · `abilities/fern1.gd`

`gain_energy` is the only op that touches energy and it calls `user.gain_random_energy()` and
nothing else. There is no path to `Character.lose_energy`. `OPS["gain_energy"]["fields"]` is
`["amount"]` only, so even a `to` selector is rejected as an unexpected field. And no condition
reads `team.energy` — 4 files (`fern1/2/3/5`) read the pool directly for gating and scaling.

> [!warning] Two implementation traps
> Energy is a **team pool** — draining `all_enemies` would drain 3× for one block unless targets are
> deduped by `.team`. And `TeamComponent.lose_energy` silently returns on an empty pool, so a naive
> `steal` would **mint free energy**; count what was actually removed.

Energy denial is the strongest tempo lever in the game and it is **un-cleansable** — there is no
counterplay effect for lost energy.

## 2.8 Colour-specific energy gain — 8 files

`abilities/naruto3.gd` · `abilities/frieren3.gd` · `abilities/luffy1.gd` · `abilities/itachi6.gd` ·
`abilities/aang6.gd` · `abilities/yuno3.gd`

`_op_gain_energy` hard-calls `gain_random_energy()` in a loop.
`Character.gain_bonus_energy(element)` is unreachable, and the fields list rejects a `color` key.
Trivial and backward-compatible (omitted colour keeps today's behaviour).

A guaranteed colour is **strictly stronger** than a random one — it fixes exactly the colour the
character's own expensive skill needs, turning a 4-colour kit into a mono-colour engine.

## 2.9 Resource counters (`Effect.mag`) — 3 `change_mag` + 7 mag-gated `extra_usable`

`abilities/uryu2.gd` · `abilities/uryu5.gd` · `abilities/byakuya5.gd` · `abilities/korra11.gd` ·
`abilities/jaden3.gd` · `abilities/madoka4.gd`

Nothing can read or write `Effect.mag`, and no condition reads it (hand-written kits use
`Condition.mag_is` constantly). `on_turn_start` exists as a trigger, but its payload can only run
the same six ops, none of which sets a counter to a value.

> [!info] There are no true team-shared pools in the engine — measured
> The only cross-character pool is `TeamComponent.energy`. `uryu2/3/5` emulate a private pool with a
> per-**character** MARK carrying `mag`. A "team resource" would be new `TeamComponent` state plus
> a wire field plus client rendering; the cheap approximation is a mirrored mark on `all_allies`,
> which the existing selector already supports.

`abilities/korra11.gd` documents the crash to avoid: a null-guard is mandatory, because a cleanse
can strip the counter before the op runs.

## 2.10 Alternate portraits — 25 files

`abilities/cell5.gd` · `abilities/eren3.gd` · `abilities/cooler6.gd` · `abilities/halibel5.gd` ·
`abilities/gatomon3.gd` · `abilities/chrome3.gd`

Blocked **three** independent ways: no kind for `Effect.portrait_change_effect`; its `mag` indexes
`Character.alt_portraits`, which only hand-written `character/<name>.gd` scripts populate
(`AuthoredCharacter.initialize` never sets it, so any index is out of range); and
`AuthoredAssets.SLOTS` has exactly **one** portrait slot, so there is nowhere to upload a second
image. Task #73 is also still open — authored characters render no portrait in battle at all yet.

Cosmetic, so the risk is **informational**: a portrait change with no kit change misleads the
opponent into playing around a transformation that never happened.

## 2.11 Skill copy / steal — 13 files — **UNSAFE**

`abilities/emiya1.gd` · `abilities/emiya2.gd` · `abilities/emiya7.gd` · `abilities/adam1.gd` ·
`abilities/adam2.gd`

> [!danger] Two independent reasons, either of which is disqualifying
> **It cannot work.** `Effect.copy_effect` derives the ability key from the copied skill's **script
> path** via `path.substr(16, len(path) - 3 - 16)` — correct for `res://abilities/emiya1.gd` →
> `emiya1`, but every authored skill's script is `res://blocks/scripted_ability.gd`, which yields a
> garbage substring. `Ability.from_database` then warns "unknown ability key" and returns null, and
> the very next line, `effect.ability_targets.user = user`, **null-derefs in a live match**.
> Authored abilities aren't in `abilities_data.json` at all, so no key could ever resolve.
>
> **It launders the validator.** A copied skill is hand-written GDScript executing engine calls the
> block validator never reviewed. An authored character with one cheap "copy" skill inherits the
> strongest shipped kit's skill at the *authored* skill's cost and cooldown — and inherits that
> skill's bespoke character coupling (several shipped abilities branch on `user.path_name`),
> producing undefined behaviour on an `AuthoredCharacter`.

## 2.12 Disguise — 2 files — **UNSAFE**

`abilities/toga5.gd` · `abilities/minene3.gd`

> [!danger] This is arbitrary code execution reached from authored data
> `Effect.disguise`'s `mag` is a **character path string**, resolved in `Character.active_portrait`
> by calling `Character.from_character_name(disguise_path)`, which does
> `load("res://character/" + char_name + ".tscn").instantiate()`. An author-supplied string is
> concatenated into a resource path and the resulting scene is instantiated — and instantiating a
> scene runs whatever script is attached to it. **That is exactly the boundary the entire block
> system exists to hold.** No numeric limit mitigates it. If disguise is ever wanted it must be a
> server-resolved **integer index** into a whitelist, never a name.
>
> Secondary: the current resolve path builds and frees an entire 7-component character on *every
> portrait resolve*, and would recursively call `AuthoredRegistry.build_character` if the name
> happened to be another authored id.

---

# Theme 3 — Targeting and logic

Who a block hits, when it fires, and what its numbers are made of. These are the gaps that make
authored skills feel *flat* — the same number to everyone, every time.

## 3.1 Conditionals have no editor UI — 0 authorable vs 6 implemented

`blocks/block_schema.gd` · `blocks/block_runner.gd` · `blocks/scripted_ability.gd` ·
`webclient/app/app.js`

The condition vocabulary is complete server-side: `CONDITIONS`, `_check_condition`,
`_validate_condition`, `extra_usable`. `_authored_palette` even ships `CONDITIONS` to the client.
But `creatorBlock()` (`app.js:5340`) renders only the op's own fields — **nothing writes `b.when`,
and nothing anywhere writes `ability.requires`**. The only thing labelled "when" in the UI
(`app.js:5391`) is the reactive **trigger** picker.

Result: **a player cannot author any conditional at all.** No schema change, no validator change,
no balance risk — `_validate_condition` and the `requires` size cap already exist and the server is
the source of truth. `_describe_condition` already renders both into the preview.

## 3.2 State-scaled amounts — 86 files

`abilities/killua3.gd` · `abilities/fern1.gd` · `abilities/frankenstein3.gd` ·
`abilities/ganta2.gd` · `abilities/frieza1.gd` · `abilities/cell1.gd` · `abilities/broly4.gd` ·
`abilities/blackwargreymon3.gd`

`BlockRunner._amount` is `clampi(int(v), 0, max_amount)`, and `_validate_amount` rejects anything
that is not int/float outright. **Every** damage, heal, shield, DoT and boost value an author can
write is a compile-time constant. There is no expression node and no accessor for stack counts, HP,
the energy pool, or team composition.

Measured: 86 files pass a state-scaled amount (classified over 497 `resolve_damage` call sites); 47
call `stack_count()`; 70 read `health.hp`; 3 read the energy pool.

> [!warning] If this ships, `bot_damage_hint` must learn the new form
> `_block_damage` reads `int(b.get("amount", 0))`. An object-form amount would score as **0**, so
> the v3 policy would never use any scaling skill. See [[Bots and Training]].

Unbounded ramp is the risk; a mandatory `cap` field is the guard. Note `fern1`'s leftover-energy
scaling is deliberately balanced by *consuming* that energy — an author would take the payout
without the cost.

## 3.3 Per-target conditional evaluation — 108 abilities

`abilities/nonon5.gd` · `abilities/cell3.gd` · `abilities/esdeath1.gd` · `abilities/gilgamesh1.gd` ·
`abilities/hashirama1.gd` · `abilities/byakuya6.gd` · `abilities/emiya4.gd`

`_run_block` checks `when` **once** before dispatching, and `_check_condition` resolves `on` to a
list and returns true if **any** member matches. The op then runs over its own full target list.

```json
{"op":"damage","to":"all_enemies","when":{"cond":"hp_below","value":40,"on":"all_enemies"}}
```

damages **every** enemy the moment **one** is under 40. There is no selector meaning "the target
currently being acted on".

> [!warning] This is arguably a live correctness bug, and fixing it is a NERF
> Today's any-of behaviour is strictly more permissive than per-target. Any already-approved
> authored AoE would get **weaker** if `when`'s meaning changed, so it must ship as an opt-in
> `per_target` flag rather than a semantic change.

## 3.4 Mark-gated targeting — 73 abilities

`abilities/killua3.gd` · `abilities/blackstar1.gd` · `abilities/death1.gd` · `abilities/cell7.gd` ·
`abilities/cooler3.gd` · `abilities/bakugo2.gd` · `abilities/boruto7.gd`

`ScriptedAbility.target` calls the default helpers with only two arguments. Both accept a **4th
`mark_req`** parameter (`ability_component.gd:803`) that filters candidates by
`has_effect(mark_req, MARK, user)`. There is no authoring field that reaches it.

An author can approximate the *usability* half with `requires` + `has_effect`, but that gates the
whole skill, not the target list — so the skill becomes usable on **any** enemy the moment one
enemy anywhere is marked. Restrictive, not permissive: the abuse direction is nil.

## 3.5 Either-faction targeting and `TargetType.ALL` — 73 abilities

`abilities/edward5.gd` · `abilities/korra9.gd` · `abilities/mars1.gd` · `abilities/nezuko1.gd` ·
`abilities/saitama3.gd` · `abilities/madoka3.gd` · `abilities/hashirama1.gd` · `abilities/gray6.gd`

Blocked three times: the validator restricts `target` to five modes;
`Ability._target_type_from_mode` maps them to only `SINGLE` / `ALL_FACTION` / `SELF`, so
`TargetType.Type.ALL` is never produced; and `ScriptedAbility.target` picks exactly **one** of the
three default helpers, so a single authored skill can never mark both factions legal.
`ALL` vs `ALL_FACTION` only differ when both factions are targetable, so the whole `ALL` branch is
unreachable for authored content. 147 `abilities_data` entries carry `ALL`; 11 carry `ALL_FACTION`.

Cheap: each helper only sets the `targeted` flag, so calling **both** is exactly what the 73
both-faction abilities do today. `_op_apply` already decides hostile-vs-allied per target, so a
mixed list routes correctly for free.

## 3.6 Main-target vs splash — 9 abilities split, 21 reference `main_target`

`abilities/gojo3.gd` · `abilities/korra7.gd` · `abilities/ace3.gd` · `abilities/mash2.gd` ·
`abilities/tsunayoshi1.gd` · `abilities/boruto6.gd` · `abilities/jupiter3.gd`

`SELECTORS` has no notion of the clicked target — `target` resolves to the **whole** targeter list.
`TargeterComponent.main_target` exists and is maintained, and `get_other_aoe_targets` appends the
splash members around it, but `BlockRunner` never reads it. So an authored AoE necessarily applies
the same amount to everyone. `gojo3` is 45 to the main target and 15 to the rest — inexpressible.

Adding `main_target` / `other_targets` selectors needs **no validator change** (the `to` whitelist
check picks them up automatically) and reads, rather than changes, the ordering invariant that
`main_target` is `targets[0]`. See [[Targeting and Main Target]].

## 3.7 Invuln-piercing targeting — 43 abilities

`abilities/mine2.gd` · `abilities/byakuya7.gd` · `abilities/gunha5.gd` · `abilities/toji4.gd` ·
`abilities/hisoka1.gd`

`Condition.can_hostile_target` drops the `not_invuln` requirement only when the **`bypassing`
parameter** is true (`scripts/condition.gd:166`). The `Bypassing` **class** is consulted nowhere in
the targeting path — its only reader is `Ability._skill_pierces_invuln`, used for reflect re-aiming.
`ScriptedAbility.target` always passes `bypassing = false`.

> [!danger] The editor ships a class that does nothing useful and one thing surprising
> `app.js:5299` offers "Bypassing" and `_validate_classes` accepts it. An author ticks it, reads
> the class name, and gets a skill that **still cannot be aimed at an invulnerable enemy** — while
> `_skill_pierces_invuln` treats it as piercing for reflect purposes. Either wire the class to
> `bypass_invuln` or remove it from the chip row; leaving it is worse than both.

## 3.8 Reactive payloads cannot read the event — 9 sites (277 trigger sites corpus-wide)

`abilities/power5.gd` · `abilities/denji5.gd` · `abilities/marco6.gd` · `abilities/natsu5.gd` ·
`abilities/ryuko3.gd` · `abilities/soul5.gd` · `abilities/old5.gd` · `abilities/sayaka5.gd` ·
`abilities/ryohei4.gd`

The payload closure receives the full `QueryContext` and uses exactly **two** fields —
`context.get("effect").user` and `context.get("owner")` — and discards the rest. `QueryContext`
carries `value`, `damage_type` and `source`, but neither `_amount` nor `_check_condition` can see
them. So "heal for half the damage you just took" (`power5` is literally
`int(context['value'] / 2.0)`), "only react to Affliction damage", and "only react when skill X hit
you" are all unauthorable — even though the reactive block itself exists.

Event-scaled payback scales with the **opponent's** investment, which is the strongest scaling axis
in the game. Any exposure needs a mandatory cap and must not feed an `all_enemies` damage op.

## 3.9 if / else — 48 files call `battle.roll`

`abilities/koro2.gd` · `abilities/erza4.gd` · `abilities/inuyasha5.gd` · `abilities/boruto5.gd` ·
`abilities/saber2.gd` · `abilities/death2.gd`

`when` is a **one-sided** guard, and `group` carries only `blocks`. Two blocks with
`{"cond":"chance","percent":50}` roll **independently**, so both can fire or neither — there is no
way to express "a coin flip: heal OR shield". The same hole applies to non-random branches: only
`has_effect` has a negation; `hp_below`/`hp_above` overlap at the boundary, and `stacks_at_least`
and `chance` have no complement at all.

> [!info] Fixing this makes authored randomness *weaker*, not stronger
> Two independent 50% blocks average 1.0 payloads **with a 25% double**. One exclusive branch
> averages exactly 1.0 with no double. Keep the single-roll-per-group property.

Implementation note: `_count_blocks` **must** recurse into `else` or the 40-block ceiling is
trivially doubled.

## 3.10 Random N distinct targets — 48 `battle.roll` files, 33 multi-instance loops

`abilities/frieren7.gd` · `abilities/gatomon11.gd` · `abilities/hisoka1.gd` · `abilities/fern3.gd` ·
`abilities/jaden5.gd` · `abilities/eren3.gd`

`random_enemy` / `random_ally` pick exactly **one** with a single roll and no memory. Repeating the
selector samples **with replacement** — three `random_enemy` blocks can all land on the same enemy —
and the count is fixed at author time. `frieren7` rolls 2 targets; `gatomon11` rolls 9.

Fisher-Yates over the living pool using `battle.roll` keeps replays and the differential fixture
bit-reproducible.

## 3.11 Counting conditions — 4 gates + 4 scaling sites

`abilities/natsu4.gd` · `abilities/inosuke3.gd` · `abilities/aiohto2.gd` ·
`abilities/blackwargreymon3.gd` · `abilities/hisoka6.gd` · `abilities/aiohto5.gd`

Every condition is boolean-per-character folded with an any-of. `stacks_at_least` counts stacks on
one named MARK, not effects. Nothing counts distinct effects, living allies, or living enemies. So
"if the target has 2+ debuffs", "if you are the last one standing" and "for each effect removed" are
unauthorable.

> [!danger] Counting is an information-leak vector
> Any effect counter **must** apply the same visibility filter as the rest of the engine. The
> `display_system` split has **eight** filter sites that have to agree; a count that includes
> system/invisible effects both leaks hidden information to the opponent and trips the drift
> validator every turn. See [[Effects and Durations]].

## 3.12 Target-type rewrite (`TARGET_CHANGE`) — 18 files

`abilities/byakuya5.gd` · `abilities/hinata2.gd` · `abilities/ichigo3.gd` · `abilities/madoka2.gd` ·
`abilities/chrome3.gd` · `abilities/lyserg1.gd`

`Effect.target_change_effect` has no kind, and `ScriptedAbility.target` branches purely on the
static `target_mode` set at `configure()` time — so an authored skill's targeting is fixed for the
whole match.

> [!warning] Widening is a raw 3× multiplier the per-block cap never observes
> `max_amount` is per **damage block**; the multiplication happens at **targeting** time. A
> 100-damage single-target skill becomes 300 spread damage for the price of one buff. It also
> silently breaks the generated description, which prints the static `target_mode`. Narrowing
> (`all_enemies` → `enemy`) and ally-side changes are free.

## 3.13 Selfless ally skills — 20 abilities

`abilities/hinata2.gd` · `abilities/tsubaki5.gd` · `abilities/alphonse4.gd` ·
`abilities/gatomon3.gd` · `abilities/halibel5.gd`

`Ability.selfless` is honoured by `default_allied_target_function` and copied by
`Ability.from_database`, but `AuthoredCharacter._build_moveset` never assigns it and there is no
schema field. So every authored `ally` / `all_allies` skill can be aimed at the caster — the classic
"heal a **teammate** for a lot" design collapses into a self-heal.

> [!warning] If this ships, `all_allies` must follow
> `all_allies` currently **includes** the user. With `exclude_self` set, a `to: all_allies` block
> must resolve like `other_allies`, or the skill applies its effect to a character it could not
> legally target — exactly the drift the validator exists to prevent.

## 3.14 `and_targeter` conditional splash — 4 abilities

`abilities/nonon5.gd` · `abilities/koro2.gd` · `abilities/hawkmon5.gd` · `abilities/kakashi4.gd`

The least-used mechanic in the analysis. `Ability.and_target(character)` is a virtual returning
false and `and_targeter` is a plain export flag read by `get_other_aoe_targets`.
`ScriptedAbility` overrides neither and `_build_moveset` never sets the flag. So "hit the clicked
enemy **and** every enemy carrying mark X" is inexpressible — only exactly-one or the whole faction.

> [!danger] The predicate must be pure
> `and_target` is queried from `character_component.gd:2004`, `player_component.gd:879/1125/1278`
> and `battle_manager.gd:1819` — **four different code paths at different moments**. A `chance`
> predicate or any state mutation inside it would desync the client and server on who got hit.

## 3.15 Cost-colour condition — 11 sites / 9 files

`abilities/death1.gd`–`death4.gd` · `abilities/saber2.gd` · `abilities/seventeen1.gd`–`4.gd`

All six conditions read a **character** or the RNG; none reads the **ability**. `Ability.cost()`
resolves `COST_CHANGE` / `COST_MOD` / `COLOR_CHANGE` every time it is called, but `BlockRunner` has
no accessor, so authored content cannot react to being taxed.

> [!warning] Trap — the honest wording is the opposite of the obvious one
> `cost()[RANDOM] >= 1` is true **only** when an opposing `COST_MOD` has taxed the caster; base
> costs never carry Random. So the description must read "if an enemy has increased this skill's
> cost", not "if this skill costs 1 Random". Getting this wrong is a known trap in this codebase —
> an author would otherwise write a skill whose stated condition is the inverse of its real one.

Low risk: it pays out precisely when the author's character is being suppressed. It stays safe only
as long as authored content cannot apply cost effects (§2.4) — the two must be reviewed together.

---

## Where the honest "no" lives

> [!info] Owner ruling, 2026-07-31 — this section was previously wrong
> Instant kill, execution and ability copying were marked "unsafe to expose". **They are not.** They
> are ordinary in-game ability outcomes and belong in the Creator like any other. What follows is the
> corrected list: two mechanics with real *technical* obstacles, and one that is simply not worth
> building. None of them are safety refusals.

| Mechanic | Status |
|---|---|
| **Instant kill / execution** (§1.17) | **Build it.** It is a normal outcome the roster already uses in 16 files. The design question is only the usual one — cost, cooldown and validator limits — not whether to expose it. A thresholded `execute` and an unconditional `instant_kill` can both exist; the roster contains both. |
| **Skill copy** (§2.11) | **Build it, after an identity fix.** No safety objection: copying a skill is a shipped mechanic. The blocker is technical — `Effect.copy_effect` derives the copied skill's identity from `copied_skill.get_script().get_path()` (`scripts/effect_component.gd:589`), and an authored ability has no script file, so the copy path has to key off ability identity instead before this can ship. |
| **Disguise as a name** (§2.12) | **Not worth building.** Toga-specific and used by 2 files; there is no general design here worth the surface. Note in passing that the current factory concatenates a caller string into `load()` + `instantiate()`, so if it were ever exposed it would need a server-resolved index rather than a name — but the simpler answer is that authors do not need it. |
| **Author-written reflect payloads** (§1.4) | **Correctness, not safety.** Targeter mutation with the `ALL` vs `ALL_FACTION` trap and bypass-aware re-validation is a bug factory in author hands. A fixed engine callable with an author-supplied *magnitude* is the right shape. |

---

## See also

[[The Creator]] · [[Block Palette Reference]] · [[Creator Roadmap]] · [[Ticking and Passives]] ·
[[Effects and Durations]] · [[Trigger Types]] · [[Targeting and Main Target]] ·
[[Damage Pipeline]] · [[Cooldowns and Energy]] · [[Node Lifecycle and Orphans]] ·
[[Traps That Have Bitten Us]]
