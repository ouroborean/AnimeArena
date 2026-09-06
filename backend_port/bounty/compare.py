"""Diff the non-Godot bounty generator against the engine-captured fixtures. Exact equality only.

  python compare.py
"""

import json
import os
import sys

from bounty_gen import BountyData, generate
from godot_primitives import GodotRNG, godot_hash

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as fh:
        return json.load(fh)


def check_primitives():
    fx = load("primitives_fixture.json")
    fails = 0
    for row in fx["hashes"]:
        got = godot_hash(row["s"])
        if got != row["global_hash"] or row["global_hash"] != row["string_hash"]:
            fails += 1
            print("  FAIL hash %r got=%d global=%d string=%d"
                  % (row["s"], got, row["global_hash"], row["string_hash"]))
    for row in fx["rng"]:
        rng = GodotRNG(row["seed_in"])
        got = [rng.randi() for _ in range(len(row["randi"]))]
        if got != row["randi"]:
            fails += 1
            print("  FAIL randi seed=%d\n    got %s\n    exp %s" % (row["seed_in"], got, row["randi"]))
        rng = GodotRNG(row["seed_in"])
        got = ([rng.randi_range(0, 5) for _ in range(8)]
               + [rng.randi_range(0, 8) for _ in range(4)]
               + [rng.randi_range(0, 38) for _ in range(4)])
        if got != row["randi_range"]:
            fails += 1
            print("  FAIL randi_range seed=%d\n    got %s\n    exp %s"
                  % (row["seed_in"], got, row["randi_range"]))
        # Degenerate/reversed ranges interleaved with normal ones: this is the row that pins
        # whether randi_range(0, 0) advances the stream (it does not).
        rng = GodotRNG(row["seed_in"])
        got = [rng.randi_range(0, 5), rng.randi_range(0, 0), rng.randi_range(0, 5),
               rng.randi_range(7, 7), rng.randi_range(0, 5), rng.randi_range(5, 0),
               rng.randi_range(0, 5), rng.randi_range(-3, 3), rng.randi_range(0, 5)]
        if got != row["degenerate_mix"]:
            fails += 1
            print("  FAIL degenerate_mix seed=%d\n    got %s\n    exp %s"
                  % (row["seed_in"], got, row["degenerate_mix"]))
    print("primitives: %d hash cases + %d rng seeds, %d failures"
          % (len(fx["hashes"]), len(fx["rng"]), fails))
    return fails


def check_generation(fixture="generation_fixture.json", label="generation"):
    data = BountyData()
    try:
        fx = load(fixture)
    except IOError:
        print("%s: no fixture, skipped" % label)
        return 0
    fails = 0
    by_group = {}
    for case in fx["cases"]:
        missions, seed_input, seed_hash = generate(
            data, case["player"], case["path"], case["rerolls"], case["type"])
        name = "%r/%s/rr=%s/%s" % (case["player"], case["path"], case["rerolls"], case["type"])
        ok = True
        if seed_input != case["seed_input"]:
            ok = False
            print("  FAIL seed_input %s: %r != %r" % (name, seed_input, case["seed_input"]))
        if seed_hash != case["seed_hash"]:
            ok = False
            print("  FAIL seed_hash %s: %d != %d" % (name, seed_hash, case["seed_hash"]))
        if missions != case["missions"]:
            ok = False
            print("  FAIL missions %s" % name)
            for i, (a, b) in enumerate(zip(missions, case["missions"])):
                if a != b:
                    print("      square %2d  got %s  exp %s" % (i, a, b))
        if not ok:
            fails += 1
        g = case.get("group", "?")
        by_group[g] = by_group.get(g, 0) + 1
    print("%s: %d cases (%s), %d failures"
          % (label, len(fx["cases"]),
             ", ".join("%s=%d" % kv for kv in sorted(by_group.items())), fails))
    return fails


def check_fallback():
    """The bounty_types.is_empty() fallback + off-roster paths + multi-digit reroll counts."""
    try:
        fx = load("fallback_fixture.json")
    except IOError:
        print("fallback: no fixture, skipped")
        return 0
    data = BountyData()
    # "vessel" is not in char_name_list, so its universe is not in reference_data's roster.
    for name, universe in fx["off_roster_universes"].items():
        data.universe_of.setdefault(name, universe)
    fails = 0
    for case in fx["cases"]:
        missions, seed_input, seed_hash = generate(
            data, case["player"], case["path"], case["rerolls"], case["type"])
        label = "%r/%s/rr=%s/%s" % (case["player"], case["path"], case["rerolls"], case["type"])
        if (missions != case["missions"] or seed_input != case["seed_input"]
                or seed_hash != case["seed_hash"]):
            fails += 1
            print("  FAIL fallback %s" % label)
            for i, (a, b) in enumerate(zip(missions, case["missions"])):
                if a != b:
                    print("      square %2d  got %s  exp %s" % (i, a, b))
    print("fallback: %d cases, %d failures" % (len(fx["cases"]), fails))
    return fails


def check_live_progress():
    """Cross-check the reproduced cards against REAL in-flight save data (read-only).

    ausers/*.dat stores only the per-square progress counts, not the missions — but
    check_all_bounties() caps each count at missions[i][2]. So every stored count must be <= the
    required count we reproduce, and a maxed square must equal it exactly. 200+ live constraints.
    """
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    ausers = os.path.join(root, "ausers")
    if not os.path.isdir(ausers):
        print("live: no ausers/ directory, skipped")
        return 0
    data = BountyData()
    fails = 0
    checked = 0
    cards = 0
    at_cap = 0
    control_fails = 0   # negative control: same account, WRONG reroll count -> a different card
    for fname in sorted(os.listdir(ausers)):
        if not fname.endswith(".dat"):
            continue
        try:
            with open(os.path.join(ausers, fname), encoding="utf-8") as fh:
                acct = json.load(fh)
        except Exception:
            continue
        active = acct.get("active_bounties") or {}
        if not isinstance(active, dict) or not active:
            continue
        username = acct.get("username")
        rerolls_map = acct.get("bounty_rerolls") or {}
        for key, progress in active.items():
            btype = "unlock"
            raw = key
            if key.endswith("_mastery"):
                btype = "mastery"
                raw = key[: -len("_mastery")]
            rr = 0
            if isinstance(rerolls_map, dict) and key in rerolls_map:
                rr = int(rerolls_map[key])
            missions, _, _ = generate(data, username, raw, str(rr), btype)
            control, _, _ = generate(data, username, raw, str(rr + 1), btype)
            cards += 1
            for i, got in enumerate(progress):
                required = missions[i][2]
                checked += 1
                if got == required:
                    at_cap += 1
                if got > required:
                    fails += 1
                    print("  FAIL %s/%s square %d: stored progress %s > reproduced required %d (%s)"
                          % (username, key, i, got, required, missions[i]))
                if got > control[i][2]:
                    control_fails += 1
    print("live: %d real cards, %d square constraints, %d violations "
          "(%d squares sit exactly at their reproduced cap)" % (cards, checked, fails, at_cap))
    print("live negative control (same cards regenerated with rerolls+1): %d violations "
          "— a non-zero number here is what gives the check teeth" % control_fails)
    return fails


if __name__ == "__main__":
    total = (check_primitives()
             + check_generation()
             # every roster character, so the proof covers the whole character space
             + check_generation("roster_fixture.json", "roster")
             + check_fallback()
             + check_live_progress())
    print("\nTOTAL FAILURES: %d" % total)
    sys.exit(1 if total else 0)
