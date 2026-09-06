extends Node
# Phase 4 (Ultra Bots) — self-queue + seating. A bot pushes itself into the ranked queue as a normal
# candidate, the sweep pairs it with the closest-rated HUMAN, a lone bot is pinned to the p2/enemy seat
# (the seat the turn-driver runs), and two bots never pair (bot-vs-bot deferred). Runs on a bare
# ServerConnection (off-tree, so _ready does NOT boot a server).
#   godot --headless --path <repo> res://training/tests/ultra_bots_queue_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _cand(peer, rating, now, waited_ms):
	return {"peer": peer, "rating": rating, "enqueued_ms": now - waited_ms, "username": "u" + str(peer), "last_opp": "", "top": false}

func _ready():
	print("=== Ultra Bots queue probe (Phase 4) ===")
	var S = load("res://components/server_connection.gd").new()   # bare: _ready does NOT fire off-tree
	var HUMAN := 1000000005   # a JSON-range (positive) peer -> _is_bot_peer false
	var BOT := -1000000001    # a bot-range (negative) peer -> _is_bot_peer true
	var BOT2 := -1000000002

	# ---- seat ordering: a lone bot always ends up as p2 ----
	var oa = S._order_seats_bot_second([BOT, {}, []], [HUMAN, {}, []])
	_check(oa[0][0] == HUMAN and oa[1][0] == BOT, "seat order: (bot, human) -> human is p1, bot is p2")
	var ob = S._order_seats_bot_second([HUMAN, {}, []], [BOT, {}, []])
	_check(ob[0][0] == HUMAN and ob[1][0] == BOT, "seat order: (human, bot) -> unchanged (bot already p2)")
	var oc = S._order_seats_bot_second([HUMAN, {}, []], [1000000009, {}, []])
	_check(oc[0][0] == HUMAN and oc[1][0] == 1000000009, "seat order: human-vs-human unchanged")

	# ---- pairing: a bot pairs with a human, but two bots never pair ----
	var now := 5000000
	var human_bot = S._best_gated_ranked_pair([_cand(HUMAN, 1200, now, 20000), _cand(BOT, 1250, now, 20000)], now)
	_check(human_bot.size() == 2, "pairing: a bot and a human DO pair")
	var bot_bot = S._best_gated_ranked_pair([_cand(BOT, 1200, now, 20000), _cand(BOT2, 1210, now, 20000)], now)
	_check(bot_bot.size() == 2, "pairing: two idle bots DO pair (bot-vs-bot enabled; human-human still preferred)")
	# a bot + a human + a second bot -> the only legal pair is human+bot
	var mixed = S._best_gated_ranked_pair([_cand(BOT, 1200, now, 20000), _cand(BOT2, 1205, now, 20000), _cand(HUMAN, 1203, now, 20000)], now)
	_check(mixed.size() == 2 and (mixed[0]["peer"] == HUMAN or mixed[1]["peer"] == HUMAN), "pairing: with 2 bots + 1 human, the human gets a bot (not the two bots each other)")

	# ---- self-queue: an online bot lands in the ranked queue as a live candidate ----
	var bot = S._build_ultra_bot_player({"username": "QueueBot", "rating": 1200, "preferred_team": ["naruto", "sakura", "hinata"]})
	S.players["QueueBot"] = bot
	var bot_peer = S._ultra_bot_online("QueueBot")
	S._ultra_bot_enqueue_ranked("QueueBot")
	_check(not S._find_ranked_entry(bot_peer).is_empty(), "self-queue: bot is in the ranked queue")
	_check(bot_peer in S._ranked_wait_start, "self-queue: bot's wait clock is stamped")
	# The enqueue arms the ephemeral-bot fallback (like a player) so a LONE queued bot still meets a
	# regular bot after RANKED_BOT_DELAY when no human/other Ultra bot pairs with it first.
	_check(bot_peer in S._ranked_fallback_gen, "self-queue: ephemeral-bot fallback is armed for the queued bot")
	var cands = S._collect_ranked_candidates(S._ranked_wait_start.get(bot_peer, 0) + 30000)
	var found := false
	for c in cands:
		if int(c["peer"]) == bot_peer: found = true
	_check(found, "self-queue: bot is collected as a live ranked candidate")

	# ---- offline pulls it back out of the queue ----
	S._ultra_bot_offline("QueueBot")
	_check(S._find_ranked_entry(bot_peer).is_empty(), "offline: bot is removed from the ranked queue")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
