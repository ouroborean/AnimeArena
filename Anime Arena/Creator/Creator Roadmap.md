---
tags: [area/systems, type/howto]
---

# Creator Roadmap

> [!info] Rewritten 2026-08-03 — this supersedes the previous roadmap in full
> The old eight-phase plan (Phases 0–7) is retired: most of its first three phases have **shipped**
> (see the ledger below) and its factual base was [[What Cannot Be Built Yet]], a per-gap survey.
> This roadmap is built from [[Creator Gap Analysis]] — the whole-corpus measurement across all 174
> roster characters — with its §6 sequencing, plus the verified corrections folded in: payload
> addressing moves early and ships as **two** selectors, the cheap tier is re-counted at its
> unique-axis reach (~217 hits, not 244), and the honest ceiling is **~146–147/174**, not 150.
> Reach numbers are quoted from the gap analysis, never re-derived here.

Every phase covers **both** halves of the Creator: the programmatic side (`blocks/block_schema.gd`,
`blocks/block_validator.gd`, `blocks/block_runner.gd`, engine primitives) and the **editor palette
UI** in `webclient/app/app.js`. The editor is palette-driven: the server ships `BlockSchema`
verbatim via `_authored_palette` (`components/server_connection.gd:4354-4392`), the client stores it
at `S.creator.palette` (`webclient/app/app.js:140`, `:5223`), and **one renderer** — `creatorBlock`
at `app.js:5662` — draws every block. But be precise about what "palette-driven" means, because the
distinction is this roadmap's whole UI ledger: the palette drives **enum contents and field
lookups**, not **control existence**. Per-op controls are hardcoded `else if (b.op === ...)`
branches (`app.js:5678-5771`), and effect-kind fields render only through a fixed chain of known
field NAMES (`:5725-5764`). A new op or a new field name renders **nothing** until it gets a
branch — the client documents this exact failure at `app.js:5595-5596`: *"`break` was offered by
the add-row but rendered no controls, so it was structurally invalid the moment it was added."*
So: new enum VALUES in existing dropdowns are free; new ops and new field names each need a small
(1–5 line) control branch; and only two genuinely NEW widgets exist in this roadmap — the
**selector card** (Phase F, built once, mounted twice) and the **scaling-amount editor** (Phase E).

Prerequisites: [[The Creator]] for the architecture and safety model, [[Block Palette Reference]]
for the current palette, [[Verification Playbook]] and [[Hard Rules and Guardrails]] for how work
lands in this repo. Palette export changes must be mirrored to deploy — see
[[Data Files and the Deploy Mirror]].

> [!warning] Two standing rules that shape every table in this document
> **1. The Creator never enforces a restriction the game does not have.** Parameters — durations
> included — stay author-controlled. Every validator limit below names the **abuse case it
> prevents**; a limit that cannot name one does not ship. The old roadmap's prescriptive numeric-cap
> tables (turns-1-only, cooldown ≥ 3, one-per-ability) violated this rule, were demonstrably not
> adopted by the shipped validator (`blocks/block_validator.gd:425` allows `-1` universally, and the
> counter comment at `:346-349` explicitly makes duration author-controlled), and **do not carry
> over**.
>
> **2. `split_desc()` / generated prose is the contract; `describe()` is not written for new work.**
> Every new block must generate readable prose and carry a `bot_tags` story, or it ships as a skill
> whose tooltip lies and that the v3 bot values at zero ([[Bots and Training]]).

---

## The plan on one page

| Phase | What | Reach gained | Engine cost | UI cost | Depends on |
|---|---|---|---|---|---|
| **A** | Correctness & hardening: reserved names, pool re-validation, Passive rules, hostility-as-data, `and_targeter`, banish-flag desync | none new — protects 100% of authored content | small, scattered fixes | ~zero (one seeding line, one chip removed) | **owner decision** on A2 (nerfs approved content) |
| **B** | The cheap tier (13 items, ~217 hits) + **payload addressing** (`holder`/`affected`) + the event-class filter | 7 → ~17+ fully expressible, 22 → ~56+ at ≤1 gap *(provisional — see B)* | schema/runner rows; two resolver arms + two stashes | nearly free; three small widget extensions | A4 (`counter.on`), A6 (`banish`) |
| **C** | The Simple Effect Table (~20 data rows, one build arm) | ≈+13 → ≈30 full, ≈91 at ≤1 gap *(provisional)* | one `_build_effect` arm + N table lines | **free** | A2, A4 |
| **D** | `recurring` — authorable ticking | ≈+8 → ≈38+ *(provisional; hostile half included, since B ships addressing)* | none for the kind; two-site `last_turn_only` fix | small (nesting gate + 2 fields) | B |
| **E** | Value reading — live state as a number | the +60 pool starts landing *(provisional)* | amount branch + **the bot-scorer update** | one new widget (small) | pairs with B's `adjust` |
| **F** | The selector system: eligibility object + block selector object | the +34 pool; cumulative → **~146–147/174** | `target()` + `_block_targets` generalisation | **the** new widget (selector card, two mounts) | A2, E |
| **G** | Long tail, parallel asset track (#72/#73), engine-fix-later, and the do-not-build ledger | closes the buildable set at the ceiling | per item | mostly free | varies |

The ordering principle, from [[Creator Gap Analysis]] §6: **there is no cheap subset that completes
characters.** The cheap tier is what makes the two big systems land *on* a character rather than
beside one, but any plan that defers eligibility and value reading spends a lot of engine work and
reports a single-digit change in "this character is authorable".

---

## Shipped since the last roadmap

So history is not lost — the old plan's Phases 0–2 are largely done and pieces of 3–7 landed under
other names. None of this is scheduled again.

| Old item | Where it lives now |
|---|---|
| Phase 0 condition UI (`when` + `requires`) | `webclient/app/app.js:5529` (composite condition editor), `:5396-5403` (requires) |
| Phase 0 `bot_tags` derived property | `blocks/scripted_ability.gd:403` |
| Phase 1 `used_ability` borrow fixes | `blocks/block_runner.gd:292-323` |
| Phase 1 server-driven class chips | `components/server_connection.gd:4381` → `app.js:5347` |
| Phase 1 stun-class whitelisting | `blocks/block_validator.gd:324-325` |
| Phase 2 `paralyze` + `taunt` kinds, `gain_energy` colour, `everyone` mode | `blocks/block_schema.gd:134-135`, OPS `:301`, `GAIN_COLOURS` `:280`; `blocks/block_validator.gd:28` |
| Phase 3 universal stacking (the `stack` op was **removed** — stacking is emergent via `stackable`) | `UNIVERSAL_EFFECT_FIELDS` `blocks/block_schema.gd:195-223` |
| Phase 3 spending stacks | `remove` with `stacks` (`blocks/block_schema.gd:321`) |
| Phase 4 `shatter` | the `break` op (`BREAK_TARGETS` `blocks/block_schema.gd:336`) |
| Phase 4 `stun_immunity` | `effect_immunity` (`blocks/block_schema.gd:136`, derived vocabulary `:269-274`) |
| Phase 5 `cost_change` / `cooldown_change` kinds | `blocks/block_schema.gd:132-133` |
| Phase 6 `counter` kind with nested `then` + `scope` (incl. raw class lists) | `blocks/block_schema.gd:131`, `blocks/block_validator.gd:342-355` |
| Phase 7a ability swap + hidden abilities, complete | swap kind `:128`, `2N+1` `spec_swap_duration` `blocks/block_schema.gd:456-471`, `max_abilities` 32 / `visible_skill_slots` 4 `:384-389`, editor hidden toggle + "becomes" picker `app.js:5497/:5758` |
| Phase 3 `per_target` | superseded by a **stronger** form: filtered selectors (`blocks/block_schema.gd:59-63`) |
| raw-`ticks` escape hatch | `blocks/block_schema.gd:448-453`, editor toggle `app.js:5733` |

Two old Phase 0 items did **not** ship and are scheduled in Phase G's parallel track: task **#72**
(approved authored characters in char-select) and **#73** (authored portraits in battle). They gate
the `PORTRAIT_CHANGE` table row.

One correction to the old file itself: its "never build" line listed instant kill and skill copy,
contradicting its own corrected 2026-07-31 ruling higher up. That ruling stands — **instant kill is
an ordinary game outcome and is built** (Phase G); skill copy is blocked by an identity **bug**, not
a design refusal (Phase G, engine-fix-later).

---

## The verification contract

> [!info] Every phase verifies the same way
> 1. Write a headless probe under `training/tests/` (alongside `block_dsl_probe.gd` and
>    `authored_character_probe.gd`). Assert both the **positive** behaviour and the **rejections**.
> 2. Run it headless. It must pass.
> 3. **REVERT the change** and run the probe again. It must **fail**. A probe that passes without
>    the change is testing nothing.
> 4. Restore the change, re-run, confirm the existing probes still pass.

> [!danger] Never `git checkout` / `restore` / `reset` / `clean` / `stash` in this repo
> There is a large amount of uncommitted work. "Revert to confirm the probe fails" means **edit the
> file back by hand** (or `cp` from a scratch copy), never a git operation. See
> [[Hard Rules and Guardrails]].

> [!warning] A new `class_name` needs `godot --headless --import`
> Any class added outside the editor will not resolve until the class cache is regenerated. Note
> `--import` does **not** compile — run a real headless scene to catch parse errors.

Every phase also has a shared checklist:

- [ ] `BlockSchema` entry added (the palette is the source of truth; `_authored_palette` ships it
      to the editor automatically, so the editor cannot drift)
- [ ] `BlockValidator` rule added, including the **unknown-field** consequence — and, for any
      per-hook control, **rejection on the hooks that ignore it** (cross-cutting hazard 1 below)
- [ ] `BlockRunner` case added, and the runtime **defensive** path (warn + skip, never crash)
- [ ] Generated prose (`split_desc()` path) updated — an undescribed block is a skill whose tooltip
      lies. `describe()` is not written for new work.
- [ ] `ScriptedAbility._block_damage` / `custom_behavior` / `bot_tags` updated if the change affects
      damage, target shape, or adds a semantic feature ([[Bots and Training]])
- [ ] Editor UI: usually **nothing**, because `creatorBlock` renders from the palette — but check
      the phase's *Palette UI* section for the exceptions
- [ ] `deploy/` mirror updated ([[Data Files and the Deploy Mirror]])

---

## Phase A — correctness and hardening (before any new capability)

No new authoring capability ships here. Every item protects **all** authored content, and every
new palette row added later widens the surface these fixes protect.

### What ships

| # | Item | Why first |
|---:|---|---|
| A1 | **Reserved-name blocklist** | A live hole reachable **today** with the shipped `mark` kind: an authored ability named `Plasmantle` that permanently self-marks takes zero Harmful damage, in two blocks ([[Creator Gap Analysis]] §3.6). |
| A2 | **Engine re-validation of non-`target` selector pools** | Four ops (`damage`, `break`, `cleanse`, `remove`) currently beat invulnerability when aimed via any selector other than `to: "target"` — a live, probed defect (§3.4). Every new POOL or PICK added later multiplies it. |
| A3 | **Passive validator rules** | The editor's default blank ability, with *Passive* ticked, produces a validated, approvable, **wholly inert** skill whose prose promises 15 damage (§3.5). |
| A4 | **`_is_hostile_effect` becomes data** | Prerequisite for the Simple Effect Table (C) and for `counter.on` (B). Do not defer it into either change. |
| A5 | **Retire or wire `and_targeter`** | An authored `all_enemies` skill with the flag ticked hits everyone when a human plays it and **only the clicked target** when a bot does. |
| A6 | **Fix the banished-flag/invuln desync** | `Character.banish_character` sets the banished flag **even when the effect application is refused** (invuln/ignore), leaving a character flagged banished with no banish effect on them. Must land before B ships the `banish` op row. |

### Engine work

- **A1** — `AuthoredRegistry.validate_character` (`blocks/authored_registry.gd:185-272`) gains one
  check, same class as the existing duplicate-name error: reject any `ability.name` or
  `name_override` colliding with the reserved list. `marked_by(name)` is `has_effect(name, MARK,
  null)` (`scripts/character_component.gd:1168-1169`) — any mark of that name from any source
  triggers the engine branch. **Three names are confirmed abusable** (Nirvana, Plasmantle, Blood
  Spear — all three return before damage at `scripts/character_component.gd:581-606`); the other
  ~37 hardcoded names need the same per-branch read **before the list is sized** — do not ship a
  list of 40 because 40 were found. `NAGISA_DR` is the same shape one level down (`:692`, `:828`).
- **A2** — one helper in `BlockRunner._resolve_targets`: after building any pool that did **not**
  come from `user.targeter.targets` (`blocks/block_runner.gd:106-131`, `:156-167`), drop candidates
  failing `Condition.can_hostile_target(user, c, ability, bypassing)` (hostile pools) or
  `can_allied_target(user, c, bypassing)` (allied pools). The runner already holds `ability` and a
  `QueryContext` (`_ctx`, `:72-73`). Author opt-out is a single **`bypassing: true`** — **the same
  field name and meaning as Phase F's**, so one concept has one word.
  **SHIPPED, and the word is `bypassing`, not `pierce`.** The opt-out was briefly named `pierce`;
  that collides with a real and different mechanic — `DamageType.Type.PIERCING` ignores damage
  REDUCTION and has nothing to do with invulnerability
  (`scripts/character_component.gd:699`, `:834`). `bypassing` is the engine's own word: the third
  parameter of `Character.add_hostile_effect` / `add_allied_effect` and of the
  `default_*_target_function` helpers, the name the `apply` op has carried since before this check
  existed (`blocks/block_schema.gd:334`), and the spelling of the ability CLASS that declares the
  same intent. Renamed on all four ops with **no compatibility alias** (nothing authored used it).
  **The `Bypassing` CLASS is now wired too** — see the `bypass_invuln` note in Phase F below:
  `ScriptedAbility.target` passes it to the targeting helpers, and it is the **default** for every
  block's pool check, which the per-block `bypassing` field overrides in **both** directions. Background: `resolve_damage`
  (`scripts/character_component.gd:2147-2164`) never checks `is_invuln`; `shatter_shields` /
  `shatter_barrier` (`:1871-1891`) check nothing; `cleanse_all_enemy_effects`
  (`scripts/effect_storage_component.gd:108-126`) is gated only on `IGNORE_CLEANSE` +
  `cleansable`. Only `apply` and `heal` are safe today.
- **A3** — validator-only. When `classes` contains `Passive`: require an explicit `to` on every
  block whose op takes one, and reject `to: "target"` with a message that says why (`"target"`
  reads `user.targeter.targets`, `blocks/block_runner.gd:83-84` → `:99`, empty at battle start —
  `Character.startup_passives` runs every Passive once at `scripts/character_component.gd:320-323`).
  Flag `to: "all_enemies"` on a Passive for review rather than banning it — 14 of the 93 shipped
  passives plant hostile effects. **Fold in the old Phase 1 permanence rule**: effects a Passive
  applies with `turns: -1` get `system: true` + `remove_on_death: false` auto-set, or a revive or
  buff-strip silently kills the passive for the match ([[Effects and Durations]],
  [[Cleanse Silence and Effect Removal]]). This never confirmed as shipped — treat it as new work.
- **A4** — replace the literal seven-name list in `BlockRunner._is_hostile_effect`
  (`blocks/block_runner.gd:547-561`) with a per-kind `hostile` column in `BlockSchema.EFFECT_KINDS`,
  read generically. Behaviour-preserving for every shipped kind.
- **A5** — `blocks/block_validator.gd:36` exposes the flag, `blocks/authored_character.gd:83`
  assigns it, and `Ability.and_target` returns false (`abilities/scripts/ability_component.gd:829-830`)
  — but the human client expands via `webclient/app/app.js:1450-1462` while the bot uses
  `scripts/player_component.gd:1274-1281`. Either wire `and_target` for `ScriptedAbility` or remove
  the flag from `ABILITY_FLAGS`. Retiring is the cheap, honest option until Phase F gives splash
  predicates a real home.
- **A6** — in `Character.banish_character`, set the banished flag only when the banish effect was
  actually applied (or explicitly clear it on refusal). Same defect family as
  `_free_unapplied_effect`: the application can be refused, and downstream state must agree.

### Palette UI

Essentially nothing — this is the validator/engine phase. Two one-liners: A3 pairs with the editor
seeding `to: "user"` the moment *Passive* is ticked (the blank ability at `app.js:5148` currently
seeds a bare damage block with no `to`); A5, if retired, removes a checkbox from the flags row
(`app.js:5361-5368`) — a hand edit, since that row is five literal `crCheck` calls, not driven by
the palette export.

### Guards & prose

- A2 **is a nerf to already-approved content and cannot be opt-in** — every approved authored AoE
  gets weaker against invulnerable defenders the day it lands. Owner decision + a patch-note line,
  same shape as the documented per-target-`when` nerf. It must **not** ship as an author-tickable
  flag: "my AoE respects invulnerability" is not something an author should have to remember.
- A3's error text names a restriction the **game** has ("a Passive runs once at battle start, before
  anyone has clicked a target"), so it does not invent a limit.
- A1's rejection message mirrors the duplicate-name error. No prose changes otherwise — nothing new
  is describable.

### Verify

`training/tests/creator_hardening_probe.gd`:

- A1: an authored self-mark named `Plasmantle` is rejected at validation; with the check hand-reverted,
  the probe shows the authored character taking zero Harmful damage (the red case).
- A2: an authored `to: all_enemies` damage/break/cleanse/remove against an invulnerable defender is
  **blocked** after; the same probe is the pre-fix red case (it lands today). Also assert `heal` and
  `apply` behaviour unchanged.
- A3: **probe the empty-target chain first** — the gap analysis verified it line-by-line but never
  observed it. An authored Passive with a default-`to` damage block must deal 0; then assert the
  validator rejects that spec, and that a `turns:-1` Passive effect survives a cleanse and a revive.
- A6: banish refused by invuln → assert the flag is not set / matches the effect's presence.
- A5: if wired — human path and bot path (`_v3_execute`) produce the same target list for a flagged
  AoE; if retired — the flag is rejected on save and absent from the palette.

Hand reversal per item, never git. Live-match check: one bot match with an approved authored AoE
character, confirming A2 changed the outcome the patch note describes.

---

## Phase B — the cheap tier, payload addressing, and the event-class filter

The corrected cheap tier: **thirteen items at ~217 character-hits** (the old 244 overstated by ~27
— `adjust` is republished at its unique-axis reach, since two of its three axes already ship via
the universal `stackable`/`stack_mag` fields, and `on_healing_given` at 1/174 belongs in Phase G's
long tail, not here). Plus the two structural riders that make the hook rows *correct*: **payload
addressing** and the **event-class filter**.

Fully expressible moves 7 → **~17+**, ≤1-gap 22 → **~56+**. *Provisional*: the measured curve in
[[Creator Gap Analysis]] §1 was computed with addressing landing after the effect table and
`recurring`; pulling it forward means some of its +18 completions arrive here and the rest complete
in C/D. The endpoint after A–D is the measured **56 fully expressible / 109 at ≤1 gap** either way.
Treat 17 as the floor for this phase, not a target.

### What ships

The thirteen, with corrected reach:

`bypass_invuln` (33) · `trigger.scope` (32) · `cost_change.mode` (27) · presence `.effect` + `.by`
(27 hard) · `counter.on` (15) · `channel` flag (15) · `repeat` op, constant form (20) · `adjust` op
(**≈14 at its unique axis — the `turns` delta**; *provisional* — the 40 figure counted all three
axes) · `reflect` kind (11) · `on_hp_changed` (11) · `banish` op (5) · `on_stunned` (4) ·
`on_skill_received` (3).

**Payload addressing** ships alongside — its own stated cost is two resolver arms and two stashes,
and the hook rows above are **wrong-by-default without it**: `on_stunned` (3 of 4 shipped users are
ally-held), `on_skill_received` (3 of 3 enemy-held), and the already-shipped `on_damage_dealt` is a
**probed** player-reachable self-kill ([[Roulette 07 - Levi Ackerman]]). Two selectors, legal only
inside `then` payloads:

- **`holder`** := `context.effect.target` — the bearer, correct on **all 15 hooks** without
  exception, because `Character.apply_effect` calls `effect.set_target(target)` unconditionally
  (`scripts/character_component.gd:178`).
- **`affected`** := `context.target` — the event's *patient*, the character the event happened
  **to**. Differs from the holder on exactly two hooks: `on_damage_dealt` (the victim,
  `scripts/character_component.gd:1297`) and healing-given (the healed, `:1098`, dispatcher
  `:1348`). The old single-binding design (`holder := context.target`) was wrong on those two —
  ship **two** rows, never one.

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

**The event-class filter** (`trigger.scope`) gates a payload on the triggering skill's class (or
name), reusing `COUNTER_SCOPES` (`blocks/block_schema.gd:242-258`) verbatim. It is **load-bearing,
not convenient**: 11 of the 14 `HARMFUL_USE` characters are *outside* `on_skill_used`'s 43 and are
served **only** by putting this filter on `on_skill_used` — the corrected containment row in
[[Creator Gap Analysis]] §5.1. (`on_harmful_used` itself stays do-not-build: its context does not
carry the used Ability, so it is the strictly weaker hook.)

### Engine work

- **Payload addressing** — two arms in `_resolve_targets`; two stashes alongside the existing
  `set_explicit_targets` in `_build_trigger` and `_build_counter` (`blocks/block_runner.gd:706-716`).
  `context.target` is currently **never read by `BlockRunner` on any path** — the stash is the whole
  change. No engine primitive is missing.
- **`trigger.scope`** — filter in the payload wrapper; per-hook capability map in the schema (the
  filter is meaningful on use/receive hooks, inert on turn hooks — validator rejects where inert).
- **`counter.on: outgoing`** — one field switching the hardcoded `COUNTER_RECEIVE` at
  `blocks/block_runner.gd:689`, **plus** `counter` added to the hostility data (A4). Wire it through
  the **live** path — `countered()` at `scripts/character_component.gd:406`, loop `:420-428`,
  cancel at `new multiplayer/battle_manager.gd:1204`. **Not** `check_counter_use_effects` /
  `check_counter_receive_effects` (`:1515`, `:1521`) — both have **zero callers repo-wide**;
  grepping the obvious names wires a no-op that passes a smoke test (hazard 3).
- **Presence `.effect` + `.by`** — the 3-arg `has_effect(name, type, user)`
  (`scripts/effect_storage_component.gd:67-71`). **They ship together or `.by` is inert** — there is
  no name+user-without-type entry point. Same change un-hardcodes `stacks_at_least`'s
  `EffectType.Type.MARK` (`blocks/block_runner.gd:216`) and subsumes `slot_holds`.
- **`bypass_invuln`** — one argument on the two targeting-helper calls at
  `blocks/scripted_ability.gd:53-65` (helpers: `abilities/scripts/ability_component.gd:857`,
  `:863`). **RESOLVED AHEAD OF PHASE F, the other way round.** The trap was real — the bare
  `Bypassing` chip rendered on an authored card and changed nothing, because `target()` called the
  helpers without their third argument. The fix was not to remove the chip but to make it mean what
  it says: `ScriptedAbility.target` now reads `classes.get("Bypassing")` and passes it as the
  helpers' `bypassing` argument, exactly as a shipped kit does (`abilities/nimaiya1.gd:56`), and
  `BlockRunner._bypass_gate` uses the same class as the default for every re-validated block pool
  so the two layers cannot disagree. A per-block `bypassing` still overrides it either way, so the
  selector object only has to **mount** that field, not invent it.
- **`channel` flag** — ability-level `"channel": "control" | "channel"` plus an accumulator in
  `BlockRunner.run` collecting each effect handed to `add_*_effect`, applying the cancel to the user
  at the end. **Guard with `is_instance_valid`** — a rejected application is `queue_free`'d by
  `_free_unapplied_effect`, a merged one is absorbed by storage; `_end_cancel_effects`
  (`scripts/character_component.gd:290-292`) already shows the correct discipline
  ([[Node Lifecycle and Orphans]]). This refutes the old "labelled effects" design — all 16 shipped
  call sites cancel *everything* the skill applied; zero are selective ([[Creator Gap Analysis]] §2.5).
- **`adjust`** — reuses `_op_remove`'s addressing exactly (`blocks/block_runner.gd:397-432`):
  match on `effect_name()`, collect-before-mutate, one-instance for partial spend. **Delta form
  only** (a `set` form invites unbounded ramps — a named abuse case, not a bound for its own sake).
  `turns` goes through `BlockSchema.turns_to_duration`'s 2N convention.
- **`repeat`** — a `group` with a count. `_count_blocks` **must recurse** into it (precedent:
  `blocks/block_validator.gd:180-181`) or the 40-block ceiling is trivially multiplied; `times`
  needs its own limit independent of `max_amount`, because **repeating a hit is not one bigger
  hit** — shields, DR, the damage floor, and receive-triggers all apply per instance.
- **`reflect` kind** — fixed engine-provided callable; `destination` is a two-value enum
  (`attacker` = bounce, `applier` = guardian), never a live `Character`, which satisfies
  [[What Cannot Be Built Yet]]'s payload rule **by construction**. Both re-aim traps (common AoE is
  `ALL(2)` not `ALL_FACTION(1)`; re-validate against `extra_targetable` + bypass-aware invuln) are
  already handled inside `reflect_retarget_to_team`
  (`abilities/scripts/ability_component.gd:418-433`).
- **Hook rows** — `on_hp_changed` (`HEALTH_CHANGE_TRIGGER`), `on_stunned`
  (`STUN_RECEIVED_TRIGGER`), `on_skill_received` (`ACTION_RECEIVE_TRIGGER`): enum rows in
  `TRIGGERS`. `on_hp_changed` is the only hook correct today without addressing (10 of 11 shipped
  users are self-held) — but **probe its re-entrancy first** (hazard 2): a payload that damages
  `holder` re-enters its own trigger with only `eff.triggered` as a brake
  (`scripts/character_component.gd:518`, `:1099`, `:1320`).
- **`banish` op** — `Character.banish_character`, adjudicated by [[Roulette 08 - Semiramis]] as an
  `OPS` row. Depends on A6.
- **`cost_change.mode`** — a third value (`add`/`set`/`swap`) on an existing, already-validated axis
  (`blocks/block_validator.gd:331-335`).

### Palette UI

Nearly everything here is **free via the export** — new enum rows, fields and kinds render through
`creatorBlock`'s palette-driven field lists. The exceptions, each small:

- **`trigger.scope`** — *nearly free*: adding `"scope"` to the trigger kind's fields lights up the
  existing shortcut-or-class-list widget (`creatorCounterScope`, wired at `app.js:5752`) with zero
  new client code. The one extension: the palette exports **which hooks accept scope** and the
  editor hides the control elsewhere (the validator rejects regardless).
- **`.effect` / `.by`** — *small extension*: condition args are palette-driven (`app.js:5555-5563`)
  but unknown args fall through to a number field — the wrong widget. Two named branches in the
  condition editor's args loop: `effect` → dropdown over `pal.immunity_effects` (the exact widget
  `remove` already uses, `app.js:5701-5703`); `by` → dropdown over `mine`/`any`.
- **`holder` / `affected`** — *nearly free to render, real work to place*: they are ordinary
  selector names, but legal only inside `then` payloads, and `creatorBlock` passes one flat
  selectors list everywhere (`app.js:5670`). Ship them as a third palette list (e.g.
  `payload_selectors` — precedent: `FILTERED_SELECTORS` is its own key exactly for placement rules,
  `components/server_connection.gd:4366-4370`) and thread an in-payload flag through the nested
  `creatorBlock` calls (`app.js:5806`, `:5818`). Show the human description in the dropdown —
  *"the character carrying this effect"* / *"the character it happened to"*; `SELECTORS` is already
  a name→description dict and the picker currently shows raw keys (`app.js:5436`) — a one-line
  label improvement.
- **Everything else** — *not* free, but cheap: each is a **1–5 line control branch**, because
  per-op controls are hardcoded (see the intro's architecture note). Itemised so nobody ships an
  invisible required field: `adjust` needs its own op branch (`remove`'s controls live inside
  `else if (b.op === "remove")` — a new op renders only to+when); `repeat` needs a branch (`group`'s
  nesting is `if (b.op === "group")`, not shared machinery); **`reflect` is the hazard case** — the
  kind appears in the dropdown and scope/turns render, but `destination` and `charges` have no
  branch in the field chain, which is the `break` defect reborn as invisible required fields;
  `cost_change.mode` and `counter.on` are new field names needing a branch each; `channel` is
  ability-level — the flags row at `app.js:5361-5368` is five literal `crCheck` calls, not driven by
  the exported `ability_flags`, so it is a hand edit. (`bypass_invuln` was in this list and is now
  DONE: it turned out to be the `Bypassing` CLASS chip, which comes from `Ability.CLASS_NAMES`, not
  the flags row — no widget work was needed once the class was wired.) Genuinely free: the
  new hook rows and `banish`'s kind entry (existing dropdowns fed by the export).

### Guards & prose

| Item | Validator rule | The abuse case it prevents |
|---|---|---|
| `holder`/`affected` | legal only inside a `then` payload (the `in_reactive` flag); resolve to ≤1 character; return `[]` when dead/invalid, **never** fall back to the caster | the run-07 defect in reverse: a silent fallback turns "damage the holder" into "damage myself" the moment the holder dies mid-payload |
| `trigger.scope` | rejected on hooks that ignore it | a control that renders, validates, and does nothing — the shipped `trigger_once` failure mode |
| `repeat.times` | bounded independently of `max_amount`; `_count_blocks` recursion | 40-block ceiling multiplication; per-instance semantics make N repeats stronger than one N-fold hit |
| `adjust` | delta form only | unbounded `set`-form ramps |
| `banish` | **pool selectors forbidden outright** | banish aimed via a pool is an instant win — probed ([[Roulette 08 - Semiramis]]) |
| `channel` | class derived from the flag, never author-set; `is_instance_valid` on the accumulator | freed-effect crash aborting a live match |
| `counter.on` | counter is hostile data (A4) | an outgoing counter planted through invuln/ignore-skill |

Prose: one noun each for the two selectors (they fit `_describe_selector`'s shape); the channel
flag prints its break condition ("…ends if the user is stunned or killed"); a scoped trigger names
the class ("whenever they use a Harmful skill…"); `reflect` prints destination and charges.
`bot_tags`: `TAG_REACTIVE` covers the hook rows; addressing needs **no new tag** —
`bot_damage_hint` ignores payload contents, and a payload that finally aims correctly changes
nothing it reads.

### Verify

`training/tests/creator_cheap_tier_probe.gd` (one assertion block per item) plus
`creator_addressing_probe.gd`. Load-bearing cases:

- `holder` resolves to the bearer on a self-held, ally-held, and **enemy-held** trigger — the
  enemy-held case is red today (fires backwards).
- `on_damage_dealt` payload aimed at `affected` hits the **victim**, not the dealer — red under any
  single-binding design; this is the probe that enforces the two-selector correction.
- A dead holder mid-payload yields `[]`, not the caster (assert no self-damage).
- `counter.on: outgoing` cancels the **enemy's** next skill via the live `countered()` path (assert
  the attacker's damage never lands).
- A scoped trigger fires for a matching class and stays silent otherwise; the same spec with scope
  on a turn hook is rejected.
- `on_hp_changed` re-entrancy: run 07's two-block payload, self-held — establish the behaviour
  **before** the row ships and write the observed brake into the note.
- `adjust` `turns:+1` extends a DoT by exactly one game turn (the 2N check — revert-fails case).
- `repeat` ×3 through a shield absorbs per instance (assert ≠ one triple hit).

Live-match check: one real bot match with a scoped trigger + an addressing payload, watching the
log for the drift validator.

---

## Phase C — the Simple Effect Table

**≈+13 → ≈30 fully expressible, ≈91 at ≤1 gap** *(provisional under the reorder; measured
endpoint after A–D is 56/109)*. The largest raw-reach item in the corpus survey (95/174 touch at
least one row), delivered as **one build arm plus N data rows** — every subsequent type is one
table line and zero code.

### What ships

A `const SIMPLE_EFFECTS` table in `blocks/block_schema.gd` covering the pure-data factories
([[Creator Gap Analysis]] §2.1): `IGNORE_NON_DAMAGE` (21) · `TARGET_CHANGE` (16) · `ISOLATE` (12)
· `BLIND` (11) · `IMMORTALITY` (9) · `BARRIER`/Nullify (9) · `DAMAGE_CAP` (6) · `DELAY` (6) ·
`IGNORE_COUNTER` (5) · `IGNORE_HEALING` (5) · `STEALTH` (2) · and the 1/174 table lines
(`PERCENT_DR`, `HEAL_CUT`, `HEALTH_CAP`, `DAMAGE_CAP_RECEIVE`, `HEALING_RECEIVED_MOD`,
`IGNORE_CLEANSE`, `IGNORE_SKILL`, `NO_BOOST`, `DODGE_CHANCE`, `SHARPSHOOTER`, `FALSE_STUN`,
`DELAY_RECEIVE`, `CHAIN_NULLIFY`, `DAMAGE_REVERSE`).

**`PORTRAIT_CHANGE` (19) — IMPLEMENTED** (was held back on the asset pipeline). Shipped as a NAMED
kind `portrait_change` (not a `SIMPLE_EFFECTS` row: it needs `system=true` + `cleansable=false`, which
only `Effect.portrait_change_effect` sets, not the generic `Effect.from` arm). `AuthoredAssets` now
carries `ALT_PORTRAIT_SLOTS` (`alt1`..`alt4`, kept OUT of `ability_slots()` so an alt is never a skill
icon); the authored `index` reserves `mag` from a universal clobber and is bounded to the alt-slot
count; the effect renders CLIENT-SIDE (`authoredArtUrl(id, "alt"+(N+1))`) so the server's
`alt_portraits[]` stays empty, guarded by a `character_component.active_portrait` bounds check. See
`training/tests/creator_portrait_change_probe.gd`. **Excluded:**
`DAMAGE_REDIRECT` — `Effect.redirect_effect` stores a live `Character` in `character_target`,
exactly the argument an authored spec cannot supply; its safe subset is a Phase G adjudication.

### Engine work

One `_build_effect` arm calling `Effect.from(EffectType.Type[row.type], {})`
(`scripts/effect_component.gd:895` — already used by five shipped abilities), letting the existing
universal pass write mag/duration/flags (`_apply_universal_fields` is kind-agnostic by design,
`blocks/block_runner.gd:493-499`; the validator already derives allowed fields from `EFFECT_KINDS`,
`blocks/block_validator.gd:289-302`). The engine-defaulted callables (`wrapup_func`, `shield_func`,
`barrier_func`, `redirect_func`, `conditional_func`, `scripts/effect_component.gd:41-45`) make the
generic arm safe — `barrier_effect` never sets `barrier_func` and `character_component.gd:860`
calls the default successfully.

Three columns the table must carry, designed **with** it, not after:

1. **`hostile`, as data** (A4). A table-driven Isolate that forgets to declare hostility routes
   through `add_allied_effect`, skipping `is_ignoring_skill`, `shrug_off_type` and
   `can_apply_hostile_effect` — it lands on targets **no hand-written kit could reach**.
2. **A `mag` normalisation.** Three incompatible percentage conventions ship today: `PERCENT_DR`'s
   mag is the percent *removed* (`scripts/character_component.gd:982`), `HEAL_CUT`'s the percent
   *retained* (`:1052`, its own factory description claims the opposite), and the 0..1 float kinds
   cannot even pass `_amount`'s `clampi` (`blocks/block_runner.gd:727`). Pick one authored
   convention, convert in the build arm, and **write the prose from the reader, never the factory
   string**.
3. **A per-row `LIMITS` column** — see guards.

**Read each factory before adding its row.** That rule is what caught `redirect_effect`.

### Palette UI

**Free — with one standing constraint.** New kinds appear in the effect-kind dropdown
automatically (`app.js:5720`); universal fields already render through the tri-state advanced card
(`app.js:5631-5660`); per-kind extra fields render through the fixed chain of known field NAMES
(`:5725-5764`). That last clause is the constraint: **every SIMPLE_EFFECTS row must confine itself
to field names that already have a control branch** (`amount`, `turns`, `classes`, `skills`,
`scope`, ...). A row introducing a NEW factory field name renders nothing — the invisible-required-
field defect — until someone adds its branch. True for every row as sketched; enforced by
convention, so check it per row at review time. Zero new widgets.

### Guards & prose

Per-row limits that name their abuse case — these are balance guards, not bounds for their own
sake, and the specific values are the **owner's** to set:

- **Isolate / `IGNORE_NON_DAMAGE`** are invisible in the damage math, so authors will underprice
  them: a permanent `all_enemies` isolate deletes healing, shields, cleanse and every ally-targeted
  buff for a match. The guard is on the duration×scope pairing, and the row's prose must say what
  it removes.
- **`IMMORTALITY`** — `is_immortal()` (`scripts/character_component.gd:1806`) consults **no
  exclusion list at all**; a permanent one is strictly worse than the documented permanent-invuln
  soft-lock. Flag it for the owner as the one row where the bound must exist before the row ships.
- **Nullify (`BARRIER`) is offensive suppression, not a shield** — the prose must say "the next N
  damage **this character deals** is absorbed", or authors price it backwards.

Prose: one generated clause per row, written from the reader's semantics (see the normalisation
column). `bot_tags`: most rows are non-damage state — tag the defensive rows so the policy sees
them; no `bot_damage_hint` change.

### Verify

`training/tests/creator_effect_table_probe.gd`: for each row, apply and assert the **reader's**
behaviour (`PERCENT_DR` reduces by mag%, `HEAL_CUT` retains mag%, a hostile row is blocked by
invuln/`shrug_off_type`, an allied row is not); diff one `Effect.from` construction against a
shipped factory call (the `gilgamesh2.gd:28` shape) for parity. Reversal: delete one table line by
hand, confirm that kind's probe goes red and the others stay green — the table's whole point is
that rows are independent.

---

## Phase D — `recurring`

**≈+8 → ≈38+ fully expressible, ≈109 at ≤1 gap** *(provisional; the measured post-A–D endpoint is
56/109)*. Ticking as an effect **kind** with a nested `then`, not a `TRIGGERS` row — the hook-row
spelling cannot carry any of the five properties ticking actually has ([[Creator Gap Analysis]]
§3.2). Reach 55/174 — larger than every hook already in the palette.

> [!success] The reorder pays off here
> The gap analysis had to caveat this phase: *"the editor must not offer the hostile install until
> addressing lands"* — ~16 of the 55 characters need `holder` or the effect fires backwards.
> Because Phase B ships payload addressing, that dependency **dissolves**: `recurring` arrives
> whole, hostile half included, with no editor gating.

### What ships

```json
{"op": "apply", "to": "target", "effect": {
  "kind": "recurring", "turns": 3, "first": "now", "stops_when_stunned": false,
  "then": [ {"op": "damage", "amount": 10, "to": "holder", "damage_type": "AFFLICTION"} ]
}}
```

- **`first`: `now` | `next`** — `now` runs the payload once at cast **and** sets engine duration
  **2K−1**; `next` sets **2K+1**. *(Corrected during implementation: `next` is 2K+1, not 2K — the
  engine decrements every effect on BOTH sides' turn boundaries, so a no-manual-instance ticker at 2K
  fires only K−1 times, a turn short. fern3.gd's shipped comment confirms 2K+1. Both modes deliver K
  fires on the correct turns.)* This folds the manual-first-instance idiom every shipped kit hand-codes
  (`abilities/fern3.gd:72-79`, `stark3.gd:53-58`) and is the difference between the generated prose
  being true and being a turn off.
- **`stops_when_stunned`** — writes the ability-level `Action` class, whose **single reader in the
  repo** is `new multiplayer/battle_manager.gd:1225`. Surfacing it here **retires the bare `Action`
  chip** in the class row, which today silently halves an effect's uptime against stuns with no
  prose and no validator message.
- **The two-site `last_turn_only` fix** rides along: the collector
  (`new multiplayer/battle_manager.gd:831` filters DAMAGE only; the `TICKING_TRIGGER` loop at
  `:838-840` has no filter) and the executor (`:1234` is inside the DAMAGE branch; `:1255-1263`
  never consults it). Fix both, or a "fires once, at the end" effect is a phantom draggable tile in
  the reorder panel every turn.

### Engine work

**None for the kind itself** — `TICKING_TRIGGER` already has a dispatcher, a wire encoding, a
client tile and a player-reorderable execution slot (`get_ticking_effect_information`,
`new multiplayer/battle_manager.gd:785`, merged at `:736-750`). The build is a sibling of
`trigger`/`counter` in `_build_*`, honouring the four cancellation gates that already exist
(`execute_ticking_effect`, `:1222-1263`: holder dead/banished, `Action`+user-stunned, isolate for
friendly ticks, invuln-unless-bypassing for hostile ticks). Side-scoping is the engine's:
tick sets are scoped by the effect's **user's** side (`:826-841`) — an enemy-planted ticker fires
on **your** turn — and the tick set is frozen at `:1622` before `start_round_loop()` at `:1640`,
which is why `first` exists.

### Palette UI

*Small extension, mostly free.* The new kind appears in the effect-kind dropdown automatically.
Three client touches: (a) extend the payload-nesting gate at `app.js:5813-5814` (currently
`trigger`/`counter`) to include `recurring` so its `then` renders; (b) `first` dropdown +
`stops_when_stunned` checkbox — existing widget shapes; (c) a seed-effect arm like trigger's
(`app.js:5608`). Plus removing the bare `Action` chip from the class row (palette-driven, free).

### Guards & prose

- **The named abuse case:** a permanent (`turns: -1`) enemy-held ticker whose payload damages
  `holder` is per-round damage forever for one cast; `execute_ticking_effect` applies **no
  magnitude bound of its own**, and the only counterplay is holder-side and side-dependent —
  which the universal `bypassing` field removes. **Cap the duration of a hostile-placed
  `recurring`** — the cap's value is the owner's call (open decision below), the existence of a cap
  is the guard.
- `stops_when_stunned` is **ability-scoped** (the gate reads `effect.source.classes`): reject a
  skill carrying two `recurring` effects with different settings rather than resolving silently.
- Prose: the `_describe_effect` arm must say **"each turn" meaning the author's turn**, not the
  holder's, and must reflect `first` (fires immediately vs from your next turn).
- Bot: `TAG_REACTIVE` + `_derive_tags(then)`, and `bot_damage_hint` must count **amount × turns**
  or the v3 policy values every ticking payout at zero ([[Bots and Training]]).

### Verify

`training/tests/creator_recurring_probe.gd`: both `first` modes fire on the correct turns (the
2K−1 / 2K distinction is the cleanest revert-fails case); an enemy-planted ticker fires on the
**caster's** turn (side-scoping); the `Action`-classed ticker stops while its author is stunned; a
hostile permanent `recurring` is rejected; the fixed `last_turn_only` produces no phantom reorder
tile (assert the collector's list). Live-match check: drag an authored ticker in the reorder panel
and confirm execution order honours it.

---

## Phase E — value reading

The largest single fully-expressible jump in the measurement (**the +60 pool**), and deliberately
scheduled **before** the selector system — a swap from the gap analysis's §6 order, for three
reasons: (1) it is self-contained engine + validator work with the smaller UI cost, so it lands
while F's larger widget is designed; (2) the reading node's `measure` vocabulary (`hp`, …) is
exactly what F's `pick: lowest` needs, so shipping readings first gives the selector card its
measure enum instead of a duplicate; (3) the **one shared bot-scorer update** covers object-form
`amount` (here) and object-form `target` (F) — building the amount half first makes the scorer
change testable on today's flat targeting. Cumulative coverage after E is *provisional* (the
measured +60 was computed after eligibility); the A–F endpoint is fixed either way.

### What ships

```json
{"op": "damage", "to": "all_enemies",
 "amount": {"base": 15, "per": 5, "cap": 45,
            "each": {"read": "stacks", "name": "Ofuda", "effect": "MARK", "of": "all_enemies"}}}
```

Not an expression language. `base + M × count` with a mandatory `cap`, where the reading node is a
**closed enum** mirroring `compare`'s shape:
`{"read": "stacks"|"effect_count"|"alive_count"|"hp"|"missing_hp"|"energy"|"duration", "of": <selector>, "name": …, "effect": …}`.
This reproduces `mars1`, `tanjiro5`, `semiramis3`, `ganta1`, `nezuko2`, `saitama7` and `tamaki1`
verbatim. The same node is legal as a `compare` value, and `repeat.times` (Phase B's constant form)
takes a reading for free. With B's `adjust`, `stacks` becomes a genuine read/write register — the
`xslash_hits` shape decomposes here instead of into a character variable
([[Creator Gap Analysis]] §5.2).

### Engine work

- `BlockRunner._amount` gains the object branch (`blocks/block_runner.gd:727-728`);
  `_validate_amount` gains the Dictionary branch (`blocks/block_validator.gd:577-585`).
- **`alive_count` moves** from `COMPARE_VALUES` (`blocks/block_schema.gd:88`) into the readings
  enum rather than being duplicated — one way to say "how many".
- **`effect_count` applies the `display_system` visibility filter** — the eight filter sites must
  agree, or it leaks hidden state as a *magnitude* and trips the per-turn drift validator.
- **Order matters on stacks**: `_clamp_stacks` is mark-gated (`blocks/block_runner.gd:488-491`) and
  its ceiling comes from `storage["block_max_stacks"]`, written only in the mark branch (`:590`).
  Generalise the **write** before the read, or every non-mark stack pins at the `_stack_ceiling`
  default of 1 (`:543`). `mag`/`stack_mag` are write-only today
  (`blocks/block_schema.gd:199-201`) — this closes that asymmetry.
- **The bot scorer — the single largest non-palette cost, and not optional**:
  `ScriptedAbility._block_damage` reads `int(b.get("amount", 0))` (`blocks/scripted_ability.gd:493`),
  so an object amount scores **zero**; the v3 policy would never select any scaling skill, and a
  character whose best skill is invisible to the bot cannot be practised against. Score at `cap`.

### Palette UI

**One new widget, small — the scaling-amount editor.** A "fixed | scales" toggle (precedent: the
condition editor's number-vs-selector alternation at `app.js:5568-5577` and the all/some-stacks
control at `:5707-5710`); when scaling: `base`/`per`/`cap` number fields (cap mandatory) plus one
reading sub-row — `read` dropdown over a new `pal.readings` export, `of` selector dropdown, `name`
text, `effect` dropdown over `pal.immunity_effects`. Renders as a sentence:
*"15 + 5 per stacks of Ofuda on all enemies, up to 45."* The same node mounts as a `compare` value
at the condition editor's reads picker (`app.js:5561`).

### Guards & prose

- **Mandatory `cap` on the `per` term**, and a **product bound** in one place: `repeat` with a
  reading `times` over a `damage` with a reading `amount` is a quadratic in one skill, and neither
  the per-block `max_amount` clamp nor the 40-block ceiling observes it. Bound
  *amount × maximum resolvable targets × repeat count* centrally rather than per row. Both are
  named-abuse guards; the numbers are author-controlled beyond that.
- `effect_count` visibility (above) is a correctness guard as much as balance.
- Prose: *"Deals 15 damage plus 5 per Ofuda on the board, up to 45."* One clause.
- Bot: object amounts scored at `cap`; no new tag.

### Verify

`training/tests/creator_reading_probe.gd`: a scaled amount clamps at `cap`; `bot_damage_hint`
returns `cap` rather than 0 (**the classic revert-fails case**); `effect_count` is blind to
`display_system` effects (assert against the drift validator); a non-mark stackable effect's stacks
are readable and adjustable (write-before-read ordering); the product bound rejects the
repeat×reading quadratic. Reversal by hand per item.

---

## Phase F — the selector system: eligibility + the selector object

**The +34 pool — the largest palette unlock in the document — and the phase that reaches the
ceiling: cumulative ~146–147/174.** The owner's ask — *"customizable selector blocks for targets
that resolve a set of conditions down to a character reference(s)"* — built as **two layers**,
because the engine resolves targets in three stages and the palette's current vocabulary lives one
stage too late ([[Creator Gap Analysis]] §4.1): eligibility (`target()` flags), the click, fan-out —
and only *then* the block-level selectors, after the interception pipeline is over.

### What ships

**Layer 1 — the ability-level eligibility object**, replacing the flat six-valued mode string:

```json
{"name": "Death Chaser", "target": {
   "mode": "enemy", "shape": "one",
   "only": [{"cond": "has_effect", "name": "Death Chaser", "effect": "MARK", "by": "mine"}],
   "bypass_invuln": false, "exclude_self": false, "include_dead": false
}}
```

Worked against shipped `target()` bodies in [[Creator Gap Analysis]] §4.2: `cooler5`, `mars1`,
`alphonse2`, `astolfo3`, `hisoka6` (`pick: lowest`, ties included), `jeanne4` (`include_dead` —
the targeting half of revive). `mode` and `shape` split — today `_target_type_from_mode`
(`abilities/scripts/ability_component.gd:147-152`) reads `all_enemies` as both pool and fan-out, so
"pick any one character on either board" is unreachable; splitting them is one function.

**Layer 2 — the block selector object** at `to`: POOL × WHERE × PICK × ORDER:

```json
{"op": "damage", "amount": 20, "when": {"cond": "hp_below", "value": 40, "on": "user"},
 "to": {"pool": "enemies",
        "where": [{"cond": "has_effect", "name": "Fracture", "effect": "MARK", "by": "mine"},
                  {"cond": "hp_above", "value": 20}],
        "pick": "all", "order": "clicked_first", "bypassing": false}}
```

This **fixes the `when`-consumption defect** — today a filtered selector consumes the block's only
`when` (`_block_targets` hands `b.when` to `_resolve_filtered`, `blocks/block_runner.gd:83-84`) —
and the desugaring is exact: `any_enemy` + `when` **is** `{"pool":"enemies","where":[<that when>]}`,
so `_is_filtered_block` (`:78-79`) and the editor's forced-mandatory-`when` special case
**disappear** rather than being papered over. The ten string selectors stay as sugar (saved
`authored/*.json` re-validates on load — the same reason `KIND_ALIASES` exists,
`blocks/block_schema.gd:147-149`).

The two layers share **one vocabulary**: `only` and `where` are the same condition list with the
same per-candidate subject binding (`_check_condition` already takes one,
`blocks/block_runner.gd:189`), and `bypass_invuln` / `bypassing` are the same concept as A2's
opt-out — one word, already shipped.
One predicate language, used in the two places targets are decided.

### Engine work

> [!warning] Phase E left a trap for `pick: lowest` — do NOT reuse `_resolve_reading` for it
> Phase E's reading resolver **folds** the selection: `hp`/`missing_hp` **sum** across the `of`
> pool, `energy` reads the first member's team pool once. F's `pick: lowest`/`highest` needs a
> **per-candidate** measure. Reuse the `READINGS` **vocabulary** (so the measure enum is shared, not
> duplicated), but wire `pick` onto a per-character evaluator — `_char_value` already does exactly
> this for `hp`/`hp_percent`. Pointing `pick` at `_resolve_reading` would compare **sums**, not
> members, and silently pick the wrong target.

- **Layer 1** — `ScriptedAbility.target` becomes: walk `battle.all_characters()`, evaluate `only`
  per candidate, call `check_hostile_target` / `check_allied_target` on the survivors
  (`abilities/scripts/ability_component.gd:849-873`) — byte-identical to what the 64 shipped
  overrides do. Everything downstream is inherited free because it keys off the flags: counters,
  reflect, taunt, blind, `_drop_invuln_targets`, AoE expansion, and the client's "no valid targets"
  refusal (`webclient/app/app.js:1447`) — which retires seven characters' hand-duplicated
  `extra_usable` logic. `bypass_invuln` is the helpers' third parameter; `target()` now passes it
  from the `Bypassing` class, so the object only has to expose a per-ability override.
  `exclude_self` is already wired end-to-end (`selfless`: `ability_component.gd:865-866`,
  `blocks/block_validator.gd:36`, `blocks/authored_character.gd:83`) **and already has an editor
  checkbox** (`app.js:5365`) — the gap analysis's "no editor affordance" line is stale; the only
  work is mounting it inside the object.
- **Layer 2** — generalise `_block_targets`; compose with **A2 mandatorily**: any pool not from
  `user.targeter.targets` runs `can_hostile_target`/`can_allied_target` with `bypassing` as the
  single opt-out. `pick: random` is **Fisher–Yates over `battle.roll`, without replacement** (today three
  `random_enemy` blocks can hit the same enemy — `:118-131` is a single roll with no memory);
  `pick: lowest` **includes ties** (the one shipped example does, `abilities/hisoka6.gd:64-68`);
  `order` is explicit because targets are damaged in list order — a mid-list death fires on-death
  triggers and consumes seeded RNG before later entries, so death order is observable, and
  `clicked_first` is the only ordering that agrees with `main_target`
  (`scripts/targeter_component.gd:26-29`, [[Targeting and Main Target]]).
- Layer 1 is **presentation and fairness, not enforcement** — `components/match.gd:591-597`
  bounds-checks submitted `target_idxs` and nothing else, and `process_turn_package`
  (`new multiplayer/battle_manager.gd:1580-1587`) applies them verbatim. The enforceable version is
  layer 2; document both as such.

### Palette UI

**The one genuinely new widget of the roadmap — the selector card — built once, mounted twice**,
and assembled entirely from existing primitives:

- pool dropdown + `where`/`only` as a **list of condition rows in per-candidate mode** (the
  machinery exists: the composite condition editor at `app.js:5529` with its "(each target)"
  subject sentinel at `:5549-5553`) + pick dropdown (with `count` / `measure` sub-fields) + order
  dropdown + the `bypassing` control (a three-way *(skill default) / ignore it / respect it*, not a
  checkbox — the ability's `Bypassing` class is the default and a checkbox cannot say "inherit").
- Rendered as a sentence card: *"[enemies] [with my Fracture] [and HP above 20] — hit [all],
  [clicked first]"*.
- **Mount 1**: the ability-level target, where the flat mode dropdown sits today (`app.js:5325`).
  **Mount 2**: the block-level `to`, where the selector dropdown sits today (`app.js:5772-5780`).
- The ten string selectors remain the **default simple picker**, with an "Advanced target…" toggle
  revealing the card — the palette's simple path stays simple.
- The forced-mandatory-`when` special case (`app.js:5790-5798`) is **retired** by the desugaring.
- The palette export grows three lists: `pools`, `picks`, `orders` (new keys in
  `_authored_palette`).

### Guards & prose

The validator rules, each with its abuse case — including the **two rules the gap analysis's
selector design missed**:

1. **Reject `chance` inside `only` / `also_hit`.** `target()` is re-run from at least four
   independent sites per turn (`_compute_special_targets`
   `new multiplayer/battle_manager.gd:2453`, `_drop_invuln_targets` `:1162`,
   `_skill_pierces_invuln` `abilities/scripts/ability_component.gd:450`, `_v3_execute`
   `scripts/player_component.gd:1272`); a re-rolled predicate answers differently at each, so the
   client's highlight, the server's drop filter and the bot's expansion would disagree about who
   was hit. `chance` stays legal in a block's `when`, evaluated once.
2. **Forbid `to`-relative selectors inside `only` predicates.** `targeter.targets` is being *reset
   during* `target()` — a predicate that reads it observes a half-built list. *(New rule — not in
   the gap analysis.)*
3. **Condition slots keep taking PLAIN selectors.** The selector object is legal at `to` (and the
   ability target), **never** nested inside a condition's `on`/`of` — the infinite-regress
   rationale is already written at `blocks/block_schema.gd:56-58`, and the editor already keeps
   condition pickers on the plain list (`app.js:5671-5674`). Reconcile the object explicitly with
   that guard so the two rules cannot drift. *(New rule — not in the gap analysis.)*
4. **Bound `amount × maximum resolvable targets`.** `LIMITS.max_amount` is per block; `shape`
   multiplies at targeting time — a 100-damage block widened to a faction is 300. This is the same
   central product bound as Phase E's.
5. **Widening `shape` needs its own guard**; narrowing and ally-side changes are free.

Prose: layer 1 appends one clause to the target line — *"Can only be used on enemies you have
marked with Death Chaser"* — and `_describe_filter` already generates exactly this sentence for
the filtered selectors, so the generator is written. Layer 2's card reads out as its sentence.
Bot: **one** scorer update, shared with E — `custom_behavior` branches on the flat `target_mode`
string (`blocks/scripted_ability.gd:493-530`) and an object-shaped `target` currently falls through
to the single-target branch.

### Verify

`training/tests/creator_selector_probe.gd`: reproduce `cooler5` / `mars1` / `alphonse2` /
`astolfo3` / `hisoka6` / `jeanne4` as eligibility objects and diff the flagged sets against the
shipped `target()` bodies; assert a filtered authored AoE is now **counterable and reflectable**
(its targets land in `targeter.targets` and enter the interception pipeline — impossible today);
`pick: random` returns distinct characters over a fixed seed; ties-at-minimum included for
`lowest`; `main_target` equals the clicked character under `clicked_first`; rejection battery for
rules 1–3. Live-match check: the client's no-valid-targets refusal driven by an authored predicate,
and one spectated match confirming highlight/server/bot agreement on who was hit.

---

## Phase G — the long tail, the parallel tracks, and the do-not-build ledger

Three buckets: small items adjudicated from the old roadmap, the asset/venue track that gates
portraits, and the explicit do-not-build list — written down so future [[Creator Roulette]] runs
do not re-propose them.

### What ships — the long tail

| Item | Notes |
|---|---|
| `on_healing_given` row | 1/174 — demoted from the cheap tier; rides B's addressing (`affected` = the healed) and E's readings for free |
| `max_uses` charges | counter mark must be `system: true`, `remove_on_death: false`, `cleansable: false` (a buff-strip must not refund charges, a revive must not reset them) and `display_system` — the opponent is entitled to see "N uses per match"; prose prints it |
| `cost_color_at_least` condition | the engine idiom exists (the Cost-Random conditional); one `CONDITIONS` row reading `ability.cost()`; review together with cost effects — a self-applied `COST_MOD` paired with the condition is a free rider |
| `else` on `group` | **one roll per group** or the double-fire returns; `_count_blocks` recurses into it |
| `drain_energy` / `steal` op + `energy_at_least` | **dedupe drain targets by `.team`** (energy is a team pool) and **count what was actually removed** before granting a steal — `lose_energy` silently returns on an empty pool; energy denial has no cleanse answer, which is the named reason its guards are tight |
| direct `cooldown` op | > [!danger] **The self-reset infinite-cast exploit must survive every rewrite of this row:** `new multiplayer/battle_manager.gd` calls `start_cooldown()` at `:1193` and `execute()` at `:1208` — a skill that resets its own cooldown lands **after** the write and becomes infinitely repeatable. Reject a negative op naming its own containing ability. Match targets by `ability_name`, never index (`abilities/stark1.gd` documents the failure). |
| `seal` | `blocks/block_schema.gd:187-189` still promises it ("see Creator Roadmap") — honour or amend that comment |
| `execute` (instant kill) | **BUILD IT** — the 2026-07-31 ruling stands: a shipped outcome used by 16 abilities, exposed with ordinary guards (a cost, a cooldown, limits on any paired `hp_below` threshold). Both shapes belong: thresholded and unconditional, because the roster contains both. |
| `revive` op + `dead_ally` pool | F's `include_dead` covers the *targeting* half only; the op needs a pool branch that deliberately skips `_alive()`, and `dead_ally` is rejected as a `when`/`requires` selector (no dead target exists during usability checks) |
| `DAMAGE_REDIRECT` (safe subset) | **DEFERRED — owner adjudication (2026-08-04).** `Effect.redirect_effect` stores a live `Character` in the effect, the exact boundary the block system holds, so an author-named redirect target cannot ship. Two options: **(a)** a bounded ENUM form — redirect-to-`user` / redirect-to-random-living-ally — resolved by the engine at trigger time so no `Character` is ever author-named; **(b)** leave it out. Recommendation: (a) IS shippable, but ONLY after verifying `check_damage_redirect` skips dead absorbers first (a redirect onto a dead ally would black-hole the hit); if that does not hold cheaply, leave it out. Not shipped this phase — no guess. |
| event-scaled amounts (`event_damage`) | **DEFERRED — owner decision (2026-08-04).** The old Phase 6 payback shape (power5) maps onto **no value in E's closed reading enum**. Option: extend the enum with a payload-only `event` reading, `in_reactive`-gated (it only means something inside a reactive payload, where the triggering event's magnitude exists). Recommendation: extend with `event` IF the payload magnitude is a single well-defined scalar the dispatcher already threads; otherwise leave deferred. Not decided here — the owner should confirm the hook carries a scalar before it is exposed. Not silently omitted: recorded here as a still-valid, deferred capability. |

### The parallel asset/venue track — schedulable any time

Tasks **#72** (approved authored characters in char-select) and **#73** (authored portraits in
battle) survive from the old Phase 0 unshipped: `loadRoster`/grid merge of `S.creator.approved`,
`portraitRel` fallback to `authoredArtUrl` for `auth_`-prefixed names, and `authored_asset_fetch`
moved outside the kill-switch gate (`components/server_connection.gd:733`) so an opponent can fetch
approved art while the Creator is off. Then, and only then: the **`PORTRAIT_CHANGE`** table row
plus alt-portrait slots (`AuthoredAssets.SLOTS` extended, `ability_slots()` switched to an explicit
list so alts are never handed out as skill icons; the factory already sets `cleansable = false`,
`system = true`, which is correct).

### Engine-fix-later

**`SKILL_COPY`** — 8/174, *a good mechanic blocked by a bug, not a design*: `Effect.copy_effect`
(`scripts/effect_component.gd:591-606`) derives identity from the copied skill's **script path**,
and every authored skill's path is `res://blocks/scripted_ability.gd`, so the key is garbage and
the next line null-derefs in a live match. The fix is an instance-based `copy_effect_instance` in
`scripts/effect_component.gd`. Nothing in the block layer ships first. **Status (2026-08-04): stays
DEFERRED, unchanged.** `copy_effect` (`:591`) keys identity on the script path — `res://blocks/
scripted_ability.gd` for every authored skill — so the key is garbage and the next line null-derefs
in a live match. The instance-based `copy_effect_instance` must land BEFORE any block-layer exposure.

### The do-not-build list, with reasons

| Item | Reason |
|---|---|
| **Disguise-by-name** | `Effect.disguise` feeds an author string to `load("res://character/…")` — the exact boundary the block system exists to hold. The only conceivable shape is a server-resolved roster index, plus an engine fix (a full character is built and freed per portrait resolve), plus it is a griefing tool in open authoring. |
| **Author-written reflect payloads** | Reflect mutates the caster's targeter in place with two known traps (common AoE is `ALL(2)` not `ALL_FACTION(1)`; re-aimed targets must be re-validated). B's fixed engine callable is the only safe shape. |
| **Per-character state variables** | Measured 2/174 (`character/yuji.gd:7`, `character/toji.gd:7`). An effect-borne register beats a node var on every axis this engine has (wire, rendering, cleanse scoping, death-cleanse, attribution, merge). The one genuine exception (`xslash_hits`) is shape, not storage — it decomposes into per-skill marks + E's value reading. |
| **`on_harmful_used` row** | The strictly weaker hook — `HARMFUL_USE_TRIGGER`'s context does not carry the used Ability; `on_skill_used` + B's event-class filter serves all 14, including the 11 outside the containment set. |
| **`on_helpful_used` / `on_helpful_received`** | Live dispatchers, **zero** shipped consumers. |
| **`EMPTY` kind** | `mark` + `cleansable: false` is behaviourally identical, and `EMPTY` is strictly *more* fragile (`shrug_off_type` exempts `MARK`, not `EMPTY`). |
| **`slot_holds` condition** | Subsumed by B's `.effect` axis; a slot-index form would re-derive and drift from `moveset_order`. |
| **Dead engine rows** | `DAMAGE_NEGATE` (zero producers, zero readers), `HEALING_MOD` (zero callers), `DAMAGE_NULLIFICATION` (only producer is a non-roster orphan), `REFLECT_USE` (zero producers), plus the dead enum rows (`UNIQUE`, `PAYLOAD_SWAP`, `CURSE`, `DELAY_TICK_TRIGGER`, `HEALING_RECEIVED_TRIGGER`) and reader-only rows (`MISS_CHANCE`, `PRIMARY_STAT_MOD`, `STUN_IMMUNITY`). Grep the **reader**, then its enclosing branch, then for a roster **producer** — the hygiene rule this list enforces. |
| **The name-keyed residue** | `XANXUS_STORAGE` (calls a method that exists only on `character/xanxus.gd:55`), `NAGISA_DR`, `ERZA_ARMOR`, `HISOKA_HEALTH_FREEZE`, the 12 engine-hardcoded `path_name`s, and the `call_unique` engine-callback targets (**mash, jaden, jupiter**). Properties of the engine reading a name, not of the authoring model. |

### Guards & prose / Verify

Guards are per item above — all named-abuse, no prescriptive caps. Prose per item follows the
standing contract. Verify: `training/tests/creator_longtail_probe.gd`, one assertion block per
shipped item; the load-bearing revert-fails cases are the **cooldown self-reset** (with the rule
hand-removed, assert the skill becomes infinitely repeatable — then restore), `max_uses` surviving
a cleanse and a revive, `else` firing exactly one branch across 100 seeded rolls, and an
`all_enemies` drain removing N, not 3N.

### Status — shipped 2026-08-04 (closes the roadmap)

**Built (nine long-tail rows), in two stages.** All confined to `blocks/` (schema/runner/validator/
scripted_ability) + the client editor `webclient/app/app.js` (mirrored byte-identical to `deploy/`) —
no `scripts/` engine change was needed. `BlockSchema.self_check()` green; full compile clean;
`creator_longtail_probe` green (Stage-1 41 + Stage-2 assertions, every negative paired with a positive
control); `advreview_phaseb` updated for the new hook and green; `creator_palette` 444/0; the rest of
the block/creator suite unregressed. `semantic_feature_probe`'s one failure (`kill_available weight`,
a bot-policy weight) is pre-existing and unrelated.

- **Stage 1 (exploit-carrying ops):** `execute` (instant kill; honours the shipped Embrace Pain /
  Sealed Nightmare immunities by going through `instant_kill`/`execute_attempt`, in `REVALIDATED_OPS`),
  `revive` + the `dead_allies` pool (targets that deliberately skip `_alive`; rejected as a
  `when`/`requires` selector), direct `cooldown` (self-reset infinite-cast refused twice — validator
  pass + runner backstop; matched by `ability_name`, never index), `drain_energy`/`steal` + the
  `energy_at_least` condition (dedupe drained targets by `.team`; steal grants only what `lose_energy`
  actually removed).
- **Stage 2 (cheaper rows):** `else` on `group` (ONE roll, exactly one branch; `_count_blocks` and
  every recursive validator/bot pass recurse into `else`), `max_uses` charges (a `system` +
  `display_system` + `remove_on_death:false` + `cleansable:false` counter mark that survives a cleanse
  AND a revive; prose prints "N uses per match"), `cost_color_at_least` (reads `ability.cost()`),
  `on_healing_given` (rides B's `affected` = the healed; joined `SCOPED_TRIGGERS` because it fires from
  a skill), and `seal` — Phase A's `skill_seal` exposed as a first-class op with the class-filter +
  name-inclusion + name-exclusion vocabulary `is_sealed_out` reads (the `block_schema.gd` promise at the
  old `:187-189` comment is now honoured, and that comment is reconciled to point at the shipped op).

**Deferred (four), with written reasons — do not silently omit:**

| Item | Decision (2026-08-04) |
|---|---|
| `DAMAGE_REDIRECT` (safe subset) | DEFERRED, owner adjudication. `Effect.redirect_effect` stores a live `Character` — the boundary the block system holds. Options: (a) an ENUM redirect-to-`user`/-random-living-ally form resolved by the engine at trigger time, or (b) leave out. Recommend (a) ONLY after confirming `check_damage_redirect` skips dead absorbers first; else leave out. No guess shipped. |
| event-scaled amounts (`event_damage`) | DEFERRED, owner decision. power5's payback maps onto no value in E's closed reading enum. Option: a payload-only `event` reading, `in_reactive`-gated. Recommend extending IF the dispatcher already threads a single scalar magnitude; else defer. Owner confirms the scalar before exposure. |
| `SKILL_COPY` | Stays DEFERRED (engine-fix-later, unchanged). `copy_effect` keys on script path (garbage for authored skills, null-derefs live). Needs `copy_effect_instance` in `scripts/effect_component.gd` first; nothing in the block layer ships before it. |
| asset/venue track (#72/#73) + `PORTRAIT_CHANGE` | Separately schedulable, gated on portraits. Not this task; left untouched. |

---

## The ceiling, honestly

**~146–147 of 174 (≈84%).** The residue is [[Creator Gap Analysis]] §5.3's 24 name-keyed characters
**plus mash, jaden and jupiter**, who reach the engine via `call_unique` callbacks and belong in
the residue, not the buildable count (the in-file 150 predates this correction). Every residue
character is blocked *only* on engine branches reading a hardcoded name or path — no palette row
reaches them, because they are properties of the engine reading a name, not of the authoring model.
`SKILL_COPY`'s 8 come back if and when the engine fix lands.

The cumulative milestones, with the measured figures where the set composition is order-independent
and *provisional* markers where the reorder makes intermediates unmeasured:

| After | Fully expressible | ≤1 gap | Status |
|---|---:|---:|---|
| today | 7 *(an upper bound — quote the shape, not the 7)* | 22 | measured |
| A + B | ~17+ | ~56+ | provisional (addressing pulled early) |
| C | ≈30 | ≈91 | provisional |
| D | **56** | **109** | measured — identical set to the gap analysis's step 17 |
| E | large jump begins | — | provisional (order swapped with F) |
| F | **~146–147** | ~171 → 174 with G's long tail | corrected endpoint |

---

## Cross-cutting hazards — carry through every phase

1. **Per-hook lies.** `once`, `last_turn_only`, `trigger.scope` and `bypassing` are each meaningful
   on some hooks and inert on others (the `DAMAGE_RECEIVE` once-guard is *commented out* at
   `scripts/character_component.gd:1334-1335`). Each must be **rejected by the validator** on hooks
   that ignore it, and the prose must not promise it there. The palette already ships the miniature
   version of this error: the dead `trigger_once` is offered (`blocks/block_schema.gd:220`) while
   the live `Effect.triggered` is classified as engine bookkeeping (`:174-177`).
2. **`on_hp_changed` has no re-entrancy brake** — probe before its row ships (Phase B).
3. **Dead entry points that pass smoke tests** — `check_counter_use_effects` /
   `check_counter_receive_effects` have zero callers; the live counter path is `countered()`
   (Phase B).
4. **One measurement band is unstable**: the "a count reaches a magnitude" shape reads 7/174
   (hand-verified counter idiom), 24/174 (traceable by any route), 45/174 (loose `+=` sweep —
   damage accumulators look identical to counters). Quote 7 or 24. Never 45.

---

## Open decisions for the owner

1. **A2 — the invuln re-validation nerf.** It weakens every already-approved authored AoE against
   invulnerable defenders, cannot be opt-in, and needs a patch-note line. Approve before Phase A
   completes; every later pool/pick widening multiplies the defect until it lands.
2. **The hostile-`recurring` duration cap** (Phase D) and the **`IMMORTALITY` / permanent-isolate
   bounds** (Phase C): the abuse cases are named; the parameter values are yours per the standing
   no-invented-limits rule.
3. **The reserved-name list's size** (Phase A1): 3 names are confirmed abusable; the other ~37
   hardcoded names need per-branch reads before the list is sized.
4. **The authored `mag` percentage convention** (Phase C): removed-vs-retained must be picked once,
   converted in the build arm, and documented — the corpus itself is inconsistent.
5. **Sequencing #72/#73** (the asset track): any time, but before `PORTRAIT_CHANGE` can ride the
   table — pulling it ahead of Phase C lets the row ship with the table instead of trailing it.
6. **Event-scaled amounts** (Phase G): extend E's reading enum with a payload-only `event` reading,
   or defer with a written reason — not silence.
7. **The Phase F AoE product ceiling** — `LIMITS.max_aoe_product` is a conservative placeholder
   (set so one full-magnitude AoE clears it and only a heavy single-target combo silently widened to
   a faction is caught), and `MAX_RESOLVABLE_FACTION` assumes the standard 3-per-side match (the
   validator has no live team size). Both are yours to confirm; the guard's existence is the point.
8. **Whether campaign-stable bot cosmetics stay as-is** once authored portraits land in battle
   (#73) — the portrait fallback path and bot-practice presentation should be decided together.
8. **`and_targeter`** (Phase A5): wire it for authored content or retire the flag until Phase F
   gives splash predicates a home. Retiring is recommended.

---

## See also

[[Creator Gap Analysis]] — the factual base · [[The Creator]] · [[Block Palette Reference]] ·
[[What Cannot Be Built Yet]] · [[Ticking and Passives]] · [[Creator Roulette]] ·
[[Roulette 06 - Boruto Uzumaki]] · [[Roulette 07 - Levi Ackerman]] · [[Roulette 08 - Semiramis]] ·
[[Verification Playbook]] · [[Hard Rules and Guardrails]] · [[Traps That Have Bitten Us]] ·
[[Bots and Training]] · [[Data Files and the Deploy Mirror]] · [[Targeting and Main Target]] ·
[[Effects and Durations]] · [[Cleanse Silence and Effect Removal]] ·
[[Node Lifecycle and Orphans]] · [[Admin and Live Ops]]
