# Reference Data Inventory

**Purpose.** The Godot backend is being replaced. This document lists *every* piece of game
reference data, says where it lives, whether it requires Godot to read, whether it is currently in
sync, and who consumes it. It is the data-side companion to `WIRE_CONTRACT.md` (protocol) and
`BACKEND_ROADMAP.md` (plan) — and it supersedes the roadmap's data section, which was written
while the inventory stage crashed.

**Status of this run.** Extraction was purely additive. No `.gd` file was modified; the Godot
server still reads its own declarations. Everything new lives in `data/`, `tools/`, and this file.

Generated / verified: 2026-08-05. Re-verify with `python tools/reference_data.py`.

---

## 0. TL;DR for the replacement backend

* **Read `data/` for everything that used to require running Godot.** 15 files, all verified.
* **Read the existing root/webclient JSON for everything else** — do not re-derive it.
* **Only one dataset genuinely still needs Godot to produce**: ability description text
  (`split_desc()`), because it is arbitrary GDScript, not a literal. It is currently **100% in
  sync** and the port needs a plan for it (see §5).
* Five findings — one stale generated file, two latent `bounty.gd` bugs, a miscounted table, and
  a set of dormant/dead symbols a port must not "restore" — are **reported, not fixed** (§6).

---

## 1. Datasets that were trapped in GDScript — now extracted to `data/`

All 17 are verified two ways: `tools/reference_data.py` re-derives them by *parsing* the `.gd`
source (no Godot), and `tools/check_extraction_vs_godot.gd` compares them to the values the
*running* engine produces (47/47 checks pass).

| Dataset | GDScript home | Extracted to | Consumer |
| --- | --- | --- | --- |
| `char_name_list()` (174), `starter_character_list()` (21), `starter_squads()` (34) | `scripts/character_database.gd` | `data/characters/character_lists.json` | server (roster validation, bots, bounty starters) |
| per-character display name + universe | `character/<path>.gd` `initialize()` | `data/characters/character_universes.json` | server |
| `by_universe()` | `scripts/character_database.gd:250` | `data/characters/by_universe.json` | server (bounty generation) |
| `CharacterConcept.Universe` **ordinals** (54) | `components/character_concept.gd:8` | `data/nexus/universe_enum.json` | server + save data |
| `all_chars` (**639** concepts) | `components/bucket_handler.gd:33` | `data/nexus/all_chars.json` | server (Nexus), client via `char_index.json` |
| `PERMANENT_EXCLUDED` (12), seeded bucket universes | `components/bucket_handler.gd:19,706` | `data/nexus/nexus_tables.json` | server |
| `mission_types` (weighted 3/2/1), `winning_patterns` (**12**), `categories` (35), `archetypes` (36) | `scripts/bounty.gd` | `data/bounty/bounty_tables.json` | both (client copy = `webclient/app/bounty_data.json`) |
| `rp_thresholds`, `ranked_streak_thresholds`, tier spans | `components/rank_component.gd:57,68` | `data/ladder/rank_tables.json` | server (**dormant** — see §6.4) |
| `GATE_BANDS`, `MM_TICK`, `ADMIN_USERNAMES`, `BOT_EXCLUDED_CHARS` | `components/server_connection.gd:56,63,358,2728` | `data/server/matchmaking.json` | server |
| `DRAFT_*` (ban/pick seconds, max bans, pick quota), `default_match_timer`, `AFK_*` (penalty step, min timer, forfeit misses) | `components/match.gd:25-37` | `data/server/match_rules.json` | server |
| `EXCLUDED_USERS` (stats-excluded dev accounts) | `components/stats_db.gd:25` | `data/server/stats_exclusions.json` | server |
| `title_data` | `scripts/player_component.gd:23` | `data/server/title_data.json` | **nobody** (see §6.5) |
| 14 enums whose ordinals are wire/save visible | `scripts/types/*.gd`, `battle_manager.gd`, `clan.gd`, `rank_component.gd`, `character_concept.gd` | `data/engine/enums.json` | both |
| `RESERVED_EFFECT_NAMES` (30), `HERO_SHIELD_BOUND` (4) | `scripts/character_component.gd:81,1246` | `data/engine/name_tables.json` | server (content validation) |
| `MAX_LEVEL`, `XP_THRESHOLDS` (101), `XP_PER_WIN/LOSS/FLOOR`, `UNLOCK_THRESHOLDS` | `components/mastery_config.gd` | `data/progression/mastery.json` | server |
| `CLASS_NAMES` (19), `FREE_SKILLS_MARK` | `abilities/scripts/ability_component.gd:28` | `data/engine/ability_classes.json` | both |
| `FORM_KITS`, `DEFAULT_KEYS` (Jin-woo summon forms) | `character/jinwoo.gd:14` | `data/characters/jinwoo_form_kits.json` | both |

**Added after an adversarial completeness pass** (three rows above): `BOT_EXCLUDED_CHARS`,
`components/match.gd`'s draft/AFK rules, and `stats_db.EXCLUDED_USERS`. The first is the one that
matters most — it is **behaviour-visible and referenced by nothing else**, so a port that silently
drops it starts fielding bot Tsubaki/Toga/Fern, a live gameplay regression rather than a cosmetic
one. Deliberately **not** extracted, and recorded here so the silence is not mistaken for an
oversight: `scripts/moveset_component.gd:139 laria_moveset` is an **empty array** (a dead stub, no
data to carry), and three enums are **not wire- or save-visible** and so are excluded by design —
`ServerConnection.NetworkMode`, `ServerSession.ConnectionState` (compared server-internally; the
client only ever receives derived strings) and `QVerdict`.

`data/` is 17 files. Five of the rows above were **not** on the audit's confirmed list — they came
out of independent sweeps for large literal tables and for enums (§7). `CLASS_NAMES` in particular
is load-bearing: its strings are stored verbatim in `abilities_data.json`, it is append-only, and
`from_database`, `AuthoredCharacter._build_moveset` and the Creator's class whitelist all derive
from it. Verified: every `classes` string in `abilities_data.json` is in `CLASS_NAMES`; two
declared classes (`Preserves Channel`, `Stealthed`) are currently unused by any ability.

### Why this layout

* **Top-level `data/`, grouped by owning subsystem** (`characters/`, `nexus/`, `bounty/`,
  `ladder/`, `server/`, `engine/`, `progression/`) rather than one blob. A port implements those
  subsystems one at a time; a per-subsystem file means a consumer loads only what it needs and a
  diff is legible.
* **One file per closely-related group, not per symbol.** `rp_thresholds` alone is meaningless
  without the tier ordinals it is keyed by, so they ship together.
* **No duplication of existing good JSON.** Nothing in `data/` restates `abilities_data.json`,
  `roster.json`, `character_colors.json`, etc. §2–§4 say where those live instead.
* **Provenance in-band.** Every file has `_source` / `_symbols` / `_generated_by`. Keys starting
  with `_` are notes, never data.
* **Enum ordinals, not just names.** `abilities_data.json` stores `target_type` and cost keys as
  these ints; snapshots carry effect/damage types as these ints; save data stores `Universe` and
  clan `Rank` as these ints. Renumbering any of them is a data migration.

---

## 2. Reference JSON that already exists at the repo root

| File | Godot-dependent? | In sync? | Consumed by |
| --- | --- | --- | --- |
| `abilities_data.json` (1087 rows) | **No** — plain JSON | Yes; **it is the source of truth** for cost / cooldown / classes / `target_type` / `script_path` / `image_path`. There is no per-ability `.tscn` to disagree with it (`abilities/` holds 1020 `.gd` and 1 `.tscn`). 96 rows have a `script_path` that no longer exists (`ash*`, `squirtle*`, `pikachu*`, `invincible*`, `omniman*`, `atomeve*`, `pyrrha*`, `gaia_*`, `river_daughter_*`) and 45 are stubs with no `classes` key — both sets are unreachable in game and are skipped by every extractor. | server (`Ability.from_database`), client (search/tooltips), 14 ability scripts, 4 probes |
| `character_ability_counts.json` (230) | No | Yes. Covers every playable character except `jinwoo`, which is **correct**: Jin-woo builds his own key-prefixed summon-form kit and never calls `Movesets.from_skill_count()`. Those keys are now in `data/characters/jinwoo_form_kits.json` (all 24 resolve to real `abilities_data.json` rows). | server (`scripts/movesets.gd`) |
| `character_colors.json` (175) | No | Yes — every roster entry has a row. Regenerated by `regenerate_character_colors.gd`, which *parses* `character/*.gd` for `character_colors = [...]` plus an `EXCLUDED`/`OVERRIDES` list held in the script itself. | server (`scripts/color_balanced_draft.gd`) |
| `help_pages.json` (10) | No | Stale-ish; **zero code references**. Authored help copy for the retired desktop client. | nobody |
| `organized_abilities.json` (107) | No | **Zero code references.** Authoring/design artifact. | nobody |
| `character_tips.json` / `.md` | No | **Zero code references.** Authoring artifact. | nobody |
| `bot_policy.json`, `bot_tuning.json`, `bot_contextual_model.json`, `bot_training_data.json`, `bot_records.json` | No | ML artifacts, not reference data — out of scope, as specified. | bot runtime / trainer |
| `server_flags.json`, `training/team_pool.json` | No | Runtime config. | server |

---

## 3. Reference JSON in `webclient/app/` (mirrored byte-identically to `deploy/`)

Verified: all 13 `webclient/app/*.json` are **byte-identical** to their `deploy/` copies.

| File | Godot-dependent? | In sync? | Consumed by |
| --- | --- | --- | --- |
| `roster.json` (174) | No | **Yes — exact match with `char_name_list()`**, both 174, identical as sets. Hand-maintained (no generator). Carries `path_name`, display `name`, universe *display string*, `gate`, `colors`, `bio`. | client only (server mentions it only in comments) |
| `char_index.json` (657) | Generated by `extract_char_index.gd` (needs Godot) | **STALE — see §6.1.** 657 rows vs 639 concepts; 18 rows describe characters that have left `all_chars`. | client (Nexus, bounty target names/portraits) |
| `ability_info.json` (1085) | Generated by `extract_ability_info.gd` | **In sync.** 0 cost / 0 cooldown / 0 classes disagreements with `abilities_data.json`; 0 `desc` disagreements with `ability_split.json`. | client, server (`battle_manager.gd`) |
| `ability_split.json` (989) | Generated by `extract_split_desc.gd` (**needs Godot**) | **In sync — 0 text drift, 0 missing, 0 extra**, proven by running `tools/check_split_desc_sync.gd` against the live `split_desc()`. | client, server (`server_connection.gd`) |
| `bounty_data.json` | Generated by `extract_bounty_data.gd` | **In sync** — `categories`, `winning_patterns`, `archetypes`, `starters` all match the GDScript exactly. | client, `training/tests/bounty_refdata_probe.gd` |
| `ability_icons.json` (1032) | No (asset manifest) | Fine | client |
| `ability_aliases.json` (1) | No | Fine (one entry: `ability_template`) | client |
| `portraits.json` (190) | No (asset manifest) | Covers all 174 roster entries; 16 extra rows for retired/never-shipped characters (`ash`, `pikachu`, `kakashi`, `uryuu`, …) plus `vessel`. Harmless. | client |
| `titles.json` (`lesser` 171 / `greater` 171) | No | 7 roster characters have **no title entry**: `arthur`, `broly`, `hibari`, `rakko`, `seventeen`, `toji`, `uranus`; 4 entries are for non-roster characters (`atomeve`, `invincible`, `omniman`, `uryuu`). Content gap, not code drift. | client |
| `shop_catalog.json` (5 items) | No | Fine | client |
| `campaign_chapters.json`, `campaign_dialogue.json` (15), `campaign_encounters.json` (2) | No | Fine | client **and** server (`scripts/campaign.gd`) |

---

## 4. Data that lives on disk but is not a table

| Thing | Where | Notes for the port |
| --- | --- | --- |
| Nexus AP per concept | `bucket data/<path_name>.dat` (one integer, one line) | **667 files vs 639 concepts** — reconciled in §6.2 |
| Nexus removals | `bucket data/removed_list.dat` | Currently **absent** (nothing removed yet); absence is valid |
| Player accounts | `ausers/*.dat` | Out of scope here; see the roadmap |
| Replays | `replays/` | `REPLAY_RETENTION_DAYS 30`, `REPLAY_MAX_FILES 5000`, `REPLAY_CHUNK 24000` |

### Tables that are *logic*, not literals

These are hard-coded in function bodies, so they cannot be mechanically extracted; a port must
reimplement them. Values recorded here so they are not lost:

* **AP payout** — `server_connection.gd:_calculate_ap_gain` (:1894). Flat per queue, no streak
  scaling: practice Bot 50/0, Quick (incl. its bot fallback) 100/50, Ranked vs human 500/50,
  Ranked vs bot 250/50, Private 0/0. The client mirrors it in `app.js:matchApGain`, and
  `training/tests/queue_rewards_probe.gd` pins all 10 cases.
* **Rank tier from rating** — `rank_component.gd:tier_for_rating` (:40). 400 rating per tier, 4
  divisions of 100, Grandmaster open-ended. (The constants *are* in `data/ladder/rank_tables.json`.)
* **Bounty mission win-counts** — `bounty.gd:generate_from_details`. Recorded descriptively under
  `mission_target_counts` in `data/bounty/bounty_tables.json`.
* **AFK / draft timers** — `components/match.gd:25-36`.

---

## 5. The generator-pipeline problem

Every existing generator is itself a Godot script. A non-Godot replacement must handle each one:

| Generator | Reads | Writes | What a non-Godot replacement must parse |
| --- | --- | --- | --- |
| `extract_split_desc.gd` | `abilities_data.json`; then `Ability.from_database(basename)` → `load(script_path).new().split_desc()` | `webclient/app/ability_split.json` | **The hard one.** `split_desc()` is a GDScript *function body* returning an Array of `String` or `[String, Color]` — the `Color` is a GDScript constant (`Color.RED`, `Color(r,g,b)`) serialized as `"#" + to_html(false)`. Bodies can branch and call helpers. Static parsing is not sufficient in general. |
| `extract_ability_info.gd` | `abilities_data.json` + `ability_split.json` + the *previous* `ability_info.json` | `webclient/app/ability_info.json` | Pure JSON→JSON. Trivial to port. Note two deliberate behaviours: `description` falls back to the previous file when the DB value is empty, and rows failing the completeness gate are **carried forward**, never pruned. |
| `extract_char_index.gd` | `bucket_handler.all_chars` (instantiates the class) | `webclient/app/char_index.json` | Now trivial: read `data/nexus/all_chars.json` instead. The `res://assets/images/` prefix is trimmed off the portrait path. |
| `extract_bounty_data.gd` | `bounty.gd` members + `CharacterDatabase.starter_squads()` | `webclient/app/bounty_data.json` | Now trivial: read `data/bounty/bounty_tables.json` + `data/characters/character_lists.json`. |
| `regenerate_character_colors.gd` | `character/*.gd` via regex `character_colors\s*=\s*\[([^\]]*)\]`; plus in-script `EXCLUDED` (8) and `OVERRIDES` (`gojo:[1]`, `tokoyami:[3]`, `crona:[]`) | `character_colors.json` | Already regex-based — a direct port. Sorts keys alphabetically; values are `Energy.Type` ints. |

**Recommended split for the port**

1. `extract_char_index`, `extract_bounty_data`, `regenerate_character_colors` and
   `extract_ability_info` become plain scripts over `data/` + the root JSON. No Godot.
2. `extract_split_desc` stays the *only* Godot dependency. Freeze `ability_split.json` as
   authored content (it is currently exact), and when authoring moves off GDScript, have the new
   ability format emit its segments directly. Until then, keep
   `tools/check_split_desc_sync.gd` in CI so the freeze can never silently rot.

---

## 6. Findings — reported, **not** fixed

### 6.1 `char_index.json` is stale (18 rows) — and naively regenerating it would make things worse

`all_chars` has 639 concepts; `char_index.json` has 657. The 18 extra rows are, verbatim and
verified by set difference (an earlier draft of this section listed 19 names for an 18-row set and
wrongly included `toji`, which is in neither file):

**14 promoted out of the Nexus into the playable roster** — `aiohto`, `astolfo`,
`blackwargreymon`, `death`, `denji`, `frieza`, `gasai`, `jinwoo`, `levi`, `minene`, `nobara`,
`power`, `tsubasa`, `yoruichi`.
**4 that are neither concept nor playable** — `hibiki`, `mashburn`, `muzan`, `subaru`.

Re-running `extract_char_index.gd` today would **delete all 18**,
because it rebuilds strictly from `all_chars`. The client uses `char_index.json` to resolve names
and portraits for bounty targets and Nexus rows, so dropping promoted characters could blank
names the UI still asks for. Decide the policy (merge-forward vs prune) before regenerating.

### 6.2 `bucket data/` has 28 orphan `.dat` files — benign, explained

667 `.dat` vs 639 concepts. The 28 extras are AP rows whose concept was deleted from `all_chars`
(promotions: `denji`, `power`, `levi`, `toji`, `frieza`, `death`, `astolfo`, `nobara`, …) or
renamed (`android17`→`seventeen`, `yunogasai`→`gasai`, `arthurff`→`arthur`). `get_bucket_data`
creates a file lazily and nothing ever deletes one. No concept is missing a file. Harmless; the
port should just ignore unknown `.dat` names.

### 6.3 Two latent bugs in `bounty.gd`

* **`archetypes` contains `"non human"`, `categories` does not.** `check_bounty_progress` does
  `if target in archetypes: ... categories[target]` — that would throw. Currently unreachable
  because generation only draws from `get_archetypes(path)`, which iterates `categories` keys. It
  becomes live the moment anything else can name an archetype.
* **`categories["lightning"]` contains the string `"lightning"`**, which is not a character
  path_name (not playable, not a concept). This one *is* reachable: a `with`/`against` mission can
  roll it as a specific target, producing a square nobody can ever complete.

`archetypes` and `get_archetype_list()` are byte-identical duplicates. The `categories` table at
`:172` and the `_categories` copy inside `flat_bounty_categories()` at `:129` are **verified
identical** (the extractor asserts this every run). A **third, much older copy** exists at
`missions/objective.gd:23` with different membership and misspelled names (`bakugou`, `tsuna`,
`satuski`, plus dead `"team 7"`/`"karakura"` archetypes) — `missions/` has **no references from
anywhere outside itself** and is dead code. Do not port it.

Also: `winning_patterns` has **12** entries, not 13 (5 rows + 5 columns + 2 diagonals). The
task brief said 13.

### 6.4 `all_chars` really has **639** entries, not ~654

A grep for `CharacterConcept.create` finds 654 lines, but **15 are commented out**
(`#"homelessemperor"`, `#"silverfang"`, 11 Slime characters, `#"crawler"`, `#"alpha"`). The
parser skips comments; `check_extraction_vs_godot.gd` confirms the live dictionary size is 639.

### 6.5 Dormant / dead data that must not be "restored" by a port

* `rp_thresholds` / `ranked_streak_thresholds` (`rank_component.gd`) are **not read by anything**.
  The promo-series design that used them was removed; tiers are now derived from rating. They are
  extracted as a spec for that layer if it is ever rebuilt — a port must not wire them up.
* `title_data` (`player_component.gd:23`) is **read by nothing**; the only grep hit is the
  declaration. The live title system is the client's `titles.json`.
* `initialize_buckets()` seeds 52 of the 54 universes: **`CHIVALRY_OF_A_FAILED_KNIGHT` and
  `CUSTOM` are missing.** Harmless today (no concept uses either), but adding a concept in either
  universe would crash boot with a missing-key error on `all_buckets[concept.universe]`.
* `PERMANENT_EXCLUDED`'s comment says the 12 names "stay in `all_chars` on purpose" — but **6 of
  them are no longer in `all_chars`** (`muichiro`, `shirou`, `muzan`, `subaru`, `frieza`,
  `yoruichi`). The exclusion still works (`_is_removed` is a name test), but the comment is wrong.

---

## 7. Sweep: how "everything" was determined

Beyond the six confirmed sources, two mechanical sweeps ran over **every** `.gd` in the repo
(only `.git` and `.godot` excluded):

1. **Large literal tables** — every top-level `var`/`const` whose `[`/`{` literal spans ≥4 lines
   or ≥300 chars. 47 candidates. Newly extracted: `mastery_config` (XP/unlock ladders),
   `character_component` (`RESERVED_EFFECT_NAMES`, `HERO_SHIELD_BOUND`),
   `ability_component.CLASS_NAMES`, `jinwoo.FORM_KITS`. Deliberately **not** extracted:
   * `blocks/block_schema.gd` (`SIMPLE_EFFECTS`, `OPS`, `_NAMED_EFFECT_KINDS`, `LIMITS`,
     `CONDITIONS`, `TRIGGERS`, `SELECTORS`, `POOLS`, …) — this is the **scrapped Creator's** DSL
     schema. Per this run's constraints `blocks/` is untouched reference material for a future
     redesign; extracting it now would freeze a vocabulary that is about to be rewritten.
   * `training/bot_policy.gd` (`FEATURE_SCHEMA`, `TARGET_SCHEMA`, `REACTIVE_TYPES`) and
     `new multiplayer/bot_contextual_model.gd` feature names — ML artifacts, out of scope.
   * `stat_component.base_stats` — randomised at runtime, not reference data.
   * `energypool.pool`/`promised_pool`, `clan.members`/`member_info`,
     `server_connection.ranked_queue` — runtime state.
   * `regenerate_character_colors` `EXCLUDED`/`OVERRIDES` — generator config, documented in §5.
   * `blocks/authored_assets.SLOTS`, probe-local oracle tables under `training/tests/` — test and
     Creator-internal fixtures.
   * `missions/objective.categories` — dead code (§6.3).
2. **Every `enum`** in the repo — 15 found, 14 extracted (the 15th,
   `ServerConnection.NetworkMode`, is a 2-value build switch, not data).

Per-character data (`character/*.gd`: `character_name`, `path_name`, `universe`,
`character_colors`) was swept separately: universes are extracted here, colors already live in
`character_colors.json`, names/bios already live in `roster.json`.

---

## 8. How to re-verify all of this

```bash
# 1. No Godot. Re-derives every data/ file by parsing .gd source; exit 1 on drift.
python tools/reference_data.py
python tools/reference_data.py --audit      # + the cross-file sync report in §2-§3

# 2. Godot, read-only. Proves parsing the source == running it.
"<godot>" --headless --path . --script res://tools/check_extraction_vs_godot.gd

# 3. Godot, read-only. Proves ability text has not drifted from split_desc().
"<godot>" --headless --path . --script res://tools/check_split_desc_sync.gd

# 4. Compile check (proves nothing was broken).
"<godot>" --headless --path . --import
```

`tools/reference_data.py --write` is the *only* thing that should ever change `data/`, and it and
the verifier share one derivation path — so the check cannot pass by comparing two stale copies.
