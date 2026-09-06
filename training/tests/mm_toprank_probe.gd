extends Node
# Verifies the Master/Grandmaster instant-pairing change in _best_gated_ranked_pair:
# two top-rank queuers pair regardless of rating gap; everyone else keeps the gated wait.
#   godot --headless --path . res://training/tests/mm_toprank_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _ready():
	# Bare instance — _ready() (socket/timer setup) only fires on tree entry, which .new() skips.
	var sc = load("res://components/server_connection.gd").new()
	var now := 100000
	var cand := func(peer, rating, wait_sec, top): return {
		"peer": peer, "rating": rating, "enqueued_ms": now - wait_sec * 1000, "top": top,
		"username": "p" + str(peer), "last_opp": "" }   # distinct names, no prior opponent -> never no-rematch-blocked

	# Threshold sanity: boundaries derived from the rank constants (TIER_SPAN=1000 -> Master 6000, GM 7000).
	var master_floor := Rank.rating_floor_for(Rank.Type.MASTER)
	var gm_floor := Rank.rating_floor_for(Rank.Type.GRANDMASTER)
	_check(Rank.tier_for_rating(master_floor)[0] == Rank.Type.MASTER, "Master floor (%d) -> Master" % master_floor)
	_check(Rank.tier_for_rating(master_floor - 1)[0] < Rank.Type.MASTER, "just below Master floor -> below Master")
	_check(Rank.tier_for_rating(gm_floor)[0] == Rank.Type.GRANDMASTER, "GM floor (%d) -> Grandmaster" % gm_floor)
	_check(Rank.Type.GRANDMASTER >= Rank.Type.MASTER, "GM counts as top")

	# 1) Two top-rank players 3500 apart, each waited only 1s -> pair IMMEDIATELY (the fix).
	var p1 = sc._best_gated_ranked_pair([cand.call(1, 2500, 1, true), cand.call(2, 6000, 1, true)], now)
	_check(not p1.is_empty(), "Two Master/GM 3500 apart pair at 1s (was gated to 60s -> bot)")

	# 2) Two NON-top players 1500 apart -> now pair IMMEDIATELY too: the rank/distance gate was lifted
	#    2026-08-14 (small player base), so the top-rank bypass is no longer a special case — everyone
	#    pairs at once, closest-first.
	var p2 = sc._best_gated_ranked_pair([cand.call(1, 500, 1, false), cand.call(2, 2000, 1, false)], now)
	_check(not p2.is_empty(), "Two non-top players 1500 apart now pair immediately (gate lifted)")

	# 3) Master + Diamond 500 apart -> also pairs immediately now (no gating for anyone).
	var p3 = sc._best_gated_ranked_pair([cand.call(1, 2500, 1, true), cand.call(2, 2000, 1, false)], now)
	_check(not p3.is_empty(), "Master + non-top pair immediately too (gate lifted)")

	# 4) Two top players at 0s wait, tiny gap -> pair (required wait is 0, 0 > 0 is false).
	var p4 = sc._best_gated_ranked_pair([cand.call(1, 2450, 0, true), cand.call(2, 2500, 0, true)], now)
	_check(not p4.is_empty(), "Two Master/GM pair at 0s wait")

	# 5) Regression: two CLOSE non-top players (same division) still pair instantly.
	var p5 = sc._best_gated_ranked_pair([cand.call(1, 1000, 0, false), cand.call(2, 1050, 0, false)], now)
	_check(not p5.is_empty(), "Two close non-top players still pair instantly (unchanged)")

	sc.free()
	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
