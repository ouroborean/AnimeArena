#!/usr/bin/env python3
"""Extract + verify every GDScript-trapped reference dataset. NO GODOT REQUIRED.

The Godot server is still the live server; this tool never touches it. It re-derives
each dataset by PARSING the .gd source and either writes it to data/ (`--write`) or
asserts the on-disk JSON already matches (default, exits 1 on any drift).

    python tools/reference_data.py            # verify; non-zero exit on drift
    python tools/reference_data.py --write    # (re)generate data/*.json
    python tools/reference_data.py --audit    # + cross-file sync report (advisory)

Verify and write share ONE derivation path (`build_all`), so the check cannot pass by
comparing a stale generator against a stale file — there is no second copy to rot.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gdlit  # noqa: E402
from gdlit import Call, Ident  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

SRC = {
    "character_database": "scripts/character_database.gd",
    "character_concept": "components/character_concept.gd",
    "bucket_handler": "components/bucket_handler.gd",
    "bounty": "scripts/bounty.gd",
    "rank_component": "components/rank_component.gd",
    "server_connection": "components/server_connection.gd",
    "match": "components/match.gd",
    "stats_db": "components/stats_db.gd",
    "player_component": "scripts/player_component.gd",
    # --- found by the sweep, beyond the originally-confirmed list -------------
    "mastery_config": "components/mastery_config.gd",
    "character_component": "scripts/character_component.gd",
    "ability_component": "abilities/scripts/ability_component.gd",
    "jinwoo": "character/jinwoo.gd",
}

# Every GDScript enum whose ORDINALS are observable outside Godot — they appear in
# abilities_data.json (target_type, cost keys), on the wire (match_type, effect/damage
# types in snapshots and battle-log events) or in save data (Universe, clan Rank). A
# reimplementation that renumbers any of them silently corrupts existing content.
# (relative .gd path, enum name, who observes the ordinals). The qualifying class name is read
# from the file's own `class_name`, not hard-coded — scripts/types/elements.gd declares `Element`,
# not `Elements`, and a hand-written label would just be a second thing to keep in sync.
ENUM_SOURCES = [
    ("scripts/types/energy.gd", "Type", "ability cost dictionary KEYS in abilities_data.json; roster.json `colors`"),
    ("scripts/types/target_type.gd", "Type", "abilities_data.json `target_type`"),
    ("scripts/types/damage_type.gd", "Type", "damage events / receive-triggers"),
    ("scripts/types/effect_type.gd", "Type", "effect payloads in match snapshots"),
    ("scripts/types/stat_type.gd", "Type", "stat mod effects"),
    ("scripts/types/elements.gd", "Type", "elemental tagging on effects"),
    ("scripts/types/ending_type.gd", "Type", "effect-removal reason"),
    ("scripts/battle_log_event.gd", "Kind", "battle log / replay event kind"),
    ("new multiplayer/battle_manager.gd", "MatchType", "match_type on the wire; `match_type == 3` IS ranked"),
    ("new multiplayer/battle_manager.gd", "Gamestate", "battle phase"),
    ("components/rank_component.gd", "Type", "ladder tier"),
    ("components/clan.gd", "Rank", "clan member role in save data"),
    ("components/character_concept.gd", "Universe", "Nexus bucket keys; authored-character universe in save data"),
    ("components/server_connection.gd", "Connection", "connection state (server-internal)"),
]


def src(key: str) -> str:
    with open(os.path.join(ROOT, SRC[key]), encoding="utf-8") as f:
        return f.read()


def _prov(gd_path: str, symbols) -> dict:
    """Provenance stamp so a reader of the JSON can find (and re-verify) its origin."""
    return {"_source": gd_path, "_symbols": list(symbols),
            "_generated_by": "tools/reference_data.py"}


# ---------------------------------------------------------------------------
# 1. scripts/character_database.gd
# ---------------------------------------------------------------------------

def build_character_lists() -> dict:
    s = src("character_database")
    out = _prov(SRC["character_database"],
                ["char_name_list", "starter_character_list", "starter_squads"])
    for fn in ("char_name_list", "starter_character_list", "starter_squads"):
        v = gdlit.read_return_literal(s, fn)
        assert all(isinstance(x, str) for x in v), fn
        out[fn] = v
    return out


# `universe = CharacterConcept.Universe.X` inside a character's initialize(). Character
# .from_character_name() instantiates the .tscn and calls initialize() with no argument,
# so the FIRST assignment (which is unconditional in every shipped character) is what
# by_universe() observes.
_UNIVERSE_RE = re.compile(r"^\s*universe\s*=\s*CharacterConcept\.Universe\.([A-Z_0-9]+)", re.M)
_CHARNAME_RE = re.compile(r"^\s*character_name\s*=\s*\"([^\"]*)\"", re.M)
_PATHNAME_RE = re.compile(r"^\s*path_name\s*=\s*\"([^\"]*)\"", re.M)


def _character_source(path_name: str) -> str:
    p = os.path.join(ROOT, "character", path_name + ".gd")
    with open(p, encoding="utf-8") as f:
        return f.read()


def build_character_universes(roster: list) -> dict:
    """path_name -> {display_name, universe, universe_ordinal}, in char_name_list order."""
    ordinals = universe_ordinals()
    entries = {}
    for name in roster:
        s = _character_source(name)
        mu, mn, mp = _UNIVERSE_RE.search(s), _CHARNAME_RE.search(s), _PATHNAME_RE.search(s)
        if mu is None:
            raise SystemExit(f"character/{name}.gd has no `universe = CharacterConcept.Universe.X`")
        # The declared path_name is what by_universe() buckets on — assert it matches the
        # roster key so a copy-paste character can't silently shadow another's slot.
        if mp is not None and mp.group(1) != name:
            raise SystemExit(f"character/{name}.gd declares path_name={mp.group(1)!r}")
        u = mu.group(1)
        if u not in ordinals:
            raise SystemExit(f"character/{name}.gd uses unknown universe {u!r}")
        entries[name] = {"name": mn.group(1) if mn else "",
                         "universe": u, "universe_ordinal": ordinals[u]}
    out = _prov("character/<path_name>.gd", ["character_name", "path_name", "universe"])
    out["characters"] = entries
    return out


def build_by_universe(roster: list, universes: dict) -> dict:
    """Re-derivation of CharacterDatabase.by_universe() with no exclusion.

    Keys are the Universe ORDINALS as strings (Godot keys the Dictionary by the enum's
    int value and saved data stores ordinals), and every universe is present — including
    the ones with no playable character — because by_universe() seeds the whole enum
    before filling it. bounty.gd indexes it by the caster's universe and checks
    len(...) != 0, so an absent key and an empty list are NOT the same thing.
    """
    ordinals = universe_ordinals()
    buckets = {str(o): [] for o in ordinals.values()}
    for name in roster:
        buckets[str(universes["characters"][name]["universe_ordinal"])].append(name)
    out = _prov(SRC["character_database"], ["by_universe"])
    out["_note"] = ("keys are Universe ordinals as strings; order within a list is "
                    "char_name_list order, which bounty generation indexes into")
    out["by_universe_ordinal"] = buckets
    return out


# ---------------------------------------------------------------------------
# 2. components/character_concept.gd + components/bucket_handler.gd
# ---------------------------------------------------------------------------

_ENUM_BODY_RE = re.compile(r"^enum\s+Universe\s*\{(.*?)^\}", re.M | re.S)


def universe_ordinals() -> dict:
    """Universe enum name -> ordinal. APPEND-ONLY in the source: the ordinals are
    persisted in save data, so they are data in their own right, not just labels."""
    m = _ENUM_BODY_RE.search(src("character_concept"))
    if not m:
        raise SystemExit("could not find `enum Universe` in character_concept.gd")
    body = re.sub(r"#[^\n]*", "", m.group(1))
    names = [t.strip() for t in body.split(",") if t.strip()]
    out = {}
    for i, n in enumerate(names):
        if "=" in n:
            raise SystemExit(f"Universe member {n!r} has an explicit value — ordinals are no "
                             "longer positional; update this extractor")
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", n):
            raise SystemExit(f"unexpected Universe member {n!r}")
        out[n] = i
    return out


def build_universe_enum() -> dict:
    out = _prov(SRC["character_concept"], ["Universe"])
    out["_note"] = ("APPEND-ONLY. Ordinals are persisted (bucket universe keys, authored "
                    "characters), so a new universe must go at the end.")
    out["ordinals"] = universe_ordinals()
    return out


def build_all_chars() -> dict:
    """bucket_handler.all_chars — the Nexus concept catalogue.

    The GDScript values are `CharacterConcept.create(name, path, load(png), desc, Universe.X)`
    calls, so this is not JSON and cannot be eval'd; the `load()` is rendered as its
    resource path string (which is all any non-Godot consumer can use anyway).
    """
    s = src("bucket_handler")
    ordinals = universe_ordinals()
    pairs = gdlit.read_decl(s, "all_chars")
    entries = {}
    for key, val in pairs:
        if not isinstance(val, Call) or val.name != "CharacterConcept.create":
            raise SystemExit(f"all_chars[{key!r}] is not a CharacterConcept.create call")
        name, path, port, desc, univ = val.args
        if not isinstance(port, Call) or port.name != "load":
            raise SystemExit(f"all_chars[{key!r}] portrait is not a load() call")
        if not isinstance(univ, Ident) or not univ.name.startswith("CharacterConcept.Universe."):
            raise SystemExit(f"all_chars[{key!r}] universe is not a Universe member")
        u = univ.name.rsplit(".", 1)[1]
        if u not in ordinals:
            raise SystemExit(f"all_chars[{key!r}] unknown universe {u!r}")
        if path != key:
            raise SystemExit(f"all_chars key {key!r} != declared path_name {path!r}")
        if key in entries:
            raise SystemExit(f"duplicate all_chars key {key!r}")
        entries[key] = {"name": name, "portrait": port.args[0], "description": desc,
                        "universe": u, "universe_ordinal": ordinals[u]}
    out = _prov(SRC["bucket_handler"], ["all_chars"])
    out["_note"] = ("Insertion order preserved: initialize_buckets() iterates all_chars in "
                    "order. `portrait` is the res:// path the GDScript load() resolves.")
    out["concepts"] = entries
    return out


_BUCKET_ORDER_RE = re.compile(r"CharacterConcept\.Universe\.([A-Z_0-9]+)\s*:\s*\{\}")


def build_nexus_tables() -> dict:
    s = src("bucket_handler")
    ordinals = universe_ordinals()
    # initialize_buckets() seeds all_buckets with an explicit universe list. It is written
    # out by hand rather than looped over the enum, so it can (and does) fall behind it.
    body_start = s.index("func initialize_buckets():")
    body = s[body_start:s.index("_load_removed_list()", body_start)]
    seeded = _BUCKET_ORDER_RE.findall(body)
    for u in seeded:
        if u not in ordinals:
            raise SystemExit(f"initialize_buckets seeds unknown universe {u!r}")
    out = _prov(SRC["bucket_handler"], ["PERMANENT_EXCLUDED", "initialize_buckets"])
    out["permanent_excluded"] = gdlit.read_decl(s, "PERMANENT_EXCLUDED")
    out["bucket_universe_order"] = seeded
    out["bucket_universes_missing_from_seed"] = [u for u in ordinals if u not in seeded]
    out["removed_list_file"] = "bucket data/removed_list.dat"
    out["bucket_ap_file_pattern"] = "bucket data/<path_name>.dat"
    return out


# ---------------------------------------------------------------------------
# 3. scripts/bounty.gd
# ---------------------------------------------------------------------------

def build_bounty() -> dict:
    s = src("bounty")
    categories = gdlit.pairs_to_dict(gdlit.read_decl(s, "categories"))
    flat = gdlit.pairs_to_dict(gdlit.read_local_decl(s, "flat_bounty_categories", "_categories"))
    archetypes = gdlit.read_decl(s, "archetypes")
    listed = gdlit.read_return_literal(s, "get_archetype_list")

    out = _prov(SRC["bounty"], ["mission_types", "winning_patterns", "categories",
                                "archetypes", "get_archetype_list",
                                "flat_bounty_categories._categories"])
    out["mission_types"] = gdlit.read_decl(s, "mission_types")
    out["_mission_types_note"] = ("A WEIGHTED table, not a set: generation rolls "
                                  "randi_range(0, 5) over it, so with:against:versus = 3:2:1.")
    out["winning_patterns"] = gdlit.read_decl(s, "winning_patterns")
    out["categories"] = categories
    out["archetypes"] = archetypes
    out["_consistency"] = {
        "flat_bounty_categories_copy_agrees": flat == categories,
        "get_archetype_list_matches_archetypes": listed == archetypes,
        "archetypes_with_no_category": [a for a in archetypes if a not in categories],
        "categories_not_in_archetypes": [k for k in categories if k not in archetypes],
    }
    out["mission_target_counts"] = {
        "_note": "win counts hard-coded in generate_from_details, by mission type and specificity",
        "with": {"archetype": 6, "specific_character": 4},
        "against": {"archetype": 4, "specific_character": 3},
        "versus": {"_note": "1 or 2 for the with-half + 0 or 1 for the against-half; "
                            "specific target -> the lower number", "min": 1, "max": 3},
    }
    out["board_size"] = 25
    out["mastery_suffix"] = "_mastery"
    return out


# ---------------------------------------------------------------------------
# 4. components/rank_component.gd
# ---------------------------------------------------------------------------

_TIER_ENUM_RE = re.compile(r"^enum\s+Type\s*\{(.*?)^\}", re.M | re.S)


def _tier_ordinals() -> dict:
    m = _TIER_ENUM_RE.search(src("rank_component"))
    if not m:
        raise SystemExit("could not find `enum Type` in rank_component.gd")
    names = [t.strip() for t in re.sub(r"#[^\n]*", "", m.group(1)).split(",") if t.strip()]
    return {n: i for i, n in enumerate(names)}


def _keyed_by_tier(pairs, tiers) -> dict:
    out = {}
    for k, v in pairs:
        if not isinstance(k, Ident) or not k.name.startswith("Type."):
            raise SystemExit(f"rank table key {k!r} is not a Type member")
        name = k.name.split(".", 1)[1]
        if name not in tiers:
            raise SystemExit(f"unknown rank tier {name!r}")
        out[name] = v
    return out


def _const_int(s: str, name: str) -> int:
    m = re.search(r"^const\s+" + name + r"\s*:?=\s*(-?\d+)", s, re.M)
    if not m:
        raise SystemExit(f"const {name} not found in rank_component.gd")
    return int(m.group(1))


def build_rank_tables() -> dict:
    s = src("rank_component")
    tiers = _tier_ordinals()
    out = _prov(SRC["rank_component"], ["Type", "rp_thresholds", "ranked_streak_thresholds",
                                        "TIER_SPAN", "DIVISION_SPAN", "DIVISIONS"])
    out["tier_ordinals"] = tiers
    out["tier_span"] = _const_int(s, "TIER_SPAN")
    out["division_span"] = _const_int(s, "DIVISION_SPAN")
    out["divisions"] = _const_int(s, "DIVISIONS")
    out["rp_thresholds"] = _keyed_by_tier(gdlit.read_decl(s, "rp_thresholds"), tiers)
    out["ranked_streak_thresholds"] = _keyed_by_tier(
        gdlit.read_decl(s, "ranked_streak_thresholds"), tiers)
    out["_status_note"] = ("rp_thresholds / ranked_streak_thresholds are DORMANT: the promo-series "
                           "design that read them was removed and tiers are now a pure function of "
                           "rating (tier_for_rating). Extracted because they are the spec for that "
                           "layer if it is ever rebuilt — a port must not treat them as live.")
    return out


# ---------------------------------------------------------------------------
# 5. components/server_connection.gd
# ---------------------------------------------------------------------------

def build_matchmaking() -> dict:
    s = src("server_connection")
    bands = gdlit.read_decl(s, "GATE_BANDS")
    for b in bands:
        if not (isinstance(b, list) and len(b) == 2):
            raise SystemExit(f"malformed GATE_BANDS row {b!r}")
    out = _prov(SRC["server_connection"], ["GATE_BANDS", "MM_TICK", "ADMIN_USERNAMES"])
    out["gate_bands"] = [{"max_delta_rating": b[0], "wait_multiplier": float(b[1])} for b in bands]
    out["_gate_bands_note"] = ("max_delta_rating -1 is the catch-all. wait_multiplier is a MULTIPLE "
                               "of the ranked bot delay, not seconds — the 'far pairs meet a bot "
                               "first' property is what the multiples encode.")
    m = re.search(r"^const\s+MM_TICK\s*:?=\s*([\d.]+)", s, re.M)
    out["mm_tick_seconds"] = float(m.group(1)) if m else None
    out["admin_usernames"] = gdlit.read_decl(s, "ADMIN_USERNAMES")
    # BEHAVIOUR-VISIBLE, and easy to lose in a port because nothing else references it: a server-built
    # bot team never fields these characters (server_connection.gd:2765 filters the roster by it).
    # Omit it in a reimplementation and bots start fielding Tsubaki/Toga/Fern — a gameplay regression.
    out["bot_excluded_chars"] = gdlit.read_decl(s, "BOT_EXCLUDED_CHARS")
    return out


# ---------------------------------------------------------------------------
# 5b. components/match.gd — draft + AFK timing rules
# ---------------------------------------------------------------------------

def build_match_rules() -> dict:
    s = src("match")
    syms = ["DRAFT_BAN_SECONDS", "DRAFT_PICK_SECONDS", "DRAFT_MAX_BANS", "DRAFT_PICK_QUOTA",
            "default_match_timer", "AFK_PENALTY_STEP", "AFK_MIN_TIMER", "AFK_FORFEIT_MISSES"]
    out = _prov(SRC["match"], syms)
    for name in syms:
        out[name.lower()] = gdlit.read_decl(s, name)
    out["_afk_note"] = ("Each turn a player lets TIME OUT shaves afk_penalty_step off their turn timer, "
                        "cumulative and floored at afk_min_timer; finishing a turn MANUALLY resets it. "
                        "Missing afk_forfeit_misses turns IN A ROW auto-forfeits. The effective timer is "
                        "maxf(afk_min_timer, default_match_timer - afk_penalty_step * misses) "
                        "(components/match.gd:713).")
    out["_draft_note"] = ("draft_pick_quota is the alternating pick pattern (1,2,2,1). The whole ranked "
                          "DRAFT path is currently DEAD CODE — start_ranked_draft() has zero callers — so "
                          "these constants describe an unreachable feature. Kept as spec, not as a port "
                          "requirement; see the roadmap's decision on whether to implement drafting.")
    return out


# ---------------------------------------------------------------------------
# 5c. components/stats_db.gd — leaderboard exclusions
# ---------------------------------------------------------------------------

def build_stats_exclusions() -> dict:
    out = _prov(SRC["stats_db"], ["EXCLUDED_USERS"])
    out["excluded_users"] = gdlit.read_decl(src("stats_db"), "EXCLUDED_USERS")
    out["_note"] = ("Accounts omitted from character usage/win statistics (dev accounts). A port that "
                    "drops this silently pollutes the stats with developer games.")
    return out


# ---------------------------------------------------------------------------
# 6. scripts/player_component.gd
# ---------------------------------------------------------------------------

def build_title_data() -> dict:
    out = _prov(SRC["player_component"], ["title_data"])
    out["title_data"] = gdlit.read_decl(src("player_component"), "title_data")
    out["_status_note"] = ("Declared on Player but read by NOTHING in the Godot source (grep: the "
                           "declaration is the only hit). The live title system is the client's "
                           "webclient/app/titles.json lesser/greater word lists. Extracted for "
                           "completeness; a port should not wire it up without asking.")
    return out


# ---------------------------------------------------------------------------
# 7. engine type enums (found by the sweep; ordinals are wire/save-visible)
# ---------------------------------------------------------------------------

def _enum_members(text: str, enum_name: str, where: str) -> dict:
    m = re.search(r"^enum\s+" + re.escape(enum_name) + r"\s*\{(.*?)^\}", text, re.M | re.S)
    if not m:
        raise SystemExit(f"enum {enum_name} not found in {where}")
    body = re.sub(r"#[^\n]*", "", m.group(1))
    out, nxt = {}, 0
    for tok in (t.strip() for t in body.split(",")):
        if not tok:
            continue
        if "=" in tok:  # explicit values are legal GDScript and DO occur (Clan.Rank)
            name, val = (p.strip() for p in tok.split("=", 1))
            nxt = int(val)
        else:
            name = tok
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            raise SystemExit(f"unexpected member {tok!r} in {enum_name} ({where})")
        out[name] = nxt
        nxt += 1
    return out


def build_enums() -> dict:
    out = _prov("various (see each entry's _source)", [e[2] for e in ENUM_SOURCES])
    out["_note"] = ("Ordinals, not just names. abilities_data.json stores target_type and cost "
                    "keys as these ints, snapshots carry effect/damage types as these ints, and "
                    "save data stores Universe/clan Rank as these ints — renumbering is a data "
                    "migration, not a rename.")
    enums = {}
    for rel, enum_name, consumer in ENUM_SOURCES:
        with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
            text = f.read()
        cn = re.search(r"^class_name\s+(\w+)", text, re.M)
        if not cn:
            raise SystemExit(f"{rel} has no class_name — cannot qualify enum {enum_name}")
        qualified = f"{cn.group(1)}.{enum_name}"
        enums[qualified] = {"_source": rel, "_consumed_by": consumer,
                            "members": _enum_members(text, enum_name, rel)}
    out["enums"] = enums
    return out


# ---------------------------------------------------------------------------
# 8. components/mastery_config.gd (found by the sweep)
# ---------------------------------------------------------------------------

def build_mastery() -> dict:
    s = src("mastery_config")
    out = _prov(SRC["mastery_config"],
                ["MAX_LEVEL", "XP_THRESHOLDS", "XP_PER_WIN", "XP_PER_LOSS", "XP_FLOOR",
                 "UNLOCK_THRESHOLDS"])
    for name in ("MAX_LEVEL", "XP_PER_WIN", "XP_PER_LOSS", "XP_FLOOR"):
        m = re.search(r"^const\s+" + name + r"\s*:?=\s*(-?\d+)", s, re.M)
        if not m:
            raise SystemExit(f"const {name} not found in mastery_config.gd")
        out[name.lower()] = int(m.group(1))
    thresholds = gdlit.read_decl(s, "XP_THRESHOLDS")
    # Index IS the level and xp_to_level() walks it from MAX_LEVEL down, so an off-by-one
    # in length silently caps or over-runs the ladder.
    if len(thresholds) != out["max_level"] + 1:
        raise SystemExit(f"XP_THRESHOLDS has {len(thresholds)} rows, expected MAX_LEVEL+1 "
                         f"= {out['max_level'] + 1}")
    out["xp_thresholds"] = thresholds
    out["_xp_thresholds_note"] = "cumulative XP to reach each level; index == level, 0-based"
    out["unlock_thresholds"] = gdlit.pairs_to_dict(gdlit.read_decl(s, "UNLOCK_THRESHOLDS"))
    return out


# ---------------------------------------------------------------------------
# 9. scripts/character_component.gd (found by the sweep)
# ---------------------------------------------------------------------------

def build_engine_name_tables() -> dict:
    s = src("character_component")
    out = _prov(SRC["character_component"], ["RESERVED_EFFECT_NAMES", "HERO_SHIELD_BOUND"])
    out["reserved_effect_names"] = gdlit.pairs_to_dict(gdlit.read_decl(s, "RESERVED_EFFECT_NAMES"))
    out["_reserved_effect_names_note"] = (
        "name -> WHY it is reserved. These are effect names the engine special-cases by STRING, so "
        "any content system that lets a user pick an effect name must refuse these.")
    out["hero_shield_bound"] = gdlit.read_decl(s, "HERO_SHIELD_BOUND")
    out["_hero_shield_bound_note"] = (
        "Elemental HERO fusions whose whole effect ends when their Shield breaks. Absences are "
        "deliberate (Clayman, Avian, Burstinatrix, Bubbleman) — see the source comment.")
    return out


# ---------------------------------------------------------------------------
# 10. abilities/scripts/ability_component.gd (found by the sweep)
# ---------------------------------------------------------------------------

def build_ability_classes() -> dict:
    """CLASS_NAMES — the canonical ability-class vocabulary.

    Append-only: the strings are stored VERBATIM in abilities_data.json, so a rename is a
    data migration. from_database, AuthoredCharacter._build_moveset and the Creator's class
    whitelist all derive from this one list precisely so they cannot drift.
    """
    s = src("ability_component")
    out = _prov(SRC["ability_component"], ["CLASS_NAMES", "FREE_SKILLS_MARK"])
    out["class_names"] = gdlit.read_decl(s, "CLASS_NAMES")
    m = re.search(r'^const\s+FREE_SKILLS_MARK\s*:?=\s*"([^"]*)"', s, re.M)
    out["free_skills_mark"] = m.group(1) if m else None
    out["_free_skills_mark_note"] = ("mark name that zeroes every one of the holder's skill costs "
                                     "(Ability.cost tail) — an engine string, not a class")
    return out


# ---------------------------------------------------------------------------
# 11. character/jinwoo.gd (found by the sweep)
# ---------------------------------------------------------------------------

def build_jinwoo_forms() -> dict:
    """Jin-woo is the one roster character with no character_ability_counts row: his kit is
    a key-prefixed summon FORM chosen pre-match, so the ability keys are the data."""
    s = src("jinwoo")
    out = _prov(SRC["jinwoo"], ["FORM_KITS", "DEFAULT_KEYS"])
    out["form_kits"] = gdlit.pairs_to_dict(gdlit.read_decl(s, "FORM_KITS"))
    out["default_keys"] = gdlit.read_decl(s, "DEFAULT_KEYS")
    out["_note"] = ("Colour forms list 5 keys: index 4 is the hidden swap-in the slot-2 Summon "
                    "pulls in; only indices 0-3 are ever displayed. An unbuilt form falls back "
                    "to the basic kit.")
    return out


# ---------------------------------------------------------------------------
# assembly
# ---------------------------------------------------------------------------

def build_all() -> dict:
    """rel_path -> JSON-able object. The single derivation used by both --write and verify."""
    chars = build_character_lists()
    universes = build_character_universes(chars["char_name_list"])
    return {
        "characters/character_lists.json": chars,
        "characters/character_universes.json": universes,
        "characters/by_universe.json": build_by_universe(chars["char_name_list"], universes),
        "nexus/universe_enum.json": build_universe_enum(),
        "nexus/all_chars.json": build_all_chars(),
        "nexus/nexus_tables.json": build_nexus_tables(),
        "bounty/bounty_tables.json": build_bounty(),
        "ladder/rank_tables.json": build_rank_tables(),
        "server/matchmaking.json": build_matchmaking(),
        "server/match_rules.json": build_match_rules(),
        "server/stats_exclusions.json": build_stats_exclusions(),
        "server/title_data.json": build_title_data(),
        "engine/enums.json": build_enums(),
        "engine/name_tables.json": build_engine_name_tables(),
        "progression/mastery.json": build_mastery(),
        "engine/ability_classes.json": build_ability_classes(),
        "characters/jinwoo_form_kits.json": build_jinwoo_forms(),
    }


def _dump(obj) -> str:
    return json.dumps(obj, indent=2, ensure_ascii=False, sort_keys=False) + "\n"


def cmd_write() -> int:
    for rel, obj in build_all().items():
        p = os.path.join(DATA, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(_dump(obj))
        print(f"[write] data/{rel}")
    return 0


def _diff(expected, actual, path=""):
    """First few structural differences, as human-readable strings."""
    out = []
    if type(expected) is not type(actual) and not (
            isinstance(expected, (int, float)) and isinstance(actual, (int, float))):
        return [f"{path or '<root>'}: type {type(expected).__name__} != {type(actual).__name__}"]
    if isinstance(expected, dict):
        for k in expected:
            if k not in actual:
                out.append(f"{path}.{k}: missing from JSON")
            else:
                out += _diff(expected[k], actual[k], f"{path}.{k}")
        for k in actual:
            if k not in expected:
                out.append(f"{path}.{k}: present in JSON, absent from source")
        return out
    if isinstance(expected, list):
        if len(expected) != len(actual):
            out.append(f"{path}: length {len(expected)} != {len(actual)}")
        for i, (a, b) in enumerate(zip(expected, actual)):
            out += _diff(a, b, f"{path}[{i}]")
        return out
    if expected != actual:
        out.append(f"{path or '<root>'}: {expected!r} != {actual!r}")
    return out


def cmd_verify() -> int:
    failures = 0
    for rel, obj in build_all().items():
        p = os.path.join(DATA, rel)
        if not os.path.exists(p):
            print(f"FAIL data/{rel}: file missing (run with --write)")
            failures += 1
            continue
        with open(p, encoding="utf-8") as f:
            try:
                on_disk = json.load(f)
            except json.JSONDecodeError as e:
                print(f"FAIL data/{rel}: not valid JSON ({e})")
                failures += 1
                continue
        diffs = _diff(obj, on_disk)
        if diffs:
            failures += 1
            print(f"FAIL data/{rel}: {len(diffs)} difference(s) vs {SRC_LABEL.get(rel, 'source')}")
            for d in diffs[:12]:
                print(f"       {d}")
            if len(diffs) > 12:
                print(f"       ... and {len(diffs) - 12} more")
        else:
            n = sum(1 for k in obj if not k.startswith("_"))
            print(f"  ok  data/{rel}  ({n} top-level dataset key(s))")
    if failures:
        print(f"\nDRIFT: {failures} dataset(s) no longer match their GDScript source.")
        print("Re-run with --write after confirming the source change is intended.")
        return 1
    print("\nAll extracted datasets match their GDScript sources.")
    return 0


SRC_LABEL = {
    "characters/character_lists.json": SRC["character_database"],
    "characters/character_universes.json": "character/*.gd",
    "characters/by_universe.json": SRC["character_database"],
    "nexus/universe_enum.json": SRC["character_concept"],
    "nexus/all_chars.json": SRC["bucket_handler"],
    "nexus/nexus_tables.json": SRC["bucket_handler"],
    "bounty/bounty_tables.json": SRC["bounty"],
    "ladder/rank_tables.json": SRC["rank_component"],
    "server/matchmaking.json": SRC["server_connection"],
    "server/title_data.json": SRC["player_component"],
    "engine/enums.json": "scripts/types/*.gd + battle_manager/clan/rank/concept",
    "engine/name_tables.json": SRC["character_component"],
    "progression/mastery.json": SRC["mastery_config"],
    "engine/ability_classes.json": SRC["ability_component"],
    "characters/jinwoo_form_kits.json": SRC["jinwoo"],
}


# ---------------------------------------------------------------------------
# --audit: advisory cross-file sync report (does NOT affect the exit code, because
# these are pre-existing content decisions, not extraction drift).
# ---------------------------------------------------------------------------

def _load(rel):
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def cmd_audit() -> int:
    built = build_all()
    roster_names = built["characters/character_lists.json"]["char_name_list"]
    concepts = built["nexus/all_chars.json"]["concepts"]
    print("=" * 72)
    print("SYNC AUDIT (advisory)")
    print("=" * 72)

    roster = _load("webclient/app/roster.json") or []
    rp = [c["path_name"] for c in roster]
    print(f"\n[roster] char_name_list={len(roster_names)}  roster.json={len(rp)}")
    print(f"         identical as sets: {set(rp) == set(roster_names)}")
    print(f"         only in char_name_list: {sorted(set(roster_names) - set(rp))}")
    print(f"         only in roster.json:    {sorted(set(rp) - set(roster_names))}")

    colors = _load("character_colors.json") or {}
    print(f"\n[colors] character_colors.json={len(colors)} keys; "
          f"roster entries missing a colors row: {sorted(set(roster_names) - set(colors))}")

    counts = _load("character_ability_counts.json") or {}
    # Movesets.from_skill_count() indexes this by path_name, so a missing row is fatal for any
    # character that goes through it. Characters that build their own kit (jinwoo's key-prefixed
    # summon forms, the campaign Vessel) never call it and are legitimately absent.
    self_built = {"jinwoo", "vessel"}
    missing_counts = sorted(set(roster_names) - set(counts) - self_built)
    print(f"[counts] character_ability_counts.json={len(counts)} keys; "
          f"roster entries missing a count: {missing_counts} "
          f"(self-built kits excluded: {sorted(self_built & set(roster_names))})")

    ci = _load("webclient/app/char_index.json") or {}
    stale = sorted(set(ci) - set(concepts))
    print(f"\n[char_index] char_index.json={len(ci)}  all_chars={len(concepts)}")
    print(f"             in char_index but no longer a concept ({len(stale)}): {stale}")
    print(f"             concepts missing from char_index: {sorted(set(concepts) - set(ci))}")
    promoted = [p for p in stale if p in roster_names]
    print(f"             ...of which are now PLAYABLE ({len(promoted)}): {promoted}")
    print(f"             ...neither concept nor playable ({len(set(stale) - set(promoted))}): "
          f"{sorted(set(stale) - set(promoted))}")

    bd = os.path.join(ROOT, "bucket data")
    if os.path.isdir(bd):
        dats = {f[:-4] for f in os.listdir(bd) if f.endswith(".dat")} - {"removed_list"}
        print(f"\n[bucket data] {len(dats)} <path>.dat files vs {len(concepts)} all_chars concepts")
        print(f"              orphan .dat (concept deleted, AP row kept): "
              f"{len(dats - set(concepts))} -> {sorted(dats - set(concepts))}")
        print(f"              concepts with no .dat (created lazily at boot): "
              f"{sorted(set(concepts) - dats)}")

    perm = built["nexus/nexus_tables.json"]["permanent_excluded"]
    gone = [p for p in perm if p not in concepts]
    print(f"\n[PERMANENT_EXCLUDED] {len(perm)} entries; {len(gone)} no longer in all_chars: {gone}")
    print("                     (the source comment claims they 'stay in all_chars on purpose')")

    bt = built["bounty/bounty_tables.json"]
    known = set(roster_names) | set(concepts)
    ghosts = sorted({m for members in bt["categories"].values() for m in members} - known)
    print(f"\n[bounty] flat copy agrees with categories: "
          f"{bt['_consistency']['flat_bounty_categories_copy_agrees']}")
    print(f"         archetypes with no category table: "
          f"{bt['_consistency']['archetypes_with_no_category']}")
    print(f"         category members that are not a playable OR concept path_name: {ghosts}")
    uncat = sorted(n for n in roster_names
                   if not any(n in v for v in bt["categories"].values()))
    print(f"         playable characters in NO category ({len(uncat)}): {uncat}")

    cbd = _load("webclient/app/bounty_data.json") or {}
    print(f"         bounty_data.json categories match source: "
          f"{cbd.get('categories') == bt['categories']}")
    print(f"         bounty_data.json winning_patterns match: "
          f"{cbd.get('winning_patterns') == bt['winning_patterns']}")
    print(f"         bounty_data.json archetypes match:       "
          f"{cbd.get('archetypes') == bt['archetypes']}")
    print(f"         bounty_data.json starters match:         "
          f"{cbd.get('starters') == built['characters/character_lists.json']['starter_squads']}")

    ad = _load("abilities_data.json") or {}
    ai = _load("webclient/app/ability_info.json") or {}
    asp = _load("webclient/app/ability_split.json") or {}
    gd_present = {k for k, v in ad.items()
                  if isinstance(v.get("script_path"), str)
                  and os.path.exists(os.path.join(ROOT, v["script_path"][6:]))}
    print(f"\n[abilities] abilities_data.json={len(ad)}  with an existing .gd={len(gd_present)}  "
          f"dangling script_path={len(ad) - len(gd_present)}")
    print(f"            ability_info.json={len(ai)}  ability_split.json={len(asp)}")
    print(f"            info rows with no abilities_data row: {len(set(ai) - set(ad))}")
    print(f"            split rows with no abilities_data row: {len(set(asp) - set(ad))}")
    print(f"            live abilities with NO split entry: "
          f"{len(gd_present - set(asp))} -> {sorted(gd_present - set(asp))[:10]}")

    mism = [k for k in set(ai) & set(asp) if ai[k].get("desc") != asp[k]]
    print(f"            ability_info.desc != ability_split entry: {len(mism)} -> {mism[:8]}")
    # abilities_data.json is the ONLY source for cost / cooldown / classes / target_type: abilities
    # are built by Ability.from_database(), and abilities/ has no per-ability .tscn to disagree with
    # it. So the meaningful check is client-vs-server, which is what this compares. A row that is a
    # STUB in abilities_data (no `classes` key at all) is a template, not a disagreement — the
    # extractor's completeness gate skips it and ability_info carries the old row forward.
    cost_bad, cd_bad, cls_bad, stubs = [], [], [], []
    for k, v in ai.items():
        if k not in ad:
            continue
        d = ad[k]
        if "classes" not in d:
            stubs.append(k)
            continue
        if "cost" in d:
            if {str(a): b for a, b in d["cost"].items()} != v.get("cost"):
                cost_bad.append(k)
        elif "cost" in v:
            cost_bad.append(k)
        if d.get("cooldown") != v.get("cooldown"):
            cd_bad.append(k)
        if d.get("classes") != v.get("classes"):
            cls_bad.append(k)
    print(f"            ability_info vs abilities_data -> cost drift {len(cost_bad)} {cost_bad[:6]}, "
          f"cooldown drift {len(cd_bad)} {cd_bad[:6]}, classes drift {len(cls_bad)} {cls_bad[:6]}")
    print(f"            (skipped {len(stubs)} stub rows with no `classes` in abilities_data)")
    # CLASS_NAMES is append-only and the strings are stored verbatim, so an unknown class in the
    # DB means either a typo or a class that was renamed out from under shipped data.
    known_classes = set(built["engine/ability_classes.json"]["class_names"])
    seen = {c for v in ad.values() for c in (v.get("classes") or [])}
    print(f"            ability classes in abilities_data not in CLASS_NAMES: "
          f"{sorted(seen - known_classes)}")
    print(f"            CLASS_NAMES never used by any ability: {sorted(known_classes - seen)}")
    jk = built["characters/jinwoo_form_kits.json"]
    missing_keys = sorted({k for v in jk["form_kits"].values() for k in v} - set(ad))
    print(f"            jinwoo form-kit ability keys with no abilities_data row: {missing_keys}")
    print("\n            NOTE: split_desc() is arbitrary GDScript; only Godot can produce ground")
    print("            truth for it. See tools/check_split_desc_sync.gd (read-only probe).")
    print("\n(audit is advisory — it never changes this command's exit code)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--write", action="store_true", help="(re)generate data/*.json from the .gd sources")
    ap.add_argument("--audit", action="store_true", help="also print the cross-file sync report")
    a = ap.parse_args()
    if a.write:
        rc = cmd_write()
    else:
        rc = cmd_verify()
    if a.audit:
        cmd_audit()
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
