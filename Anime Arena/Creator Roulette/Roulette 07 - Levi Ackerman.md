---
tags: [area/playbook, type/reference]
---

# Roulette 07 - Levi Ackerman

**Draw:** `draw 79/174 -> levi` — recorded before any script was opened.
**Universe:** Attack on Titan · **Gate:** `levi_unlock` · **Abilities:** 5 (4 visible, 1 passive, no
hidden slots).
**Verdict:** **Buildable with fidelity loss** — 15 mechanics: **11 buildable, 2 approximable, 2
blocked**. No skill is wholly out of reach. Skill 2 loses one clause's identity; the passive keeps
its firing condition after all, via `on_death` rather than the absent `on_kill` (corrected below).

> [!danger] Corrected after an adversarial pass — the passive was wrongly called Blocked
> The first version of this page marked levi5's on-kill firing **Blocked** and said "the passive
> loses its firing condition". That was a **false Blocked**, the exact failure the playbook defines
> against ("no combination reaches it" — a combination does). `Character.die()` calls
> `check_death_triggers(killer)`, which sets `context["owner"] = killer`
> (`scripts/character_component.gd:1459-1466`) and runs at `:1903`, **before**
> `cleanse_death_effects()` at `:1904`. `on_death` is a **shipped** `TRIGGERS` row. So Levi plants
> `on_death` watchers on the enemy team; when one dies, the payload's `target` resolves to the
> killer, and gating on an invisible identity mark the holder carries recovers exact attribution.
> Probed 12/12 on a real BattleManager: naive form pays out on an ally's kill (attribution loss),
> the gated form pays the holder only. The error is left visible rather than quietly rewritten.

> [!danger] Conflict of interest — **this kit was written by the assistant auditing it**
> `abilities/levi1-5.gd` and their `abilities_data.json` rows were authored by me, earlier in this
> same project (tasks 16-19). Two biases follow and a reader should discount for both: a pull toward
> declaring the kit buildable, and a pull toward treating whatever it happens to use as obviously
> in-scope for the palette.
>
> The counter-pressure applied, so the discount can be calibrated:
> - The one flattering result — "levi2's exotic mechanic is approximable at full numeric fidelity" —
>   is **true only at Levi's exact parameters**, and the page says why. levi2 is the only 1 of 15
>   shipped `color_change_effect` call sites that filters to a named skill, and the skill it names
>   costs exactly 1 point of the swapped colour. Both properties are load-bearing. At the other 14
>   sites the same approximation is not close.
> - The gap this kit exposes measures **2/174**. It is written up as a row, not a system.
> - The audit hunted the kit for defects and found three: an **inert argument** (levi2), a **revive
>   hole** (levi5), and a brief that mis-stated its own cost. All three are recorded below.

---

## The kit

| # | Skill | Cost | CD | What it actually does (from the script) |
|---|---|---|---|---|
| 1 | **Precision Strike** | 1 Green | 0 | 20 Piercing to one enemy |
| 2 | **ODM Gear Assault** | 1 Red, 1 Random | 3 | Self-Invulnerable 1 turn · **Precision Strike costs 1 Random *instead of* 1 Green** (raw dur 3, `refresh`) · 20 Piercing now + a raw-3 Piercing DoT (= 2 instances) |
| 3 | **Humanity's Strongest** | 1 Green, 1 Red | 2 | 40 Piercing to one enemy |
| 4 | **Unmatched Agility** | 1 Random | 4 | Self-Invulnerable 1 turn |
| 5 | **Relentless Captain** | — | — | **Passive.** Permanent invisible `MISSION_TRIGGER_ON_KILL` on Levi; **each kill** applies a permanent stacking `+5` damage buff |

> [!warning] Correction to the run brief — levi2 costs **1 Red**, not 1 White
> `abilities_data.json` gives `levi2.cost = {"0":0,"1":0,"2":0,"3":1,"4":1}`, and `Energy.Type` is
> `GREEN=0, BLUE=1, WHITE=2, RED=3, RANDOM=4`. Index 3 is **RED**. `BlockValidator._validate_cost`
> uses the same indices, so an authored copy writes `"cost": {"3": 1, "4": 1}`.

---

## Mechanic audit

| Skill | Mechanic | Verdict | Notes |
|---|---|---|---|
| 1 | 20 Piercing to one enemy | **Buildable** | `{"op":"damage","to":"target","amount":20,"damage_type":"PIERCING"}`. `to: "target"` is on the **safe** side of run 06's pool defect — the targeter was pre-stripped of invulnerable enemies |
| 1, 3 | cost / cooldown / classes / target type | **Buildable** | `AuthoredCharacter._build_moveset` writes all four through. Colour keys 0-4, values 0-20, no total cap. **Gotcha: "Damaging" is not auto-derived** — omit it and `is_silenced_out` makes the skill unusable under Silence |
| 2 | Self-Invulnerable 1 turn | **Buildable** | `{"kind":"invulnerable","turns":1}` → `turns_to_duration(1) == 2` → the identical `Effect.invuln_effect(2)` the script calls |
| 2 | **COLOR_CHANGE** — Precision Strike costs Random *instead of* Green | **Approximable** | A `cost_change −1 green` + `cost_change +1 random` pair. **Bit-exact for Levi, and only for Levi** — three measured divergences and two residual losses below |
| 2 | `refresh = true` on the colour swap | **Blocked** | Not in `UNIVERSAL_EFFECT_FIELDS`; probed rejected. **Zero observable loss for COLOR_CHANGE** (the transfer is idempotent) — but severe for the approximation |
| 2 | `add_allied_effect(..., bypassing=true)` | **Buildable** | Nothing to build: the argument is **inert here**. Omitting it is a fidelity *improvement* over the shipped script |
| 2 | Immediate 20 + raw-3 Piercing DoT (2 instances) | **Buildable** | `apply` `damage_over_time` with **`ticks: 3`** (`turns` can only ever be even), then `damage`. **Order is load-bearing** — `apply` first, or a lethal first instance drops the DoT |
| 3 | 40 Piercing to one enemy | **Buildable** | levi1 with `amount: 40` |
| 4 | Self-Invulnerable 1 turn, self-target | **Buildable** | `target: "self"` → `TargetType.SELF` → `default_self_target_function`, exactly what the script uses. Zero loss |
| 5 | Install once at battle start (Passive) | **Buildable** | `startup_passives` calls `execute()` on any ability with the Passive class; the validator requires cooldown 0, which levi5 has. Already green in `creator_palette_probe` |
| 5 | Permanent (`-1`) duration | **Buildable** | Explicitly admitted on both `turns` and `ticks`. **127/174 of the roster uses it** |
| 5 | `invisible` + `system` on the trigger | **Buildable** | Both universal fields. `system` = cleanse-proof **and** hidden from both players; `invisible` = wire-visible but hidden from the opponent; `display_system` splits the two. All three authorable |
| 5 | **ON-KILL firing condition** | **Approximable** | `on_kill` is genuinely absent (probed rejected), but the shipped `on_death` row REACHES the mechanic — watchers planted on the enemy team, `context["owner"] = killer`. Probed 12/12. `on_kill` is an ERGONOMICS row, not the blocker — see below |
| 5 | Per-kill firing (not once-per-turn) | **Buildable** | The authored default. `Effect.triggered` is never set true by the engine, and `_build_trigger`'s Callable never writes it |
| 5 | Growing permanent buff (`stackable` + `stack_mag` + `display_stacks`) | **Buildable** | **Proven by a shipped green probe**, not reasoned: `creator_palette_probe.gd:169-194` merges two authored casts to 2 stacks and carries `mag 5 → 10`, with a no-`stackable` contrast case storing two effects |

Eleven buildable, one approximable, three blocked. Skills 1, 3 and 4 are authorable **exactly**;
skill 2 loses one clause's identity; skill 5 loses only the hook it hangs on.

---

## What blocks it

### 1. COLOR_CHANGE is a factory the palette never exposed — and the substitute is a trap

`Effect.color_change_effect(inc, replaced, dur, targets)` (`effect_component.gd:684-707`) sets
`mag = inc_color`, `cost_change_element = replaced_color` and hard-sets `cleansable = false`. It is
consumed in a **third** pass of `Ability.cost()` (`ability_component.gd:333-352`), after the
COST_CHANGE override pass and after the COST_MOD pass:

```gdscript
var total_cost = output_dict[replaced]
output_dict[replaced] -= total_cost
output_dict[inc]      += total_cost
```

That is a **transfer**, not an arithmetic delta. The palette's `cost_change` → `cost_mod_effect` is
`output_dict[element] += mag`, floored per colour at 0. The two are not the same operation, and the
run-06 rule applies: an "approximable" has to be written out and measured, not asserted.

**Live `cost()` differential** — printed from a real `BattleManager` with the real Levi, not reasoned:

```
baseline  Precision Strike  = G1 Rnd0      Unmatched Agility = G0 Rnd1      Two Green (synth) = G2 Rnd0
[COLOR_CHANGE]      PS=G0 Rnd1    UA=G0 Rnd1    2G=G0 Rnd2
[cost_change pair]  PS=G0 Rnd1    UA=G0 Rnd2    2G=G1 Rnd1
```

| # | Divergence | Why |
|---|---|---|
| 1 | A colour already at **0 still gets taxed** | `−1 green` floors at 0 (a no-op), but `+1 random` is unconditional. `UA: Rnd1 → Rnd2`. COLOR_CHANGE moves `total_cost = 0` and is a true no-op |
| 2 | **Not proportional** | COLOR_CHANGE moves the whole cost (`G2 → Rnd2`). The pair is a fixed 1, producing a *split* cost (`G1 Rnd1`) that is worse than either |
| 3 | The two deltas are **independent** | Nothing ties the amount removed to the amount added. One transfer cannot desynchronise; two effects can |

**For levi2 it is exact** — `skills: ["Precision Strike"]`, and Precision Strike costs exactly
`{"0": 1}`. `PS=G0 Rnd1` both ways. Two non-numeric losses survive even there:

- **Two pips, two clauses.** One effect becomes two, and the generated prose reads "Precision Strike
  cost 1 less Green energy for 1 turn. Precision Strike cost 1 more Random energy for 1 turn."
- **Cleanse asymmetry — a state the original cannot reach.** `color_change_effect` hard-sets
  `cleansable = false`; `cost_mod_effect` inherits the `true` default. A buff-strip can take *one*
  half, leaving Precision Strike costing **1 Green AND 1 Random** — strictly worse than baseline.
  The author can close it with `cleansable: false` on both (it validates), but it is not the default.
- **Name-collision footgun.** Both halves are COST_MOD from the same ability on the same character,
  and `effect_name()` falls back to the source ability's name. They coexist at the default
  `stackable: false`, but an author who ticks `stackable: true` — the natural response to the
  re-cast problem below — makes the second **merge into** the first and the `+1 random` half
  vanishes silently. `name_override` on at least one is mandatory, and nothing warns.

> [!warning] The approximation is Levi-shaped, and Levi is the outlier
> **14 of the 15 shipped call sites pass an empty `targets` list** — the swap applies to the
> holder's whole kit (crona6 does all four colours at once; lizandpatty1/2 do two each). Only levi2
> filters to a named skill. An unfiltered whole-kit swap would need one `−N/+N` pair *per colour*,
> with N unknowable at authoring time because it depends on each skill's own cost. Quoting "8/174,
> approximable" without this qualifier would describe a workaround that serves 1/174.

### 2. `refresh` — one reader, and the honest conclusion cuts against exposing it

`Effect.refresh` (`effect_component.gd:19`) has exactly **one** functional reader repo-wide:
`EffectStorageComponent.add_effect` (`effect_storage_component.gd:45`) —
`elif eff_match.refresh: remove_effect(...); _store_effect(effect)`. It is read off the
**already-stored** effect, and it sits in the `elif` *after* `stackable`, so `stackable` wins if both
are set. It is not in `UNIVERSAL_EFFECT_FIELDS` and the validator rejects it:
`unexpected field 'refresh' for effect 'cost_change'`.

**Probed both ways, and the two answers point in opposite directions:**

| Re-cast without `refresh` | Result |
|---|---|
| **COLOR_CHANGE** ×2 | Cost is **byte-identical** (`PS=G0 Rnd1`). The transfer is idempotent — the second effect finds the colour already at 0 and moves 0. The only difference is a duplicate pip and a spurious expiry event |
| **the `cost_change` pair** ×2 | `PS=G0 Rnd2`. The Random tax **doubles, and keeps doubling** |

So `refresh` is not needed to ship a COLOR_CHANGE row; it is needed the moment an author tries to
hand-roll one. **That is an argument for shipping the row, not for exposing the field.** levi2 escapes
the runaway only because its cooldown (3) outlives its effect (`ticks: 3`), so two casts can never
overlap — a coincidence an author cannot rely on.

### 3. The ON-KILL hook — and why a `TRIGGERS` row alone ships broken

`check_kill_triggers` (`character_component.gd:1468-1477`) is called on the **killer** from inside
`die()`, and builds `QueryContext.from_trigger_source(source, eff, killed)`. Resolving that against
`query_context.gd:52-68`: `context.owner = source.user` = **the killer**; `context.target` = **the
victim**. `BlockRunner._build_trigger` binds `set_explicit_targets([context.owner])`
(`block_runner.gd:712-714`) — so an `on_kill` row bolted onto today's runner would make the payload's
`target` selector mean **the killer**, i.e. the holder, which is already what `user` means, and the
victim would have no name at all.

Same trap run 06 found for `TICKING_TRIGGER`, different mechanism. **`on_kill` cannot ship before
run 06's Payload addressing.**

> [!danger] The mis-binding is not hypothetical — `on_damage_dealt` ships with it today. **Probed.**
> A throwaway headless probe gave a character an authored
> `{"kind":"trigger","trigger":"on_damage_dealt","then":[…]}` and made them damage an enemy. 7/7:
>
> | Payload | Result |
> |---|---|
> | `apply` a mark `to: "target"` | `Branded held by: levi=true victim=false bystander=false` — the payload branded **its own holder**; the character actually damaged is unaddressable |
> | `damage 10` `to: "target"` | `levi 100 → 0, victim 80 → 60` — the holder damaged **himself**, which **re-entered the same hook**, running until he was dead. **10 damage authored, 100 taken.** |
>
> `check_damage_dealt_triggers` is called on the *dealer* with the victim in `context.target`
> (`character_component.gd:692`, `:1261`), and the runner binds `target` to `context.owner` = the
> dealer. The generated prose says "when they deal damage" and promises the opposite of what runs.
> Four of the seven shipped hooks bind correctly (`on_harmful_received`, `on_damage_received`,
> `on_death`), three are self-held and harmlessly degenerate — **`on_damage_dealt` is wrong, and it
> is a player-reachable self-kill in two blocks.** Probe deleted; copy in the run scratchpad.

---

## Proposed systems — **none**

> [!info] Checked against the ledger first, as the process page requires
> Every gap this run found already has a home. Run 07 proposes **no new system** and adds a
> **Runs served** tick to **Payload addressing**, which it hits twice independently: the `on_kill`
> binding, and the probed `on_damage_dealt` defect.

Each finding, named and priced. The process page asks for this explicitly, because inflating a
missing enum row into a "framework" is the same failure as proposing something character-shaped.

| Finding | **What it is** | Price | Reach |
|---|---|---|---|
| **COLOR_CHANGE** | **a row** in `EFFECT_KINDS` | One `EFFECT_KINDS` entry, one `_build_effect` match arm, one validator arm reusing `COST_COLOURS` + the existing named-skill check, one `_describe_effect` clause, one editor field. **No engine work** — the factory has shipped since before the Creator existed, already parameterised on (incoming × replaced × duration × named skills) | **8/174 (4.6%)** |
| **`refresh`** | **a field** in `UNIVERSAL_EFFECT_FIELDS` | One schema entry, one `_apply_universal_fields` line. **Do not build it for this run's sake** — it buys nothing for COLOR_CHANGE and its value is confined to kinds the palette already ships | 15/174 gross, **11/174 load-bearing** |
| **`on_kill`** | **a row** in `TRIGGERS` | One `TRIGGERS` entry, one `trigger_hook_id` arm, one `_describe_trigger_hook` line. **Gated on Payload addressing** or it ships pointing at the wrong character | **2/174 (1.1%)** |
| **`on_damage_dealt` mis-binding** | **a defect**, probed | Part of Payload addressing's `_build_trigger` change. Not a feature | ships today |
| **MISSION_TRIGGER_\* prefix ban** | **a comment + a predicate** | ~10 lines. See below | **0/174** unlocked |

**Why COLOR_CHANGE is not a family.** It is one axis (cost colour), it is the axis the ledger's
*Energy colour* row already tracks at 25/174, and 15/15 shipped call sites pass `inc = RANDOM` — the
mechanic as actually used is one-directional. It goes on that row as a sub-entry. Bot story: none
needed — `_derive_tags` already declines to tag a cost *discount*, with a written rationale, and a
colour swap is neither a tax nor a discount. Prose: "Precision Strike costs Random instead of Green
energy for 1 turn", one clause, already written by the factory's own description Callable.

**Why `on_kill` is not a system.** Point 2 of the design bar: "a system serving one character is a
band-aid by definition." The on-kill *union* — `MISSION_TRIGGER_ON_KILL` plus the overridable
`Ability.on_kill()` hook — is `{levi, ryuko}` = **2/174**, and one of the two is the kit under audit.
It is a sub-row under *Trigger-hook coverage*, behind `on_ticking` at 53/174.

### The schema comment that is wrong, and must not be repeated

`block_schema.gd:266-268` excludes the whole `MISSION_TRIGGER_*` family from `immunity_effects()` on
the grounds that they are "mission/achievement bookkeeping hooks, not battle effects a character
could meaningfully resist or would ever hand-remove". **Both halves of that are false.**

- Of the 26 enum members, **15 are dispatched by battle code in `scripts/character_component.gd`**,
  not by `missions/` — `ON_KILL`, `ON_STUN`, `ON_HEAL`, `ON_DAMAGE`, `ON_COUNTER`, `ON_SHIELD`,
  `ON_INVULN`, `ON_BLIND`, `ON_TAUNT`, `ON_SHATTER`, `ON_NULLIFY`, `ON_SILENCE`, `ON_DR_ABSORB`,
  `ON_WEAKNESS_ABSORB`, `GAME_END`. They run every battle whether a mission is attached or not.
- **Three are core gameplay on shipped characters:** `ON_KILL` (`levi5.gd:22`), `ON_STUN`
  (`horohoro4.gd:17`, and `:39` reads it back as a *usability gate*), `ON_INVULN` (`nel3.gd:40`).
- `nel3` applies its `ON_INVULN` watcher to **every enemy** via `add_hostile_effect`, which calls
  `target.shrug_off_type(effect.effect_type)` — precisely what an `effect_immunity` naming that type
  would trip. So it *is* a battle effect a character could meaningfully resist.
- The remaining **11 have no dispatcher anywhere** and are dead enum rows.

**Narrowing:** key the exclusion on "has no dispatcher", not on the `MISSION_TRIGGER_` name prefix.
This is the same mistake the file's own comment records having made once before, when a hand-kept
nine-name whitelist rejected SHIELD and COUNTER_RECEIVE/COUNTER_USE.

> [!warning] …and do **not** oversell it — the measured reach of that fix is **0/174**
> No shipped ability immunises against or type-removes a `MISSION_TRIGGER_*` today, and `remove`
> does not need it (the `effect` field is an optional disambiguator, so an author can already strip
> one by name). This is a **correctness-and-comment fix worth ~10 lines**, not a capability unlock.
> Its value is preventing the next wrong inference, and it costs editing two green probes that
> currently assert the exclusion as desired behaviour.

---

## Auditing my own kit harder — two defects found in the shipped scripts

**1. `abilities/levi2.gd:31` passes an argument that does nothing.** On the *allied* path,
`bypassing` gates exactly one thing (`condition.gd:114`):

```gdscript
if not bypassing and effect.source.classes["Helpful"]:
    conditions.append(helpable)
```

levi2's classes are `[Physical, Action, Harmful, Damaging]` — probed, `classes["Helpful"] == false`
— so the guard is never appended either way. The invulnerability check lives only on the *hostile*
path. The file is also internally inconsistent: line 25 adds the invuln **without** the argument.
The palette's `apply.bypassing` is literally the same 5th parameter, and an authored copy should
**omit** it.

**2. `abilities/levi5.gd:24-25` sets `system = true` without `remove_on_death = false`.** The death
cleanse spares an effect only when `not effect.system or effect.remove_on_death` is false — so
`system` with the default `remove_on_death = true` **is stripped**. When Levi dies, the kill trigger
and every accumulated `+5` are erased, and `startup_passives` never re-runs, so a revived Levi plays
on with a dead passive and zero accumulated damage. `stark5.gd:50-56` documents this exact trap and
gets it right; levi5 copied `adam5.gd:26-27`, which has the same hole.

> [!success] The genuinely pro-Creator result, and the one I was *not* biased toward
> `remove_on_death` **is** in `UNIVERSAL_EFFECT_FIELDS`. A player authoring Levi in the block editor
> can write the correct form that the hand-written script does not — and that **17/174 shipped
> characters** (permanent + `system` + no guard) also do not, against **8/174** that carry the
> guard. The self-authored kit inherited a corpus-wide bug that the authoring layer prevents.

---

## Reach

Roster frame verified at 174 (`char_name_list()`), every count intersected with it.

```bash
sed -n '5,178p' scripts/character_database.gd | sed 's/[\t",]//g' | awk 'NF' | sort > chars.txt   # 174
cd abilities && grep -l '<PATTERN>' *.gd | sed 's#\.gd$##; s#[0-9]*$##' | sort -u \
  | comm -12 - ../chars.txt | wc -l
```

| Gap | Characters | Pattern | Note |
|---|---|---|---|
| **COLOR_CHANGE** | **8 (4.6%)** | `Effect\.color_change_effect\(` | 10 files, **15 source lines, 18 runtime applications** (`allmight5.gd:55-56` loops one line over 4 colours). Factory grep, 0% FP, all 15 lines read |
| **`refresh` field** | **15 (8.6%)** | `\.refresh\s*=\s*true` | 19 files, **all 19 opened, 0% FP**. Split: **11/174 load-bearing** (damage_mod, cost_mod, shield, DoT, trigger — duplication changes the numbers) vs **4/174 cosmetic** (mark, swap, ignore_effect, target_change, **and colour swap**) |
| **`MISSION_TRIGGER_ON_KILL`** | **1 (0.6%)** | `MISSION_TRIGGER_ON_KILL` | `levi5.gd` — the self-authored kit |
| **on-kill union** | **2 (1.1%)** | + `^func on_kill\(` | `ryuko1.gd` is the only override, and it does the *same* mechanic (heal 10 + permanent `damage_mod_effect(10, -1)`) |
| all `MISSION_TRIGGER_*` | **3 (1.7%)** | `MISSION_TRIGGER` | 4 lines in 3 files: `horohoro4`, `levi5`, `nel3`. The other 23 enum members: **0/174** |

**Not gaps — shipped palette, quoted as coverage evidence only:**

| Shipped capability | Characters | Note |
|---|---|---|
| permanent (`-1`) duration | **127 (73.0%)** | 430 call sites / 245 files, from a brace-matched parse checking `-1` in each factory's *actual* duration position. `damage_mod` sub-count: 34/174 |
| `stackable = true` | **79 (45.4%)** | adversarially verified, 0% FP |
| `invisible = true` | 70 (40.2%) | ceiling — not hand-inspected |
| `system = true` | 48 (27.6%) | ceiling — not hand-inspected |
| perm `damage_mod` + `stackable`/`stack_mag` | **28 (16.1%)** | same-effect binding. levi5's exact triple: 13/174 |
| `stack_mag = true` | **25 (14.4%)** | tight |

> [!warning] Adversarial pass — my #1 count moved **down**, and one prior figure is corrected
> Permanent duration first read **129/174** from the naive "any bare `-1` in an `Effect.*_effect(`
> call". Against a per-factory duration-position table it is **127** — a **5.7% call-site FP rate**,
> 2 characters lost. Two real causes: `cost_mod_effect(-1, dur, …)` passes `-1` as the **magnitude**
> (21 sites), and `reflect_effect(…, -1, …)` passes it as `reflect_target` or `count` (5 sites).
>
> `stack_mag` reads **27/174 loose** but **25/174 tight**: the loose grep counts
> `asta2.gd:34 shield.stack_mag = false` and two comments — one of which literally says
> *"stack_mag is deliberately NOT set"*. A grep that counts a comment denying a field as a use of
> that field is run 06's hygiene failure in its purest form.

---

## Verdict for the roadmap

**Two rows and a field, and none of them is urgent.** That is a good result, and the process page
says so: a boring run is evidence about coverage.

1. **The `on_damage_dealt` mis-binding is a fix and outranks everything else here.** Probed: an
   authored two-block skill kills its own author. It is part of **Payload addressing**'s
   `_build_trigger` change and is a second reason that system is the ledger's top open item —
   alongside run 06's authored-AoE-ignores-Invulnerability defect, which is still ahead of all new
   palette work.
2. **`on_kill` → a sub-row under *Trigger-hook coverage*** ([[Creator Roadmap]] Phase 2's enum-row
   bucket), **behind `on_ticking` (53/174) and gated on Payload addressing.** 2/174 does not justify
   it on its own; it rides along when the hook enum is next touched.
3. **COLOR_CHANGE → a sub-row on the ledger's *Energy colour* entry.** 8/174, no engine work, one
   `_build_effect` arm. Cheap, low priority, add it whenever the palette is next opened. Its
   strongest argument is not its own reach but that the hand-rolled substitute has a runaway
   doubling failure an author cannot see coming.
4. **`refresh` → do not build.** It buys nothing for the mechanic that motivated it.
5. **Narrow the `MISSION_TRIGGER_*` exclusion** to "has no dispatcher". A correctness fix; 0/174
   unlocked; the comment above it is factually wrong and future runs must not inherit it.

> [!info] What run 07 says about the through-line
> Run 06's through-line — *the palette can hold state and cannot reliably point at anybody* — is
> confirmed from a different direction. Levi has no rotation and no delayed payloads; his passive is
> the simplest possible persistent-state design, and **every piece of its machinery is shipped**
> (permanent duration 127/174, `stackable` 79/174, `system`/`invisible`, per-kill repetition). What
> blocks him is one hook, and the hook cannot ship because the payload could not name the character
> the event happened *to*. Seven runs in, "who / which / when" is still the gap, and "what" is not.

> [!warning] What was and was not executed
> **Executed:** a validator + live-`cost()` probe (13 assertions, 13 passed) covering every JSON on
> this page, the COLOR_CHANGE ↔ `cost_change` differential, the `refresh` idempotence result and the
> inert-`bypassing` check; and a separate `on_damage_dealt` addressing probe (7 assertions, 7
> passed). Both were throwaway files under `training/tests/`, **deleted after the run**, with copies
> and logs in the run scratchpad.
> **Not executed:** every reach number is a grep, with FP rates stated above; the `refresh`
> load-bearing/cosmetic split is reasoned from each factory's semantics, not probed per kind; and the
> 17/174 revive-hole figure is an upper bound, not a confirmed defect count. Confirming any
> individual one needs the normal loop in [[Verification Playbook]].

---

Related: [[Creator Roulette]] · [[Roulette 01 - Naruto Uzumaki]] · [[Roulette 02 - Death the Kid]] ·
[[Roulette 03 - Sailor Mercury]] · [[Roulette 04 - Superbi Squalo]] · [[Roulette 05 - Shiro]] ·
[[Roulette 06 - Boruto Uzumaki]] · [[Block Palette Reference]] · [[Creator Roadmap]] ·
[[What Cannot Be Built Yet]] · [[Trigger Types]] · [[Cooldowns and Energy]] ·
[[Effects and Durations]] · [[Cleanse Silence and Effect Removal]] · [[Bots and Training]] ·
[[Verification Playbook]]
