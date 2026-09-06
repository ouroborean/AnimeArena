extends Node
# Ultra Bots NO-REMATCH (owner 2026-08-16): an ultra bot won't be paired with the exact opponent it just
# faced. Human-vs-human rematches stay allowed (owner 2026-08-15). Tests _best_gated_ranked_pair directly
# with hand-built candidate dicts. Bare ServerConnection (off-tree).
#   godot --headless --path <repo> res://training/tests/ultra_bots_rematch_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _cand(peer, uname, is_ultra, last_opp, now):
	return {"peer": peer, "rating": 1200, "enqueued_ms": now - 60000, "username": uname,
			"is_ultra": is_ultra, "last_opp": last_opp, "top": false}

func _peers(pair) -> Array:
	var out := []
	for c in pair: out.append(int(c["peer"]))
	return out

func _ready():
	print("=== Ultra Bots no-rematch probe ===")
	var S = load("res://components/server_connection.gd").new()
	var now := 9000000
	var A = _cand(-1000000060, "BotA", true, "BotB", now)     # ultra bot, just played BotB
	var B = _cand(-1000000061, "BotB", true, "BotA", now)     # ultra bot, just played BotA
	var C = _cand(-1000000062, "BotC", true, "", now)         # ultra bot, unrelated
	var H = _cand(1000000005, "HumanH", false, "", now)       # human, unrelated

	# 1) two ultra bots that just faced each other DON'T re-pair (their only option is a rematch)
	_check(S._best_gated_ranked_pair([A, B], now).is_empty(), "two ultra bots avoid an immediate rematch")

	# 2) with a third bot available, the A+B rematch is never the chosen pair
	var p2 := _peers(S._best_gated_ranked_pair([A, B, C], now))
	_check(p2.size() == 2 and not (-1000000060 in p2 and -1000000061 in p2), "A+B is never chosen when a third opponent exists")

	# 3) an ultra bot avoids the HUMAN it just faced
	var Auh = _cand(-1000000060, "BotA", true, "HumanH", now)
	_check(S._best_gated_ranked_pair([Auh, H], now).is_empty(), "an ultra bot avoids the human it just played")

	# 4) human-vs-human rematch is STILL allowed (owner 2026-08-15 rule preserved)
	var H1 = _cand(1000000005, "HumanH", false, "HumanG", now)
	var H2 = _cand(1000000006, "HumanG", false, "HumanH", now)
	_check(S._best_gated_ranked_pair([H1, H2], now).size() == 2, "human-vs-human rematch is still allowed")

	# 5) an ultra bot re-pairs freely with someone who ISN'T its last opponent
	_check(S._best_gated_ranked_pair([C, H], now).size() == 2, "ultra bot pairs with a non-last opponent")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
