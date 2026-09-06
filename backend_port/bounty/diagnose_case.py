"""Throwaway diagnosis: replay a failing case and report, per square, which branch the ENGINE
must have taken (by resyncing the stream against the engine's output) vs which branch we take."""
import io
import json
import sys

from bounty_gen import BountyData
from godot_primitives import GodotRNG

d = BountyData()
fx = json.load(io.open("generation_fixture.json", encoding="utf-8"))
player, path, rr, typ = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
case = [c for c in fx["cases"] if c["player"] == player and c["path"] == path
        and c["rerolls"] == rr and c["type"] == typ][0]

bt = d.get_archetypes(path) or list(d.category_order)
su = d.by_universe(path)[d.universe_of[path]]
cats = d.categories
rng = GodotRNG(case["seed_hash"])
print("bounty_types=%s  |same_universe|=%d" % (bt, len(su)))

for i, exp in enumerate(case["missions"]):
    mt_draw = rng.randi_range(0, 5)
    mt = d.mission_types[mt_draw]
    note = ""
    if mt != exp[0]:
        print("square %2d: MISSION TYPE DIVERGES. we drew %d -> %s, engine has %s"
              % (i, mt_draw, mt, exp[0]))
        break
    if mt == "with":
        odds = rng.randi_range(0, 4)
        cat = bt[rng.randi_range(0, len(bt) - 1)]
        if odds == 0:
            members = cats[cat]
            tgt = members[rng.randi_range(0, len(members) - 1)]
            got = [mt, [cat], 6] if tgt == path else [mt, [tgt], 4]
            note = "odds=0 member=%s" % tgt
        elif odds == 1 and su:
            tgt = su[rng.randi_range(0, len(su) - 1)]
            got = [mt, [tgt], 4]
            note = "odds=1 universe=%s" % tgt
        else:
            got = [mt, [cat], 6]
            note = "odds=%d category" % odds
    elif mt == "against":
        odds = rng.randi_range(0, 8)
        cat = bt[rng.randi_range(0, len(bt) - 1)]
        if odds == 0:
            members = cats[cat]
            tgt = members[rng.randi_range(0, len(members) - 1)]
            got = [mt, [cat], 4] if tgt == path else [mt, [tgt], 3]
            note = "odds=0 member=%s" % tgt
        elif odds == 1 and su:
            tgt = su[rng.randi_range(0, len(su) - 1)]
            got = [mt, [tgt], 3]
            note = "odds=1 universe=%s" % tgt
        else:
            got = [mt, [cat], 4]
            note = "odds=%d category" % odds
    else:
        wo = rng.randi_range(0, 4)
        to = rng.randi_range(0, 8)
        wc = bt[rng.randi_range(0, len(bt) - 1)]
        tc = bt[rng.randi_range(0, len(bt) - 1)]
        vd = []
        if wo == 0:
            m = cats[wc]
            t = m[rng.randi_range(0, len(m) - 1)]
            if t == path:
                vd.append(wc); wo = 1
            else:
                vd.append(t)
        elif wo == 1 and su:
            vd.append(su[rng.randi_range(0, len(su) - 1)])
        else:
            vd.append(wc)
        if to == 0:
            m = cats[tc]
            t = m[rng.randi_range(0, len(m) - 1)]
            if t == path:
                vd.append(tc); to = 1
            else:
                vd.append(t)
        elif to == 1 and su:
            vd.append(su[rng.randi_range(0, len(su) - 1)])
        else:
            vd.append(tc)
        got = [mt, vd, (2 if wo else 1) + (1 if to else 0)]
        note = "wo=%s to=%s" % (wo, to)
    flag = "" if got == exp else "   <<< MISMATCH"
    print("square %2d: mt=%-8s %-40s exp %-40s %s%s"
          % (i, mt, str(got), str(exp), note, flag))
    if got != exp:
        break
