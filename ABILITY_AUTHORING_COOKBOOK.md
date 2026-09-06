# Anime Arena — Ability & Character Authoring Cookbook

> A pattern cookbook for turning a **readable ability description** into a working `.gd` file fast.
> Companion to [CODEBASE_CHEATSHEET.md](CODEBASE_CHEATSHEET.md) (which explains the engine); this doc
> is the **how-to-write-abilities** reference, mined from the 873 real ability files.
>
> Workflow: (1) skim [§1 mental model](#1-the-30-second-mental-model) once, (2) [register](#3-registration--wiring-a-new-ability-or-character)
> the ability's JSON, (3) find the matching pattern via the [phrase→pattern index](#13-readable-phrase--pattern-index)
> or the [archetype cookbook](#7-pattern-cookbook), (4) copy the skeleton, (5) fill in numbers.
>
> Line numbers were verified at authoring time but drift — **grep the symbol name** if one looks off.

## Contents
1. [The 30-second mental model](#1-the-30-second-mental-model)
2. [The universal `execute()` idiom & golden rules](#2-the-universal-execute-idiom--golden-rules)
3. [Registration: wiring a new ability or character](#3-registration--wiring-a-new-ability-or-character)
4. [`abilities_data.json` field reference](#4-abilities_datajson-field-reference)
5. [The `classes` flags](#5-the-classes-flags)
6. [Targeting & bot AI (`target()` + `custom_behavior()`)](#6-targeting--bot-ai)
7. [Pattern cookbook](#7-pattern-cookbook) — damage · control · defensive/reactive · buffs/mitigation · over-time/triggers · state machines
8. [Effect factory reference (the vocabulary)](#8-effect-factory-reference)
9. [Effect mechanics: source, stacking, duration, flags](#9-effect-mechanics)
10. [`Condition` & `Trigger` reference](#10-condition--trigger-reference)
11. [Enum quick reference](#11-enum-quick-reference)
12. [Master gotcha list](#12-master-gotcha-list)
13. [Readable-phrase → pattern index](#13-readable-phrase--pattern-index)

---

## 1. The 30-second mental model

- An ability is `abilities/<charpath><n>.gd` that `extends Ability` (base class:
  `abilities/scripts/ability_component.gd`).
- **The `.gd` supplies ONLY behavior.** ALL metadata — energy cost, cooldown, target type,
  `classes`, name, icon, flags — lives in **`abilities_data.json`** and is stamped onto the instance
  at load (`Ability.from_database`). Setting cost/cooldown in the `.gd` does nothing.
- You override a small set of methods: **`execute(user, battle)`** (the effect), **`target(user, battle)`**
  (whitelist legal chairs), **`describe(user)`** + **`split_desc()`** (tooltip), **`extra_usable(user)`**
  (extra gate), **`custom_behavior(context)`** (bot AI). Plus usually `var base_damage = N`.
- **Almost everything is built from three primitives:**
  1. `Character.resolve_damage(context, target, amount, DamageType.Type.X)` — deal damage.
  2. `Character.resolve_healing(context, target, amount)` — heal.
  3. `Effect.<factory>(...)` → `eff.set_source(self)` → `Character.add_hostile_effect`/`add_allied_effect(context, user, target, eff)` — apply a status.
- **Status effects are all one class (`Effect`)** distinguished by `effect_type`. There are ~65 factory
  functions (`Effect.stun_effect`, `Effect.shield_effect`, `Effect.trigger_effect`, …) — see [§8](#8-effect-factory-reference).
- **Reactive behavior ("when X happens, do Y")** = an `Effect.trigger_effect(...)` holding a `Trigger`
  whose callback method on the ability fires later — see [§7e](#7e-over-time-triggers--marks).

---

## 2. The universal `execute()` idiom & golden rules

The idiom **~90% of real files use** (the low-level form; the Tier-1 helpers exist but most files inline it):

```gdscript
extends Ability
var base_damage = 30

func execute(user, battle):
    var context = QueryContext.from_game_state(user, battle)   # or: make_context(battle)
    for target in user.targeter.targets:                       # the player's chosen targets
        Character.resolve_damage(context, target, base_damage, DamageType.Type.PHYSICAL)
        var eff = Effect.stun_effect(2, ["Physical"])          # build a status from a factory
        eff.set_source(self)                                   # ← MANDATORY before applying
        Character.add_hostile_effect(context, user, target, eff)
```

### Golden rules (violating these = the most common bugs)
1. **`eff.set_source(self)` before every `add_*_effect`.** `set_source` sets `source` AND `user`
   (from `source.user`); the engine names, stacks, cleanses, and attributes effects via `source`.
   Forgetting it null-crashes `effect_name()`. *(Or use the `apply_hostile`/`apply_allied` helpers,
   which call `set_source` for you.)*
2. **Routing: `add_allied_effect` for self/ally (buffs, shields, heals — even self-drawbacks);
   `add_hostile_effect` for enemies (debuffs, vulnerability).** Mixing them silently no-ops.
3. **`target()` only WHITELISTS chairs** via `set_targeted()` (usually a `default_*_target_function`).
   It does NOT pick targets. The player's picks land in `user.targeter.targets` / `.main_target`,
   which `execute()` iterates. Single vs AoE is decided by `target_type` in **JSON**, not the `.gd`.
4. **Never write `target.health.hp` directly for damage** — route through `Character.resolve_damage`
   so boosts/vulns/mitigation/lifesteal/triggers apply. (Raw HP-set is legitimate ONLY for explicit
   "set HP to N" / execute mechanics — see [pattern D7](#7a-damage).)
5. **`execute()` runs AFTER cost is paid, cooldown is set, and counters/accuracy resolved.** Don't
   re-check affordability or re-start cooldown inside it.
6. **Inside a trigger callback, use `Character.resolve_effect_damage(context, context['effect'], target, dmg, type)`**
   (not `resolve_damage`) so the damage is attributed to the effect.
7. **`duration` is in turns and ticks down by 1 at the END of every turn — including the turn it's
   applied; the effect falls off at 0** (`-1` = permanent). Turns alternate player→enemy→player, so the
   number depends on **who interacts with the effect and for how many of their turns** — see
   [Duration: how to choose the number](#duration-how-to-choose-the-number). Quick version: enemy-facing
   "1 turn" (stun, ally-invuln) = **`dur 2`**; player-facing "1 turn" (skill swap, self damage-buff) =
   **`dur 3`**; ticking damage "for N turns" = `execute()` hits now + a ticking trigger with **`dur 2N-1`**.
8. **Stateful ability fields leak.** `health_drain`, `minimum_damage`, `modifier_value` live on the
   persistent ability instance — if you set them conditionally, reset them (`= false` / `0` / `1`) at the
   end of `execute()`, or every future cast inherits them.

### Duration: how to choose the number

`duration` is in **turns**. It ticks down by 1 at the **end of every turn, including the turn the effect
is applied**, and the effect falls off when it reaches 0 (`-1` = permanent). Turns alternate
**player → enemy → player → …**. So the number you pass depends on **who needs to interact with the
effect, and for how many of their turns**:

| The effect is experienced by… | "1 turn" | "2 turns" | N turns |
|---|---|---|---|
| **The enemy** (stun, taunt, blind; ally invuln so the enemy can't hit them; an enemy debuff they "carry") | `2` | `4` | `2N` |
| **The player / caster** (skill swap, self damage-buff, cost discount, self shield) | `3` | `5` | `2N+1` |
| **Ticking damage that also hits on cast** ("deals X for N turns") | — | `3` | `2N-1` |

Why the asymmetry: the **enemy's turn is the *next* turn** after you cast (1 boundary away → `dur 2`),
but the **player's next turn is *two* turns away** (your cast turn + the enemy turn in between → `dur 3`).

Worked examples:
- **1-turn stun / "ally is invulnerable for 1 turn"** (enemy-facing) → `dur 2`: present on your cast turn
  **and** the enemy's immediately-following turn (when they're stunned / can't land a hit), then falls off.
  The enemy loses exactly one action.
- **"Swaps to X for 1 turn" / "+10 damage for 1 turn"** (player-facing) → `dur 3`: survives your cast turn,
  the enemy's turn, and your **next** turn (when you actually press the swapped button / make the buffed
  attack), then falls off.
- **"Deals 10 to one enemy for 2 turns"** → `execute()` deals 10 now (hit 1); apply a ticking trigger with
  `dur 3`. It does **not** tick the turn it's applied, and **ticks fire only on the caster's (your) turns**
  — so it skips the enemy's turn, then ticks on your next turn (hit 2), then falls off. (Net: the trigger
  fires once even though `execute()` already covered the first turn.)

---

## 3. Registration — wiring a new ability or character

### Recipe (a): new ability on an EXISTING character
1. **Bump the count** in `character_ability_counts.json` (e.g. `"asta": 4` → `5`).
   `Movesets.from_skill_count` ([movesets.gd:25](scripts/movesets.gd:25)) loads `<path_name>1 … <path_name>N`
   where N is that count, so the key index must be **contiguous 1..N**.
2. **Add the JSON entry** keyed `"<path_name><N>"` in `abilities_data.json` (see [§4](#4-abilities_datajson-field-reference)):
   ```json
   "asta5": {
     "script_path": "res://abilities/asta5.gd",
     "name": "Black Slash",
     "cost": {"3": 1}, "cooldown": 1, "target_type": 0,
     "classes": ["Harmful", "Instant", "Physical"],
     "image_path": "res://assets/images/Asta/asta5.png",
     "description": "Deals 30 damage to one enemy."
   }
   ```
3. **Create `abilities/asta5.gd`** extending `Ability`, overriding `execute`/`target`/`describe`/`split_desc`/`custom_behavior`.
4. **Add the icon** at `image_path`.

> The **JSON key** (not `script_path`) is what wires the ability into the moveset. `script_path`'s
> filename may even differ from the key. Forget step 1 and the ability is invisible to the character.

### Recipe (b): brand-NEW character
1. Add `path_name` to `CharacterDatabase.char_name_list()` ([character_database.gd:3](scripts/character_database.gd:3))
   (optionally `starter_squads()` for default-unlocked).
2. Add `"<path_name>": <ability count>` to `character_ability_counts.json`.
3. Copy `character/character_template.{gd,tscn}` → `character/<path_name>.{gd,tscn}`. In the `.gd` override
   `initialize(_moveset=false)`:
   ```gdscript
   func initialize(_moveset = false):
       character_colors = [0, 1]                          # Energy.Type ints (identity/draft)
       character_name = "Asta"
       universe = CharacterConcept.Universe.BLACK_CLOVER
       path_name = "asta"
       description = "..."
       if _moveset:
           moveset.set_base_abilities(Movesets.from_skill_count(self), self)
   ```
   In the `.tscn`: bind the 6 component NodePaths (`effects/health/stats/_name/moveset/targeter`),
   set `portrait_texture` (+ optional `mastery_portrait`/`mastery_name`, `alt_portraits`), and **wire
   `HealthComponent.died → die`**.
4. Add each ability via Recipe (a). The `path_name`, `char_name_list()` entry, `character_ability_counts.json`
   key, and `.tscn` filename **must all be the same string** (`from_character_name` loads `res://character/<path_name>.tscn`).

### `base_abilities` indexing (for transformations)
`user.moveset.base_abilities` holds the **full kit**: indices **0–3 = the four visible buttons**,
**4,5,6,7… = hidden alternate skills**. Declare the hidden ones in `abilities_data.json` too
(`<path_name>5`, `<path_name>6`, …) and bump the count to include them. Ability-swaps re-point a visible
slot at a hidden index — see [§7f](#7f-state-machines-swaps-transformations-passives).

---

## 4. `abilities_data.json` field reference

| Field | Type | Meaning |
|---|---|---|
| `script_path` | string ✅ | `res://abilities/<name>.gd` — the only link to behavior. May differ from the JSON key. |
| `name` | string ✅ | Display name. **Used as a literal key** in `ability_targets`/`marked_by`/mastery checks across the engine — renaming silently breaks logic keyed on it. |
| `cost` | `{"0".."4": int}` | Energy by `Energy.Type` (0=GREEN,1=BLUE,2=WHITE,3=RED,**4=RANDOM**=any color). Keys are JSON strings, int-cast on load. Omit = free. JSON is the BASE cost; `cost()` layers cost-mod effects. |
| `cooldown` | int ✅ | Base turns locked. **Implicit +1**: `start_cooldown` sets `cooldown_remaining = cooldown + 1`. So `0` = usable next cycle; `1` = skip a turn. |
| `target_type` | int ✅ | `TargetType.Type`: 0=SINGLE, 1=ALL_FACTION, 2=ALL, 3=COUNT, 4=SELF. Governs AoE auto-expansion & blind-immunity; **does NOT decide legality** (`target()` does). |
| `classes` | string[] ✅ | Category tags (see [§5](#5-the-classes-flags)). Misspelling silently no-ops. |
| `image_path` | string ✅ | `res://assets/images/<Char>/<name>.png`. No fallback. |
| `mastery_name` / `mastery_image_path` | string | Alt "mastery skin" name/icon (shown when `mastery_skin_on`). Omit if none. |
| `and_targeter` | bool | With COUNT/AoE: prompt for extra targets, each validated by your `and_target(character)` override. |
| `selfless` | bool | `default_allied_target_function` skips the caster (ally buffs that can't hit self). |
| `stunnable` | bool (default true) | If false, `is_stunned()` ignores stuns for this skill. |
| `accurate` | bool | If true, skips the accuracy/miss check (can't miss / ignores blind). |
| `important` | bool | Cosmetic highlight only. |
| `invisible` | bool | Use is hidden from the battle log (hidden setup/auto skills, e.g. Susanoo). |
| `description` | string | Fallback tooltip text; keep in sync with `describe()`. **`split_desc()` wins when non-empty.** |

---

## 5. The `classes` flags

Set at least one **school** + intent + timing. Schools/intent drive stun/counter matching and gating.

- **Schools** (what STUN/COUNTER effects key on; `is_stunned` checks `classes[that_class]`):
  `Physical`, `Energy`, `Mental`, `Affliction`, `Strategic`. *(Separate from `DamageType.Type` — set both, keep them thematically consistent.)*
- **Intent:** `Harmful` (damages/debuffs an enemy — gates taunt: a taunted char can only use Harmful on the taunter),
  `Helpful` (heals/buffs allies — gates allied-effect application).
- **Timing/discipline:**
  - `Instant` — resolves immediately (most attacks).
  - `Action` — an ongoing effect that is **cancelled if its user is stunned**.
  - `Channeled` — multi-turn channel; torn down on stun/death (use with `Effect.channel_cancel`, see [§7e](#7e-over-time-triggers--marks)).
  - `Control` — lockdown tracked via `CONTROL_CANCEL`, drops when the user is stunned (use `track_cancellable`).
  - `Preserves Channel` — using this skill does NOT break the user's existing channel.
- **Special:** `Uncounterable` (can't be countered — opt-in only), `Bypassing` (ignores INVULN when applying damage/effects),
  `Stealthed` (won't trigger enemy reactive effects), `Passive` (auto-run once at battle start by `startup_passives`; never manually used).

---

## 6. Targeting & bot AI

Two hooks, linked at runtime: the bot's chosen targets are re-validated against `target()`, so **keep
`target()` and `custom_behavior()` consistent** or the bot's pick is silently dropped.

### `target()` recipes
```gdscript
func target(user, battle): default_hostile_target_function(user, battle)       # enemies
func target(user, battle): default_allied_target_function(user, battle)        # allies (skips self if selfless=true)
func target(user, battle): default_self_target_function(user, battle)          # self only (bypassing=true, always legal)
func target(user, battle):                                                     # everyone (both teams)
    default_hostile_target_function(user, battle); default_allied_target_function(user, battle)
func target(user, battle): default_hostile_target_function(user, battle, false, "Ofuda")  # only MARK-bearing enemies (4th arg)
func target(user, battle): default_hostile_target_function(user, battle, true)            # bypassing: include invuln (3rd arg)
```
- **AoE all-enemies** = JSON `target_type:1` (ALL_FACTION) + plain `default_hostile_target_function` (the engine auto-expands the faction). Do NOT loop in `target()`.
- **`and_targeter`** (JSON) + `func and_target(character) -> bool`: bundle fixed extra targets alongside the player's main pick.
- **Custom legality** (rez dead allies, HP thresholds, non-MARK conditions): hand-roll a loop calling
  `character.set_targeted()` (no built-in legality check — guard `banished`/`dead`/`invuln` yourself) or
  `check_hostile_target(user, c, context)` / `check_allied_target(...)` to reuse standard rules.

### `custom_behavior()` — pick the matching `behavior_*` builder
Return `behavior_X(context, base_mod, …)`. `base_mod` is a flat **priority** bonus (how much the bot
WANTS the skill, ~75 = strong), **not damage**. All builders auto-skip dead/banished/invuln and emit a
clean `PASS` when no legal target exists.

| Ability kind | Builder | Notes |
|---|---|---|
| Single-enemy damage | `behavior_single_target_damage(ctx, mod, missing_ratio=1.0, bypass=false)` | scores `100 + missing_hp*ratio`; favors finishing low-HP enemies |
| Single-enemy, effect-centric (HP irrelevant) | `behavior_single_target_hostile(ctx, mod)` | flat 100+mod |
| Single-enemy stun | `behavior_single_target_stun(ctx, mod)` | skips STUN-immune enemies |
| AoE all enemies | `behavior_hostile_aoe_damage(ctx, mod, ratio)` | one variation, whole team |
| AoE main+splash | `behavior_hostile_splash_aoe(ctx, mod, ratio)` | random main_target first |
| Single ally heal | `behavior_single_target_heal(ctx, mod, ratio)` | skips full-HP allies |
| Single ally buff | `behavior_single_target_helpful(ctx, mod)` / `_selfless_helpful` | flat over allies |
| AoE ally aid | `behavior_helpful_aoe_aid(ctx, mod, ratio)` | |
| Self-buff / defensive cooldown | `behavior_self_panic_button(ctx, mod, panic_mod=1.0)` | scores `-30 + mod + missing_hp*panic` → used when hurt |
| Mark-gated hit/heal | `behavior_hostile_single_require_mark(ctx, name, type, mod, per_mark=false)` / `_helpful_…` | only scores marked targets |
| Spread a mark | `behavior_hostile_spread_out(ctx, name, type, mod, exclusion_mod)` | down-weights already-marked |
| Everyone / any-one | `behavior_all_target(ctx, mod)` / `behavior_any_target(ctx, mod)` | |
| **Passive / never auto-cast** | `return [[0, [user, "PASS", []]]]` | the canonical passive signal |

**`bot_damage_hint()`** (defaults to `base_damage`): override it for AoE/multi-hit/scaling abilities or
the contextual model reads them as 0 threat.

---

## 7. Pattern cookbook

Each pattern: **readable phrasing → skeleton → key APIs → examples**. Skeletons are copy-pasteable;
fill in numbers and names. (Common `extends Ability` / `target()` / `custom_behavior()` omitted where obvious.)

### 7a. Damage

**D1 — Plain single-target / AoE damage.** *"Deals 30 Piercing damage to target enemy."*
```gdscript
var base_damage = 30
func execute(user, battle):
    var context = QueryContext.from_game_state(user, battle)
    for target in user.targeter.targets:
        Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
func custom_behavior(context): return behavior_single_target_damage(context, 40)
func target(user, battle): default_hostile_target_function(user, battle)
```
Pick `DamageType` to match the word: `PHYSICAL`, `ENERGY`, `PIERCING` (ignores DR), `AFFLICTION`
(ignores barriers/shields, DoT-flavored), `BLEED` (usually a DoT), `TRUE` (ignores everything), `NORMAL`
(default mitigatable). AoE vs single is set by JSON `target_type`, not the loop. *(ex: cell3, cooler1, ace1)*

**D2 — Damage + apply an effect.** *"Deals 20 Piercing, removes 1 energy, and marks them."*
Deal damage **first**, then build/apply the effect:
```gdscript
for target in user.targeter.targets:
    Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
    target.lose_energy(user, 1)                                  # energy drain is imperative, not an Effect
    var mark = Effect.mark(5, "Marked.")
    mark.set_source(self)
    Character.add_hostile_effect(context, user, target, mark)
```
*(ex: alphonse3, toph2, gohan3, cell1)*

**D3 — Scaling by stacks / mark count.** *"Deals 30 + 5 per Genetic Perfection stack."*
```gdscript
var stacks = 0
var counter = user.has_effect("Genetic Perfection", EffectType.Type.MARK, user)
if counter: stacks = counter.stack_count()                       # guard: has_effect returns null if absent
var damage = base_damage + 5 * stacks
for target in user.targeter.targets:
    Character.resolve_damage(context, target, damage, DamageType.Type.PIERCING)
```
Variants: read `.mag` for resource counters (uryu5); scaling can flip `DamageType` (yuji1: NORMAL→TRUE). *(ex: cell3, yuji1, eren1)*

**D4 — Scaling by missing-HP / energy / ally count.**
```gdscript
var missing = user.get_modified_max_hp() - user.health.hp        # use get_modified_max_hp, not literal 100
var bonus = int(missing / 15)                                     # bucket
# enemy/ally count: iterate context['enemy_team'].characters / ['ally_team'], count not (dead or banished)
```
*(ex: uryu5 energy-spend, cell4 missing-hp, esdeath1 threshold buildup)*

**D5 — AoE main-target heavy + splash.** *"40 to target, 0 stacking Affliction DoT to all enemies."*
```gdscript
for target in user.targeter.targets:
    if target == user.targeter.main_target:
        Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
    # ... apply a (lighter) effect/damage to every target
func custom_behavior(context): return behavior_hostile_splash_aoe(context, 50)
```
Or use the helper `damage_splash(context, main_damage, splash_damage, damage_type)`. *(ex: ace3)*

**D6 — Lifesteal.** Set `health_drain = true` so the engine heals the user for damage dealt:
```gdscript
func execute(user, battle):
    health_drain = true                                          # whole-cast drain
    var context = QueryContext.from_game_state(user, battle)
    for target in user.targeter.targets:
        Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
    health_drain = false                                         # RESET if conditional (stateful field!)
```
Per-DoT drain: `dot.health_drain = true` on the effect. *(ex: myotismon1, nagisa1, erza3)*

**D7 — Execute / instant-kill / set-HP.**
```gdscript
target.execute_attempt(10, user, self)        # kills ONLY if target.health.hp <= 10 (call AFTER damage)
target.instant_kill(user, self)               # unconditional kill (e.g. from a mark wrapup)
# Set-HP bypass (legitimate ONLY for "force HP to exactly N", not damage):
target.health.hp = 60
target.health.health_changed.emit(target.health.hp)             # MUST emit so UI/triggers update
```
*(ex: sukuna2 HP buckets, gohan1, saturn3 wrapup, esdeath1)*

**D8 — Output modifiers.** `minimum_damage = 20` (damage floor), `modifier_value = 2` (how strongly
external damage-mods apply to this hit) — both **stateful, reset if conditional**. Enemy damage debuff =
`Effect.damage_mod_effect(-10, dur, [], [], [DamageType.Type.AFFLICTION])` applied hostile (see [§7d](#7d-buffs--mitigation)).

### 7b. Control & disruption

All share: loop targets, optional `resolve_damage`, build the disable factory, `set_source(self)`,
`add_hostile_effect`. The factory differs; many take class include/exclude lists.

| Readable | Factory | Notes |
|---|---|---|
| Stun (all / by class / all-but-class) | `Effect.stun_effect(dur, class_targets=[], exclude=[])` | `["Physical"]`=only Physical; `[],["Mental"]`=all but Mental; `[]`=full. Behavior: `behavior_single_target_stun`. |
| Silence | `Effect.silence_effect(dur)` | **no class arg.** Blocks applying new non-damage effects. |
| Taunt (force-target) | `Effect.taunt_effect(dur, user)` | 2nd arg = who they're forced to hit (usually `user`). Often `add_hostile_effect(...,true)` bypass. |
| Blind (attacks miss) | `Effect.blind_effect(dur, targets=[], exclude=[])` | same include/exclude shape as stun. `target.blind_check()` queries it. |
| Paralyze (freeze cooldowns) | `Effect.paralyze_effect(dur)` | no class arg. Distinct from stun — they can still use 0-cd skills. |
| Isolate (heal-block) | `Effect.isolate(dur)` | `target.is_isolated()` queries it. |
| Shatter (negate defenses) | `Effect.def_negate(dur)` | `dur=1` = until end of turn. Often paired with vulnerability/blind. |
| Energy drain | `target.lose_energy(user, n)` | **imperative, NOT an Effect** — no set_source/add. `n` omitted = 1. |
| Cost tax | `Effect.cost_mod_effect(1, dur, Energy.Type.RANDOM)` hostile | +1 cost. `cost_change_effect` rewrites the whole cost. |

**Cancellable disable channel** (Control class): bundle every applied effect into a `cancels` array,
then apply `Effect.control_cancel(dur, ability_name, cancels)` **to the user** (`add_allied_effect`) so the
whole disable is undone if the user is stunned. One-liner helper: `track_cancellable(context, dur, cancels)`. *(ex: korra8, machinedramon3)*

### 7c. Defensive & reactive (counters / reflects / invuln / ignore)

Install a defensive effect; the mechanic differs by what happens on an incoming skill. **Counters/reflects
almost always set `eff.invisible = true` + `eff.wrapup_func = default_counter_timeout`.**

**C1 — Counter the next skill (abort it).**
```gdscript
var trigger = Trigger.from_condition(Condition.always(), default_counter_trigger)
var eff = Effect.counter_effect(trigger, EffectType.Type.COUNTER_RECEIVE, 2,
    func(e): return "The next Harmful skill on this character is countered.", ["Harmful"])
eff.invisible = true
eff.wrapup_func = default_counter_timeout
eff.set_source(self)
Character.add_allied_effect(context, user, user, eff)            # RECEIVE→allied (on self/ally)
```
- **`COUNTER_RECEIVE`** = counter skills used ON the holder (cast allied). **`COUNTER_USE`** = counter the
  next skill the holder USES (cast **hostile** on an enemy). In both, `context['owner']` = the enemy being countered.
- **Punishing counter** = a custom callback that reads `context['owner']` (attacker) and
  `context['effect'].user` (you), deals `Character.resolve_effect_damage(context, context['effect'], attacker, …)`
  / applies effects, **then MUST call `default_counter_trigger(context)`** to actually abort. *(ex: kakashi3, tsunayoshi2, gilgamesh2)*

**C2 — Reflect a single-target skill back.**
```gdscript
# arg3 reflect_target: `user` = bounce to caster, -1 = bounce to attacker. arg8 count: 1 = single-use.
var eff = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE,
    -1, 2, "Harmful skills are reflected to their user.", ["Harmful"], [], 1)
eff.set_source(self); eff.invisible = true; eff.wrapup_func = default_counter_timeout
Character.add_allied_effect(context, user, target, eff)
```
**Reflect only works on SINGLE-target skills** (the built-in `reflect_trigger` early-returns on AoE). *(ex: eren2, king4, mash4)*

**C3 — Invulnerability.** `Effect.invuln_effect(dur, class_targets=[], exclude=[])` — `["Physical"]`=immune
ONLY to Physical; `[],["Strategic"]`=immune to all but Strategic; `[]`=total. Applied allied. Just BLOCKS
(doesn't abort/bounce). *(ex: king4, mash4, koro1 random-class)*

**C4 — Selective immunity.** `ignore_damage_effect(dur)` (immune to damage, still debuffable) +
`ignore_non_damage_effect(dur)` (immune to debuffs, still damageable) — **pair both for total harmful
immunity**. `ignore_effect_effect(dur, EffectType.Type.X)` ignores one mechanic.
`ignore_counter_effect(dur, [names])` makes YOUR skills bypass counters. *(ex: hisoka4, kakashi5, kurapika4)*

**C5 — Soften, not block.** `Effect.immortality_effect(dur)` (can't be killed, still takes damage — pair
with a `DAMAGE_RECEIVE_TRIGGER` for revive logic), `Effect.damage_cap(cap, dur)` (caps holder's OUTGOING
per-hit), `Effect.damage_cap_receive(cap, dur)` (caps INCOMING). *(ex: allmight2, ban6, kaiba5)*

### 7d. Buffs & mitigation

Self/ally = `add_allied_effect`; enemy = `add_hostile_effect`. **Same factory + negative mag = the
opposite effect** (e.g. `damage_mod_effect` positive on self = damage up; negative on enemy = their damage down).

| Readable | Factory | Notes |
|---|---|---|
| Instant heal | `Character.resolve_healing(context, target, amount)` | guard `not target.dead and not target.banished` in mixed loops |
| Heal-over-time | `Effect.healing_effect(perTurn, dur)` | auto-ticks; **don't add a trigger for it** |
| Healing received + | `Effect.healing_received_mod_effect(mag, dur, names=[])` | flat bonus to healing the holder receives |
| Shield (absorb on defender) | `Effect.shield_effect(mag, dur)` | on the TARGET via `add_allied_effect`; `wrapup_func` can convert leftover to heal |
| Barrier / Nullify | `Effect.barrier_effect(mag, dur)` | distinct from SHIELD; auto-stackable; often applied to enemies from a trigger |
| Flat DR | `Effect.damage_reduction_effect(mag, dur)` | |
| Percent DR | `Effect.percent_dr(mag, dur)` | mag = % |
| Own damage up | `Effect.damage_mod_effect(mag, dur, names=[], class=[], excl=[], types=[])` | positive, allied. Scope by ability name (3rd) or damage type (6th) |
| Enemy damage down | same factory, **negative mag**, hostile | |
| Enemy takes more dmg | `Effect.vulnerability_effect(mag, dur, names=[], …)` | hostile; mirror of negative damage_mod |
| Cap max HP | `Effect.health_cap_effect(mag, dur)` | read `target.health.hp` AFTER the hit to cap at current |
| Anti-heal | `Effect.heal_cut(mag%, dur)` / `Effect.ignore_healing(dur)` | hostile |
| Dodge / accuracy | `Effect.dodge_effect(mag%, dur)` / `Effect.sharpshooter(dur)` (can't miss/be dodged) | |

**Accumulating buff** (DR, damage-mod): set `eff.stackable = true; eff.display_stacks = true; eff.stack_mag = true`.
*(ex: ace4 DR, zoro2 damage-mod, satsuki5 HoT, orihime3 shield, midoriya1 vulnerability)*

### 7e. Over-time, triggers & marks

The reactive workhorse: `Effect.trigger_effect(Trigger.always(cb) OR Trigger.from_condition(cond, cb),
EffectType.Type.<X>_TRIGGER, dur, desc)`. The callback `cb(context)` is a **method on the ability** and
reads `context` keys: `['owner']` (holder/actor/attacker — varies by trigger), `['target']` (victim),
`['effect']` (the trigger itself — pass to `resolve_effect_damage`), `['source']` (incoming skill;
`['source'].source.ability_name` = which ability), `.value` (damage amount, on damage-receive).

**T0 — Plain DoT** (passive, engine-ticked — no callback):
```gdscript
for target in user.targeter.targets:
    Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)   # hit 1 (now)
    var dot = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, 3)           # dur 2N-1: "2 turns" → 3
    dot.set_source(self)
    Character.add_hostile_effect(context, user, target, dot)
```
Stacking DoT: `dot.stackable = true; dot.stack_mag = true; dot.display_mag = true`. `damage_effect` does
**not** hit on apply (and doesn't tick the apply turn) — pair with `resolve_damage` for the first hit; use
`dur = 2N-1` for "deals X and X per turn for N turns" (see [Duration](#duration-how-to-choose-the-number)). *(ex: gray2, boruto3, ace3)*

**T1 — End-of-turn ticking action** (`TICKING_TRIGGER`):
```gdscript
func execute(user, battle):
    var context = QueryContext.from_game_state(user, battle)
    var trig = Effect.trigger_effect(Trigger.always(tick_cb), EffectType.Type.TICKING_TRIGGER, -1,
        "Deals 15 to a random enemy each turn.")
    trig.set_source(self)
    Character.add_allied_effect(context, user, user, trig)
    context['effect'] = trig                                     # fire once now so the cast turn benefits
    tick_cb(context)
func tick_cb(context):
    var me = context['owner']
    if me == null or me.dead or me.banished: return              # triggers can fire on a corpse — guard
    # pick targets via me.battle.roll(0, n) ...
    Character.resolve_effect_damage(context, context['effect'], target, 15, DamageType.Type.NORMAL)
```
*(ex: asta1, cell6, akame2 delayed-kill via finite duration)*

**T2 — On-damage-received** (`DAMAGE_RECEIVE_TRIGGER` = any damage; `HARMFUL_RECEIVE_TRIGGER` = only
harmful skills). Callback: attacker = `context['owner']`, you/defender = `context['target']`, amount =
`context.value`. Retaliate via `resolve_effect_damage` back at `context['owner']`. "First time / once per
turn": `trig.wrapup_func = default_counter_timeout`. *(ex: marco6 heal-per-15, boruto4 retaliate+invuln, ace2 mark-counter)*

**T3 — On-damage-dealt** (`DAMAGE_DEALT_TRIGGER`): apply a follow-up to the victim. Dealer = `context['owner']`,
victim = `context['target']`. **Filter by `context['source'].source.ability_name`** or it fires on every
damage source (DoT ticks, counters). *(ex: asta1 nullify-on-hit)*

**T4 — On-action-use** (`ACTION_USE_TRIGGER`): react when the target acts. Actor = `context['owner']`,
trigger owner = `context['effect'].user`, who they aimed at = `enemy.targeter.targets`. *(ex: itachi1 punish, uraraka3 energy-drain)*

**T5 — On-death** (`ON_DEATH_TRIGGER`, usually `system = true`): fires during ANY turn (unlike
TICKING_TRIGGER which only fires on the owner's round). Dying char = `context.target`. *(ex: sukuna5, jeanne1)*

**T6 — Mark as a gate/state.** A `Effect.mark(dur, desc)` is a named tag other skills check.
```gdscript
# Skill that applies it:
var mark = Effect.mark(-1, "Active.")
mark.set_source(self); Character.add_allied_effect(context, user, user, mark)
# Skill gated on it (separate file):
func extra_usable(user): return user.marked_by("Active", user)  # only castable while marked
```
State machine: store data in `.mag` (`user.effects.has_effect("X", MARK, user).mag = N`, branch via
`Condition.mag_is`). `mark.skill_seal = true` = soft skill-lock (NOT a stun; stun-immunity doesn't bypass it). *(ex: gray2, aang2 Avatar Cycle, itachi5)*

**T7 — Delayed strike** (mark now + payload later): self-tag `Effect.mark` + a finite `TICKING_TRIGGER`
on the victim whose callback resolves the payload at elapse (gate on `context['effect'].duration == 1` if
only the last tick acts). *(ex: boruto1, akame2)*. The engine-level alternative (`delay_execution` /
`Effect.delayed_skill_eff`) re-runs the full `execute()` later but is rarely hand-used.

**T8 — Channeled** (multi-turn): each channeled effect gets `.channel = true` and is appended to a
`cancels` array; apply one `Effect.channel_cancel(-1, ability_name, cancels)` master to the user; **fire
the first tick immediately** in `execute()` (the channel breaks when the user next acts). *(ex: cell6, sakura2)*

### 7f. State machines: swaps, transformations, passives, energy

**S1 — Slot-swap rider** (this skill morphs a button for a window):
```gdscript
var swap = Effect.ability_swap_effect(4, 2, user, 3)   # hidden index 4 → visible slot 2, for ~1 turn
swap.set_source(self)
Character.add_allied_effect(context, user, user, swap)  # ALWAYS allied-to-self (modifies caster's moveset)
```
Or the wrapper `swap_ability(context, swap_in, slot, dur)`. `dur=3` ≈ 1 turn, `-1` = permanent. For
co-op refresh across two skills, set `swap.refresh = true` and source from the same base ability. *(ex: bakugo3, ban1, cooler1)*

**S2 — Transformation ultimate** (reveal hidden kit on a threshold). `HEALTH_CHANGE_TRIGGER` fires only on
a transition — **guard the already-below case and call the callback directly**, then one-shot the trigger:
```gdscript
func execute(user, battle):
    var context = make_context(battle)
    apply_allied(context, user, Effect.mark(-1, "Used.").set_invisible_system())   # lock re-cast
    if user.health.hp < 50: susanoo_activate(context); return                      # immediate-fire guard
    var trig = Effect.trigger_effect(Trigger.from_condition(Condition.health_is(user, -1, 49), susanoo_activate),
        EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, "Below 50 HP: transform.")
    trig.invisible = true; apply_allied(context, user, trig)
func susanoo_activate(context):
    var me = context['owner']
    var qc = QueryContext.from_game_state(me, me.battle)
    apply_allied(qc, me, Effect.shield_effect(35, -1))
    swap_ability(qc, 4, 0, -1); swap_ability(qc, 5, 1, -1); swap_ability(qc, 6, 2, -1)   # reveal alt kit
    var portrait = Effect.portrait_change_effect(0, -1); portrait.set_source(self)
    Character.add_allied_effect(qc, me, me, portrait)
    me.effects.remove_effect("Susanoo", EffectType.Type.HEALTH_CHANGE_TRIGGER, me)        # one-shot
```
*(Pseudo `.set_invisible_system()` = set `.invisible=true; .system=true` on the effect.)* *(ex: itachi4, halibel5, cell5 multi-stage)*

**S3 — N-use transform** (`ACTION_USE_TRIGGER` countdown): store the count in `trig.mag`, decrement with
`context['effect'].change_mag(-1)`, and on `<= 0` remove the trigger + apply the swaps/`target_change_effect`. *(ex: byakuya5)*

**S4 — Passive install** (`classes.Passive = true` → `startup_passives` runs `execute` once at battle start):
```gdscript
func execute(user, battle):
    var context = QueryContext.from_game_state(user, battle)
    var mark = Effect.mark(-1, "Permanent passive state.")
    mark.set_source(self); Character.add_allied_effect(context, user, user, mark)
    # ... install permanent (-1) triggers on allies if needed, evaluate once now ...
func custom_behavior(context): return [[0, [user, "PASS", []]]]   # never auto-cast
```
If the passive's effects are applied by a sibling ability, make `execute()` a bare `pass`. *(ex: sukuna5, ace5, aang5)*

**S5 — Self-toggle / stance** (gate via `extra_usable`):
```gdscript
func extra_usable(user):                                                 # toggle-ON gate
    return user.has_effect("Demon-Slayer Sword", EffectType.Type.DAMAGE_DEALT_TRIGGER, user) == null
# require-stance gate (opposite): return user.marked_by("Malevolent Shrine")
```
*(ex: asta1 equip, sukuna2/4 finishers, cooler5)*

**S6 — Skill copy/theft** (`SKILL_COPY`): `Effect.copy_effect(stolen_ability, replace_slot, dur, user)`
installs a copy into a slot; pair with `Effect.cost_change_effect({}, dur, [name])` to make it free.
`stolen = attacker.used_ability`. Set `copy.unique_render_id` if multiple copies coexist. *(ex: rimuru6, emiya1)*

**S7 — Energy economy:**
- **Gain** (Character methods, NOT effects): `user.gain_random_energy()` (+1 random real color),
  `user.gain_bonus_energy(Energy.Type.RED)` (+1 specific).
- **Discount own** (allied, negative mag): `Effect.cost_mod_effect(-1, dur, Energy.Type.RANDOM, ["Skill"])`,
  `Effect.cooldown_mod(-1, dur, ["Skill"])`.
- **Tax enemy** (hostile, positive mag): `Effect.cost_mod_effect(1, dur, Energy.Type.RANDOM)`.
- **Replace cost**: `Effect.cost_change_effect({}, dur, ["Skill"])` (free) or `{Energy.Type.RANDOM: 2}` (flat).
- **Recolor**: `Effect.color_change_effect(inc_color, replaced_color, dur, [...])`.
- `targets=[]` = all the character's skills; `["Name"]` = scoped. *(ex: alphonse1, korra6, cooler6, allmight5)*

---

## 8. Effect factory reference

All in `scripts/effect_component.gd`. Build → `set_source(self)` → `add_hostile_effect`/`add_allied_effect`.
Signature defaults shown. `dur=-1` is permanent everywhere.

**Damage / healing over time**
- `damage_effect(dmg, type=NORMAL, dur=1, use_source=true)` → DAMAGE — DoT, engine-ticked (not on apply).
- `healing_effect(heal, dur)` → HEALING — HoT, auto-ticks.

**Disables**
- `stun_effect(dur, class_targets=[], exclude=[])` → STUN — class lists filter which skill-classes are stunned. `remove_on_death=false`.
- `silence_effect(dur)` → SILENCE — blocks applying new non-damage effects. No class arg.
- `blind_effect(dur, targets=[], exclude=[])` → BLIND — attacks miss.
- `paralyze_effect(dur)` → PARALYZE — freezes cooldowns.
- `isolate(dur)` → ISOLATE — heal-block.
- `taunt_effect(dur, user)` → TAUNT — forces holder to target `user`.
- `def_negate(dur)` → DEF_NEGATE — "Shatter", negates defensive resources.
- `delay_eff(mag, dur, count=1, classes=[])` → DELAY (push back next skills); `delay_receive_eff(...)` → DELAY_RECEIVE (incoming).

**Defense / mitigation**
- `shield_effect(mag, dur, display=true)` → SHIELD — absorb pool on the defender (allied). Stacks add mag.
- `barrier_effect(mag, dur, display=true)` → BARRIER — "Nullify", always stackable+stack_mag.
- `damage_reduction_effect(mag, dur)` → DAMAGE_REDUCTION — flat.
- `percent_dr(mag, dur)` → PERCENT_DR — % (mag=percent). *(note: `unpierceable` param is unused.)*
- `invuln_effect(dur, class_targets=[], exclude=[])` → INVULN.
- `immortality_effect(dur)` → IMMORTALITY — can't die (still takes damage).
- `damage_cap(cap, dur)` → caps OUTGOING per-hit; `damage_cap_receive(cap, dur)` → caps INCOMING.
- `health_cap_effect(mag, dur)` → HEALTH_CAP — cap max HP.
- `ignore_damage_effect(dur)` / `ignore_non_damage_effect(dur, cond=null)` / `ignore_effect_effect(dur, EffectType)` / `ignore_counter_effect(dur, names=[])` / `ignore_healing(dur)` / `ignore_cleanse_effect(dur)`.
- `heal_cut(mag%, dur)` → HEAL_CUT; `healing_received_mod_effect(mag, dur, names=[])`; `healing_mod_effect(mag, dur, names=[])` (output).
- `sharpshooter(dur)` (can't miss/be dodged) / `dodge_effect(mag%, dur)` / `miss_effect(mag%, dur)`.
- `damage_null_effect(mag, dur)` → outgoing damage ×(1-mag).

**Offense modifiers**
- `damage_mod_effect(mag, dur, names=[], class=[], excl=[], types=[])` → DAMAGE_MOD — flat +/- outgoing. Scope by ability name (3rd) or DamageType (6th).
- `vulnerability_effect(mag, dur, names=[], class=[], excl=[])` → VULNERABILITY — flat +/- incoming on a foe.
- `stat_mod_effect(StatType, mag, dur)` → PRIMARY_STAT_MOD — % stat change (mag is a fraction).

**Counters / reflects / redirects**
- `counter_effect(trigger, eff_type, dur, desc="", classes=[], exclude=[])` → pass COUNTER_USE / COUNTER_RECEIVE.
- `reflect_effect(trigger, eff_type, reflect_target, dur, desc, classes=[], exclude=[], count=-1)` → REFLECT_USE/RECEIVE. `reflect_target`: `user`/`-1`/Character. SINGLE-target only.
- `redirect_effect(frac, char_target, dur)` → DAMAGE_REDIRECT — send a fraction of incoming to another char.

**Marks / triggers / meta**
- `mark(dur, desc="")` → MARK — a tag (set `.skill_seal=true` for a soft skill-lock).
- `trigger_effect(trigger, EffectType.Type.<X>_TRIGGER, dur, desc="")` → any listener (TICKING / DAMAGE_DEALT / DAMAGE_RECEIVE / HARMFUL_RECEIVE / ACTION_USE / HEALTH_CHANGE / ON_DEATH).
- `empty(dur, desc="")` → EMPTY — display-only placeholder.
- `from(eff_type, kwargs={})` → escape hatch: build any type + set arbitrary fields (`stackable`, `bypassing`, …).

**Cost / cooldown / kit**
- `cost_mod_effect(mag, dur, element, names=[])` (+/- one color) / `cost_change_effect(cost={}, dur=-1, names=[])` (replace whole dict; `{}`=free) / `color_change_effect(inc, replaced, dur, names=[])` / `cooldown_mod(mag, dur, names=[])`.
- `ability_swap_effect(swap_in, slot, user, dur)` → ABILITY_SWAP / `copy_effect(skill, slot, dur, user)` → SKILL_COPY / `target_change_effect(TargetType, dur, names=[])` → TARGET_CHANGE.

**Channel / control / delay / cosmetic**
- `control_cancel(dur, ability_name, cancel_effects)` (drops on stun) / `channel_cancel(dur, ability_name, cancel_effects)` (drops on stun or new action).
- `portrait_change_effect(num, dur)` (transform art, `system=true`) / `stealth_effect(dur)` / `disguise(path)` / `invisible_expiration_effect(ability, dur)`.
- `delayed_skill_eff(skill, targets, main, dur)` / `delay_target_marker(skill, dur)` (engine delayed cast).

---

## 9. Effect mechanics

- **`set_source(self)` is mandatory** — sets `source` AND `user` (= `source.user`). Or use `apply_hostile`/`apply_allied`/`buff_self`/`swap_ability` helpers which do it for you.
- **Identity for stacking** = `(effect_name(), effect_type, user)` where `effect_name()` = `source.ability_name`.
  Two effects "merge" only if from the SAME ability + SAME caster + SAME type.
- **Stack vs refresh vs append** (on re-apply when a match exists):
  - `eff.stackable` → MERGE: `stacks += new.stacks`, and if `stack_mag` also `mag += new.mag` (how SHIELD/BARRIER/DELAY accumulate).
  - `eff.refresh` (not stackable) → remove old, add new (resets duration).
  - neither (the default) → append a **second independent instance**.
  - Display: `display_mag` (show summed magnitude), `display_stacks` (show count). `per_stack` multiplies effective magnitude by stacks (you set it manually — no factory does).
- **Duration**: decrements by 1 at the **end of every turn, including the turn applied**; `end_effect` at `<= 0` (runs `wrapup_func` if CANCELLED). `consume_stack(n)` decrements stacks, ends at 0. `-1` = permanent. Choosing the number is turn-facing — see [Duration: how to choose the number](#duration-how-to-choose-the-number). Ticking effects (DoT/HoT/`TICKING_TRIGGER`) fire only on the **caster's/owner's** turns, not the enemy's, and not on the turn they're applied.
- **DAMAGE/HEALING effects are ticked by the engine** (DoT/HoT); **`*_TRIGGER` effects are listeners** fired on events — don't confuse `Effect.damage_effect` (a DoT) with a `DAMAGE_DEALT_TRIGGER`.
- **Filter fields** (overloaded per factory — check signatures): `ability_targets` (named abilities), `class_targets` (ability/damage classes), `exclusion_targets` (inverse), `type_targets` (DamageType list). Empty = applies to everything.
- **Flags worth knowing**: `invisible` (hidden from enemy UI), `system` (no status chip; survives death unless `remove_on_death`), `remove_on_death=false` (persist past death), `bypassing` (ignore target immunity — or pass `true` as the 5th arg to `add_hostile_effect`), `cleansable` (default true; `IGNORE_CLEANSE` on a target makes ALL cleanses bail).

---

## 10. `Condition` & `Trigger` reference

**`Trigger`** (`scripts/trigger.gd`): `Trigger.always(callback)` or `Trigger.from_condition(cond, callback)`.
`check(context)` runs `callback.call(context)` iff the condition holds. Used inside `Effect.trigger_effect`/`counter_effect`/`reflect_effect`.

**`Condition`** (`scripts/condition.gd`) — composable predicates evaluated against a `QueryContext`. Most useful for `extra_usable` gates and `from_condition` triggers:
- Combinators: `always()`, `is_not(c)`, `multi([c…])` (AND), `any([c…])` (OR).
- State: `is_alive(char)`, `is_invuln(char, ability=null)`, `is_hostile(char, target)`, `is_healable(char)`, `is_damageable(char, src)`.
- Queries (great for `extra_usable`): `has_effect(target, name, type, user)`, `health_is(target, min=-1, max=-1)`, `mag_is(target, name, type, user, min, max)`, `stack_count_is(target, name, type, user, min, max)`, `value_is(v, min, max)`.
- Use: `var ok = Condition.health_is(user, -1, 49); if ok.satisfied(context): …` (or pass the condition to `Trigger.from_condition`).

---

## 11. Enum quick reference

- **`Energy.Type`**: GREEN=0, BLUE=1, WHITE=2, RED=3, RANDOM=4 (cost keys, `character_colors`).
- **`DamageType.Type`**: NORMAL=0, ENERGY=1, PHYSICAL=2, PIERCING=3, AFFLICTION=4, BLEED=5, TRUE=6. (PIERCING/TRUE/def_broken bypass DR; AFFLICTION/BLEED bypass barriers/shields.)
- **`TargetType.Type`**: SINGLE=0, ALL_FACTION=1, ALL=2, COUNT=3, SELF=4.
- **`StatType.Type`**: ATTACK=0, DEFENSE=1, MIND=2, RESIST=3, SPEED=4 *(vestigial — combat is ability-driven)*.
- **`EffectType.Type`** (~120): the discriminator. Triggers: `TICKING_TRIGGER, DAMAGE_DEALT_TRIGGER, DAMAGE_RECEIVE_TRIGGER, HARMFUL_RECEIVE_TRIGGER, ACTION_USE_TRIGGER, HEALTH_CHANGE_TRIGGER, ON_DEATH_TRIGGER`. Statuses: see [§8](#8-effect-factory-reference).
- **`CharacterConcept.Universe`** (~50): `CharacterConcept.Universe.NARUTO`, `.BLEACH`, … (set in `initialize()`).

---

## 12. Master gotcha list

- 🔴 **`eff.set_source(self)` before every `add_*_effect`** — #1 bug. Else `effect_name()` null-crashes.
- 🔴 **Metadata goes in `abilities_data.json`, not the `.gd`** — `@export` cost/cooldown/type are overwritten on load.
- 🔴 **Bump `character_ability_counts.json`** when adding a skill, with **contiguous** keys `1..N`, or it's invisible.
- 🔴 **`target()` only whitelists; JSON `target_type` sets AoE.** A `target()` loop over all enemies ≠ AoE (it makes them individually clickable).
- **`add_allied_effect` (self/ally) vs `add_hostile_effect` (enemy)** — mixing silently no-ops. Self-drawbacks still use allied.
- **Same factory + negative mag = opposite effect** (`damage_mod` up vs down; route accordingly).
- **`COUNTER_RECEIVE`→allied, `COUNTER_USE`→hostile.** A custom counter callback MUST end with `default_counter_trigger(context)` to actually abort.
- **Reflect only works on SINGLE-target skills.**
- **Energy drain (`lose_energy`) and energy gain (`gain_random_energy`/`gain_bonus_energy`) are Character methods, NOT effects** — no `set_source`/`add`.
- **Trigger callbacks: use `Character.resolve_effect_damage(context, context['effect'], …)`** (attributed), and **guard `context['owner'].dead/banished`** (triggers fire on corpses).
- **`HEALTH_CHANGE_TRIGGER` fires only on a transition** — guard the already-below case and call the callback directly, then one-shot the trigger.
- **`damage_effect` does NOT hit on apply** — add a `resolve_damage` for the immediate portion.
- **Stateful ability fields leak** (`health_drain`, `minimum_damage`, `modifier_value`) — reset conditional ones.
- **Don't write `target.health.hp` for damage** (bypasses mitigation/lifesteal/triggers) — only for explicit set-HP, and then `health_changed.emit`.
- **Ability swaps are always applied allied-to-SELF** (they modify the caster's own moveset); `dur=3` ≈ 1 turn, `-1` permanent.
- **Duration is turn-facing**: enemy-facing "1 turn" = `dur 2`, player-facing "1 turn" = `dur 3`, ticking "N turns" = `dur 2N-1`; it ticks down at the end of every turn (incl. the apply turn). See [Duration: how to choose the number](#duration-how-to-choose-the-number). `-1` = permanent.
- **Renaming an ability `name` can break engine logic** keyed on the literal string (`ability_targets`, `marked_by`, mastery terms).
- **`split_desc()` wins over `describe()`/JSON `description`** when non-empty, and takes no args + gets no mastery-term replacement. Edit `split_desc()` when it exists. *(memory note)*
- **Passive `custom_behavior` must return `[[0, [user, "PASS", []]]]`** so the bot never tries to cast it.

---

## 13. Readable-phrase → pattern index

| The tooltip says… | Go to |
|---|---|
| "Deals N [type] damage to one/all enem(y/ies)" | [D1](#7a-damage) |
| "…and stuns / silences / marks / drains energy" | [D2](#7a-damage) + [§7b](#7b-control--disruption) |
| "+N damage per stack / per mark / for each missing HP / per energy" | [D3](#7a-damage), [D4](#7a-damage) |
| "N to target and less to other enemies" | [D5](#7a-damage) |
| "heals the user for damage dealt" / lifesteal | [D6](#7a-damage) |
| "executes / kills if below N HP" / "sets HP to N" | [D7](#7a-damage) |
| "Stun / Silence / Taunt / Blind / Paralyze / Isolate / Shatter their skills" | [§7b](#7b-control--disruption) |
| "raises their energy cost" / "remove N energy" | [§7b](#7b-control--disruption) tax/drain, [S7](#7f-state-machines-swaps-transformations-passives) |
| "ongoing disable, ends if the user is stunned" | [§7b](#7b-control--disruption) cancellable channel |
| "the next skill used on them is countered" | [C1](#7c-defensive--reactive-counters--reflects--invuln--ignore) |
| "reflects the next skill back" | [C2](#7c-defensive--reactive-counters--reflects--invuln--ignore) |
| "becomes Invulnerable / ignores damage / ignores harmful effects" | [C3, C4](#7c-defensive--reactive-counters--reflects--invuln--ignore) |
| "cannot be killed / can't deal/take more than N" | [C5](#7c-defensive--reactive-counters--reflects--invuln--ignore) |
| "heals N" / "heals N per turn" / "gains N Shield / Barrier / DR" | [§7d](#7d-buffs--mitigation) |
| "deals N more damage" (self) / "takes N more damage" (enemy) | [§7d](#7d-buffs--mitigation) damage_mod / vulnerability |
| "N damage now and N per turn" / poison / burn / bleed | [T0](#7e-over-time-triggers--marks) |
| "each turn, …" / "at the end of each turn, …" | [T1](#7e-over-time-triggers--marks) |
| "when this character is damaged / hit by a harmful skill, …" | [T2](#7e-over-time-triggers--marks) |
| "enemies this character damages gain / suffer …" | [T3](#7e-over-time-triggers--marks) |
| "if this enemy uses a skill, …" | [T4](#7e-over-time-triggers--marks) |
| "when an ally/enemy dies, …" | [T5](#7e-over-time-triggers--marks) |
| "while [Mark] is active, …" / "only usable after …" | [T6](#7e-over-time-triggers--marks), [S5](#7f-state-machines-swaps-transformations-passives) |
| "next turn, …" / charged / delayed strike | [T7](#7e-over-time-triggers--marks) |
| "each turn while channeling …" | [T8](#7e-over-time-triggers--marks) |
| "this skill becomes [other skill] for N turns" | [S1](#7f-state-machines-swaps-transformations-passives) |
| "transforms / awakens / activates, replacing skills" (on threshold/after N uses) | [S2, S3](#7f-state-machines-swaps-transformations-passives) |
| "(passive) at the start of the battle …" | [S4](#7f-state-machines-swaps-transformations-passives) |
| "copies / steals an enemy skill" | [S6](#7f-state-machines-swaps-transformations-passives) |
| "gains energy" / "costs N less" / "reduces cooldown" | [S7](#7f-state-machines-swaps-transformations-passives) |
