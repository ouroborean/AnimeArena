---
tags: [area/playbook, type/howto]
---

# Adding a Playable Character

A new roster character touches **six server files, seven client files, one art folder, and a deploy
mirror**. There is no generator for most of it. Miss one and the failure is usually silent: the
character loads fine on the server and is simply invisible in char-select, or shows up with a blank
icon, or crashes only when someone actually drafts them.

Work in this order. Every step is verifiable before you move on.

Throughout, `<p>` is the **path name** (lowercase, no spaces — `toji`, `stark`, `aiohto`) and
`<Display Name>` is the asset-folder name (`Toji Fushiguro`, `Stark`).

---

## Phase 0 — Pre-flight: claim the path name

The path name is a global key across four namespaces that do **not** cross-validate. A collision is a
silent dict overwrite, not an error.

```bash
grep -n '"<p>"' components/bucket_handler.gd scripts/character_database.gd
grep -n '"<p>' abilities_data.json
python -c "import json;print([r for r in json.load(open('webclient/app/roster.json')) if r['path_name']=='<p>'])"
```

> [!warning] Trap — Nexus concepts occupy path names too
> `components/bucket_handler.gd` `all_chars` holds hundreds of **non-playable** concept characters
> (see [[Adding Nexus Concepts]]). When Ai Ohto was added, `ai` was already **Ai Mikami** (Mirai
> Nikki, portrait only, no kit), so she had to ship as `aiohto`. Grep before you write a single file.

Also decide up front:

| Decision | Default | Where it lives |
|---|---|---|
| Locked or free? | **Locked** | `roster.json` `gate: "<p>_unlock"` |
| How many ability keys? | 4 actives + passive/hidden slots | `character_ability_counts.json` |
| Universe | must exist in the enum | `components/character_concept.gd` |

> [!danger] New characters are LOCKED by default
> Unless the owner explicitly says otherwise, a new character ships gated behind `<p>_unlock`. Do
> **not** set `gate: "always"` and do **not** add them to `CharacterDatabase.starter_squads()` —
> `Character.unlocked(player)` (`scripts/character_component.gd:98`) treats a starter as always
> unlocked, which would silently defeat the gate:
> ```gdscript
> func unlocked(player):
> 	return (path_name in CharacterDatabase.starter_squads()) or (path_name + "_unlock" in player.unlocks) or "all_unlock" in player.unlocks
> ```
> The character script's own `is_unlocked(player)` can stay `return true` — toji/adam/sukuna all do.
> `unlocked()` is the authoritative gate and is not overridden.

---

## Phase 1 — Ability scripts (`abilities/<p>1.gd` … `<p>N.gd`)

Each ability is a plain GDScript `extends Ability`. `abilities/fern1.gd` is a good modern reference.
The methods that matter:

| Method | Purpose |
|---|---|
| `describe(user)` | Prose. Feeds only the char-select search blob — see [[Changing Ability Text]] |
| `split_desc()` | The **colored segments the client actually renders**. Parameterless |
| `execute(user, battle)` | The effect. Iterate `user.targeter.targets` |
| `target(user, battle)` | Populates `user.targeter.targets`. Usually `default_hostile_target_function(user, battle)` |
| `extra_usable(user)` | Extra usability gate on top of cost/cooldown/stun |
| `custom_behavior(context)` | The legacy priority bot's scoring hook |

```gdscript
extends Ability

func describe(user):
	return "Deals 45 Piercing damage to target enemy."

func split_desc():
	return [
		"Deals 45 Piercing damage to target enemy",
		["Under Mana Control this scales with unspent energy", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 45, DamageType.Type.PIERCING)

func target(user, battle):
	default_hostile_target_function(user, battle)
```

Colors used across the codebase: `Color.CADET_BLUE` (#5f9ea0), `Color.ORANGE_RED` (#ff4500),
`Color.AQUAMARINE` (#7fffd4), `Color.DIM_GRAY` (#696969), `Color.LIGHT_GREEN` (#90ee90).

See [[Damage Pipeline]], [[Effects and Durations]] and [[Trigger Types]] for what to call inside
`execute`. The [[Traps That Have Bitten Us]] note collects the authoring landmines; the ones that
bite *while writing a new kit* are reproduced at the bottom of this note.

---

## Phase 2 — Server registration

### 2a. `abilities_data.json` (root, server source of truth)

One row per ability key. This file is the **runtime source for cost, cooldown, classes, target type
and icon** — `Ability.from_database` (`abilities/scripts/ability_component.gd:120`) reads it every
time a moveset is built. There are no per-ability `.tscn` files.

```json
"toji1": {
	"script_path": "res://abilities/toji1.gd",
	"target_type": 0,
	"and_targeter": false,
	"selfless": false,
	"stunnable": true,
	"accurate": false,
	"cost": { "0": 2, "1": 0, "2": 0, "3": 0, "4": 0 },
	"cooldown": 2,
	"name": "Split Soul Katana",
	"classes": ["Physical", "Instant", "Harmful", "Damaging"],
	"image_path": "res://assets/images/Toji Fushiguro/toji1.png",
	"description": "Deals 40 Piercing damage to target enemy and stuns their skills that cost Green energy for 2 turns."
}
```

`target_type` is the `TargetType.Type` ordinal (`scripts/types/target_type.gd`):

| Value | Name | Use |
|---|---|---|
| 0 | `SINGLE` | one target |
| 1 | `ALL_FACTION` | one whole team |
| 2 | `ALL` | everybody — **this is what AoE-all-enemies uses**, with `target()` narrowing to enemies |
| 3 | `COUNT` | — |
| 4 | `SELF` | self-target and passives |

`cost` keys are `Energy.Type` ordinals (`scripts/types/energy.gd`): **0=GREEN, 1=BLUE, 2=WHITE,
3=RED, 4=RANDOM**.

`classes` are booleans in a fixed dict (`abilities/scripts/ability_component.gd:175-190`): Physical,
Energy, Mental, Affliction, Strategic, Harmful, Helpful, Instant, Action, Control, Channeled,
Uncounterable, Bypassing, Stealthed, Passive, Preserves Channel, **Damaging**.

> [!warning] `"Damaging"` is not decoration
> Silence is a pure usability gate: `Ability.is_silenced_out(user)` (line 471) returns
> `user.is_silenced() and not classes.get("Damaging", false)`. Omit `"Damaging"` from a damage skill
> and a silenced character can no longer use it. See [[Cleanse Silence and Effect Removal]].

> [!danger] Never round-trip `abilities_data.json` through a JSON dumper
> The file has **organic mixed indentation** — tabs on most lines, two spaces on others, hand-edited
> over years. A `json.load` / `json.dump` cycle reformats all ~26k lines and produces a diff nobody
> can review. **Insert your new block as RAW TEXT** at the right place, or text-replace an exact
> substring. If you must script it, `open(..., newline='')` and operate on the string.

### 2b. `character_ability_counts.json`

```json
"<p>": 5
```

`N` is the **total number of ability keys**, including the passive slot and any hidden swap-in —
not the four visible slots. `Movesets.from_skill_count` (`scripts/movesets.gd`) simply loops
`1..N` and calls `Ability.from_database("<p>" + str(i))`.

Reference counts in the repo: `toji 5`, `power 5`, `fern 5`, `denji 6`, `frieza 6`, `stark 7`.

Two characters deliberately have **no** entry — `vessel` and `jinwoo` — because they override
`initialize()` and build the moveset by hand. See [[Campaign Mode]] for the Vessel pattern.

### 2c. `character/<p>.gd` and `character/<p>.tscn`

The `.gd` extends `Character` and defines `initialize`:

```gdscript
extends Character

func initialize(_moveset = false):
	character_name = "Fushiguro Toji"
	path_name = "toji"
	universe = CharacterConcept.Universe.JUJUTSU_KAISEN
	character_colors = [0]
	description = "Toji Fushiguro, the Sorcerer Killer. ..."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
```

The `.tscn` is a copy of any existing character scene with the script path and the portrait
`ext_resource` swapped. `character/toji.tscn` is a clean template: it wires
`effects/health/stats/_name/moveset/targeter` NodePaths, sets `portrait_texture`, and connects
`HealthComponent.died -> die`. The `.gd.uid` regenerates on import — do not hand-write it.

`Character.from_character_name(name)` just loads `res://character/<name>.tscn`, so the file name IS
the lookup key.

> [!tip] Passive machinery belongs in `startup()`, not a synthetic "Passive" ability
> The house style (owner-stated) is to install a character's permanent reactive hooks in the
> character script's `startup(nbattle)`, sourced to a real ability. `character/toji.gd` plants three
> permanent invisible triggers (`DAMAGE_DEALT_TRIGGER`, `HARMFUL_RECEIVE_TRIGGER`,
> `START_OF_TURN_TRIGGER`) sourced to `moveset.base_abilities[4]`. `character/alphonse.gd` does the
> same for a permanent shield. Do **not** invent an extra ability slot just to hold bookkeeping.
> (A genuine displayed passive is different: give it `classes: ["Passive"]` and
> `Character.startup_passives` at `scripts/character_component.gd:284` executes it automatically —
> and it does **not** consume a display slot.)

### 2d. `scripts/character_database.gd` — `char_name_list()`

Add `"<p>"` to the array. This is the server's team-validation pool, the draft pool, and the random
pool. Nothing persists an index into it, so reordering is safe.

> [!warning] The list is GROUPED BY UNIVERSE, not appended to
> `char_name_list()` and the client's `CHAR_SELECT_ORDER` both start with the one-per-universe
> `starter_squads()` leaders, then give every remaining character a **contiguous block with the rest
> of their universe**. Appending to the end is wrong unless the character's universe has no other
> non-starter member. Insert at the end of their own universe's block, in **both** lists. (Owner
> asked for this explicitly when Frieza and Yoruichi were added.)

### 2e. `components/bucket_handler.gd` — `PERMANENT_EXCLUDED`

```gdscript
const PERMANENT_EXCLUDED := ["muichiro", "shirou", "muzan", "subaru", "law", "frieza", "yoruichi", "fern", "stark"]
```

The Nexus is a *poll for what to build next*. Once a character is greenlit there is nothing left to
vote on, so add `"<p>"` here — this is what `_is_removed()` (line 893) checks, and it removes them
from `get_bucket_list`, rejects further donations via `has_character_bucket`, and skips them in
`initialize_buckets`.

Do **not** delete their `all_chars` row: the entry is what resolves an existing donation or a
`removed_list.dat` row, so deleting it strands that history instead of retiring the candidate. Also
do **not** add a brand-new playable character to `all_chars` — a playable character does not belong
in the Nexus at all.

### 2f. `character_colors.json`

Regenerated, not hand-edited:

```bash
godot --headless --path . --script res://regenerate_character_colors.gd
```

It parses `character_colors = [...]` out of every `character/*.gd`. If your new script has no such
declaration it defaults to `[]` and prints a warning — which silently removes the character from
color-coverage in `scripts/color_balanced_draft.gd`. Declare it.

### 2g. Bounty archetypes (`scripts/bounty.gd`) — usually a separate ask

A character in no archetype makes bounties fall back to all categories. Archetype keys are lowercase
(`sword`, `gun`, `defender`, `villain`, `hero`, `digimon`, `servant`, `mage`, `brawler`, …).

> [!warning] The category dict is DUPLICATED
> It exists as `_categories` inside `static func flat_bounty_categories(path_name)`
> (`scripts/bounty.gd:128`) **and** as the instance `var categories` (line 172). Use a
> replace-all so both copies are hit, then regenerate the client mirror:
> ```bash
> godot --headless --path . --script res://extract_bounty_data.gd   # -> webclient/app/bounty_data.json
> cp webclient/app/bounty_data.json deploy/
> ```

---

## Phase 3 — Art

```
assets/images/<Display Name>/<p>prof.png       # portrait
assets/images/<Display Name>/<p>1.png … <p>N.png   # ability icons
```

Placeholders are acceptable to unblock (Toji shipped with five copies of `tojiprof.png`), but flag
them as pending.

> [!danger] The art must be a REAL PNG, not a WebP renamed `.png`
> Godot's importer decodes by extension, chokes on WebP bytes, and leaves the `.import` file with
> `valid=false` and no `[remap] path=`. The symptom is sneaky: the **browser** renders WebP-as-`.png`
> perfectly, so ability icons look right, while every server-side effect tooltip shows a blank grey
> square. Check the magic bytes (`\x89PNG`, not `RIFF….WEBP`); re-encode with
> `Image.open(f).convert('RGBA').save(f, 'PNG')`, delete the stale `.png.import` and
> `.godot/imported/<name>.ctex`, then re-import. (Hit adding Ai Ohto.)

Then always:

```bash
"/c/Users/mailj/Downloads/Godot_v4.6.2-stable_win64.exe/godot.exe" --headless --import
```

---

## Phase 4 — Client data (`webclient/app/`)

There is **no generator for roster/portraits/icons** — author them by hand from the `.gd`. Two of
the seven files DO have extractors; use them.

| File | Shape | How |
|---|---|---|
| `roster.json` | list of `{path_name, name, universe, gate, colors, bio}` | by hand, `indent=0` style (one key per line, unindented) |
| `portraits.json` | `{"<p>": {"default": "<Display Name>/<p>prof.png", "alts": []}}` | by hand |
| `char_index.json` | `{"<p>": {"default": "...", "name": "..."}}` | `extract_char_index.gd` (only covers `all_chars`; add playable-only chars by hand) |
| `ability_split.json` | `{key: [{text, color?}]}` | `extract_split_desc.gd` |
| `ability_info.json` | `{key: {name, description, classes, cooldown, desc, cost}}` | `extract_ability_info.gd` |
| `ability_icons.json` | `{"<p>N": "<Display Name>/<p>N.png"}` | by hand |
| `titles.json` | `{"lesser": {"<p>": [...]}, "greater": {"<p>": [...]}}` | by hand |

```bash
godot --headless --path . --script res://extract_split_desc.gd
godot --headless --path . --script res://extract_ability_info.gd
```

`roster.json` `universe` must exactly match the client's rendering of the enum key —
`Universe.keys()[u].capitalize()`, i.e. `WONDER_EGG_PRIORITY` → "Wonder Egg Priority".

`titles.json` words are pooled into a Set and the player composes up to `MAX_TITLE_WORDS` (5)
alongside `BASE_TITLE_WORDS` (`The`, `of`, `the`, `and`, …), so **each word must read standalone**;
multi-word tokens are hyphen-joined (`Flash-Goddess`, `Shadow-Monarch`). `lesser` unlocks at mastery
2 (1-3 trait/role/weapon words), `greater` at mastery 4 (1-3 signature epithet/technique words).

### `CHAR_SELECT_ORDER` in `app.js` — the step everyone misses

```js
const CHAR_SELECT_ORDER = [ "naruto", "luffy", ... , "aiohto", "jinwoo", "tsubasa", "power" ];
const CHAR_SELECT_SET  = new Set(CHAR_SELECT_ORDER);
const CHAR_SELECT_RANK = new Map(CHAR_SELECT_ORDER.map((n, i) => [n, i]));
```

`gridArea()` (`webclient/app/app.js:2187`) does:

```js
const base = (roster || []).filter((r) => CHAR_SELECT_SET.has(r.path_name))
  .sort((a, b) => CHAR_SELECT_RANK.get(a.path_name) - CHAR_SELECT_RANK.get(b.path_name));
```

> [!danger] A character in `roster.json` but not in `CHAR_SELECT_ORDER` is INVISIBLE
> They still appear in the Mastery panel, so the bug reads as "the roster loaded fine". Toji was in
> every JSON and absent from the grid until this array was updated. Same universe-block ordering rule
> as `char_name_list`.

The client derives a character's kit purely from key naming — `charAbilities(pathName)` (line 2346)
filters `ability_info.json` keys matching `^<path><digits>$`. No manifest needed, but it also means
a stray key like `<p>10` gets picked up.

---

## Phase 5 — Deploy mirror

Every client edit must be mirrored to `deploy/`. That folder is what Cloudflare Pages publishes.

```bash
cp webclient/app/{roster,portraits,char_index,ability_info,ability_split,ability_icons,titles}.json deploy/
cp webclient/app/app.js deploy/
cp -r "assets/images/<Display Name>" "deploy/assets/images/"
```

Or rebuild the whole bundle: `.\build-pages-deploy.ps1` (clean rebuild of `deploy/`, copies
`webclient/app/*` minus test artifacts, mirrors `images avatars backgrounds bounty cosmetics videos
sounds`, strips `*.import`). `.\deploy.ps1` runs that plus `wrangler pages deploy` plus the server
binary scp. See [[Data Files and the Deploy Mirror]].

> [!danger] Never use git to sync or undo here
> The working tree carries large amounts of uncommitted work. `git checkout -- <file>` once reverted
> `abilities_data.json` to HEAD and destroyed 16 uncommitted ability entries. Use `cp` and direct
> edits. See [[Hard Rules and Guardrails]].

---

## Phase 6 — Verify

1. **Compile / import**
   ```bash
   godot --headless --import
   ```
   Expect 0 Parse/Compile errors. A brand-new `class_name` needs this run before other scripts can
   resolve it — the registry lives in `.godot/global_script_class_cache.cfg` and only the editor
   writes it. A whole-project check with autoloads loaded:
   `godot --headless --editor --quit-after 300`, then grep stderr for
   `SCRIPT ERROR|Parse Error|Compile Error`.
2. **In-engine kit probe** — an `extends SceneTree` script that builds the character and fires each
   ability. See the harness caveats below.
3. **Live WS bot match** — grant `<p>_unlock` (or `all_unlock`) so the gate passes, then confirm 0
   `SCRIPT ERROR`s and that mastery logs the character.
4. **Browser** — char-select grid shows the character, the kit strip shows N-1 icons, the info panel
   shows the bio, tooltips show `desc` segments and real (non-grey) ability art.

### Headless-harness caveats

> [!warning] The isolated `Battle` is not the real `BattleManager`
> - `scripts/battle.gd` lacks `log_damage` / `log_*`, so damage aborts. Subclass `Battle` with no-op
>   `log_*` shims — and give the subclass a **unique** class name; `TestBattle` is already taken.
> - `Character.resolve_damage` bails immediately if `context['owner'].used_ability` is null. The turn
>   system sets it before `execute()`; a direct `ability.execute(user, battle)` does not. Set
>   `user.used_ability = ability` first or your damage silently no-ops (this made an entire Jin-woo
>   phase-2 test pass vacuously). `resolve_effect_damage` does not need it.
> - The `--script` SceneTree lacks the `GlobalPlayerSettings` autoload, which zeroes
>   `resolve_damage`/`resolve_healing` numbers. Effects still apply. **Verify damage NUMBERS over the
>   WS harness against the real server**, not in `--script`.
> - A test that pre-sets `targeter.targets` bypasses `target()` entirely, so it **cannot** catch a
>   targeting bug. Verify targeting separately. (This is exactly how a missing invuln-bypass third
>   argument survived the Jin-woo green-form tests.)

---

## Engine gotchas that bite during authoring

> [!warning] `effect_name()` is the SOURCE ABILITY's name
> `effect.effect_name()` == `source.ability_name` (the `name` from `abilities_data.json`). Every
> effect from one ability shares a name; distinguish by `EffectType`. `has_effect(name, type, user)`
> matches on `eff.user` — the applier, not the holder.
>
> When one ability legitimately needs two same-typed effects with different names, set
> **`effect.name_override`** (`scripts/effect_component.gd:75`, checked first in `effect_name()` at
> line 1277)
> **before** `add_effect`, since merging keys on `effect_name()`. Symptom of forgetting: Frieza's
> every-3rd-use swap never fired and a shield-decay counter froze at 1, because
> `has_effect(COUNTER, MARK, user)` kept finding the wrong effect. Keep `source` as the real ability
> — `get_active_abilities` only honours an `ABILITY_SWAP` whose `source` is in `base_abilities`.

> [!warning] Only four slots ever display
> `MovesetComponent.display_abilities()` (`scripts/moveset_component.gd:111`) returns indices 0-3.
> Ability keys at index ≥ 4 are hidden swap-in payloads, reachable only via
> `Effect.ability_swap_effect(swap_in_idx, display_slot_0_3, user, dur)`. A passive
> (`classes["Passive"]`) auto-runs through `startup_passives` and is not a display slot.

Other high-frequency ones, each covered in depth elsewhere:

- **Durations tick on every player's turn.** "N turns" = `2N`; an ability **swap** "N turns" = `2N+1`;
  invuln "1 turn" = `2`. A DoT needs an immediate manual first tick plus double duration —
  see [[Effects and Durations]].
- **Bypassing invuln is a TARGETING concern.** `check_hostile_target(user, target, context, bypassing=true)`
  — invuln is enforced at targeting, `resolve_damage` does not recheck. The `"Bypassing"` class alone
  lets damage through *once targeted*; it does not let you target. See [[Targeting and Main Target]].
- **Trigger damage pierces invuln unless you guard it.** A per-turn or overflow trigger must check
  `enemy.is_invuln(self)` itself (`abilities/asta4.gd:39` is the reference guard). Affliction correctly
  omits the guard — it bypasses invuln by design. See [[Trigger Types]].
- **RNG must be `battle.roll(min, max)`**, never `randi` — matches are seeded and replayable
  ([[Server Authority Model]]).
- **"Gain a random energy" is `character.gain_random_energy()`**, not
  `gain_bonus_energy(Energy.Type.RANDOM)`. RANDOM is a cost token, not a storable colour;
  `EnergyPool.change_energy(RANDOM, …)` `push_error`s and no-ops, so the energy silently never
  appears. See [[Cooldowns and Energy]].
- **Class-targeted cost changes match by ability NAME, not class.**
  `Effect.cost_mod_effect(mag, dur, element, targets=[])` (`scripts/effect_component.gd:656`) stores
  `targets` into `ability_targets` and compares against ability *names*. Collect the target's
  class-matching names first and guard against an empty list — `targets == []` means **ALL** skills:
  ```gdscript
  var strat = []
  for abi in target.moveset.get_active_abilities(target):
  	if abi != null and abi.classes["Strategic"]:
  		strat.append(abi.ability_name)
  if not strat.is_empty():
  	var cost_up = Effect.cost_mod_effect(1, 8, Energy.Type.RANDOM, strat)
  ```
  (`abilities/blackwargreymon2.gd:15-22`.)
- **Permanent machinery must survive the death cleanse.** A permanent effect installed by a passive
  needs `system = true` **and** `remove_on_death = false`, or a revive silently kills the passive for
  the rest of the match. See [[Node Lifecycle and Orphans]] and [[Effects and Durations]].
- **Invisible skills**: `"invisible": true` is a top-level key in `abilities_data.json` and sets
  `ability.invisible`. The `"Invisible"` entry in `classes` is a forward-compat/display tag —
  `components/match_event_recorder.gd:115` reads `ability.invisible or ability.classes.get("Invisible", false)`.
  A hidden counter wants both, plus `counter.invisible = true` on the effect itself (which hides the
  counter marker from the opponent).
- **Self-target `custom_behavior` must pass `[user, self, [user]]`**, never `[…, []]`. An empty
  target list is filtered out by `get_target_variation_priorities`, so the legacy priority bot never
  casts it — which for Denji meant the bot could not unlock his kit at all. See [[Bots and Training]].

---

## Master checklist

| # | File | Edit |
|---|---|---|
| 1 | `abilities/<p>1..N.gd` | new scripts |
| 2 | `abilities_data.json` | N rows, **raw insert** |
| 3 | `character_ability_counts.json` | `"<p>": N` |
| 4 | `character/<p>.gd` | `initialize()` (+ `startup()` for passives) |
| 5 | `character/<p>.tscn` | copy + swap script & portrait |
| 6 | `scripts/character_database.gd` | `char_name_list()`, in the universe block |
| 7 | `components/bucket_handler.gd` | `PERMANENT_EXCLUDED` |
| 8 | `character_colors.json` | regenerate via script |
| 9 | `scripts/bounty.gd` | archetypes ×2 dicts (+ regen `bounty_data.json`) |
| 10 | `assets/images/<Display Name>/` | `<p>prof.png` + `<p>1..N.png`, real PNG |
| 11 | `webclient/app/roster.json` | entry with `gate: "<p>_unlock"` |
| 12 | `webclient/app/portraits.json` | entry |
| 13 | `webclient/app/char_index.json` | entry |
| 14 | `webclient/app/ability_info.json` | regenerate |
| 15 | `webclient/app/ability_split.json` | regenerate |
| 16 | `webclient/app/ability_icons.json` | N entries |
| 17 | `webclient/app/titles.json` | `lesser` + `greater` |
| 18 | `webclient/app/app.js` | `CHAR_SELECT_ORDER`, in the universe block |
| 19 | `deploy/` | mirror every client file + the art folder |
| 20 | — | `godot --headless --import` |

---

## Related

[[System Overview]] · [[Web Client Architecture]] · [[Data Files and the Deploy Mirror]] ·
[[Changing Ability Text]] · [[Adding Nexus Concepts]] · [[Verification Playbook]] ·
[[Traps That Have Bitten Us]] · [[The Turn Pipeline]] · [[Anime Arena]]
