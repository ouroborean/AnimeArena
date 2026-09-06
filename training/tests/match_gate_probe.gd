extends Node

# Ranked matchmaking probe (rewritten 2026-08-14 for the ladder rework):
#   - Req 1: the rank/rating gate is LIFTED. ranked_required_wait() returns 0 for every gap, so any two
#     queued players pair immediately — closest-rated pair first (a quality nicety, not a restriction).
#   - Back-to-back rematches ALLOWED (owner request 2026-08-15): the former no-back-to-back rule is
#     disabled, so two players who just faced each other pair again immediately (last_opp no longer gates).
#   Runs against the pure functions on a bare ServerConnection instance (NOT added to the tree —
#   _ready would boot a whole game server).

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

# Mirrors the shape _collect_ranked_candidates builds (peer/rating/enqueued_ms/username/last_opp/top).
func _c(peer: int, rating: int, waited_s: float, now_ms: int, username := "", last_opp := "") -> Dictionary:
	return {
		"peer": peer, "rating": rating, "enqueued_ms": now_ms - int(waited_s * 1000.0),
		"username": (username if username != "" else "p" + str(peer)),
		"last_opp": last_opp,
		"top": Rank.tier_for_rating(rating)[0] >= Rank.Type.MASTER,
	}

func _ready() -> void:
	print("=== ranked matchmaking probe (gate lifted + rematches allowed) ===")
	var S = load("res://components/server_connection.gd").new()
	var now := 1000000

	# ---- Req 1: the gate is lifted — zero wait at every distance --------------------------------
	ck("ranked_required_wait is 0 at delta 0", S.ranked_required_wait(0) == 0.0)
	ck("ranked_required_wait is 0 at delta 500", S.ranked_required_wait(500) == 0.0)
	ck("ranked_required_wait is 0 at a huge delta (5000)", S.ranked_required_wait(5000) == 0.0)

	# Any two queued players pair immediately, however far apart.
	var far: Array = S._best_gated_ranked_pair([_c(1, 1000, 0.0, now), _c(2, 6000, 0.0, now)], now)
	ck("two players 5000 apart pair immediately (rank restriction lifted)", far.size() == 2)
	var same: Array = S._best_gated_ranked_pair([_c(1, 1500, 0.0, now), _c(2, 1500, 0.0, now)], now)
	ck("two equal-rated players pair immediately", same.size() == 2)

	# Closest-rated pair still wins when several are legal.
	var three: Array = S._best_gated_ranked_pair(
		[_c(1, 1000, 0.0, now), _c(2, 1010, 0.0, now), _c(3, 5000, 0.0, now)], now)
	ck("picks the CLOSEST pair among candidates", three.size() == 2
		and absi(int(three[0]["rating"]) - int(three[1]["rating"])) == 10)

	# ---- Back-to-back rematches ALLOWED (owner request 2026-08-15) ------------------------------
	# The former no-back-to-back rule is disabled: two players whose most recent ladder opponent was
	# each other pair again immediately, exactly like any other pair.
	var alice_bob: Array = S._best_gated_ranked_pair(
		[_c(1, 1000, 0.0, now, "alice", "bob"), _c(2, 1000, 0.0, now, "bob", "alice")], now)
	ck("two players who just faced each other CAN be re-paired (no-back-to-back disabled)", alice_bob.size() == 2)

	# last_opp no longer influences pairing: the closest-rated pair wins even when it is a rematch.
	var trio: Array = S._best_gated_ranked_pair(
		[_c(1, 1000, 0.0, now, "alice", "bob"), _c(2, 1000, 0.0, now, "bob", "alice"),
		 _c(3, 1005, 0.0, now, "carol", "")], now)
	ck("closest pair (a rematch) still wins over a farther-rated fresh opponent",
		trio.size() == 2 and ("alice" in [trio[0]["username"], trio[1]["username"]])
		and ("bob" in [trio[0]["username"], trio[1]["username"]]))

	# ---- the no-await invariant (unchanged safety argument for atomic seating) ------------------
	var src: String = FileAccess.get_file_as_string("res://components/server_connection.gd")
	var bad := 0
	for fname in ["func _gate_tick(", "func _best_gated_ranked_pair(", "func _collect_ranked_candidates(",
			"func _ranked_entry_verdict(", "func _release_queues(", "func _find_ranked_entry("]:
		var i: int = src.find(fname)
		if i < 0:
			printerr("    could not locate %s" % fname)
			bad += 1
			continue
		var j := src.find("\nfunc ", i + 1)
		var body: String = src.substr(i, (j - i) if j > i else 4000)
		var code := ""
		for line in body.split("\n"):
			if not line.strip_edges().begins_with("#"):
				code += line + "\n"
		if code.contains("await"):
			printerr("    %s CONTAINS await" % fname)
			bad += 1
	ck("no await anywhere in the sweep path (pair-seating stays atomic)", bad == 0)

	S.free()
	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
