---
tags: [area/playbook, type/howto]
---

# Patch 2026-08-02 - Implementation Roadmap

The engineering plan for [[Patch 2026-08-02]]. 42 characters, **73** changes, one engine edit. (Earlier drafts said 76; the true atomic count is 73.)

> [!info] The headline, up front
> **This patch needs exactly one new engine change, and it serves one character.** Everything else is
> a literal, a data field, or an assembly of primitives that already ship. The real cost of the patch
> is not capability — it is that **nine changes across five characters delete or retype an effect
> that a *sibling skill* uses as its lookup handle**. Every one of those fails silently as a
> permanently greyed-out button, not as an error, so a compile check and a casual smoke test both
> pass. That hazard, not the engine work, is what the phase order is built around.

Repo root: `C:/Users/mailj/Downloads/AnimeArena-webclient`. All paths below are relative to it.

## The shape of the work

| Work type | Count | What it means here |
| --- | --- | --- |
| **New engine primitive** | 1 | A class filter + name exclusion on the existing `skill_seal` branch. Yugi only |
| **Structural** | 8 | Korra's row removal, Jaden's Shield-as-token refactor, Mavis's Fairy Heart, the Thompson Sisters' mutual exclusion, Esdeath's STUN→MARK migration |
| **Script** | ~34 | A literal, a duration, or a small assembly inside one or two `.gd` files |
| **Script + data** | ~10 | A script edit that also moves a `cost` / `target_type` / cached description |
| **Data-only** | 19 | 14 costs + 5 cooldowns. *Never one file* — see [[#Client data]] |
| **Description-only** | 4 | `kurotsuchi2`, `jaden5`, `jaden6`, `jaden8` |

> [!danger] "Data-only" never means one file in this repo
> `webclient/app/ability_info.json` carries its **own** copy of `cost` and `cooldown`
> (`extract_ability_info.gd:46`, `:56-62`). All 19 pure-number changes therefore need the extractor
> run and the `deploy/` mirror even though no description moved. Skipping the client half is a silent
> lie in the skill panel — the server charges the new cost while the pips show the old one. Full
> pipeline in [[Changing Ability Text]].

> [!danger] Only 6 of the "number" changes are actually in the data file
> Numbers that read like a JSON field but are **hardcoded in GDScript**: `eren6.gd:3`
> `base_damage = 65`; `ryuko1.gd:22` `damage_cap(20, 2)`; `ganta5.gd`'s two literal `3`s;
> `yuji5.gd:20` `mark.mag = 10`; `character/yuji.gd:3` `black_flash_minimum = 10`;
> `character/madoka.gd:27` `passive.mag >= 15`; `mash2.gd:2` `base_damage = 25`; `broly4.gd:3`
> `heal_per_stack = 10`; `soul2.gd:3` `base_damage = 30`; `inosuke1.gd:19` the literal `15`;
> `muichiro3.gd:20`/`:38` the literals `5`; `yubel3.gd`/`yubel5.gd` the stack thresholds.
> **Two changes are not even in the ability the owner named:** Nightmare Sonata's boost lives in
> `soul2.gd:28`, and Xanxus's stack grant lives in `character/xanxus.gd:28-87`.

---

## Phased build order

The order is driven by three constraints, in priority order:

1. **Primitives before consumers**, so a consumer is never debugged against an unvalidated primitive.
2. **Hard blockers early**, while the diff is small enough to bisect.
3. **Anything that deletes rows goes last**, because the client rebuild is purely additive and never
   prunes (`extract_ability_info.gd:70-74`) — so a row deletion's client half is manual and would be
   silently undone by any later extractor run.

### Phase 0 — Pre-flight (no edits)

Two things, both cheap, both of which prevent the patch's dominant failure mode.

**0a. The presence-handle audit.** Before deleting or retyping *any* effect in this patch:

```bash
grep -rn "<Ability Name>" abilities/ character/
```

and check **every** hit for a typed `has_effect(...)` / `marked_by(...)`. This is a checklist gate on
the whole patch, not a per-character discovery. The nine known sites are in [[#Risks]]; the grep is
what catches a tenth.

**0b. Record the known-before ledger.** At least eight description/behaviour desyncs already exist
under code this patch changes. Write them down *before* editing so the post-patch diff is honest and
so a reviewer does not attribute a pre-existing bug to the patch. See [[#Known before this patch]].

### Phase 1 — The skill seal (Esdeath → engine → Yugi)

**Why this order.** Esdeath's *Mahapadma* needs **zero engine work** — the shipped `skill_seal`
branch reads `seal.ability_targets.is_empty() or ability_name in seal.ability_targets`, and an empty
list already means *seal every skill*. So Esdeath is a pure migration that exercises the shipped path
end to end and forces every STUN→MARK side-effect decision, at zero engine risk. Only then is the
class filter added, and only then does Yugi ride it. Building the filter first and testing it on Yugi
means debugging a new engine branch **and** a four-site typed-lookup retype simultaneously.

1. **Esdeath** — migrate `esdeath2.gd:19` from `stun_effect(4)` to a sealing `Effect.mark(4, …)`, and
   retype the self-check at `:26` from `STUN` to `MARK`. Answer the STUN-side-effect enumeration
   (below) **once**, for both characters.
2. **Engine** — teach the seal branch class matching + name exclusion, at **both** call sites.
3. **Yugi** — `yugi3` builds the filtered seal; `yugi2` and `yugi5` get their four `STUN` lookups
   retyped to `MARK` and their names added to the exclusion list.

### Phase 2 — Presence-handle rewires (each is ONE commit)

These are the changes where the requested edit removes the handle a *different* skill uses to find
its own target or prove its own usability. **Half a commit here ships a permanently unusable skill.**

- **Maka** — delete Witch Hunter's `HARMFUL_USE_TRIGGER` **and** re-key `maka5.gd:40` in the same
  commit. Hard blocker.
- **Jaden** — remove the base HERO Shields **and** repoint all six fusion `extra_usable` gates (plus
  the four consume blocks) in the same commit. Hard blocker; **all FOUR fusions die without it** — every fusion gate looks its ingredients up BY SHIELD EFFECT: `jaden5` Avian+Burstinatrix, `jaden6` Clayman+**Burstinatrix**, `jaden7` Clayman+Bubbleman, `jaden8` Avian+Bubbleman. Clayman keeps its Shield, but `jaden6` still dies on the Burstinatrix half — an earlier draft of this document said "three" and named only 5/7/8, which would have shipped `jaden6` permanently greyed out.
- **Noelle** — gate the trigger's **body**, never its application.
- **Thompson Sisters** — reuse the existing `HARMFUL_USE_TRIGGER` wield handle; do not invent a
  second token.
- **Gogeta** — the instant-strike path must not swap in Bluff Kamehameha, which has no valid target
  without the ticking trigger an instant strike never plants.

### Phase 3 — Per-turn accrual (one mechanism, five consumers)

Madoka, Xanxus, Shokuhou, Soul and Muichiro all want "fires once per round on my own side's turn".
Write the pattern once and check each against the dispatcher's gates. Cadence is verified:
`get_ticking_effects` (`new multiplayer/battle_manager.gd:824-846`) filters `effect.user in team`
against the **acting** team, so a self-owned `TICKING_TRIGGER` fires **once per round**, not on both
players' turns. Never compensate for that with a doubled duration.

Do Madoka first: `abilities/mami6.gd:29-35` is a literal six-line template for it, and Madoka's
change also forces the null-guard fix that all three Soul Gems share.

### Phase 4 — Shared script idioms

Grouped so one decision covers several characters:

- **Bleed/DoT riders** (`2N+1`): Denji, Inosuke.
- **Immediate + ticker** (`2N-1`): Ganta, Jaden Burstinatrix.
- **`COOLDOWN_MOD` by ability name**: Ryuko.
- **Permanent ability swap (`-1`)**: Sasuke.
- **Stack cap** (there is no engine cap — it is a pre-add guard): Broly.
- **Soul Gem accrual + threshold**: Sayaka (and Madoka's threshold from Phase 3).
- **`SKILL_COPY` / Bestow parity**: Tsubaki.

### Phase 5 — The long tail

Isolated literals and one-line deletions with no shared machinery: Nimaiya, Midoriya, Meliodas, Yuji,
Eren's damage, Mash, Broly's heal, Erza, Lucy, Itachi's duration, Katara, Yubel, Rakko, Android 17,
Mavis. Order within the phase does not matter.

### Phase 6 — The data pass (one JSON session)

All 14 cost edits and 5 cooldown edits in `abilities_data.json`, done as **surgical raw text** in one
sitting. Batching matters: it is one file, and a scattered edit history across 19 commits makes the
mixed-indent diff unreviewable.

### Phase 7 — The client data rebuild (ONCE, for everything)

Run the extractors once, at the end, for all ~35 script-touched abilities plus all 19 data-only ones.
Running the pipeline per character rewrites the same two ~18k-line JSONs 40 times.

### Phase 8 — Korra (last, and partly manual)

The only change that **deletes rows**. It must come after Phase 7 because the client rebuild never
prunes, so its client half is hand-work that a later extractor run would not restore and would not
undo either — but sequencing it last means nothing after it can confuse the two.

### Phase 9 — Verification and adversarial review

See [[#Verification]].

---

## The engine work

**One edit. Two call sites. Roughly six lines, duplicated.**

### What already ships

`skill_seal` is a bool on an `Effect` (`scripts/effect_component.gd:80`), consumed by two identical
branches in `abilities/scripts/ability_component.gd`:

```gdscript
for seal in user.effects.get_effects_by_type(EffectType.Type.MARK):
    if seal.skill_seal and (seal.ability_targets.is_empty() or ability_name in seal.ability_targets):
        return false
```
`ability_component.gd:521` (inside `usable`) and `:551` (inside `authoritative_usable`) — verbatim
duplicates.

Shipping example: `abilities/itachi5.gd` (*Totsuka Blade*, "that enemy cannot use skills (this is not
a stun effect)"), read back by `abilities/itachi7.gd:20` and `:36`.

> [!success] "Cannot be ignored" costs **zero** new code
> The seal branch consults **none** of the six Stun escape hatches, each verified individually:
> `ability.stunnable` / the `Unstunnable` class (`character_component.gd:1608`),
> `shrug_off_type(STUN)` (`:1610`), Erza's Clear Heart Clothing (`:1604-1606`), `COST_STUN` (`:1616`),
> the stun's own class filters (`:1621-1629`), and Gunha's application-time veto `on_stun_received`
> (`:165-168` → `character/gunha.gd:24`, which frees the effect outright).

> [!warning] One residual hole, currently empty
> `add_hostile_effect` still drops on `shrug_off_type(effect_type)` (`character_component.gd:2092`).
> `shrug_off_type` **exempts MARK** from the blanket "ignore all non-damage effects" (`:1601`), so a
> true-ignoring character cannot shrug the seal — but a *specific* `ignore_effect_effect(-1, MARK)`
> would eat it. The shipped census of `ignore_effect_effect` targets is 15 STUN, 4 SHIELD, 2 SILENCE,
> 2 BLIND, 1 COUNTER_USE, 1 COUNTER_RECEIVE, 1 COST_MOD — **no MARK**. Genuinely un-ignorable today;
> one authored ability away from not being. Note also that `Condition.can_apply_hostile_effect` still
> runs at `:2095`, so invulnerable enemies are still spared, exactly as under the stun.

### Why not Silence

`Ability.is_silenced_out` (`ability_component.gd:487-488`) is the right *shape* — a pure usability
gate outside the stun system — but it hardwires one class (`not classes.get("Damaging", false)`) and
routes through `is_silenced()`, which still honours `shrug_off_type(SILENCE)`. It cannot be
parameterised per caster. `skill_seal` is the extensible one. (Silence's rewrite is still the design
precedent for "prevents skills, is not a stun" — see [[Cleanse Silence and Effect Removal]].)

### The change

Esdeath needs the branch **as it is**. Yugi needs it to also match by **ability class**, with a
**name exclusion**. Both fields already exist as free lists on `Effect` and are already used this way
by five other systems:

| Field | Declared | Precedent |
| --- | --- | --- |
| `class_targets` | `effect_component.gd:29` | `damage_mod_effect` (`:364-405`), `vulnerability_effect` (`:840-863`), `Character.is_invuln` (`character_component.gd:1657-1668`) |
| `exclusion_targets` | `effect_component.gd:28` | `counter_effect` (`:270`, `:308`), `Character.is_stunned` (`:1621-1629`) |

Sketch, applied identically at `:521` **and** `:551`:

```gdscript
for seal in user.effects.get_effects_by_type(EffectType.Type.MARK):
    if not seal.skill_seal:
        continue
    if ability_name in seal.exclusion_targets:        # named exemptions win outright
        continue
    if not seal.ability_targets.is_empty() and ability_name in seal.ability_targets:
        return false
    if not seal.class_targets.is_empty():
        for cls in seal.class_targets:
            if classes.get(cls, false):               # .get(), NOT classes[cls]
                return false
        continue
    if seal.ability_targets.is_empty():               # unfiltered seal = seal everything
        return false
```

Three notes on that sketch:

- **Use `.get(cls, false)`, not `classes[cls]`.** `is_stunned` (`:1623`) and `is_invuln` (`:1659`)
  both use the unguarded index and would crash on a short or authored class dict.
  `is_silenced_out` (`:488`) uses `.get` — copy that one.
- The class vocabulary is `Ability.CLASS_NAMES` (`ability_component.gd:28-56`), with
  `default_classes()` producing an all-false dict (`:60-63`).
- **Both sites or neither.** `usable()` drives the local skill card; `authoritative_usable()` drives
  the `usable` flag in the wire snapshot. Editing one produces a skill that looks usable and is
  rejected, or the reverse.

### The migration's fallout — decide ONCE, apply to both characters

Everything the `STUN` effect type emits at application (`scripts/character_component.gd:179-187`) that a `MARK` does not:

| Dropped                                                                                             | Consumers                                                                                                                                                               | Decision                                                           |
| --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `wrath_check('stun')` (`:181`)                                                                      | `character/xanxus.gd:28` — **Xanxus is in this patch**                                                                                                                  | Should not trigger for either                                      |
| `check_stun_triggers` → `MISSION_TRIGGER_ON_STUN`                                                   | `horohoro4`                                                                                                                                                             | Should not trigger for either                                      |
| `on_control_effect_received`                                                                        | Tokoyami                                                                                                                                                                | Should not trigger for either                                      |
| `silphymon_check`                                                                                   | Hawkmon                                                                                                                                                                 | Should not trigger for either                                      |
| `check_stun_received_triggers` → `STUN_RECEIVED_TRIGGER`                                            | `hinata4`, `horohoro1`, `horohoro3`, `koro5`, `nel3`, **`shokuhou2`** — Shokuhou is in this patch                                                                       | Should not trigger for either                                      |
| **`check_cancels`** (`:272-283`) — ends `CONTROL_CANCEL` / `CHANNEL_CANCEL` on `is_stunned(source)` | **Enemy channels now survive both seals.** Directly couples this to **Maka** (Witch Hunter sets `channel = true` at `maka3.gd:26/32/38/50`) and **Mavis** (Fairy Heart) | Both should cancel channels/control skills (for Harmful if Yugi's) |
| `remove_on_death = false` (`stun_effect` sets it; `Effect.mark` does not)                           | —                                                                                                                                                                       | Remove both on death                                               |
| Esdeath's own `esdeath5` execute threshold ("+5 per stun, silence, or hostile damage mod")          | Esdeath silently nerfs her own execute range                                                                                                                            | Should not count either for execute range                          |

The channel-breaking row is a **real balance change the owner did not ask for**. It must be decided,
not discovered in playtest.

---

## Exact numbers to write

The duration model is in [[Effects and Durations]]; the two DoT formulas are in [[Trigger Types]].
Both formulas are live in this patch, so this table exists so nobody re-derives them.

> [!danger] The two formulas are different and both appear here
> - **Window that INCLUDES the cast turn** (a manual immediate instance + a ticker) → ticker duration
>   **`2N - 1`**. Used by Ganta, Jaden Burstinatrix, Kurotsuchi, Shokuhou.
> - **Pure delayed rider, no immediate instance** → duration **`2N + 1`**. `3` = one tick next turn,
>   `5` = two ticks, `7` = three. Used by Denji, Inosuke, Rakko. The canonical citation is the
>   shipped comment at `abilities/denji2.gd:21-22`.
>
> Confusing them buys a free extra tick or loses one, with no error either way.

### Durations

| Change | Player text | Write exactly |
| --- | --- | --- |
| Itachi *Kotoamatsukami* | "2 turns" | `counter_effect(..., **4**, ...)` in **both** branches (hostile `COUNTER_USE` **and** allied `COUNTER_RECEIVE`) |
| Itachi Tsukuyomi breadcrumb | "last turn" | stays **2** — genuinely 1 turn, do **not** touch |
| Lucy *Aquarius* base | "2 turns" | `var duration = **4**` |
| Lucy *Aquarius* under Gemini | "3 turns" | `4 + 2 = **6**`; **retarget the `if duration == 4` gate to `== 6`** or the Gemini rider fires on every cast |
| Lucy Gemini damage repeat | "3 turns of damage" *(pending Q4)* | dur `3` → **5** |
| Sasuke *Great Dragon Fire* swap | "permanent" | `ability_swap_effect(5, 2, user, **-1**)` |
| Sasuke *Great Dragon Fire* mark | 3 turns | stays **6** unless Q7 says otherwise |
| Erza *Queen of Fairies* | "1 turn" | dur stays **2**; magnitude `10` → **15** |
| Mavis *Fairy Heart* shield | "3 turns" | `shield_effect(15, **6**)` |
| Denji *Rip and Tear* Bleed | "next turn" | stays dur **3** + `last_turn_only = true` — **already correct, do not "fix"** |
| Inosuke *Double Serrated Slash* Bleed | "following 2 turns" | dur `3` → **5** |
| Ganta *Woodpecker* | "5 Affliction for 3 turns" | manual instance `3` → **5**; `damage_effect(**5**, AFFLICTION, **5**)` (was `(3, AFFLICTION, 9)`) |
| Yugi seal | 3 turns | dur **6** — unchanged from the stun |
| Yugi paired ability swap | should match the seal | `5` → **7** *(pending Q6)* |
| Esdeath seal | 2 turns | dur **4** — unchanged from the stun |
| Jaden base HERO swaps ×3 | 3 turns | `5` → **7** *(pending Q13)* |
| Gogeta un-triggered marker | "the following turn" | `Effect.mark(**2**, ...)` |
| Madoka per-turn stack | permanent | `TICKING_TRIGGER`, dur **-1** |
| Shokuhou *Mental Out* damage | matches the stun | **reuse the local `duration` var** (`3`, or `7` when Exterior is consumed) — a literal silently drops the Exterior extension |
| Soul *Nightmare Sonata* tick | "while active" (3 turns) | immediate + `TICKING_TRIGGER` dur **5**, **or** `damage_effect(10, AFFLICTION, **7**)` with no immediate *(pending Q10)* |
| Tsubaki *Uncanny Sword* copy | Bestow parity | Bestow uses **4** (2 turns); "1 turn" is **2** *(pending Q15)* |
| Muichiro *Obscuring Clouds* | 20% rising 10%/turn | dodge dur **8** and ticker dur **7** both **unchanged**; `dodge_effect(**20**, 8)`, `effect.mag += **10**` → 20/30/40/50 |
| Ryuko *Fiber Lost* cooldown | "1 turn" | `Effect.cooldown_mod(**1**, **-1**, ["Fiber Lost"])`, `set_source(self)` |
| Ryuko *Fiber Lost* damage cap | 10 | `Effect.damage_cap(**10**, 2)` — dur 2 already correct |

### Cooldowns — write the PRINTED value

`start_cooldown` writes `cooldown + 1` and `advance_cooldowns` takes it back the same turn
(`ability_component.gd:641-652`). **Never pre-compensate.** See [[Cooldowns and Energy]].

| Ability | Row | From → To |
| --- | --- | --- |
| Midoriya *One For All* | `midoriya4` | 4 → **2** |
| Eren *Titan Heal* | `eren8` | 1 → **2** |
| Inuyasha *Iron Reaver Soul Stealer* | `inuyasha3` | 0 → **2** |
| Itachi *Kotoamatsukami* | `itachi3` | 1 → **2** |
| Marco *Blue Flames of Resurrection* | `marco1` | 0 → **1** |

Ryuko's is not a cooldown field at all — it is a `COOLDOWN_MOD`, and because of the always-`+1`
bookkeeping a `mag = 1` mod lands the skill on **exactly 1 turn**, not 2.

### Costs — `Energy.Type` is `0=GREEN 1=BLUE 2=WHITE 3=RED 4=RANDOM`

Every edit is index arithmetic on the existing 5-key dict. **No key is ever added or removed**; only
its value changes. Source: `scripts/types/energy.gd`.

| Ability | From | To |
| --- | --- | --- |
| `eren6` Titan Bite | `{0:1, 4:2}` | `{0:1, 4:1}` |
| `eren7` Titan KO | `{4:3}` | `{4:2}` |
| `eren8` Titan Heal | `{4:2}` | `{4:1}` |
| `nagisa1` Killing Intent | `{4:1}` | `{1:1}` *(pending Q20 — replace or add?)* |
| `rob5` Tobu Shigan Bachi | `{2:1, 3:1, 4:1}` | `{2:1, 3:1}` |
| `rob6` Rankyaku Gaicho | `{3:2, 4:2}` | `{3:2, 4:1}` |
| `rob7` Sai Dai Rin: Rokuogan | `{2:1, 3:2}` | `{2:1, 3:1}` |
| `rob8` Tekkai Utsugi | `{3:1, 4:2}` | `{3:1, 4:1}` |
| `sukuna1` Malevolent Shrine | `{4:2}` | `{3:1, 4:1}` |
| `sukuna2` Fire Arrow | `{4:2}` | `{3:1, 4:1}` |
| `mavis3` Fairy Sphere | `{2:2}` | `{2:2, 4:1}` |
| `hisoka3` Texture Surprise | `{3:1}` | `{4:1}` |
| `inosuke3` Spatial Awareness | `{4:1}` | all zeros |
| `broly3` Explosive Wave | `{0:1}` | `{0:1, 4:1}` |

> [!info] Two of these are colour swaps, not pip changes
> `nagisa1` Random → Blue and `hisoka3` Red → Random are the **same pip count**. Nagisa's is a
> tightening (Random is payable with any colour; Blue is not — on a turn with energy but no Blue the
> skill becomes unusable). Hisoka's is a loosening. Neither is a cost increase or decrease
> arithmetically, and the player notes should not imply otherwise.

> [!warning] Rob Lucci's written costs are not the costs players pay
> `rob9`'s passive applies a standing `cost_mod_effect(-1, 5, RED, [all four skill names])` refreshed
> on every alternate-skill use. In the alternate form the effective cost is **one Red below** every
> value in the table. Post-patch that makes *Sai Dai Rin: Rokuogan* — an instant kill — cost **1 White
> alone**. See Q21.

---

## The full change table

Work types: **D** data-only · **S** script · **S+D** script + data · **T** description (text) only ·
**X** structural · **E** new engine primitive.

| Ph | Character | Key | Change | Work | Files | Traps |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Esdeath | `esdeath2` | Mahapadma prevents skills, cannot be ignored, no longer a Stun | X | `abilities/esdeath2.gd` | `:19` `stun_effect(4)` → sealing `mark(4)`; `:26` self-check `STUN` → `MARK` or the self-penalty **double-fires**. Drops 8 STUN side effects — see the fallout table |
| 1 | — | *engine* | Class filter + name exclusion on the seal branch | E | `abilities/scripts/ability_component.gd` | **Both** `:521` and `:551`. `.get(cls, false)`, never `classes[cls]` |
| 1 | Yugi Mutou | `yugi3` | Swords prevents Harmful skills, cannot be ignored, no longer a Stun | E | `abilities/yugi3.gd` | Seal dur **6**. Targets **both teams incl. Yugi** — without the exclusion he can never end his own Swords |
| 1 | Yugi Mutou | `yugi2` | Dark Magician Girl ignores the prevention | S+D | `abilities/yugi2.gd` | Add to `exclusion_targets`. `:21` and `:23` probe `STUN` → retype to `MARK` or the whole "ends Swords + swaps" branch dies silently. `Unstunnable` buys nothing under a seal |
| 1 | Yugi Mutou | `yugi5` | Dark Magician ignores the prevention | S+D | `abilities/yugi5.gd` | Same two edits; `:28` and `:30` |
| 2 | Maka Albarn | `maka3` | Witch Hunter no longer ends on a new Harmful skill | S+D | `abilities/maka3.gd`, `abilities/maka5.gd` | **HARD BLOCKER.** `maka5.gd:40` finds its victim via that exact `HARMFUL_USE_TRIGGER`. Re-key onto the `DAMAGE` effect **in the same commit** or Figure-6 Hunter has zero targets forever |
| 2 | Jaden Yuki | `jaden1` | Avian no longer grants Shield | X | `abilities/jaden1.gd` | The Shield **is** the fusion gate token |
| 2 | Jaden Yuki | `jaden2` | Burstinatrix no longer grants Shield | X | `abilities/jaden2.gd` | Gates `jaden5` **and** `jaden6` |
| 2 | Jaden Yuki | `jaden4` | Bubbleman no longer grants Shield | X | `abilities/jaden4.gd` | Gates `jaden7` **and** `jaden8`. Clayman (`jaden3`) is **not** in the list and keeps its Shield — the four HEROes end up asymmetric |
| 2 | Jaden Yuki | `jaden5/6/7/8` | **Not requested but mandatory:** repoint the fusion gates | X | `abilities/jaden5.gd`, `jaden6.gd`, `jaden7.gd`, `jaden8.gd` | Every `extra_usable` proves its base HERO via `has_effect(<hero>, SHIELD)`. Without this, `jaden5`/`7`/`8` are **permanently unusable**. Recommended token: the base HERO's own `TICKING_TRIGGER` (exists for all four). Also the `SHIELD` lines in the four consume blocks become no-ops |
| 2 | Jaden Yuki | *engine hook* | Base HERO effects no longer removed when their Shield breaks | X | `scripts/character_component.gd:885-886`, `character/jaden.gd` | **Not in `abilities/` at all.** `check_effect_breaking` prefix-matches `"Elemental HERO"` → `break_hero`, which wipes every same-named effect off **every** character (incl. the enemy debuff). Narrow or delete — explicit decision, not a side effect |
| 2 | Jaden Yuki | `jaden2` | Burstinatrix 5 Affliction/turn | S+D | `abilities/jaden2.gd` | The `10` is a bare literal in **two** places (manual first instance **and** the tick) plus the `tick_desc` lambda — that lambda renders on the board itself and is not covered by the description pipeline |
| 2 | Noelle Silva | `noelle2` | Cradle not removed on a new skill while Valkyrie Dress is up | S | `abilities/noelle2.gd` | **Edit site is `noelle2`, not `noelle3`.** Gate the **body** of `remove_trigger` (`:33-37`), never the trigger's application — `noelle1.gd:20` and `noelle5.gd:20` use that trigger as the Cradle's presence handle. Precedent for the guard is `noelle1.gd:21` |
| 2 | Thompson Sisters | `lizandpatty1/2` | Liz and Patty cannot share a target, except Death the Kid | S | `abilities/lizandpatty1.gd`, `lizandpatty2.gd` | Reuse the existing `HARMFUL_USE_TRIGGER` handle (`lizandpatty3.gd:38-39`). Hand-roll `target()` (both call the bare default at `:68`); mirror into `extra_usable` or the button never greys. **Leave the existing Kid double-apply branch (`:24-31`) intact** — it is the exemption. Data bug worth fixing here: `lizandpatty2`'s `target_type` is 4 (SELF) while the script targets allies |
| 2 | Gogeta | `gogeta4` | Unapproachable Stance no longer Invisible | S+D | `abilities/gogeta4.gd`, `abilities_data.json` | **Two independent flags.** `trigger.invisible = true` in the script (wire filter) **and** the row's top-level `"invisible": true` (suppresses the use-flash, `battle_manager.gd:1057`/`:1989`). The row key is not exported to `ability_info.json` |
| 2 | Gogeta | `gogeta4`/`gogeta1` | Un-triggered stance → instant Big Bang next turn | S | `abilities/gogeta4.gd`, `abilities/gogeta1.gd` | **No new primitive** — `wrapup_func` on natural expiry is the `default_counter_timeout` mechanism (~25 users, incl. `gogeta3` in this same kit). **Collision:** `gogeta5.gd:43` targets only characters holding the Big Bang `TICKING_TRIGGER`; the instant path plants none, so the Bluff swap must be skipped. Also `wrapup_func` fires on *forced* removal too — guard on natural expiry if a cleansed stance should not pay out |
| 3 | Kaname Madoka | `madoka5` | +1 Soul Gem stack each turn | S | `abilities/madoka5.gd`, `character/madoka.gd` | Copy `abilities/mami6.gd:29-35` verbatim. **`character/madoka.gd:26-27` has no null guard** (Mami and Sayaka both do) — latent today, a crash **every turn** once a ticker calls it. Fix in the same commit |
| 3 | Kaname Madoka | `madoka5` | Dies at 12 stacks | S | `character/madoka.gd:27` | **Not in the ability or the JSON.** Three text surfaces repeat "15", including the effect's own inline tooltip literal inside `execute()` |
| 3 | Xanxus | `xanxus5` | +1 Scars of Wrath stack on his 2nd and 4th turns | S | `character/xanxus.gd:28-87`, `abilities/xanxus5.gd` | **Edit site is the character file.** "Stacks" is not a counter — it is the three stackable mods at `xanxus.gd:33-51`; refactor into a `grant_wrath_stack()` helper. **Do not key off `battle.current_turn_number`** (counts both sides). A ticker planted at battle start first fires on his turn 2 |
| 3 | Shokuhou Misaki | `shokuhou1` | Mental Out deals 10 Piercing each turn | S+D | `abilities/shokuhou1.gd`, `abilities_data.json` | **Reuse the local `duration` var** — Exterior extends it 3 → 7. A manual first instance implies adding the `Damaging` class, **which also makes Mental Out usable while Silenced** (`ability_component.gd:487`). Real balance consequence, not bookkeeping |
| 3 | Soul Evans | `soul3` | Sonata deals 10 Affliction/turn to all targets + the wielder | S | `abilities/soul3.gd` | **`soul3` is `Action`-classed**, so `battle_manager.gd:1224` suppresses its tick while Soul is stunned — the only one of the five per-turn changes with that property. The wielder can change mid-window, so resolve the wielder **inside** the callback |
| 3 | Soul Evans | `soul2` | Nightmare Wavelength: 20 Affliction to target + 10 to Soul, redirected to the WIELDER if Soul is wielded | S | `abilities/soul2.gd` | **The most novel line in the patch.** Needs a wielder lookup at resolve time, with a fallback to Soul himself when unwielded. Resolve the wielder INSIDE the resolution, not at cast — the wielder can change. Confirm whether the self/ally 10 is `resolve_damage` (ability) or `resolve_effect_damage` (effect); they differ on the ignore-damage gates |
| 3 | Soul Evans | `soul3` | Nightmare Sonata boost to Wavelength reduced 20 → 10 | S | `abilities/soul3.gd` | Separate from the Sonata tick row below. **Known pre-existing bug it collides with:** the +20 is added to `mod_damage`, which only feeds the SELF/ALLY half — it has never boosted the enemy hit. Decide whether "increases by 10" means the enemy hit too (Q11) before writing the number |
| 3 | Soul Evans | `soul1` | Scythe Transformation: damage boost +5 whenever its target takes damage from Soul | S | `abilities/soul1.gd` | A per-damage-instance accumulator — needs a damage hook keyed to Soul as the source, not a per-turn ticker. Closest shipped idiom is a `DAMAGE_RECEIVE_TRIGGER` filtered on the dealer. Note `soul3:19` tests `PERCENT_DR` while `soul1` emits `DAMAGE_REDUCTION` — that branch is already dead code and will mislead whoever edits this |
| 4 | Ryuko Matoi | `ryuko1` | Fiber Lost damage cap 20 → 10 | S | `abilities/ryuko1.gd` | Hardcoded literal at `:21` — `Effect.damage_cap(20, 2)` → `(10, 2)`. **Duration 2 is already correct; do not touch it.** Pairs with the Fiber Lost cooldown row in Phase 4 |
| 3 | Muichiro Tokito | `muichiro3` | 20% dodge, +10%/turn | S | `abilities/muichiro3.gd` | `:20` `dodge_effect(5, 8)` → `(20, 8)`; `:38` `+= 5` → `+= 10`. **Durations already correct — do not touch.** Pre-existing display bug this makes glaring: `dodge_effect` (`effect_component.gd:619-626`) closes over the constructor arg, not `eff.mag`, so the tooltip reads "20%" forever. `dodge_check` (`:1783-1792`) **doubles** this effect vs a Blinded attacker and again under Fifth Form — 50% base becomes a guaranteed dodge |
| 4 | Denji | `denji1` | Rip and Tear 10 damage + 10 Piercing | S+D | `abilities/denji1.gd` | Two bare literal `15`s; no `base_damage` var. **The Bleed rider is already correct** (`dur 3` + `last_turn_only`) — do not touch it. Bot weight `behavior_single_target_damage(context, 30)` should follow to 20 |
| 4 | Hashibira Inosuke | `inosuke1` | 10 Piercing, then 10 Bleed for 2 turns | S | `abilities/inosuke1.gd` | `:19` literal `15` → 10; `:20` Bleed dur `3` → **5** (`2N+1`, **not** `2N-1`). Keep the 4th arg `false` (`use_source`) |
| 4 | Igarashi Ganta | `ganta5` | 5 Affliction for 3 turns | S | `abilities/ganta5.gd` | Three literals. Duration is **5**, not 6 — this ability already implements `2N-1` correctly. **Silent collateral:** `ganta1.gd:19-23` and `ganta3.gd:34-38` define "stacks" as the **count** of live Woodpecker DAMAGE effects, so a shorter duration lowers both. Raising per-tick damage does not compensate — they read count, never magnitude |
| 4 | Ryuko Matoi | `ryuko2` | Fiber Lost gains a 1-turn cooldown under Decapitation Mode | S | `abilities/ryuko2.gd` | Reuse `Effect.cooldown_mod` — no new anything. Teardown is automatic (`full_remove_effect_by_name` is name-keyed). Leave the JSON cooldown at 0. **Scope:** the existing `target_change` and `cost_mod` name **both** Fiber Lost and Life Fiber Synchronization; the owner named only Fiber Lost — do not copy-paste the list (Q18) |
| 4 | Uchiha Sasuke | `sasuke3` | Great Dragon Fire swaps to Kirin permanently | S | `abilities/sasuke3.gd` | One literal: `2` → `-1`. **Guard:** `character_component.gd:161-164` silently frees any `ABILITY_SWAP` whose `source` is not in the applier's `base_abilities`; sourced to `self` it is safe, but any re-sourcing makes the swap vanish with no error |
| 4 | Uchiha Sasuke | `sasuke6` | Kirin +10 vs the marked enemy | S+D | `abilities/sasuke6.gd` | Today it hits **any** target for a flat 40 and checks no mark. Use `target.marked_by("Great Dragon Fire", user)` — the mark's name is the source ability name and `sasuke3` does `set_source(self)`, so the literal string is right |
| 4 | Broly | `broly5` | Legendary Super Saiyan caps at 4 stacks | S+D | `abilities/broly5.gd` | **There is no engine stack cap.** `effect_storage_component.gd:33-38` merges unconditionally. Guard **before** `add_allied_effect` — after the call the merge already happened. The existing ascension swap also fires at 4, so cap and ascension coincide |
| 4 | Miki Sayaka | `sayaka4` | Enraged Slash gives 2 stacks | S+D | `abilities/sayaka4.gd` | `character/sayaka.gd:22` `gain_corruption()` takes **no** arguments — call it twice rather than inventing a parameter, which also keeps the death check firing **between** the two stacks. Keep the `path_name == "sayaka"` guard |
| 4 | Tsubaki Nanatsukasa | `tsubaki3` | Soul Resonance no longer needs the target to use a skill | S | `abilities/tsubaki3.gd` | Move the `copy_effect` + `add_allied_effect` out of `use_trigger` into `execute()`; delete the trigger and the dead callback. **Keep** the wield gate at `:26` — the owner removed the *uses a skill* requirement, not the wield requirement |
| 4 | Tsubaki Nanatsukasa | `tsubaki6` | Uncanny Sword replaces the target's first skill | S | `abilities/tsubaki3.gd` | **`tsubaki6.gd` itself needs no change** — the slot lives in the `copy_effect` call. Hardcode slot **0** (Bestow's model, `mavis2.gd:16-19`). `SKILL_COPY` beats `ABILITY_SWAP` when both contest a slot (`moveset_component.gd:94-107`) |
| 5 | Nimaiya Oetsu | `nimaiya1` | No longer bypasses Invulnerability | S+D | `abilities/nimaiya1.gd`, `abilities_data.json` | **Two independent bypass sources.** `:52` the 3rd positional `true` to `default_hostile_target_function` **and** the `"Bypassing"` string in the row's `classes` — `_skill_pierces_invuln` short-circuits on the class alone, which is what the reflect-retarget path reads. Nimaiya is one of the rare rows carrying both |
| 5 | Itadori Yuji | `yuji5` | Black Flash baseline 15% | S | `abilities/yuji5.gd:20`, `character/yuji.gd:3` | **Two files.** The ability stamps the initial mag; the character file supplies both the reset-on-proc target and the re-seed when the mark is cleansed. Change one and every reset drops it back |
| 5 | Itadori Yuji | `yuji5` | +20% per True damage | S | `character/yuji.gd:47` | The increment is in the **else** branch — it fires only on a **failed** roll. And "whenever he deals True damage" is **not** an engine hook: `check_black_flash` has exactly two callers, both in `yuji1.gd` (Q1, Q3) |
| 5 | Itadori Yuji | `yuji3` | Consume Finger +15% minimum **and** current | S | `abilities/yuji3.gd:24-29` | The minimum bump is already 15; what is missing is an explicit `flash.mag += 15`. Today it only raises current **up to** the floor. `yuji3` is the only one of the three sites with **no 100 clamp** |
| 5 | Itadori Yuji | `yuji2` | Combat Awakening +25% current | S | `abilities/yuji2.gd:31` | `+= 20` → 25. Clamp already present. All three description surfaces disagree with the code **today** |
| 5 | Midoriya Izuku | `midoriya4` | One For All no longer grants Stun immunity | S | `abilities/midoriya4.gd` | Delete the `stun_ign` construction (`:26-29`) and its `add_allied_effect` (`:35`). Self-contained. **`allmight5` is also named "One For All"** — no name-driven replace |
| 5 | Meliodas | `meliodas3` | No longer ignores negative non-damage effects | S | `abilities/meliodas3.gd` | Delete only the `ignore_non_damage_effect(4)` block. **Leave the `mark(4)`** — that is the real "cannot use skills" lockout, enforced via `extra_usable` in `meliodas1/2/4`. Removes a blanket shrug for the whole charge window; the stored-damage trigger is finite and therefore **cleansable by default** |
| 5 | Eren Yeager | `eren6` | Titan Bite 40 damage | S | `abilities/eren6.gd:3` | Hardcoded `base_damage = 65`. Bot hint `behavior_single_target_damage(context, 135, 0.6)` is tuned to a 65 nuke |
| 5 | Mash Kyrielight | `mash2` | Around Round Crash 15 damage | S+D | `abilities/mash2.gd:2` | Hardcoded `base_damage = 25`. **The `abilities_data.json` description already says 15** — a reviewer checking the JSON will mark this done while the runtime is unchanged. Also update the bot weight `(context, 35, 1.1)` |
| 5 | Broly | `broly4` | Powered Shell Protect heals 5/stack | S+D | `abilities/broly4.gd:3` | Hardcoded `heal_per_stack = 10`. With the 4-stack cap the max heal drops from uncapped to a hard **20 HP** — three Broly nerfs in one patch |
| 5 | Erza Scarlett | `erza4` | Queen of Fairies 15 Shield | S | `abilities/erza4.gd` | Hardcoded `shield_effect(10, 2)`. **Do not touch** the `cooldown_mod(-1, -1, ["Queen of Fairies"])` rider or the `battle.roll(0, 2)` requip — the roll is seeded RNG and reordering it changes replays. Row has **no** `description` key |
| 5 | Lucy Heartphilia | `lucy1` | Aquarius 2 turns / 3 under Gemini | S | `abilities/lucy1.gd` | **Highest-risk numeric edit in the patch.** `if duration == 4:` three lines below becomes true for the *non*-Gemini case once the base is 4. Make it `== 6` or better a `var geminied` bool |
| 5 | Uchiha Itachi | `itachi3` | Kotoamatsukami lasts 2 turns | S+D | `abilities/itachi3.gd` | **Both** branches (`COUNTER_USE` and `COUNTER_RECEIVE`) are dur 2 → **4**. Leave the `mark(2)` breadcrumb `itachi2` reads. Scope: `itachi4` permanently replaces this below 50 HP, so both Itachi changes govern only the pre-Susanoo phase |
| 5 | Katara | `kitara2` | Ice Deflection usable on any ally | S+D | `abilities/kitara2.gd`, `abilities_data.json` | `target_type` 4 (SELF) → 0 (SINGLE). **No engine change** — `reflect_check` already reads `REFLECT_RECEIVE` off each of the attacker's targets. **Gotcha:** `default_self_target_function` passes `bypassing = true`; the allied one does not, so an isolated Katara may no longer be able to protect **herself**. Bot hint is `behavior_self_panic_button` and will never pick an ally |
| 5 | Mavis Vermilion | `mavis4` | Fairy Heart: 15 Shield, no Invulnerability | X | `abilities/mavis4.gd` | Swap `invuln_effect(6)` for `shield_effect(15, 6)`. **The `mark(6)` lockout is deliberate** (a mark, not a stun, per the in-file comment) and `mavis1/2/3/6` gate `extra_usable` on it. Structural because the invuln was the only thing protecting a character locked out for 3 turns |
| 5 | Mavis Vermilion | `mavis4` | No longer requires a living ally | S | `abilities/mavis4.gd:48` | One-line. **Do not apply the same edit to `mavis2.gd:24`**, which has an identical-looking clause and is not in this patch. Delete the dedicated dim-gray `split_desc` line |
| 5 | Yubel | `yubel6` | No longer permanently Isolated | S+D | `abilities/yubel6.gd` | Delete the `isolate(-1)` block. Blast radius: `is_isolated()` gates Helpful targeting **and both healing entry points**, so she becomes a legal heal/shield/buff target for the first time. Does **not** affect `has_targetable_living_ally` |
| 5 | Yubel | `yubel3` | Terror Incarnate needs 3 stacks | S+D | `abilities/yubel3.gd` | Hardcoded `>= 2`. The reflect itself is engine-side (`_capture_reflect`); `yubel3.trigger()` is an empty stub — do not go looking for the logic in the ability |
| 5 | Yubel | `yubel5` | Ultimate Nightmare needs 6 stacks | S+D | `abilities/yubel5.gd` | Hardcoded `>= 5`. `execute()` opens by wiping all Terror Incarnate stacks, so the ladder becomes 3 to arm, 6 to upgrade, and the upgrade zeroes the counter |
| 5 | Android 17 | `seventeen5` | Bonus energy only on a 3-energy skill | S+D | `abilities/seventeen5.gd` | Move the existing `gain_random_energy()` inside the existing `if total_cost >= 3:` branch. **`used_skill.cost()` is the RESOLVED cost** — it already includes this passive's own +1 Random per stack, and any enemy cost-increase, so the threshold is partly self-fulfilling (Q23) |
| 5 | Yumiya Rakko | `rakko2` | While free, only targets enemies Shattered by Wave Tracking | S | `abilities/rakko2.gd` | **Currently unreachable:** `rakko5` (Wave Tracking) is an explicitly-unimplemented stub, so nothing is ever Shattered by it and the free condition can never hold (Q25). Factor the free test into **one** helper shared by `cost()` and `target()`, but do **not** route targeting through `cost()` — it short-circuits to `server_cost` on a passive client |
| 6 | Eren Yeager | `eren6/7/8` | Costs; Titan Heal cooldown | D | `abilities_data.json` | See the cost and cooldown tables |
| 6 | Shiota Nagisa | `nagisa1` | Killing Intent costs 1 Blue | D | `abilities_data.json` | Colour-lock, not a pip increase (Q20) |
| 6 | Rob Lucci | `rob5/6/7/8` | Four cost reductions | D | `abilities_data.json` | Rows have **no** `description` key. `rob9`'s standing −1 Red makes the effective costs lower than written (Q21). `rob7`'s `classes` array mixes tabs and 6-space indent **within one array** |
| 6 | Ryomen Sukuna | `sukuna1/2` | 1 Red + 1 Random | D | `abilities_data.json` | `sukuna4` can grant the Shrine state without paying `sukuna1`'s cost |
| 6 | Mavis Vermilion | `mavis3` | Fairy Sphere +1 Random | D | `abilities_data.json` | — |
| 6 | Hisoka Morow | `hisoka3` | Texture Surprise 1 Random | D | `abilities_data.json` | Preserve the row's `important` and `invisible` keys |
| 6 | Hashibira Inosuke | `inosuke3` | Spatial Awareness free | D | `abilities_data.json` | Becomes a 0-cost, cd-3, Uncounterable AoE counter-strip that also self-buffs; nothing else in the kit gates it |
| 6 | Broly | `broly3` | Explosive Wave +1 Random | D | `abilities_data.json` | A cost **increase** (1 → 2 energy) |
| 6 | Midoriya / Inuyasha / Itachi / Marco | `midoriya4`, `inuyasha3`, `itachi3`, `marco1` | Cooldowns | D | `abilities_data.json` | Printed values. `inuyasha3` has no cached description **and** `describe()` returns `""` — zero description work. `marco1`'s `classes` array is mixed-indent |
| 7 | Kurotsuchi Mayuri | `kurotsuchi2` | Description states 3 turns | T | `abilities/kurotsuchi2.gd` + pipeline | `describe()` and the JSON **already** say 3 turns; only `split_desc()` lacks it — and `split_desc` is what the panel renders. **Duration audit:** the energy half is correct (`2*3-1 = 5`), but the reveal `mark(5)` wants **6** for a literal 3 turns. Flag, do not silently change (Q24) |
| 7 | Jaden Yuki | `jaden5/6/8` | Flame Wingman / Rampart Blaster / Mariner state durations | T | `abilities/jaden5.gd`, `jaden6.gd`, `jaden8.gd` + pipeline | Know the truth before writing it: their ticking triggers are **permanent (`-1`)** and they grant **no Shield at all**, despite the text promising 45. So "specify durations" resolves to "say permanent" and delete a phantom Shield — unless the owner meant to *add* a real duration (Q14) |
| 8 | Korra | `korra9/10/11` | Reduce to 8 skills | X | `abilities_data.json`, `webclient/app/ability_info.json`, `ability_split.json`, `ability_icons.json`, `deploy/*` | **Partly done, server-only.** See [[#Korra]] |

---

## Client data

The pipeline, its ordering and its traps are documented in full in [[Changing Ability Text]]. What is
specific to *this* patch:

### Who needs it

| Bucket | Count | Why |
| --- | --- | --- |
| Every cost and cooldown change | 19 | `ability_info.json` carries its own `cost`/`cooldown` copies |
| Every script change whose `describe()`/`split_desc()` moves | ~35 | The client never reads the `.gd` |
| Pure description changes | 4 | `kurotsuchi2`, `jaden5`, `jaden6`, `jaden8` |
| Korra's row deletion | 3 rows | **Manual** — the rebuild never prunes |

### The sequence, once, at Phase 7

```bash
# 1. .gd split_desc() edits are already done
# 2. abilities_data.json "description" cache patched as RAW TEXT
godot --headless --path . --script res://extract_split_desc.gd     # -> ability_split.json
godot --headless --path . --script res://extract_ability_info.gd   # MUST run second; reads the split
cp webclient/app/ability_info.json webclient/app/ability_split.json deploy/
```

### Three traps specific to this patch

> [!warning] Rows with no `description` key render from `split_desc` alone
> Verified absent on `rob5`, `rob6`, `rob7`, `rob8`, `erza4`, `inuyasha3`, `yugi2`, `yugi3`, `yugi5`,
> `tsubaki3`, `tsubaki6`, `esdeath2`, `inosuke1`, `inosuke3`. Do not patch a cache that is not there,
> and do not add one.

> [!warning] Description precedence silently preserves stale text
> When `abilities_data.json`'s value is empty, `extract_ability_info.gd:39-42` falls back to the
> **previous** `ability_info.json` value. Blanking a cache does not clear it.

> [!danger] The rebuild is purely additive and NEVER prunes
> `extract_ability_info.gd:70-74` carries forward every key the new pass rejected. Confirmed:
> `korra9`, `korra10` and `korra11` are present in `abilities_data.json`, `webclient/app/ability_info.json`,
> `ability_split.json`, `ability_icons.json` **and** `deploy/ability_info.json`. Deleting the server
> rows will not remove them from the client.

### Not covered by any pipeline

- **Effect tooltips** are baked live per snapshot from the `.gd` — a script edit is the whole job. But
  `jaden2`'s `tick_desc` lambda renders "10 Affliction damage each turn" **on the board**, so missing
  it leaves the board contradicting the skill panel.
- **Bot behaviour weights.** `mash2` `(context, 35, 1.1)`, `eren6` `(context, 135, 0.6)`, `denji1`
  `(context, 30)`, `broly4` `(context, 25)`, plus `Ability.bot_damage_hint()`'s automatic read of
  `base_damage`. A dozen damage nerfs here leave the trained policy over-valuing the nerfed skill.
  See [[Bots and Training]].

---

## Verification

The standing loop is [[Verification Playbook]]. Its step 3 is not optional here:

> [!danger] Reversal test, by hand, every time
> Put the buggy behaviour **back by hand**, run the probe, **watch it go red**, then restore the fix
> by hand and watch it go green. Record what the reverted run printed. A probe that passes both with
> and without the change is not a probe.
>
> **Never `git checkout` / `restore` / `reset` / `stash`** to do the reversal — this repo has a large
> uncommitted working tree. See [[Hard Rules and Guardrails]].

> [!warning] The compile check proves nothing about this patch's dominant failure mode
> A broken presence-handle lookup compiles, loads and renders. It just greys a button forever. Every
> phase below therefore has a **targeted usability probe**, not just a build.

| Phase | Probe | Must show |
| --- | --- | --- |
| 1 | Seal probe on a real `BattleManager` | A sealed enemy's Harmful skills report `usable == false` from **both** `usable()` and `authoritative_usable()`; a non-Harmful skill is still usable under Yugi's seal; Esdeath's unfiltered seal block **Assert the POSITIVE case FIRST — a Harmful skill must report `usable == false`.** The negative-only form passes against a seal that does nothing at all, since under a no-op seal everything is usable; it is exactly the vacuous-assertion shape this project has been bitten by before.s everything; an `Unstunnable` skill is **not** exempt; Dark Magician and Dark Magician Girl **are**; Yugi can still end his own Swords. Controls: an unsealed character, and a Stun for contrast |
| 1 | Channel regression | Cast Maka's Witch Hunter, then apply the seal — the channel **survives** (it broke under the stun). This asserts the decided answer, whichever way it went |
| 2 | Maka | Figure-6 Hunter has **≥1 valid target** after Witch Hunter lands. Control: no Witch Hunter → zero targets |
| 2 | Jaden | For **each** of the four fusions: cast its two components, confirm the fusion lights up **and** that using it consumes both components. Four separate assertions, not one |
| 2 | Noelle | Sea Dragon's Roar and Point-Blank still find their Cradle rider while Valkyrie Dress is up, **and** the Cradle survives the target using a skill |
| 2 | Thompson Sisters | Liz on ally A → Patty cannot target A; Patty can target B; **both** land on Death the Kid; the skill greys out when no legal target remains |
| 2 | Gogeta | Un-triggered stance → Big Bang strikes instantly next turn **and** Bluff Kamehameha is not swapped in with zero targets. Control: triggered stance → normal channel |
| 3 | Per-turn probe | Assert the **offsets** each accrual fires on, not the count. One tick per round, on the owner's side. Madoka's ticker must not crash when the mark is absent |
| 3 | Shokuhou | Mental Out's damage window matches the stun window **with Exterior consumed** (7), not just without it (3) |
| 4 | DoT probe | Inosuke: exactly **two** delayed Bleed ticks, none on the cast turn. Ganta: **three** Affliction instances total, first one immediate. Assert offsets |
| 4 | Ryuko | Fiber Lost is on cooldown for exactly **1** turn under Decapitation Mode, and **0** without it |
| 4 | Sasuke | Kirin still present after the old 2-duration window would have expired |
| 4 | Broly | A 5th Legendary Super Saiyan attempt does not raise `stack_count()` past 4 |
| 5 | Nimaiya | An invulnerable enemy takes **zero** from Unblockable Strike — via the normal path **and** via a reflect-retarget |
| 5 | Lucy | The Gemini damage repeat does **not** fire on a non-Gemini cast. This is the specific `== 4` regression |
| 5 | Katara | Ice Deflection protects an ally; **and** Katara can still protect herself while isolated (or the answer to Q19 is recorded as "no") |
| 7 | Client data | Diff the regenerated split against the `desc` already in `ability_info.json` and **revert unrelated drift**. A full regen surfaces pre-existing drift on abilities this patch never touched |
| 8 | Korra | Char-select shows **8** skills, not 11 |
| 9 | Standing gates | Full `training/tests/*_probe.tscn` suite · orphan delta ≤ 25 · a 40-match roster sweep grepped for `SCRIPT ERROR` · every touched client file byte-identical in `deploy/` |

> [!warning] GDScript runtime errors log and continue
> A null dereference produces a dead passive plus stderr spam, **not** a failed probe. Anything in
> this patch that could null-deref (Madoka's ticker above all) must be verified by **grepping stderr**,
> not by asserting a return value.

---

## Open questions

Every one is phrased so a yes/no or a single number closes it. Nothing in Phase 1 should start before Q5–Q9 are answered.

### Itadori Yuji

1. Does the Black Flash chance still **reset to the minimum on a successful proc**? (Today the +chance lives only in the failed-roll branch and a success snaps back.) — yes, but it should track any modifications to the minimum
2. "Consume Finger increases minimum **and** current by 15%": if current is already sitting at the
   minimum, is the net gain to current **15 or 30**? the net gain should only ever be 15; if the current is 20% and the minimum is 20%, then the current and minimum should become 35%
3. Should `check_black_flash` stay wired only to Divergent Fist, or become a genuine any-True-damage hook? (The latter is a new engine hook, not a number change.) — stay
4. Is **100%** still the ceiling? (`yuji3` has no clamp today; `yuji2` and `character/yuji.gd` clamp at different operators.) — yes

### The seal (Yugi + Esdeath) — blocks Phase 1

5. Which of the eight dropped STUN side effects must be **re-emitted**? Answer per row of the fallout table above, once, for both characters. The load-bearing one: should Mahapadma and Swords still **break enemy channels**? — *yes*, other questions answered
6. Does the prevention keep the stun's current length, and if so should Yugi's paired ability swap go **5 → 7** so it stops reverting a turn early? — *yes*
7. Is the exemption a **name** list (Dark Magician + Dark Magician Girl specifically) or a rule ("all
   of Yugi's own skills")? — *names*
8. Does each seal keep its current scope? Mahapadma currently hits **all** characters including
   Esdeath's own allies; Swords hits both teams including Yugi himself. — *keep*
9. Is Esdeath's own **self-penalty** still a Stun, or does she take the new prevention too? — *prevention*

### Damage and duration

10. Soul: does *Nightmare Sonata*'s new 10 Affliction tick land on the **cast turn**? (Decides
    immediate + dur 5 versus dur 7, and whether the window totals 30 or 20.) — *yes*
11. Soul: *Nightmare Wavelength*'s 10 to the wielder — **instead of** Soul (Soul takes 0), or split?
    The code splits today; the owner's word is "instead". — *instead*
12. Soul: *Scythe Transformation*'s +5 — per damage **instance**, or once per turn? — *instance*, it should just apply another +5 damage mod
13. Jaden: with the Shield gone, what defines how long the base HEROes last? The three timers disagree today (Shield 6, ticker 5, swap 5). Make all three a clean 3 turns (**swap → 7**)? — do not change any of the current timers, they should all be functioning as intended
14. Jaden: "now specify durations" for Flame Wingman / Rampart Blaster / Mariner — write down
    **"permanent"** (what the code does), or **add** a real finite duration (a behaviour change)? —
    *write*
15. Tsubaki: how long does Uncanny Sword occupy the ally's first slot? Bestow uses **4** (2 turns);
    "1 turn" is **2**. — *1 turn*
16. Lucy: does "2 turns / 3 turns" cover only the team Damage Reduction, or also the AoE damage repeat? *Also the damage repeat*
    And should the non-Gemini version now gain the repeat? — The non-Gemini version should last 2 turns, the Gemini version should last 3 turns
17. Ganta: is the knock-on nerf intended? A shorter Woodpecker lowers the concurrent-instance count that `ganta1` (+5 damage/stack) and `ganta3` (usability HP threshold) both read. — *yes*
18. Ryuko: does the Decapitation-Mode cooldown apply **only** to Fiber Lost, or also to Life Fiber
    Synchronization (which the existing mods both name)? — *only*
19. Katara: with Ice Deflection targeting allies, must she still be able to protect **herself while
    isolated**? (The self-targeting helper bypasses targetability; the allied one does not.) — *no*, and the skill should also gain the Helpful class

### Costs and economy

20. Nagisa: "cost increased to 1 Blue" — does the Blue **replace** the Random (total stays 1 pip,
    colour-locked), or is it **in addition**? — *replace*
21. Rob Lucci: are the four new costs what players should **pay**, or the raw values before `rob9`'s
    standing −1 Red? As written, Sai Dai Rin: Rokuogan becomes **1 White** for an instant kill. —
    I'm not sure as to the distinction, but your as written is correct. If rob9's additional -1 Red is active, Sai Dai Rin: Rokuogan costs 1 White.
22. Hisoka: Texture Surprise already costs exactly 1 pip. Is the intent purely to make it
    colour-flexible, or was a genuine reduction to **0** meant? — My description here was explicit; it cost 1 Red energy, and it's new cost is 1 Random (This is considered a cost "reduction" in a balance sense because Random costs are less stringent than specific colored costs)
23. Android 17: "a skill costing 3 energy" — **exactly 3 or 3+**? And measured on the **base** cost or
    the **resolved** cost (which already includes this passive's own +1 Random per stack)? — 3+

### Structural

24. Kurotsuchi: the reveal mark runs 5 while the energy tick runs a full 3 turns. Correct the mark to
    **6** so "3 turns" is literally true, or is a description-only edit genuinely all that is wanted?
    —*description only*
25. Rakko: Wave Tracking is an unimplemented stub, so this change is inert and untestable until that passive exists. Ship it as forward-compatible dead code, or hold Rakko out of the patch? — Rakko's passive works, it just isn't handled in the script itself; the triggering happens in character_component.gd
26. Jaden: repointing the six fusion gates to the base HERO's `TICKING_TRIGGER` is **required work the owner did not list**, and Jaden is unshippable without it. Confirm it is in scope. — *yes*
27. Jaden: should the engine hook at `scripts/character_component.gd:885-886` be **deleted outright**, or narrowed to still tear down Mudballman? — *narrow*, it should also make sure to clean up Clayman
28. Sasuke: Kirin is single-use and self-marks. With a permanent swap, once Kirin is spent slot 2 is
    occupied **forever** by an unusable skill and Sasuke plays on with 3 skills. Intended? — *no*, Kirin should swap back to Great Dragon Fire once used, but remain as Kirin until used
29. Sasuke: should the Great Dragon Fire mark also become permanent (currently 3 turns) so Kirin's +10 stays reachable? — *yes*
30. Madoka: with +1 stack per turn, `madoka4` currently gates on `mag >= 7` — roughly half the old 15 ceiling. Rescale it to **6**, or leave at 7? — 7
31. Madoka / Mami / Sayaka: the Soul Gem marks are `cleansable = false` but do **not** set
    `system = true` / `remove_on_death = false`, so a **revive silently deletes the passive** for the
    rest of the match. Harden all three in this pass? — if revived, the marks should be removed, but the passive itself should remain (the ticking and tracking)
32. Xanxus: "1 stack" — Scars of Wrath stores nine *named* categories, not a counter. Does a free
    stack grant only the three generic bonuses, or also **unlock one category**? If the latter, which?
    — *generic*, can potentially name them with unique categories like "2nd turn" and "4th turn", etc
33. Xanxus: "his 2nd and 4th turns" — counted from match start or from his first acting turn? And does the count pause while he is dead, banished or stunned? — acting*, *pause: no*
34. Meliodas: with the blanket ignore gone, should Revenge Counter's accumulated charge be explicitly protected from cleanse? It is a finite trigger and therefore **cleansable by default**, so the payoff can now be erased. — *yes*
35. Maka: with the break trigger gone, Witch Hunter has no enemy-side counterplay left — it ends only via the channel cancel. Intended, or should another exit condition replace it? — *intended*
36. Nimaiya: strip the cosmetic `"Bypassing"` **class** from the row as well as the targeting flag? It
    is load-bearing on the reflect-retarget path. — *yes*
37. Shokuhou: does the 10 Piercing land on the **cast turn**? If yes, Mental Out needs the `Damaging`class — **which also makes it usable while Silenced**. — *yes*
38. Sayaka: should the death check run **between** the two stacks (dying at 10 rather than reaching
    11)? And the client text says 12 while the code kills at 10 — which is correct? — Sayaka should die once she reaches the stack count, but she should never be visibly AT that stack count (because she'd die once she reached it). Correct the code so it kills at the correct count from the split_desc
39. Broly: at exactly 4 stacks, is the 4th granted and further ones refused (max +20 damage)? And
    since the ascension swap already fires at 4, do cap and ascension deliberately coincide? — *yes*
40. Yugi/Broly/Xanxus asymmetry: Broly is being **capped** at 4 stacks while Xanxus's three permanent per-stack modifiers stay uncapped and **gain a second faucet** in the same patch. Deliberate? — *yes*
41. Eren: Titan Bite 65 → 40 is a 38% cut. Confirm 40 is the final figure and not 40 on top of some
    scaling. — *yes*
42. Mash: the cached description also promises a "costs 1 less Random after A Knight That Protects" discount that is **implemented nowhere**. Delete the claim, or implement it? — *implement*

### Korra

Reported, not fixed. **The change is partly done, and the done half is server-only.**

`character_ability_counts.json` already reads `korra: 8` (an **uncommitted** working-tree edit; `git
HEAD` says 11). `Movesets.from_skill_count` builds `korra1`..`korra8` only, so `korra9`, `korra10` and
`korra11` are never instantiated server-side.

> [!danger] Dropping the PASSIVE is categorically different from dropping an active
> `korra11` *Korra Avatar State* is a **Passive**, and passives execute only through
> `startup_passives` (`scripts/character_component.gd:284-287`), which iterates the **built** moveset.
> Cutting the count to 8 did not hide a button — it **deleted the Avatar State mechanic outright**,
> silently, with no code removed. `korra9` (Energybending) and `korra10` (Gate Open) were only ever
> reachable through `korra11`'s own `ability_swap_effect(8, 2)` / `(9, 3)` — slot indices that do not
> exist in an 8-slot `base_abilities` — so they are doubly unreachable and would index-error even if
> the passive fired.

Still outstanding, all verified present:

- All three rows remain in `abilities_data.json`.
- All three remain in `webclient/app/ability_info.json`, `ability_split.json`, `ability_icons.json`
  **and** the `deploy/` mirrors — and `app.js:2351-2358` derives a character's kit purely from
  `ability_info.json` key prefixes, so **char-select still shows players three skills that cannot
  exist in a match**.
- `scripts/movesets.gd:162-187` `korra_moveset()` still loads `res://abilities/korra1..korra11.tscn`
  — files that do not exist. Zero callers. Dead, but landmine-shaped.
- `korra11.gd`'s `split_desc` still advertises the Avatar State.

No `korra1`-`korra8` script references Energybending, Gate Open or Avatar State, so removing the rows
breaks nothing on the live 8.

**43. Is the Avatar State supposed to be gone, or was the count reduced to 8 as a temporary hide?** —
*gone*
**44. If gone: delete the three rows from `abilities_data.json` and hand-prune the client JSONs, or keep them on disk as disabled?** — *delete*

---

## Risks

Ordered by how badly and how quietly each fails.

> [!danger] 1 — Nine presence-handle lookups, all failing silently
> Each of these keys a sibling skill off the exact effect this patch deletes or retypes. The failure
> is a permanently greyed button or a dead branch — **no error**, passes compile and a casual smoke
> test.
>
> | Site | Reads | Broken by |
> |---|---|---|
> | `maka5.gd:40` | `HARMFUL_USE_TRIGGER` | Maka's change. **Hard blocker** |
> | `noelle1.gd:20`, `noelle5.gd:20` | `ACTION_USE_TRIGGER` | The naive Noelle implementation |
> | `yugi2.gd:21`/`:23`, `yugi5.gd:28`/`:30` | `STUN` | Yugi's retype |
> | `esdeath2.gd:26` | `STUN` | Esdeath's retype — self-penalty **double-fires** |
> | `jaden5/6/7/8` `extra_usable` | `SHIELD` | The Shield removal. **Hard blocker** |
> | `gogeta5.gd:43` | `TICKING_TRIGGER` | The instant-strike path |
> | `lizandpatty3.gd:38-39`, `5.gd:28`, `6.gd:30` | `HARMFUL_USE_TRIGGER` | This *is* the handle the new rule must read — reuse it |

> [!danger] 2 — Two changes that MUST be a single commit
> Ship either half alone and a skill becomes permanently unusable with no error: **Maka** (trigger
> deletion + `maka5` re-key) and **Jaden** (Shield removal + four fusion gate repoints). These are the
> two places where a per-character workflow actively breaks the game.

> [!danger] 3 — Lucy's `if duration == 4`
> The single most likely numeric regression. Raising the base duration from 2 to 4 makes a gate three
> lines below silently true for the *non*-Gemini case, granting the Gemini damage repeat on **every**
> cast. No error, no log — just a quietly much stronger skill.

> [!warning] 4 — The seal changes six behaviours at once, for two characters
> If the STUN→MARK fallout is decided per character rather than once, Yugi and Esdeath end up with
> different semantics behind the same player-facing sentence — exactly what a shared primitive is
> supposed to prevent. Channel breaking is the one with real gameplay weight.

> [!warning] 5 — Jaden's `break_hero` blast radius
> `full_remove_effect_by_name` is called on **every** character for the broken HERO's name, so it
> currently strips the *enemy-side* Avian debuff and Rampart shatters too. Narrowing or deleting the
> hook changes enemy-side state, not just Jaden's. Regression-test against a live enemy team, not a
> solo probe.

> [!warning] 6 — Compounding changes on one character
> **Broly** takes three nerfs at once (cost 1 → 2 energy, a 4-stack cap, and 10 → 5 HP per stack —
> together dropping the max heal from uncapped to a hard 20). **Mavis** loses Invulnerability *and*
> the living-ally requirement, so a solo Mavis can self-lock for 3 turns with no protection.
> **Yubel** gains ally healing/shielding for the first time while both her stack gates rise. Each pair
> should be signed off together, not separately.

> [!warning] 7 — Two constants that live in two files each
> Yuji's baseline chance (`yuji5.gd:20` stamps the initial mag; `character/yuji.gd:3` supplies the
> reset target **and** the re-seed after a cleanse) and Madoka's death threshold
> (`character/madoka.gd:27` is authoritative while `madoka5.gd` repeats "15" three times, including
> the effect's own inline tooltip literal). Change one and not the other and the value silently
> desyncs.

> [!warning] 8 — `abilities_data.json` formatting
> Organic mixed indentation **down to individual array elements** — `marco1`'s and `rob7`'s `classes`
> arrays mix tab-indented and 6-space-indented entries within a single array. Any JSON round-trip or
> format-on-save rewrites thousands of unrelated lines and buries the patch. All ~25 JSON edits are
> surgical raw text, brace-scoped to the ability's own block.

> [!warning] 9 — Verification will be misled by stale caches
> `mash2`'s cached description **already** reads 15 and `kurotsuchi2`'s already says 3 turns, while
> both scripts are unchanged. A reviewer spot-checking the JSON will mark them done. Verify against
> the `.gd` and a live battle.

> [!warning] 10 — Two abilities named "One For All"
> `midoriya4` and `allmight5`. Only Midoriya changes. Any name-driven search-and-replace across
> `abilities_data.json` or the client JSONs hits All Might's passive too.

---

## Known before this patch

Recorded in Phase 0 so the post-patch diff is honest and nobody attributes these to the patch.

| Where | What is already wrong |
| --- | --- |
| `yuji1/2/3/5` | Four-way drift: `describe()`, `split_desc()`, the code and the cached description all disagree, in different directions |
| `meliodas3` | `describe()` describes an **entirely different ability** (a reflect counter) |
| `sasuke6` | Cached description promises a mark check and 50 damage; the script deals a flat 40 and checks nothing |
| `sasuke3` | `split_desc` says "on the third turn… for 1 turn"; the cache says "on the second turn". Both wrong |
| `mash2` | Cached description already reads 15; also promises a cost discount implemented nowhere |
| `soul3:19` | Tests `PERCENT_DR` while `soul1` emits `DAMAGE_REDUCTION` — the branch is **dead code** |
| `soul2` | Nightmare Sonata's +20 is added to `mod_damage`, which only feeds the **self/ally** damage. It has never boosted the enemy hit |
| `jaden1/2/3/4/5/6/8` | Base HEROes claim "permanently gains 25 Shield" (script: 15 for 3 turns); fusions claim 45 Shield (script: none) |
| `yugi3`, `jaden1`, `jaden2`, `jaden4` | Four ability swaps at duration 5 (2 turns) against 3-turn effects — all un-swap a turn early. This patch rewrites all four lines anyway: fix all four or leave all four |
| `noelle3`, `soul3` | Mark/swap durations of 5 against 3-turn windows |
| `sayaka5` | Cached description says she dies at 12; `character/sayaka.gd:26` and `split_desc` say 10 |
| `ganta5` | Cached description omits "or receives" — the ability applies both a use- and a receive-trigger |
| `effect_component.gd:619-626` | `dodge_effect`'s description closes over the constructor arg, not `eff.mag`, so a mutated dodge displays its original percentage forever |
| `lizandpatty2` | `target_type` 4 (SELF) in data while the script targets allies |
| `eren7` | Declares `var base_damage = 30` and then passes the literal 30 — the var is dead. **Leave it**; a drive-by cleanup muddies the diff |
| `rakko5` | *Wave Tracking* is an explicitly-unimplemented stub whose `execute()` is a comment ending in `pass` |
| `scripts/movesets.gd:162-187` | `korra_moveset()` loads eleven `.tscn` files that do not exist. Zero callers |

---

## Related

[[Patch Notes]] · [[Patch 2026-08-02]] · [[Effects and Durations]] · [[Trigger Types]] ·
[[Cooldowns and Energy]] · [[Cleanse Silence and Effect Removal]] · [[Targeting and Main Target]] ·
[[Changing Ability Text]] · [[Data Files and the Deploy Mirror]] · [[Verification Playbook]] ·
[[Hard Rules and Guardrails]] · [[Traps That Have Bitten Us]] · [[Bots and Training]]
