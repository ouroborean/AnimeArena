# -*- coding: utf-8 -*-
"""
Derive / audit each roster character's energy-filter `colors` from the ACTUAL energy
costs of their abilities in abilities_data.json — instead of hand-authoring them.

The character-select colour filter (webclient app.js) reads roster.json's `colors`
array and matches a character iff it uses ALL selected colours. The correct value is
the set of distinct NON-random cost colours across the character's `<path><N>.gd`
abilities. Random (index 4) is a wildcard and is never a filter colour.

Colour indices: 0=Green 1=Blue 2=White 3=Red 4=Random.

Usage:
  python tools/roster_colors.py           # audit: list characters whose colors drift
  python tools/roster_colors.py --fix      # rewrite colors in BOTH roster.json trees

Run this whenever a character is added or their ability costs change.
"""
import json, re, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AD = os.path.join(ROOT, "abilities_data.json")
ROSTERS = [os.path.join(ROOT, "webclient", "app", "roster.json"),
           os.path.join(ROOT, "deploy", "roster.json")]
NAMES = ["Green", "Blue", "White", "Red", "Random"]


def build_path_costs():
    ad = json.load(open(AD, encoding="utf-8"))
    by_path = {}
    for _k, v in ad.items():
        if not isinstance(v, dict):
            continue
        m = re.match(r'^res://abilities/([a-zA-Z0-9]+?)\d+\.gd$', v.get("script_path", ""))
        if not m:
            continue
        by_path.setdefault(m.group(1), []).append(v.get("cost") or {})
    return by_path


def derive(path, by_path):
    """Sorted list of non-random colour indices the character's abilities cost, or None
    if no abilities map to this path (leave such a row untouched rather than guess)."""
    costs = by_path.get(path)
    if not costs:
        return None
    used = set()
    for c in costs:
        for idx in range(4):  # 0..3 only; 4=Random is a wildcard, never a filter colour
            if int(c.get(str(idx), 0)) > 0:
                used.add(idx)
    return sorted(used)


def audit(by_path):
    roster = json.load(open(ROSTERS[0], encoding="utf-8"))
    rows = []
    for r in roster:
        p = r.get("path_name")
        cur = sorted(set(r.get("colors") or []))
        d = derive(p, by_path)
        if d is None or cur == d:
            continue
        rows.append((p, r.get("name"), cur, d))
    return rows, len(roster)


def fix(by_path):
    changed_total = {}
    for path in ROSTERS:
        roster = json.load(open(path, encoding="utf-8"))
        # Round-trip stability guard: re-dumping the UNMODIFIED data must reproduce the file
        # byte-for-byte, so the write only ever changes the colour arrays we intend.
        original = open(path, encoding="utf-8").read()
        redump = json.dumps(roster, indent=0, ensure_ascii=False)
        if redump.strip() != original.strip():
            print("ABORT: %s does not round-trip under json.dumps(indent=0); "
                  "not rewriting to avoid unrelated churn." % path)
            sys.exit(2)
        changed = []
        for r in roster:
            d = derive(r.get("path_name"), by_path)
            if d is None:
                continue
            if sorted(set(r.get("colors") or [])) != d:
                changed.append((r.get("path_name"), r.get("colors"), d))
                r["colors"] = d
        open(path, "w", encoding="utf-8", newline="").write(
            json.dumps(roster, indent=0, ensure_ascii=False))
        changed_total[path] = changed
    return changed_total


def main():
    by_path = build_path_costs()
    do_fix = "--fix" in sys.argv[1:]
    rows, total = audit(by_path)
    if not do_fix:
        print("Audited %d characters — %d drift:" % (total, len(rows)))
        for p, n, cur, d in sorted(rows):
            print("  %-18s %-26s %s %s  ->  %s %s"
                  % (p, n, cur, [NAMES[i] for i in cur], d, [NAMES[i] for i in d]))
        if not rows:
            print("  (all colors match derived-from-cost — nothing to do)")
        return
    ct = fix(by_path)
    for path, changed in ct.items():
        print("%s: %d updated" % (path, len(changed)))
        for p, old, new in changed:
            print("   %-18s %s -> %s" % (p, old, new))


if __name__ == "__main__":
    main()
