extends Node
# Bot-vs-bot + pinned-bot follow-up. Bot-vs-bot pairs are now ALLOWED (lowest priority): the pairing tier
# is human-human > human-bot > bot-bot, so humans still pair each other first, a lone human still gets a
# bot instantly, and two idle bots only play each other when no human is in the pair. Also: an admin-PINNED
# bot stays online regardless of the time-of-day schedule. Bare ServerConnection (off-tree, no server boot).
#   godot --headless --path <repo> res://training/tests/ultra_bots_botvbot_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _cand(peer, rating, now, waited_ms):
	return {"peer": peer, "rating": rating, "enqueued_ms": now - waited_ms, "username": "u" + str(peer), "last_opp": "", "top": false}

func _peers(pair) -> Array:
	var out := []
	for c in pair: out.append(int(c["peer"]))
	return out

func _ready():
	print("=== Ultra Bots bot-vs-bot + pinning probe ===")
	var S = load("res://components/server_connection.gd").new()   # bare: _ready does NOT boot a server
	S._gate_tick_running = true   # suppress the sweep so the rotation tick's enqueue can't seat a match (no tree here)
	S._ultra_bot_deployed = true  # the rotation tick is a no-op until the fleet is deployed (admin switch)
	var now := 9000000
	var H1 = _cand(1000000001, 1200, now, 20000)
	var H2 = _cand(1000000002, 1250, now, 20000)
	var B1 = _cand(-1000000060, 1210, now, 20000)
	var B2 = _cand(-1000000061, 1220, now, 20000)
	var B3 = _cand(-1000000062, 1400, now, 20000)

	# ---- bot-vs-bot now pairs (it was skipped before) ----
	_check(S._best_gated_ranked_pair([B1, B2], now).size() == 2, "two idle bots now pair (bot-vs-bot enabled)")

	# ---- tier order: human-human > human-bot > bot-bot ----
	var mix = _peers(S._best_gated_ranked_pair([H1, H2, B1], now))
	_check(1000000001 in mix and 1000000002 in mix, "tier: human-human wins over human-bot")
	var oneH = _peers(S._best_gated_ranked_pair([H1, B1, B2], now))
	_check(1000000001 in oneH, "tier: 1 human + 2 bots -> the human is in the pair (human-bot beats bot-bot)")
	var allB = _peers(S._best_gated_ranked_pair([B1, B2, B3], now))
	_check(allB.size() == 2, "tier: 3 bots -> two of them pair")
	_check(-1000000060 in allB and -1000000061 in allB, "bot-vs-bot picks the closest-rated bot pair (1210 vs 1220)")

	# ---- pinning: a pinned out-of-window bot stays online ----
	# Fixed test roster (decoupled from the shipped ultra_bots.json). MiddayHunter's window is [12,18).
	S._ultra_bot_roster_override = [
		{"username": "MiddayHunter", "rating": 900, "preferred_team": ["gon", "hisoka", "killua"], "online_windows": [[12, 18]]},
	]
	for entry in S._load_ultra_bot_roster():
		var bot = S._build_ultra_bot_player(entry)
		if bot != null: S.players[bot.username] = bot
	# MiddayHunter's window is [12,18]; pin it, then tick at hour 3 (out of window) -> must stay online.
	S._ultra_bot_online("MiddayHunter")
	S._ultra_bot_pinned["MiddayHunter"] = true
	S._ultra_bot_rotation_tick(3)
	_check("MiddayHunter" in S._ultra_bot_peers, "pinned bot stays online out-of-window (schedule does NOT reclaim it)")
	# taking it offline clears the pin
	S._ultra_bot_offline("MiddayHunter")
	_check(not ("MiddayHunter" in S._ultra_bot_pinned), "offline clears the pin")
	# online again but NOT pinned -> the schedule reclaims it out-of-window
	S._ultra_bot_online("MiddayHunter")
	S._ultra_bot_rotation_tick(3)
	_check(not ("MiddayHunter" in S._ultra_bot_peers), "an un-pinned out-of-window bot IS reclaimed by the schedule")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
