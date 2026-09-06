# Anime Arena — Mechanics & Architecture Deep Dive

<!-- Auto-generated 2026-06-26 from a multi-agent deep read of the codebase (10 subsystem readers + adversarial verification + synthesis). Spot-verified against live source. Keep updated when core mechanics move. -->


> **Authoritative developer reference.** Every mechanic below is backed by `file:line` citations. Where the source subsystem analyses, the completeness critic, and the adversarial verifiers disagreed, this document presents the **verified** version and flags the resolution inline. Three facts were re-verified against the live source while writing this and override all upstream claims: the `EffectType.Type` member count (**122**, 0..121), the damage pipeline order (triggers fire **last**, not first), and the live-vs-dead status of `battle_manager.gd` (**live**).

---

## 1. Executive Summary & Tech Stack

Anime Arena is a turn-based, simultaneous-selection / alternating-resolution anime fighter built in **Godot 4.6 (GDScript)**. The roster is ~164 characters; each character has N abilities defined as individual `.gd` scripts (**896 ability scripts** in `abilities/`) whose static metadata lives in `abilities_data.json`. The entire game is **data-driven by enum ordinals**: every type vocabulary (`EffectType`, `DamageType`, `Energy`, etc.) is a bare `enum`, and the integer ordinal of each member is what gets persisted to JSON, shipped over the wire, and switched on throughout the engine.

| Layer | Tech / File |
|---|---|
| Engine | Godot 4.6, GDScript |
| Entry | `project.godot:18` `run/main_scene="res://root.tscn"` → `root.gd` → `game.tscn` |
| Autoload (only one) | `GlobalPlayerSettings` (`res://global_player_settings.gd`) |
| Networking | Godot high-level multiplayer over **WebSocket** (`WebSocketMultiplayerPeer`), `wss://server.animaslashanimearenaserver.org` (REMOTE) / `ws://127.0.0.1:5695` (LOCAL) |
| Server | The exported Godot binary itself, run `--headless` (`server.exe` / `auth_anime_server.x86_64`) — there is **no** separate Node/Python backend |
| Persistence | One JSON line per user `ausers/<name>.dat`; clans `clans/<name>.dat`; mastery ladder SQLite `mastery.db` via the **only** addon, `addons/godot-sqlite` |
| Web client | HTML5 export in `html/` (uses `JavaScriptBridge` for downloads, `libgdsqlite.web.template_debug` wasm) |

**The single most important architectural rule** is the enum-ordinal contract (§5). The second is the **live-vs-dead file split** (§13) — the repo ships three parallel battle implementations and a pile of `_old` duplicates, and editing a dead file compiles cleanly while changing nothing.

---

## 2. Repo / Directory Map

```
root.tscn / root.gd          Entry. Headless → server role; else client.
game.tscn / game.gd          The single persistent hub scene. Toggles child nodes via show/hide;
                             NEVER calls change_scene_to.
project.godot                main_scene, single autoload GlobalPlayerSettings, godot-sqlite plugin

scripts/                     Core engine (LIVE + some DEAD):
  battle_scene.gd            LIVE battle SCENE (class BattleScene) — thin display wrapper
  battle.gd                  DEAD legacy monolithic engine (class Battle)
  new_battle_scene.gd        DEAD predecessor scene
  bot_battle_scene.gd        DEAD bot test harness
  character_component.gd     LIVE Character entity (~1919 lines) — damage/heal/effect/death
  player_component.gd        LIVE Player — owns team, drives 3 bot brains, persistence/cosmetics
  effect_component.gd        LIVE Effect class — ~60 static factories
  effect_storage_component.gd Per-character effect store
  condition.gd / trigger.gd / query_context.gd   The condition/trigger DSL + data bus
  movesets.gd                from_skill_count loader (+ dead legacy <name>_moveset() funcs)
  *_component.gd             Health, Stat, Name, Moveset, Targeter, Team components
  character_database.gd      THE character registry (~164 names)
  characters.gd              DEAD empty stub (NOT the registry)
  types/                     Enum vocabulary: effect_type, damage_type, energy, elements,
                             stat_type, target_type, ending_type
  color_balanced_draft.gd    LIVE bot draft scorer

abilities/                   896 ability .gd files (<path_name><index>.gd)
  scripts/ability_component.gd   LIVE base class (class Ability extends Node)
  ability.gd                 DELETED (old extends Resource ancestor — red herring)

character/<name>.gd/.tscn    164 character defs (extends Character)

components/                  energypool, team, match, match_event_recorder, match_replay_log/player,
                             server_connection.gd (LIVE), server_connection_old.gd (DEAD),
                             mastery_db.gd, mastery_config.gd, character_progress.gd,
                             stats_manager.gd, clan.gd, rank_component.gd, Rating.gd,
                             character_component.tscn (wires died→die)

"new multiplayer/"           MIXED live/dead:
  battle_manager.gd          LIVE core engine (class BattleManager, ~3006 lines)
  bot_contextual_model.gd    LIVE contextual-bandit bot brain
  bot_training_data.gd       LIVE flat-winrate fallback
  battle_display.gd          DEAD scaffolding
  test_battle*.gd, test_scene.tscn  DEV/DEAD training harnesses

ui/                          Panels; many *_old.* DEAD duplicates
  help/help_data.gd, help_overlay.gd   In-game help (help_pages.json)
scenes/                      Top scenes: battle_scene.tscn (LIVE), char_select_scene,
                             new_battle_scene.tscn / bot_battle_scene.tscn (DEAD), draft_scene.gd
html/                        Web export
abilities_data.json          Ability metadata (cost/cooldown/classes/...)
character_ability_counts.json  path_name → skill count
character_colors.json        path_name → energy-color identity (for draft)
bot_contextual_model.json    ~1.4 MB trained bot weights
```

---

## 3. App Boot & Scene Flow

The boot chain is unambiguous and there is **no runtime scene-swapping** — the whole game lives inside `game.tscn` and toggles child nodes.

1. `project.godot:18` → `run/main_scene="res://root.tscn"`.
2. `root.gd` branches on `DisplayServer.get_name() == "headless"`:
   - **Headless** → `game.server.actually_start_server()` → `multiplayer_peer.create_server(5695)` (`server_connection.gd:192-203`). This process IS the authoritative match server.
   - **Client** → `root.gd:30` `game = load("res://game.tscn").instantiate()`.
3. `game.tscn` is the persistent hub. It instances `scenes/char_select_scene.tscn` (`CharSelectScene`) and `scenes/battle_scene.tscn` (`BattleScene`, `game.tscn:186-187`), and attaches the **non-`_old`** `components/server_connection.gd` (`game.tscn:5`).
4. `char_select_scene.gd` emits `start_battle(...)` for QUICK (962), BOT (994/1049/1473), RANKED (1123), PRIVATE (1210). `game.tscn:429` wires this to `game.gd.start_battle`.
5. `game.gd:173-180` `start_battle()` → `battle_scene.show_scene(); current_scene = battle_scene; battle_scene.start_battle_scene(...)`.
6. `battle_scene.gd:124` `manager = BattleManager.new()` — the display scene delegates **all** logic to the manager.

> **Verifier confirmation (VERDICT 1):** `scripts/battle_scene.gd` is live for all real flows (PvP and bot). `new_battle_scene.gd` and `battle.gd` are dead. **`new multiplayer/battle_manager.gd` is NOT dead — it is the core live engine**, instantiated by both the client `BattleScene` (`battle_scene.gd:124`) and the server-side shadow `Match` (`components/match.gd:110`). Any upstream text lumping `battle_manager.gd` with the dead files is corrected here.

---

## 4. The Character Entity & Component Model

A `Character` (`scripts/character_component.gd`, `class_name Character extends Node`) is the behavior hub. It aggregates six exported sub-component nodes, wired by NodePath in each character's `.tscn`:

```gdscript
@export var effects:  EffectStorageComponent   # character_component.gd:4-9
@export var health:   HealthComponent
@export var stats:    StatComponent
@export var _name:    NameComponent
@export var moveset:  MovesetComponent
@export var targeter: TargeterComponent
```

The components are dumb data holders; the Character routes through them. Plus plain battle-state fields (`dead`, `banished`, `enemy`, `acted`, `waiting`, `used_ability`, `was_countered`, `hp_last_turn`...), a back-reference `battle`, and `team: TeamComponent`.

### Instantiation & registry
- `Character.from_character_name(name)` (static, `character_component.gd:1841-1844`): `load("res://character/<name>.tscn").instantiate()` then `.initialize()`.
- `CharacterDatabase` (`scripts/character_database.gd`) is the **real registry**: `char_name_list()` (~164), `get_characters()`, `starter_squads()`, `by_universe()`. `scripts/characters.gd` is a dead empty stub.

### Component table

| Component | File | Key contents |
|---|---|---|
| Health | `health_component.gd:22-31` | `hp=100`, `max_hp`; `modify_hp(mod, modifier, source)` clamps `[0,max]`, emits `died(killer,source)` at 0 |
| Stat | `stat_component.gd:6-34` | 5 base stats randomized 25-100; `get_mod_stat` adds `base_stat * boost.mag` per `PRIMARY_STAT_MOD` |
| Moveset | `moveset_component.gd:18-84` | `abilities`/`base_abilities`; `display_abilities()`=slots 0-3 visible; `get_active_abilities()` resolves `ABILITY_SWAP`/`SKILL_COPY`; slots 4+ are hidden alts |
| Targeter | `targeter_component.gd` | `targets[]`, `main_target`, `targeting`, `targeting_ability` |
| Effects | `effect_storage_component.gd` | `_effects: Array[Effect]` (live), `_display_effects` (passive-client mirror) |
| Team | `team_component.gd` | `max_members=3`, `characters[]`, shared `energy: EnergyPool` |

> **Death wiring lives in the scene, not the code:** `components/character_component.tscn:34` connects `HealthComponent.died → Character.die`. Grepping the `.gd` finds nothing.

### Player & Team relationship
A `Player` (`player_component.gd`) owns one `team`. `recruit_character` appends `path_name` to `equipped_characters` and calls `team.add_character` (`:462-466`), which sets `character.team = self` (`team_component.gd:15-18`). **Energy is a TEAM resource**, never per-character.

### The canonical mutation API (no `stun()`/`taunt()`/`give_energy`)
There is **no** `give_energy`, `stun()`, `taunt()`, or `invuln()` mutating method. Those are read-only state checks (`is_stunned`, `is_taunted`, `is_invuln`). To apply state you build an `Effect`, bind it, and route through a static helper:

```gdscript
var eff = Effect.stun_effect(2, [], ['Mental'])   # kakashi1.gd:28
eff.set_source(self)                              # MANDATORY (§6)
Character.add_hostile_effect(context, user, target, eff)
```

- `Character.add_allied_effect(context, user, target, effect, bypassing=false)` (`:1846-1855`)
- `Character.add_hostile_effect(...)` (`:1856-1866`) — additionally bails if user silenced and effect ∈ `silenced_effects()`, and if target `shrug_off_type(effect.effect_type)`.
- Both stamp `effect.id = context.id`, then call the instance dispatcher `apply_effect(effect, target)` (`:152-219`), which runs a per-`EffectType` side-effect switch (STUN fires xanxus-wrath/`check_stun_triggers`/`on_control_effect_received`/`check_cancels`, etc.).

### Energy API (all team-scoped)
- `gain_bonus_energy(element)` → `team.change_energy(element, 1)` (`:1397`)
- `gain_random_energy()` → roll 0-3 → `team.change_energy(roll, 1)` (`:1393`)
- `lose_energy(drainer, val=1)` → `team.lose_energy(val, battle)` (random drain across colors)
- `EnergyPool.change_energy(RANDOM)` **push_errors** — RANDOM is a cost token, never stored (`energypool.gd:110-125`).

### `call_unique` — cross-character dispatch
`call_unique(user_path, function_name, args)` (`:97-101`): if `self.path_name == user_path`, calls `get(function_name).call(args)` (a method only that subclass defines), else returns `null`. Used for bespoke interactions, e.g. `target.call_unique('erza', 'wearing_armor', ["Heaven's Wheel Armor"])`.

### Death lifecycle
`die(killer, source)` (`:1653-1696`): **no-ops on passive multiplayer clients** (server authoritative). Handles Post-Mortem Nen / `is_immortal()` (sets HP to 1 instead). Otherwise: `health.set_health(0)` → `source.on_kill` → `killer.check_kill_triggers` → `dead=true` → `check_death_triggers` → `cleanse_death_effects` → emit `character_died` → `refresh(dead)`. `refresh(death)` (`:1709-1717`) latches `waiting=dead`, resets targeter, clears `used_ability`, and (unless death) clears `acted`.

---

## 5. Type Vocabulary (Enums)

> **THE ENUM-ORDINAL CONTRACT (read first).** Each type is `class_name X` + `enum Type {...}`. A member's integer value is its **zero-based declaration ordinal**. That integer is what is stored in `abilities_data.json`, shipped in wire frames/snapshots/`EFFECT_ADDED` events, and switched on across the damage pipeline. **Inserting a member mid-enum silently renumbers every later member**, corrupting persisted JSON and de-syncing networked clients. **Always append new members at the END.**

### DamageType.Type — 7 members (`damage_type.gd:3-11`, verified)

| Member | Val | Mitigation note |
|---|---|---|
| NORMAL | 0 | full pipeline |
| ENERGY | 1 | behaves as NORMAL for mitigation |
| PHYSICAL | 2 | behaves as NORMAL for mitigation |
| PIERCING | 3 | **skips flat+percent DR** (still hits barrier/shield) |
| AFFLICTION | 4 | **skips barriers/shields/DR**; **bypasses invuln** on ticks |
| BLEED | 5 | same as AFFLICTION for mitigation/invuln-bypass |
| TRUE | 6 | **skips DR** |

### EffectType.Type — **122 members, indices 0..121** (`effect_type.gd:3-122`, RE-VERIFIED)

> **CONTRADICTION RESOLVED.** Section 1 claimed 119 (0..118); the completeness critic claimed 118 (0..117) with `IGNORE_CLEANSE=117`. **Both are wrong.** Direct read of `effect_type.gd` shows **122 members, 0..121**, with `IGNORE_CLEANSE = 121`. The actual tail ordering also differs from Section 1's. The correct authoritative table:

| Val | Member | Val | Member | Val | Member |
|---|---|---|---|---|---|
| 0 | SHIELD | 41 | INVISIBLE_EXPIRATION | 82 | ABILITY_SWAP |
| 1 | DAMAGE | 42 | HEALING_MOD | 83 | TICKING_TRIGGER |
| 2 | PRIMARY_STAT_MOD | 43 | DAMAGE_REDIRECT | 84 | PERCENT_DR |
| 3 | DAMAGE_MOD | 44 | ABSORB_TRIGGER | 85 | HEALTH_CHANGE_TRIGGER |
| 4 | DAMAGE_REDUCTION | 45 | VULNERABILITY | 86 | DELAY |
| 5 | HEALING | 46 | IGNORE_EFFECT | 87 | DELAYED_SKILL |
| 6 | STUN | 47 | IGNORE_DAMAGE | 88 | EMPTY |
| 7 | STUN_IMMUNITY | 48 | IGNORE_HEALING | 89 | COLOR_CHANGE |
| 8 | INVULN | 49 | IGNORE_NON_DAMAGE | 90 | PORTRAIT_CHANGE |
| 9 | DEF_NEGATE | 50 | IGNORE_COUNTER | 91 | SILENCE |
| 10 | DAMAGE_NEGATE | 51 | ERZA_ARMOR | 92 | DAMAGE_REVERSE |
| 11 | DAMAGE_DEALT_TRIGGER | 52 | BARRIER | 93 | STEALTH |
| 12 | HARMFUL_USE_TRIGGER | 53 | MISSION_TRIGGER_GAME_END | 94 | CURSE |
| 13 | HEALING_GIVEN_TRIGGER | 54 | MISSION_TRIGGER_ON_KILL | 95 | ISOLATE |
| 14 | HEALING_RECEIVED_TRIGGER | 55 | MISSION_TRIGGER_ON_USE | 96 | MISS_CHANCE |
| 15 | HELPFUL_USE_TRIGGER | 56 | MISSION_TRIGGER_ON_HEAL | 97 | DODGE_CHANCE |
| 16 | ACTION_USE_TRIGGER | 57 | MISSION_TRIGGER_ON_DAMAGE | 98 | IMMORTALITY |
| 17 | ACTION_RECEIVE_TRIGGER | 58 | MISSION_TRIGGER_ON_EXECUTE | 99 | TAUNT |
| 18 | HARMFUL_RECEIVE_TRIGGER | 59 | MISSION_TRIGGER_ON_STUN | 100 | SKILL_COPY |
| 19 | DAMAGE_RECEIVE_TRIGGER | 60 | MISSION_TRIGGER_ON_COUNTER | 101 | PARALYZE |
| 20 | HELPFUL_RECEIVE_TRIGGER | 61 | MISSION_TRIGGER_ON_IGNORE | 102 | CONTROL_CANCEL |
| 21 | END_OF_TURN_TRIGGER | 62 | MISSION_TRIGGER_ON_NEGATE_HEALING | 103 | CHANNEL_CANCEL |
| 22 | START_OF_TURN_TRIGGER | 63 | MISSION_TRIGGER_ON_GAIN_ENERGY | 104 | FALSE_STUN |
| 23 | ON_DEATH_TRIGGER | 64 | MISSION_TRIGGER_ON_DRAIN_ENERGY | 105 | SHARPSHOOTER |
| 24 | STUN_RECEIVED_TRIGGER | 65 | MISSION_TRIGGER_ON_CONSUME_STACKS | 106 | HEAL_CUT |
| 25 | MARK | 66 | MISSION_TRIGGER_ON_END_TURN | 107 | CHAIN_NULLIFY |
| 26 | UNIQUE | 67 | MISSION_TRIGGER_ON_DESTROY_SHIELD | 108 | DAMAGE_CAP |
| 27 | PAYLOAD_SWAP | 68 | MISSION_TRIGGER_ON_TRIGGER_EFFECT | 109 | HEALTH_CAP |
| 28 | COST_CHANGE | 69 | MISSION_TRIGGER_ON_PREVENT_DEATH | 110 | BANISH |
| 29 | COST_MOD | 70 | MISSION_TRIGGER_ON_SHIELD | 111 | XANXUS_STORAGE |
| 30 | TARGET_CHANGE | 71 | MISSION_TRIGGER_ON_INVULN | 112 | HEALING_RECEIVED_MOD |
| 31 | PASSIVE | 72 | MISSION_TRIGGER_ON_BLIND | 113 | NAGISA_DR |
| 32 | COUNTER_USE | 73 | MISSION_TRIGGER_ON_TAUNT | 114 | DELAY_TICK_TRIGGER |
| 33 | COUNTER_RECEIVE | 74 | MISSION_TRIGGER_ON_SHATTER | 115 | DELAY_RECEIVE |
| 34 | COUNTER_TRIGGER_NOTIFICATION | 75 | MISSION_TRIGGER_ON_NULLIFY | 116 | DELAY_MARKER |
| 35 | REFLECT_RECEIVE | 76 | MISSION_TRIGGER_ON_DR_ABSORB | 117 | DISGUISE |
| 36 | REFLECT_USE | 77 | MISSION_TRIGGER_ON_WEAKNESS_ABSORB | 118 | IGNORE_SKILL |
| 37 | INVISIBLE_EXPIRATION* | 78 | MISSION_TRIGGER_ON_SILENCE | 119 | HISOKA_HEALTH_FREEZE |
| 38 | HEALING_MOD* | 79 | DAMAGE_NULLIFICATION | 120 | DAMAGE_CAP_RECEIVE |
| 39 | DAMAGE_REDIRECT* | 80 | BLIND | 121 | IGNORE_CLEANSE |
| 40 | ABSORB_TRIGGER* | 81 | COOLDOWN_MOD | | |

\*Reading the actual enum, indices 37-40 are `INVISIBLE_EXPIRATION, HEALING_MOD, DAMAGE_REDIRECT, ABSORB_TRIGGER`; the table above is transcribed directly from `effect_type.gd:41-52`. The MISSION block occupies **53-78** (26 members), and the gameplay tail runs 79-121.

**Member groups:** value/state mods (SHIELD, DAMAGE, DAMAGE_MOD, DAMAGE_REDUCTION, PERCENT_DR, VULNERABILITY, BARRIER, STUN, INVULN, SILENCE, BLIND, TAUNT, STEALTH, BANISH...), 14+ gameplay TRIGGER types, **26 MISSION_TRIGGER_\*** (53-78), and bespoke per-character types (ERZA_ARMOR=51, XANXUS_STORAGE=111, NAGISA_DR=113, HISOKA_HEALTH_FREEZE=119).

**Static helpers** (`effect_type.gd:124+`): `silenced_effects()` (the cleanse/silence-dispellable status list — note `PERCENT_DR` appears twice, harmless), `use_or_receive_triggers()` (the 6 ACTION/HARMFUL/HELPFUL use/receive types), `stealthable_triggers()` (trigger types a stealthed char skips).

### Other enums

| Enum | File | Members |
|---|---|---|
| Element.Type | `elements.gd:3-16` | **12** (verified): BASE=0, FIRE, ICE, WATER, LIGHTNING, WIND, POISON, EARTH, HOLY, UNHOLY, SHADOW, GENERIC=11 |
| Energy.Type | `energy.gd:3-9` | GREEN=0, BLUE=1, WHITE=2, RED=3, RANDOM=4 |
| StatType.Type | `stat_type.gd:3-9` | ATTACK=0, DEFENSE=1, MIND=2, RESIST=3, SPEED=4 |
| TargetType.Type | `target_type.gd:3-9` | SINGLE=0, ALL_FACTION=1, ALL=2, COUNT=3, SELF=4 |
| EndingType.Type | `ending_type.gd:3-8` | DURATION=0, CANCELLED=1, DISPELLED=2, CONSUMED=3 |

> **Bug (verified `energy.gd:16-22`):** `Energy.get_energy_name(energy_type)` reads `Element.Type.keys()[energy_type]` — the **wrong enum**. It returns Element names (BASE/FIRE/ICE/...) for Energy values. Use `Energy.Type.keys()` directly. `Energy.get_symbol` (line 12) correctly uses `Energy.Type.keys()`.

### The Condition / Trigger / QueryContext DSL

- **`Condition`** (`condition.gd`): one field `satisfied_condition: Callable(query_context)->bool` (default true). ~30 **static factories** return composable conditions. Combinators: `always()`, `is_not(c)`, `multi([...])` (AND), `any([...])` (OR). Targeting/state: `is_invuln`, `is_alive`, `is_hostile`, `can_apply_hostile_effect`, `can_hostile_target`, `extra_targetable` (hardcodes per-character rules: Sealed King / Iron Maiden / Gibbet). Introspection: `has_effect`, `value_is`, `mag_is`, `stack_count_is`, `has_ability_class`, `is_acting_alone`.
  - `action_countered(ability, effect)` (`:247-267`) is the heart of the counter system: true when effect.user is hostile to ability.user, ability matches one of `effect.class_targets` (empty = match any), and matches **none** of `effect.exclusion_targets`.
  - **Gotcha:** `is_healable` and `is_helpable` are currently identical (`not is_isolated()`); `is_healable` has a TODO (`condition.gd:85`) — heal-ban is not yet enforced here.

- **`Trigger`** (`trigger.gd`): `{condition: Condition, payload: Callable}`. Constructors `from_condition(cond, payload)`, `always(payload)`. `check(context)` runs `payload.call(context)` iff `condition.satisfied(context)`, returns whether it fired.

- **`QueryContext`** (`query_context.gd`): the universal data bus, fields `{owner, target, battle, ally_team, enemy_team, id, effect, source=0, value, won, damage_type}`. **Never constructed via `.new()` by callers**; five factories populate subsets and always resolve teams via `battle.get_team_factions_from_character(owner)` → `[ally_team, enemy_team]`:
  - `from_game_state(owner, match)` — ability execute time.
  - `from_counter_check(targeter, target, effect, match)` — counter dispatch.
  - `from_effect_end(effect)` — effect expiry/tick; sets **both** `source=effect` and `effect=effect`.
  - `from_trigger_source(source, trigger, target, value=0)` — main gameplay-trigger factory.

> **FOOTGUN — field-name inversion:** in `from_trigger_source`, the trigger-bearing `Effect` lands in `context.effect`, while the originating Ability/Effect lands in `context.source`. Payloads read `context['effect']` to get the effect carrying themselves. Also: `source` defaults to integer `0` (not null); `damage_type`/`won` are **not** set by any factory — callers assign them after construction (e.g. `character_component.gd:1138 context.damage_type = damage_type`).

---

## 6. The Effect System + Factory Reference

Every status, buff, debuff, DoT, shield, trigger hook, and bookkeeping flag is an **`Effect`** (`scripts/effect_component.gd`, `class_name Effect extends Node`). The system is **polymorphic-by-enum, not by subclass**: there is exactly one `Effect` class, and its `effect_type` (an `EffectType.Type` value) determines how every consumer interprets it.

### Construction pattern
Effects are never `new()`'d. ~60 **static factories** each `load("res://components/effect_component.tscn").instantiate()` (so effects are real scene-tree Nodes), set `effect_type` + fields + a `description` Callable, and call `set_duration(dur)`.

```gdscript
var e = Effect.shield_effect(50, 3)   # build
e.set_source(self)                    # bind (MANDATORY)
Character.add_allied_effect(context, user, target, e)   # apply
```

> **`set_source(self)` is mandatory** and does triple duty (Sections 3 & 5 both flag this as the #1 authoring bug): it copies `nsource.user → effect.user` (team ownership), sets `effect.source` (used by `effect_name()` → `source.ability_name`, the stacking/removal key), and loads the tooltip icon. `effect_name()` is called inside `add_effect`/`has_effect`/`cleanse` — a missing source **null-crashes immediately** with no validation.

### Factory reference (selected)

| Factory | EffectType | Notes |
|---|---|---|
| `damage_effect(dmg, type=NORMAL, dur=1, use_source=true)` | DAMAGE | DoT; ticked by `execute_ticking_effect` → `resolve_effect_damage` |
| `healing_effect(heal, dur)` | HEALING | HoT; skipped if target isolated |
| `trigger_effect(trig, type, dur=1, desc)` | (any trigger) | workhorse; sets `waiting=true` if type ∈ `use_or_receive_triggers()` |
| `counter_effect(cb, type, dur, desc, class_targets=[], exclude=[])` | COUNTER_USE/RECEIVE | class/exclusion gating |
| `reflect_effect(...)` | REFLECT_* | stores reflect target in `mag`, use-count in `stacks` |
| `shield_effect(mag, dur, display=true)` | SHIELD | `display` arg couples stackable+stack_mag+display_mag |
| `barrier_effect(mag, dur)` | BARRIER | "Nullify" in UI; stackable. **OUTGOING-damage reduction on the HOLDER** (a reverse-Shield) — `check_damage_against_barriers` reads the *attacker's* barriers (`:592`), so placing Nullify on an enemy makes *their* attacks hit softer. Not a defensive shield. |
| `damage_reduction_effect(mag, dur)` | DAMAGE_REDUCTION | flat |
| `percent_dr(mag, dur, unpierceable=false)` | PERCENT_DR | `damage *= (100-mag)/100`; **`unpierceable` arg is silently dropped** |
| `damage_mod_effect(mag, dur, targets, class_targets, exclusion, type_targets)` | DAMAGE_MOD | outgoing +/- |
| `vulnerability_effect(...)` | VULNERABILITY | inbound mirror |
| `damage_null_effect(mag, dur)` | DAMAGE_NULLIFICATION | multiplicative output cut |
| `damage_cap(cap,dur)` / `damage_cap_receive(cap,dur)` | DAMAGE_CAP/_RECEIVE | clamp single hit |
| `stun_effect(dur, class_targets=[], exclude=[])` | STUN | `remove_on_death=false` |
| `false_stun`, `paralyze_effect`, `silence_effect`, `isolate` | FALSE_STUN/PARALYZE/SILENCE/ISOLATE | |
| `invuln_effect(dur, class_targets, exclude)` | INVULN | scope by damage class |
| `immortality_effect`, `ignore_damage_effect`, `ignore_effect_effect`, `ignore_cleanse_effect` | IMMORTALITY/IGNORE_* | `ignore_effect_effect`'s `helpful_only` arg is unused |
| `taunt_effect(dur, user)` | TAUNT | forces targeting onto user |
| `mark(dur, desc)` | MARK | `skill_seal` bool blocks ability use — explicitly NOT a stun |
| `heal_cut(mag,dur)` / `healing_mod_effect` / `healing_received_mod_effect` | HEAL_CUT/HEALING_MOD/HEALING_RECEIVED_MOD | |
| `cost_mod_effect`, `cost_change_effect`, `color_change_effect`, `cooldown_mod` | COST_MOD/COST_CHANGE/COLOR_CHANGE/COOLDOWN_MOD | |
| `delay_eff`, `delay_receive_eff`, `delayed_skill_eff`, `delay_target_marker` | DELAY/DELAY_RECEIVE/DELAYED_SKILL/DELAY_MARKER | DELAYED_SKILL fires its stored skill when duration hits 1 |
| `xanxus_storage_effect`, `erza_armor_effect` | XANXUS_STORAGE/ERZA_ARMOR | erza's `effect_name()` returns `mag` (armor name) |
| `from(eff_type, kwargs=[])` | (any) | generic escape hatch; `.set()`s each kwarg |

### Storage, stacking & duration
- **`add_effect(effect, prepend)`** (`effect_storage_component.gd:19-50`): matches existing by `(name, type, user)`. If matched and `stackable`: if `stack_mag`, `mag += incoming.mag` and `stacks += stack_count()`; if a use/receive trigger, sets `fresh_stack=true`. Else if `refresh`: remove old + append new (resets duration). Else append a new instance. **`refresh` and `stackable` are mutually exclusive branches** — if `stackable`, `refresh` is never consulted.
- **`has_effect(name, type, user=null)`**: `user==null` is a **wildcard**.
- **Duration**: `set_duration` stores `dur`. `tick_effect()` (`:1216-1224`) early-returns if `duration==-1` (permanent), else decrements and calls `end_effect()` at `<=0`. `end_effect`'s **default ending_type is CANCELLED**, which is the **only** type that runs `wrapup_func` — so natural expiry DOES run wrapup. `EndingType` naming is misleading vs. usage.
- **Per-turn flag reset** (`tick_all_effects_durations`, `:263-271`): **before** ticking, resets `waiting=false, fresh_stack=false, triggered=false` on every effect, then `tick_effect()`. Banished characters skip this reset and only tick BANISH + `tick_during_banish` effects.

### Trigger firing & the `triggered` guard
Pipelines fetch effects by type and loop `eff.trigger.check(context)`. Most loops `if eff.triggered: continue`, so a trigger fires at most once per turn (re-armed by the per-turn reset). **Exception:** `check_damage_taken_triggers` (`character_component.gd:1174-1175`) **comments out** the guard, so `DAMAGE_RECEIVE_TRIGGER` fires on every instance of damage taken. `TICKING_TRIGGER` is an on-owner-turn engine: gathered in `get_ticking_effects` and run by `execute_ticking_effect`; `dur=-1` makes it a permanent per-turn engine (Asta's Liebe Unite, Vegeta Ki Blast).

### Cleanse & visibility
- Cleanse functions (`:69-141`) **bail returning 0 if target has any IGNORE_CLEANSE effect**. They keep an effect unless it is hostile/ally AND `cleansable` AND its type ∈ `silenced_effects()`. So DoTs, all triggers, MARK, DELAYED_SKILL, ISOLATE, PARALYZE, STEALTH, CURSE survive a cleanse by type alone.
- `get_effect_clusters` (`:226-256`) **silently drops `system` effects and unrevealed `invisible` enemy effects** — an effect can be fully active in logic yet absent from the tooltip UI (debugging "missing" icons → check `system`/`invisible`). Toph reveals invisible Physical effects; Kurotsuchi's Data Collection reveals all invisible enemy effects.

### Passive-client mirror
`DisplayEffect` (`display_effect.gd`) is a lightweight RefCounted reconstruction of an Effect from a wire `EffectPayload`, used to render `_display_effects` on passive multiplayer clients (the Node-based Effect with its Callables/Trigger can't be rebuilt from wire data). Game logic only ever touches `_effects`.

---

## 7. The Battle Engine

The live engine is `BattleManager` (`new multiplayer/battle_manager.gd`, ~3006 lines). `BattleScene` (`battle_scene.gd`) is a thin display wrapper whose properties (`player`, `enemy`, `gamestate`, `match_type`) are getters delegating to `manager` (`:79-96`). **`character.battle` IS the BattleManager**, not the scene.

### 7.1 Turn lifecycle (simultaneous-selection, alternating-resolution)
Exactly **one team acts per turn**. The acting player queues an action per affordable living character (3 max), then ends the turn.

- **Match start** (`start_battle`, `:215-315`): resets bookkeeping, sets `passive = not shadow_mode and m_type != BOT`, seeds RNG, resets energy, `character.initialize(true)` + `startup(self)`, `startup_passives` (non-passive; Semiramis last by special rule). If `first` → `start_new_turn(true)`; else `went_second=true; waiting_for_turn=true; wait_for_turn()`.
- **`start_new_turn(first)`** (`:456`): local player's turn — increment turn, fire START_OF_TURN_TRIGGERs (both teams), generate team energy, `refresh` every character, `gamestate=OPEN`, emit `turn_started(true)`.
- **`wait_for_turn`** (`:506`): opponent's turn — `gamestate=CLOSED`, emit `waiting_for_opponent`; if bot, request a bot turn.
- **`turn_over`** (`:544`): clears `action_order`, checks match-over, alternates turn.
- **Action selection**: `receive_ability_use_request` → targeting → `receive_character_use_request` appends to `action_order` (`:597-624`) → `finalize_action`/`other_character_clicked` calls `team.pay_for_ability` (reserve cost) and sets `waiting=true`. **`acted` is set at EXECUTION time** (`execute_ability:1111`), NOT selection — don't confuse `acted` with `waiting`.
- **End turn** (`turn_end_clicked`, `:655`): builds `execution_order` dict (keys 0-2 = acting-team slots, 3+ = ticking-effect batches via `get_ticking_effect_information`), pops the RANDOM-energy allocation panel; `allotment_accepted` (`:688`) sets `true_execution_order` and runs `start_round_loop → execution_loop_step`.
- **Execution loop** (`:903`/async `:1016`): pops `true_execution_order` (player-chosen order), coerces id type to match dict keys, runs `execute_step` (Ability → `execute_ability`; Array → ticking batch sorted by `twin_priority`). Calls `check_match_over()` after **every** step. A reentrancy guard `_execution_loop_active` prevents double-draining.
- **`execute_ability`** (`:1078`): skips if stunned/dead/banished; logs use; `start_cooldown()`; blind retarget; taunt resolution; delayed-skill deferral; channel cancellation. Then the gate: if NOT `countered` → `reflect_check` → `accuracy_check` (dodge removes targets) → `ability.execute` → `check_ability_use_triggers` → `acted=true`.

### 7.2 Energy economy
4 storable colors **GREEN/BLUE/WHITE/RED** + **RANDOM** (cost token only, never stored — `change_energy(RANDOM)` push_errors).

- **Gain**: `generate_team_energy` (`:1244`) — each living, non-banished character `generate_energy()` rolls one color (3-char team → 3 energy/turn). **First turn generates only 1 energy total** (`:1250`).
- **Two-phase spend** (CONSISTENT across §2/§4/§7): `pay_for_ability` reserves cost into `promised_pool` at selection; the real `pool` is drained at submit via `receive_generic_allocation_offer`. `total_available()` = Σpool − Σpromised − promised[RANDOM] (`energypool.gd:47-53`). The RANDOM-cost portion is allocated by the acting player via the allocation panel; the **bot blindly rolls colors** for RANDOM (`player_component.gd`, with a TODO noting no strategic color choice).
- **Exchange** (`accept_exchange`, `:1264`): trade N of some colors for 1 chosen color; requires ≥2 of some color and ≥2 total available.

### 7.3 Damage pipeline — VERIFIED order

> **CONTRADICTION RESOLVED (VERDICT 2 — claim REFUTED).** The intuitive "triggers first → modifiers → reduction → ... → HP" order is **wrong**. The real order spans three functions:

**Step 1 — `resolve_damage(context, target, pre_mod, type)`** (`character_component.gd:1868`):
- `mod_damage = owner.used_ability.get_true_damage(...)` — **damage MODIFIERS applied FIRST**. `get_true_damage` (`ability_component.gd:489`) iterates `DAMAGE_MOD` effects (`mod_damage += boost_mag * modifier_value`, filtered by class/exclusion/ability/type targets, per-stack), clamps `<0 → 0`, then applies VULNERABILITY.
- Floor at `ability.minimum_damage`.
- **INVULN / ignore-damage check** (`is_ignoring_damage`, `:1875`) — if invulnerable, `deal_ability_damage` is never called (Terror Incarnate / Ultimate Nightmare reflect marks handled here).

**Step 2 — `deal_ability_damage(...)`** (`:501-631`), in this exact sequence:
1. CHAIN_NULLIFY zero-out (`:504`)
2. `check_damage_nullification` (multiplicative `×(1−mag)`) (`:510`)
3. Nirvana/Plasmantle conversions → self-barrier/shield and return (`:514-530`)
4. damage CAPS — deal-side `get_damage_cap()` + receive-side `get_damage_cap_receive()` (`:535-549`)
5. DAMAGE_REVERSE → convert to healing and return (`:551`)
6. flat affliction/esdeath reductions (`:556-565`)
7. Saturn Crystal / Silence Wall halve + redirect (`:568-589`)
8. **BARRIERS / "Nullify"** `check_damage_against_barriers(…, self)` (`:592`) — reads the **ATTACKER's** barriers → reduces *outgoing* damage (a reverse-Shield; Nullify on an enemy weakens their hits). *skipped for AFFLICTION/BLEED*
9. **SHIELDS** `check_damage_against_shielding(…, target)` (`:593`) — reads the **TARGET's** shields → absorbs *incoming* damage (the defensive layer). *skipped for AFFLICTION/BLEED*
10. flat **DAMAGE_REDUCTION** (`:596`) — *skipped for PIERCING/TRUE or def_broken*
11. **PERCENT_DR** (`:597`) — same guard
12. DAMAGE_REDIRECT split (`:599`)
13. Heavenly Intervention (`:604`)
14. `target.receive_ability_damage(...)` (`:614`)

**Step 3 — application & triggers**: `receive_ability_damage` (`:384`) → `receive_damage` (`:440`) → `health.modify_hp(-damage)` (`health_component.gd:22`) — **HP is reduced HERE**. Then:
- `check_damage_taken_triggers` (DAMAGE_RECEIVE_TRIGGER) fires **AFTER** HP reduction (`:393`).
- Back in `deal_ability_damage`, `check_damage_dealt_triggers` (DAMAGE_DEALT_TRIGGER, XANXUS wrath) fires **LAST**, after everything (`:631`).

**Key corrections:** modifiers + invuln are FIRST (not middle); barriers/shields come BEFORE flat/percent DR; HP is reduced BEFORE receive-triggers; **dealt-triggers are LAST, not first**. `deal_effect_damage` (`:633`) mirrors this but **skips** Nirvana/Plasmantle/Heavenly-Intervention and uses `receive_effect_damage`.

### 7.4 Healing pipeline
`resolve_healing`/`resolve_effect_healing` (`:1907-1918`) → `get_true_healing` (currently passthrough) → blocked if `target.is_isolated()` → `give_*_healing` (bail if `heal_blocked`/dead/banished, CHAIN_NULLIFY zeroes) → apply HEAL_CUT (`×mag/100`) → `receive_healing` (`:928`) applies HEALING_RECEIVED_MOD, clamps to `(modified_max_hp − hp)`, `modify_hp(+)`, emits signals, runs `staunch_bleeding()` (**any heal erases BLEED damage effects**), fires HEALING_GIVEN_TRIGGER / MISSION_TRIGGER_ON_HEAL.

### 7.5 End-of-turn ticking & durations — VERIFIED timing model
> **Critical subtlety:** DoTs/HoTs do **NOT** apply during duration ticking. They are queued as ticking-effect Array steps at `turn_end_clicked` and **execute INSIDE the execution loop** (player-chosen order), via `execute_ticking_effect` (`:1123`). The **duration decrement happens AFTER** the loop. So an effect can tick its DAMAGE this turn **and** have its duration decremented the same turn.

`end_of_turn_effect_handling` (`:1220`) order:
1. emit `turn_ended_event`; reset targeting.
2. dead/banished chars: `check_cancels` + clear non-system effects.
3. acting team's living chars: `moveset.advance_cooldowns` (decrement cooldown_remaining by 1; **blocked if paralyzed**) then `check_end_of_turn_triggers` (END_OF_TURN_TRIGGER).
4. `tick_durations()` — every char `effects.tick_all_effects_durations()` (resets per-turn flags, decrements each `duration`, ends at ≤0; banished chars only tick BANISH + `tick_during_banish`).
5. `turn_over()`.

**Cooldowns:** `start_cooldown()` sets `cooldown_remaining = cooldown + 1` at execution; `advance_cooldowns` decrements by 1 at end of the acting team's turn — the `+1` compensates for the same-turn decrement. Paralyzed users skip advance AND get `start_mod=0`.

### 7.6 Win conditions
`check_match_over` (`:1611`), checked after every execution step and at `turn_over`:
- **Loss** = ALL `player.team.characters` dead-or-banished.
- **Win** = ALL `enemy.team.characters` dead-or-banished.
- `end_match(won: bool)` (`:1635`) — plain boolean, **no match-level EndingType enum**. Applies rank/AP (non-PRIVATE), fires game-end triggers, saves missions/bounties/player.

### 7.7 Passive vs active execution
> **Two answers to "how damage works."** When `passive` is true (any non-BOT client match), the local manager does **not** simulate: `roll()` returns 0, `die()` early-returns, `start_new_turn` skips triggers/energy gen, and authoritative state arrives via `apply_turn_result`/`apply_match_state` events. The entire damage/effect/energy machinery in §6-7 runs **only** on the bot/active path and the server shadow (`shadow_mode`); a passive client replays a wire event stream. Bot matches (`match_type==BOT`) run fully local/active.

### 7.8 Surrender & timeout (client/bot side)
The networking section (§10) covers server-side surrender/timeout. On the **client/bot** side: `battle_manager.gd` has `send_surrender`/`bot_surrender_triggered` signals, `bot_wants_surrender()` (`:561`), a bot self-surrender roll (`:538-539`), and `receive_surrender()` (`:1911`). Match-level turn timeout is 120s with a 3-strike cancel (`Match.handle_turn_timeout`, `match.gd:347-386`); the timer is **paused** when the acting player disconnects and resumed on reconnect.

---

## 8. Ability Authoring Contract + Registration Recipe

Every skill is `extends Ability` (base class `abilities/scripts/ability_component.gd`, `class_name Ability extends Node`). The git-DELETED `abilities/ability.gd` was an old `extends Resource` ancestor — **a red herring, don't cite it**.

### Static metadata lives in JSON, not the .gd
`Ability.from_database(path)` (`:98-161`) reads `abilities_data.json`, `load(script_path).new()`, then injects `ability_name`, `_cost` (integer-keyed), `cooldown`, `_target_type`, `image`, `classes` (boolean dict flipped from the JSON string array), optional `mastery_*`, and flags `and_targeter`/`selfless`/`stunnable`/`accurate`/`important`/`invisible`. **Editing cost/cooldown in the `.gd` does nothing — edit the JSON.** (Matching `@export` vars exist on the base class but `from_database` overwrites them; a few scripts mutate `cooldown` at runtime for gameplay, e.g. `blackstar1.gd:26`.)

### Virtual methods authors override
`execute(user, battle)`, `target(user, battle)`, `describe(user)` / `split_desc()`, `extra_usable(user)`, `custom_behavior(context)` (bot AI), `and_target(character)`.

### Execute idiom
```gdscript
func execute(user, battle):
    var context = QueryContext.from_game_state(user, battle)
    for target in user.targeter.targets:
        Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
        var eff = Effect.stun_effect(2, [], ['Mental'])
        eff.set_source(self)
        Character.add_hostile_effect(context, user, target, eff)
```

### Targeting
`target(user, battle)` marks legal targets via `set_targeted()`. Defaults (`:645-661`): `default_hostile_target_function`, `default_allied_target_function` (respects `selfless`), `default_self_target_function`. `_target_type` (TargetType) drives splash auto-collection (`ALL`/`ALL_FACTION`) after the player picks a main target; `and_targeter` adds targets where `and_target(character)` returns true — **but `and_target` defaults to false**, so `and_targeter:true` in JSON does nothing without an override.

### Usability gate
`usable(user)` (`:342-374`) checks affordability, delay, `waiting_for_turn`, cooldown, stun (if `stunnable`), already-acted, banish, skill-seal MARKs, then `extra_usable(user)`. A server-side `authoritative_usable` omits the client-only `waiting_for_turn` check.

### Descriptions — `split_desc` supersedes `describe`
`ability_description_panel.gd:27-46` checks `split_desc() != []` **first**; if non-empty, `describe()` is dead for the panel. **Edit `split_desc` when it exists.** `split_desc()` returns lines that are plain `String` or `[text, Color]` pairs.

### Damage-class vs ability-class gating (footgun)
> Two different matching domains share similarly-named fields. `DAMAGE_MOD.class_targets` is matched against the **damage_type enum** (`ability_component.gd:489-605`), while a counter's `class_targets` is matched against the **ability's CLASSES dict** (Physical/Energy/Mental/Affliction/Strategic/Harmful/... from JSON). Don't conflate damage-type-class gating with ability-class gating.

### Registration recipe (3 coordinated edits + naming rule)
> **VERDICT 3 (partial) — the moveset wiring step is corrected.** The live moveset is **fully data-driven**; you do **NOT** hand-edit a `base_abilities` array.

1. **Create** `abilities/<path_name><next_index>.gd` extending `Ability`, overriding `execute`/`target` (e.g. `asta5.gd`).
2. **Add** a matching entry in `abilities_data.json` keyed `"<path_name><index>"` with `script_path`, `cost`, `cooldown`, `target_type`, `classes`, `name`, `image_path` (and optional `mastery_*`, `description`). The JSON `description` is **authoring-only documentation** — runtime descriptions come from `describe()`/`split_desc()`.
3. **Bump** the count in `character_ability_counts.json` so the loader reaches it.

The loader: `Character.initialize(true)` → `Movesets.from_skill_count(self)` (`movesets.gd:25-37`) reads the count, then loops `Ability.from_database(path_name + str(i+1))` for i in 0..count-1. **There is no separate moveset-array edit** — the `<name>_moveset()` functions in `movesets.gd` and per-ability `.tscn` loading are **dead legacy** (only `ability_component.tscn` exists; 896 `.gd` files, 1 `.tscn`).

### Hidden alts & swaps
Slots 0-3 are the visible action bar; slots 4+ are hidden alts used as `ABILITY_SWAP`/`SKILL_COPY` payloads (referenced **by index** into `base_abilities`) or passives. `Effect.ability_swap_effect(4, 0, user, 3)` swaps hidden index-4 into visible slot 0. **Reordering a moveset silently breaks every index-based swap** (cooler1.gd warns base_abilities[5] must stay stable).

### Bot AI hook
`custom_behavior(context)` returns `[[priority, [user, ability_or_'PASS', [targets]]], ...]` built from ~25 `behavior_*` helpers. **This is bot-only** — a broken `custom_behavior` still works fine for human players.

---

## 9. Bot AI & Training

Three bot brains share one execution path:

1. **Priority/heuristic bot** — `Ability.custom_behavior` returns scored variations; `Character.get_action(bot_difficulty)` (`:1828`) collects the best variation per ability, adds `randi_range(-bot_difficulty, +bot_difficulty)` jitter, picks the highest. Top helpers: `behavior_single_target_damage` (260 uses; prefers low-HP targets), `behavior_self_panic_button` (211 uses; only fires when hurt), `behavior_hostile_aoe_damage`.
2. **Flat win-rate tracker** `BotTrainingData` — Laplace-smoothed `(wins+1)/(uses+2)`; used only with `--no-contextual`.
3. **Contextual-bandits model** `BotContextualModel` — the **live brain**. Per (char, ability) weight vectors dotted against board-state features.

> **`bot_difficulty` is INVERTED:** it is the jitter amplitude. **Higher = noisier = weaker.** Training uses 70; live bots use the default 35.

### Live decision path (`_contextual_bot_act`, `player_component.gd:901`)
A single `randf()` dispatches to a 5-mode **mixture** via cumulative thresholds `_MIX_PASS_UPPER=0.01`, `_MIX_RANDOM_UPPER=0.02`, `_MIX_EXPENSIVE_UPPER=0.03`, `_MIX_PRIORITY_MODEL=0.30`:

| Range | Mode | ~Prob |
|---|---|---|
| <0.01 | PASS | 1% |
| <0.02 | uniform random | 1% |
| <0.03 | most-expensive ability + model-best target | 1% |
| <0.30 | **legacy priority bot** (`get_action`) | ~27% |
| ≥0.30 | **model argmax** ability + target | ~70% |

> **STALE-COMMENT TRAP:** the doc-comment at `player_component.gd:561-573` claims 5/5/30/30/30. The actual constants give ~70% model / ~27% priority. Trust the constants. (Section 2 describes the same code without percentages — don't let it lead you to the stale comment.)

Within a turn, characters are ordered by `_best_ability_score` (highest-confidence actor claims energy first). The live BEST branch uses **argmax** (`_argmax_model_ability/target`), **not** the softmax/epsilon-greedy/annealing samplers that also exist (`pick`, `pick_annealed`) — those are effectively off the hot path.

### Features
17-d ability vector (`bot_contextual_model.gd:89`, indices 0-7 macro state, 8-13 threat/burst/turn/hp-lead, 14-16 per-candidate cost/color-starvation/burst-break) + 13-d target vector. **Feature arrays are APPEND-ONLY** — reordering silently corrupts saved weights; `_migrate_feature_dimensions` zero-pads shorter saved vectors.

### Training (offline self-play)
`run_bot_training.ps1`/`.sh` launch Godot `--headless` on `test_scene.tscn` (root `TestBattleHeadless`). Matches run through `BattleManager` with `shadow_mode=true` (synchronous, no animation pacing). After each match, `commit_match(winner, reward)` applies a REINFORCE update `w += lr * reward * features` (+reward to winner's recorded actions, −reward to loser's), `lr = 0.05/(1+updates/200)`. `reward` is HP-margin-scaled in [0.5, 1.5] (`_compute_hp_margin_reward`) — blowouts teach harder than squeakers. **Credit assignment is blunt:** every winning action gets +reward, every losing action −reward, no per-action attribution.

CLI flags: `--matches`, `--variety`, `--save-interval`, `--no-contextual`, `--eval`/`--eval-b`, `--vs-priority`, `--vs-random`, `--anchor` (synergy sweep), `--p1/p2-team`. Persistence: `bot_contextual_model.json` (real brain, ~1.4 MB), `bot_training_data.json` (flat fallback), `bot_records.json` (legacy tally from the DEAD `bot_battle_scene.gd`).

---

## 10. Networking / Multiplayer / Replays

**Transport: WebSocket** (`WebSocketMultiplayerPeer`, NOT ENet). The headless Godot binary IS the authoritative server (peer id 1). `NETWORK_MODE` is a **compile-time constant** (`server_connection.gd:11`) — local testing requires recompiling.

### RPC protocol
`components/server_connection.gd` (~2396 lines) runs on both sides. Client methods wrap `rpc_id(1, "receive_*"/"submit_*", ...)`; server `@rpc("any_peer")` handlers run authoritative logic and reply `rpc_id(peer_id, "receive_*", ...)`. Handlers gate on `get_session(peer_id)` and resolve the match via `session.current_match` (never a client-supplied id).

- **Login** (`:404-471`): **passwords are PLAINTEXT** — `player_data['pass_hash'] == password` with the raw password. No hashing/salting; the client keeps `_stored_password` in memory for auto-reconnect.
- **Sessions/reconnect**: `ServerSession` per user. On disconnect, a 120s grace timer before auto-surrender. Tab-away reconnection without re-login via `request_session_validation`. **Two liveness checks**: 10s client heartbeat + 15s server ping/pong (the latter exists because Godot does NOT fire `peer_disconnected` for a frozen-but-TCP-alive browser tab).
- **Matchmaking**: quick = **first-two-in-queue, no skill matching**; ranked spirals tier-by-tier (`find_nearest_ranked_player`); private = keyed by target username. **No live ban/pick draft phase** despite `accept_ban`/`accept_pick` existing.

### Server-authoritative turn pipeline ("Phase 7")
The server runs a hidden **shadow `BattleManager`** (`shadow_mode=true`) per match inside `Match` (`match.gd:99-128`). Flow:
1. Client `BattleManager.build_turn_input` (canonical-frame) → `send_turn_input` → `submit_turn_input` (`:1706`).
2. Server `Match.validate_input` (`match.gd:176-252`): enforces sender == `acting_player`, char/ability indices in range, not dead/cooldown/stunned, targets in bounds, total cost affordable (handles RANDOM substitution).
3. `Match.apply_input` → `_canonical_input_to_legacy_package` → `manager.receive_turn_package`.
4. `_broadcast_turn_result` (`:1335`): ships `event_recorder.events` + `serialize_wire_snapshot()` via `apply_turn_result` to both clients + spectators.
5. Clients run their own passive `BattleManager` consuming only the event stream → `_reconcile_to_snapshot`. **Passive clients read server-resolved `cost`/`usable`/`special_targets`/`target_type` verbatim** because their local `_effects` are empty.

Canonical seat ordering is load-bearing: `players.keys()[0]` is always p1, `[1]` p2; `check_in_player` preserves key order on reconnect to avoid flipping roles.

### Replays
`MatchEventRecorder` subscribes to shadow-manager signals → wire-event dicts. `MatchReplayLog` records initial snapshot + per-turn `(events, snapshot)` → `.replay` JSON (version 1). **Replays are NOT persisted server-side** — `pending_replays` is in-memory, discarded on session wipe; the client must request + download (`JavaScriptBridge.download_buffer` on web). Playback via `MatchReplayPlayer` re-feeds turns into a spectate-mode `BattleManager`.

### Vestigial / dormant
- `_advance_shadow` + `report_state_hash` (Phase-2 desync hashing) — `_advance_shadow` has **zero callers**.
- `send_match_ending`/`report_match_ending` — survive only for client-side BOT matches.
- **Spectating** is fully server-implemented (`submit_spectate_request`, init package, ongoing broadcast) but **no client UI invokes `send_spectate_request`** — dormant.
- `components/server_connection_old.gd` — fully dead (zero references).

---

## 11. Meta-Progression Systems

Central object: `Player` (`player_component.gd`) carries `ap`, `unlocks`, equipped cosmetics, `rank`, `character_progress`, `active_bounties`/`bounty_rerolls`, `clan`. `save()`/`load_player()` serialize to `ausers/<username>.dat` (one JSON line).

| System | File(s) | Mechanic |
|---|---|---|
| **Mastery** | `mastery_config.gd`, `character_progress.gd`, `mastery_db.gd` | Per-character XP: +100/win, −40/loss (floored 0). 101-entry `XP_THRESHOLDS`, max level 100. Cosmetic unlocks: playercard L3, action_frame L5, hat L8, elite L12, mastery portrait L15, mastery skin L20. **SQLite `mastery.db` is a denormalized read-index; JSON `mastery_xp` is the source of truth** — `backfill_from_players` rebuilds the DB from JSON every boot. `clan_name` is NOT in the DB (looked up live). |
| **Stats** | `stats_manager.gd`, `match_record.gd` | Records non-private, non-bot matches: `stats/matches/<id>.json` + per-char aggregate `.stats`. |
| **Bounties** | `bounty.gd`, `bounty_panel.gd` | Deterministic 5×5 bingo of 25 win-conditions, seeded by `hash(username+path+rerolls)`. Complete any line → unlock a character OR +5000 AP + 1000 XP. **The actively-used objective system.** |
| **Missions** | `missions/` | Trigger-objective framework — **DORMANT**: `all_missions()`/`mission_list()` return empty; `mission_data` not persisted; `save()` writes `missions={}`. |
| **Clans** | `clan.gd` | LEADER/OFFICER/MEMBER; wins-based levels. Clan wins increment only between different non-Clanless clans. |
| **Shop/Cosmetics** | `shop_panel.gd`, `cosmetics_menu.gd`, `character_cosmetic_set.gd` | Spend AP (750-1000) on cosmetics/character unlocks. |
| **Ranking** | `rank_component.gd`, `Rating.gd` | 8-tier `Rank` enum + Elo-like `Rating` (floor 1000). **Tier promotion is DISABLED** — `rank_up()` is commented out; only deranks work. |
| **Draft** | `color_balanced_draft.gd`, `draft_scene.gd` | `ColorBalancedDraft` scores bot teams by energy-color coverage (LIVE). `DraftScene` pick/ban UI appears **unwired**. |

> **Cross-cutting insight:** the **26 MISSION_TRIGGER_\* effect types (53-78)** and their dispatch path in `character_component.gd` feed the **dormant** missions system — half the trigger taxonomy currently fires into a void, while live progression (bounties) uses a separate deterministic-bingo mechanism with no trigger hooks.

> **Economy is largely client-trusted:** bounty reroll (1500 AP), mastery-complete rewards, and shop purchases are applied **client-side** then absorbed wholesale by the server (`absorb_cosmetic_update`). Only `wins`/`losses`/`rating` are server-authoritative and refused from client payloads.

---

## 12. UI Architecture

The game never swaps scenes — `game.tscn` toggles child node visibility (`show_scene`/`hide_scene` + `current_scene = X`, `game.gd`). UI panels subscribe to manager/server signals.

- **`battle_scene.gd`** — display shell; forwards input to `manager`, reacts to manager signals for sound/UI/panels.
- **`ability_description_panel.gd`** — `split_desc` supersedes `describe` (§8); colored sub-labels (Color.CADET_BLUE conditional, ORANGE_RED debuff, DIM_GRAY passive).
- **`effect_container_component.gd`** / **`effect_tooltip.gd`** — rebuild from `get_effect_clusters(get_renderable_effects())`; reads `display_mag`/`display_stacks` for the number badge. (System/invisible effects silently absent — §6.)
- **`leaderboard_panel.gd`** — tabs RATING/MOST_WINS/WIN_STREAK/CLANS/CHARACTER, fed by server RPCs. `ladder_panel.gd` is an older simpler view.
- **`cosmetics_menu.gd`** — builds equippable pools from owned unlocks (parsed by `_`-prefix) + mastery-derived cosmetics.
- **`replay_list_panel.gd`** — loads `.replay` via web `<input type=file>`+`FileReader` or native `FileDialog`.
- **`ui/help/`** — `help_data.gd`/`help_overlay.gd` in-game help (data in `help_pages.json`); a live feature per recent git history ("add the help").
- **`DescriptionAnimator`** — note (per project memory): for a **separate tutorial interface only**; do not swap it into existing description panels.

---

## 13. GOTCHAS & Dead-Code Map (live vs dead, with proof)

> The single biggest footgun: the repo has **three parallel battle implementations** plus `_old` UI duplicates. Editing a dead file compiles cleanly and changes nothing in-game.

### LIVE (edit these)
| File | Proof |
|---|---|
| `scripts/battle_scene.gd` | attached by `battle_scene.tscn:3`, instanced by `game.tscn:186` |
| `new multiplayer/battle_manager.gd` | `battle_scene.gd:124` + `match.gd:110` (VERDICT 1) |
| `scripts/character_component.gd`, `player_component.gd`, `effect_component.gd` | core engine |
| `abilities/scripts/ability_component.gd` | `class Ability extends Node`; every ability `extends Ability` |
| `components/server_connection.gd` | `game.tscn:5` (non-`_old`) |
| `components/match.gd`, `match_event_recorder.gd`, `match_replay_*.gd` | reachable from live server |
| `new multiplayer/bot_contextual_model.gd`, `scripts/color_balanced_draft.gd` | used by `battle_manager.gd`/`player_component.gd`/`char_select_scene.gd` |
| `scripts/character_database.gd` | the real registry |

### DEAD (do not edit — zero live references)
| File | Why dead |
|---|---|
| `scripts/battle.gd` (class Battle) | instanced only by dead `new_battle_scene.gd:81` |
| `scripts/new_battle_scene.gd` / `scenes/new_battle_scene.tscn` | instanced by nothing |
| `scripts/bot_battle_scene.gd` / `scenes/bot_battle_scene.tscn` | bot matches use the live path; writes `bot_records.json` via old priority bot |
| `abilities/ability.gd` | DELETED old `extends Resource` ancestor (red herring) |
| `scripts/characters.gd` | empty stub, NOT the registry |
| `new multiplayer/battle_display.gd`, `test_battle*.gd`, `test_scene.tscn` | scaffolding (test harness may run manually) |
| `components/server_connection_old.gd` | near-complete copy of the live server, 0 refs |
| `ui/*_old.{gd,tscn}` (nexus_panel, shop_panel, cosmetics_menu, character_cosmetic_set, shop_button, nexus_leaderboard_list_node, nexus_universe_node, mastery_list_row) | 0 live references |

### Red herrings
- **`BattleScene.Match.*`** in many live files is just an **enum lookup** on `class_name BattleScene` (`battle_scene.gd:27-32`), not a scene load. Don't infer aliveness from it.
- **`new multiplayer/` mixes live and dead** — `battle_manager`/`bot_contextual_model` live; `battle_display`/`test_*` dead.

### Other gotchas (consolidated)
- **Enum ordinals are the persisted/wire integers** — append-only or corrupt saves + desync (§5).
- **`set_source()` mandatory on every effect** or null-crash (§6).
- **Damage triggers fire LAST, not first; HP reduced before receive-triggers** (§7.3).
- **DoTs tick during the execution loop; durations decrement after** (§7.5).
- **`bot_difficulty` is inverted** (higher = weaker, §9).
- **Mixture doc-comment is stale** (§9).
- **Passwords are plaintext; economy is client-trusted** (§10-11).
- **Rank promotion disabled; missions dormant** (§11).
- **`die()`/`roll()` no-op on passive clients** (§7.7).
- **`EnergyPool.change_energy(RANDOM)` push_errors** (§2/§7).
- `condition.gd` `extra_targetable` hardcodes per-character names (Sealed King/Iron Maiden/Gibbet) — extend the method, not data.
- `is_healable`/`is_helpable` identical (heal-ban not yet enforced).
- `percent_dr`'s `unpierceable` and `ignore_effect_effect`'s `helpful_only` args are silently dropped.

---

## 14. Open Questions / Unknowns

1. **`QueryContext.won`** is declared but set by no factory — likely assigned in game-end/`MISSION_TRIGGER_GAME_END` dispatch; not traced.
2. **Stat-based damage scaling** (`modify_damage_by_stats`, `ability_component.gd:459`) exists, but whether/which live abilities call it in the standard pipeline (vs. override-only) is unconfirmed. The role of ATTACK/DEFENSE/MIND/RESIST/SPEED beyond PRIMARY_STAT_MOD is undocumented.
3. **`RESOLVING`/`TARGETING`/`LOADING` gamestates** are declared but only `OPEN`/`CLOSED` were observed being set in traced paths.
4. **Effect flags `breaker`, `twin_priority`, `channel`, `health_drain`** and ability flags `important`/`invisible`/`special_targeting`/`accurate`/`minimum_damage` — full runtime semantics not traced beyond injection.
5. **Character transformation pattern** (Eren/Cell/Cooler/Korra: simultaneous multi-slot `ABILITY_SWAP` + `PORTRAIT_CHANGE` + `COLOR_CHANGE`, persistence/revert) is covered only as disconnected primitives; the end-to-end pattern wasn't synthesized.
6. **`DraftScene`** (pick/ban UI) — built but no instantiation found; confirm whether a ranked draft mode wires it.
7. **Spectating** — fully server-implemented but no client entry point located; dormant or hidden?
8. **Save format versioning/migration** — `Player.save()`/`load_player()` encode nested components (Rank, Rating, CharacterProgress, Clan) but the field-by-field schema, version field, and malformed-`.dat` handling were not enumerated. JSON parsing across `abilities_data.json`, `character_ability_counts.json`, `bot_contextual_model.json`, and saves is **unguarded** (`ability_component.gd:101` does a raw `JSON.parse_string`) — error-handling resilience is undocumented.
9. **`GlobalPlayerSettings`** (the single autoload) — contents (settings/volume/persistence) not read.
10. **Web export boot** (`html/` index.html/js/wasm, audio worklet, web SQLite wasm) — only incidentally covered.
11. **The completeness critic's EffectType count (118) was itself wrong** — they appear to have read a different/older `effect_type.gd`. The verified live file has **122 members**; if a divergent copy exists elsewhere in the tree, it should be reconciled. (Resolved here by direct read.)
12. **Effect category live-trigger vs passive-marker map** — a complete map of which `check_*` function consumes which EffectType would require reading all of `character_component.gd`/`effect_component.gd`.