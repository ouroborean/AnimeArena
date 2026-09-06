# `data/` — reference data, extracted out of GDScript

Every file here was **trapped inside a `.gd` file** and is now readable without Godot. This
directory exists for the replacement backend: a non-Godot server must be able to load all game
reference data from disk, and several tables were previously only reachable by instantiating
Godot classes.

**Nothing in the live Godot server reads these files.** The Godot server still reads its own
`.gd` declarations, exactly as before. This directory is an *additive, verified mirror* — the
extraction changed no behaviour.

## Rules

1. **Do not hand-edit these files.** They are generated. Edit the `.gd` source, then run
   `python tools/reference_data.py --write`.
2. **Do not add data here that already lives in good JSON elsewhere.** Duplication invites
   drift. See `REFERENCE_DATA_INVENTORY.md` (repo root) for where everything else lives.
3. Every file carries `_source` / `_symbols` provenance so a reader can find and re-verify
   the declaration it came from. Keys beginning with `_` are notes, not data.

## Layout

| Path | Extracted from | What it is |
| --- | --- | --- |
| `characters/character_lists.json` | `scripts/character_database.gd` | `char_name_list` (174), `starter_character_list`, `starter_squads` |
| `characters/character_universes.json` | `character/<path>.gd` | per-playable-character display name + universe (name **and** ordinal) |
| `characters/by_universe.json` | `character_database.by_universe()` | ordinal → ordered path_names; the table bounty generation indexes into |
| `characters/jinwoo_form_kits.json` | `character/jinwoo.gd` | Jin-woo's per-summon-form ability keys (the one roster character with no ability-count row) |
| `nexus/universe_enum.json` | `components/character_concept.gd` | the `Universe` enum **ordinals** (append-only; persisted) |
| `nexus/all_chars.json` | `components/bucket_handler.gd` | 639 Nexus character concepts (name, portrait path, description, universe) |
| `nexus/nexus_tables.json` | `components/bucket_handler.gd` | `PERMANENT_EXCLUDED`, the seeded bucket-universe order, the on-disk file layout |
| `bounty/bounty_tables.json` | `scripts/bounty.gd` | `mission_types` (weighted), `winning_patterns`, `categories`, `archetypes` + consistency findings |
| `ladder/rank_tables.json` | `components/rank_component.gd` | tier ordinals, `TIER_SPAN`/`DIVISION_SPAN`/`DIVISIONS`, `rp_thresholds`, `ranked_streak_thresholds` |
| `server/matchmaking.json` | `components/server_connection.gd` | `GATE_BANDS`, `MM_TICK`, `ADMIN_USERNAMES` |
| `server/title_data.json` | `scripts/player_component.gd` | `title_data` word list (currently unread — see the note in the file) |
| `engine/enums.json` | `scripts/types/*.gd` + 4 others | 14 enums whose **ordinals** are wire- or save-visible |
| `engine/name_tables.json` | `scripts/character_component.gd` | `RESERVED_EFFECT_NAMES` (name → why), `HERO_SHIELD_BOUND` |
| `engine/ability_classes.json` | `abilities/scripts/ability_component.gd` | `CLASS_NAMES` — the canonical ability-class vocabulary (append-only), `FREE_SKILLS_MARK` |
| `progression/mastery.json` | `components/mastery_config.gd` | 101-row XP ladder, per-match XP, cosmetic unlock levels |

## Verifying

```
python tools/reference_data.py            # re-derives everything by PARSING the .gd source
                                          # and fails (exit 1) on any drift. No Godot needed.
python tools/reference_data.py --write    # regenerate after an intended source change
python tools/reference_data.py --audit    # + advisory cross-file sync report
```

Two Godot-side probes cover what static parsing cannot. Both are **read-only** and write nothing:

```
godot --headless --path . --script res://tools/check_extraction_vs_godot.gd   # data/ == live Godot values
godot --headless --path . --script res://tools/check_split_desc_sync.gd       # ability text still in sync
```
