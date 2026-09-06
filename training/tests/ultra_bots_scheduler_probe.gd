extends Node
# Phase 5 (Ultra Bots) — the stateless daily rotation scheduler + the "bots fill gaps" pairing preference.
# Verifies: online_windows membership, the rotation tick brings the right bots online/queued for a given
# hour and drops the rest, and _best_gated_ranked_pair prefers a human-human pair over a human-bot pair
# (bots only fill when no human opponent is available). Bare ServerConnection (off-tree, no server boot).
#   godot --headless --path <repo> res://training/tests/ultra_bots_scheduler_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

# A fixed roster this probe drives via S._ultra_bot_roster_override, so it never breaks when the shipped
# ultra_bots.json is re-generated. Windows match the assertions below.
func _test_roster() -> Array:
	return [
		{"username": "NightOwlNaru", "rating": 1150, "preferred_team": ["naruto", "sakura", "hinata"], "online_windows": [[0, 6], [22, 24]]},
		{"username": "DawnPatrolMisaka", "rating": 1350, "preferred_team": ["misaka", "eren", "gray"], "online_windows": [[6, 12]]},
		{"username": "MiddayHunter", "rating": 900, "preferred_team": ["gon", "hisoka", "killua"], "online_windows": [[12, 18]]},
		{"username": "PlusUltraPal", "rating": 1600, "preferred_team": ["midoriya", "bakugo", "allmight"], "online_windows": [[16, 22]]},
	]

func _cand(peer, rating, now, waited_ms):
	return {"peer": peer, "rating": rating, "enqueued_ms": now - waited_ms, "username": "u" + str(peer), "last_opp": "", "top": false}

func _online(S, name) -> bool:
	return name in S._ultra_bot_peers

func _queued(S, name) -> bool:
	return (name in S._ultra_bot_peers) and not S._find_ranked_entry(S._ultra_bot_peers[name]).is_empty()

func _ready():
	print("=== Ultra Bots scheduler probe (Phase 5) ===")
	var S = load("res://components/server_connection.gd").new()   # bare: _ready does NOT fire off-tree
	# Suppress the ranked sweep: on a bare (tree-less) instance the enqueue's _gate_tick would seat a
	# bot-vs-bot match and the driver's get_tree().create_timer would null-crash. The gate re-entrancy flag
	# makes _gate_tick a no-op, so we test online/offline + enqueue without triggering a real seat.
	S._gate_tick_running = true
	S._ultra_bot_deployed = true   # the rotation tick is a no-op until the fleet is deployed (admin switch)

	# ---- window membership (end-exclusive), now MINUTE-precise with a per-bot offset (P3) ----
	# `w` has no username -> a fixed offset; test mid-window / clearly-outside (robust to the +/-30min shift).
	var w = {"online_windows": [[0, 6], [22, 24]]}
	_check(S._ultra_bot_in_window(w, 3 * 60) and S._ultra_bot_in_window(w, 23 * 60), "in_window: inside [0,6) and [22,24)")
	_check(not S._ultra_bot_in_window(w, 8 * 60) and not S._ultra_bot_in_window(w, 13 * 60), "in_window: hours 8 and 13 are outside both windows")

	# ---- per-bot minute offset de-synchronizes the schedule (P3) ----
	var off_a: int = S._ultra_bot_window_offset("NightOwlNaru")
	_check(off_a == S._ultra_bot_window_offset("NightOwlNaru"), "offset: stable per username")
	_check(off_a >= -29 and off_a <= 30, "offset: within +/-30 minutes (got %d)" % off_a)
	var distinct := {}
	for n in ["NightOwlNaru", "DawnPatrolMisaka", "MiddayHunter", "PlusUltraPal", "MBLD", "Kosac"]:
		distinct[S._ultra_bot_window_offset(n)] = true
	_check(distinct.size() >= 3, "offset: varies across bots (%d distinct of 6)" % distinct.size())
	# end-exclusive boundary still holds, at the OFFSET-ADJUSTED edge (window [8,10) -> [480,600) shifted by off)
	var je = {"username": "JitterBot", "online_windows": [[8, 10]]}
	var jo: int = S._ultra_bot_window_offset("JitterBot")
	_check(S._ultra_bot_in_window(je, 8 * 60 + jo), "in_window: start edge INCLUSIVE at the offset-adjusted minute")
	_check(not S._ultra_bot_in_window(je, 10 * 60 + jo), "in_window: end edge EXCLUSIVE at the offset-adjusted minute")
	_check(S._ultra_bot_in_window(je, 10 * 60 + jo - 1), "in_window: one minute before the offset-adjusted end is inside")

	# ---- seed a FIXED test roster (decoupled from the shipped ultra_bots.json, which changes) ----
	S._ultra_bot_roster_override = _test_roster()
	for entry in S._load_ultra_bot_roster():
		var bot = S._build_ultra_bot_player(entry)
		if bot != null: S.players[bot.username] = bot

	# hour 3 -> only NightOwlNaru ([[0,6],[22,24]]) online. It does NOT queue on the activation tick: the
	# human-like re-queue pause is armed on activation and the tick honors it. Once the pause elapses
	# (cleared here to simulate) the next tick queues it.
	S._ultra_bot_rotation_tick(3)
	_check(_online(S, "NightOwlNaru") and not _queued(S, "NightOwlNaru"), "rotation@3: NightOwlNaru online, NOT queued yet (re-queue pause armed on activation)")
	_check(not _online(S, "DawnPatrolMisaka") and not _online(S, "MiddayHunter") and not _online(S, "PlusUltraPal"), "rotation@3: the other three are offline")
	S._ultra_bot_next_queue_at.clear()
	S._ultra_bot_rotation_tick(3)
	_check(_queued(S, "NightOwlNaru"), "rotation@3: after the re-queue pause elapses, the tick queues it")

	# hour 17 -> MiddayHunter ([12,18)) + PlusUltraPal ([16,22)) online; NightOwl dropped offline
	S._ultra_bot_rotation_tick(17)
	_check(_online(S, "MiddayHunter") and _online(S, "PlusUltraPal"), "rotation@17: MiddayHunter + PlusUltraPal online")
	_check(not _online(S, "NightOwlNaru"), "rotation@17: NightOwlNaru rotated OFFLINE (was online at 3)")

	# hour 8 -> only DawnPatrolMisaka ([6,12)); the 17:00 pair rotated off. Same pause-then-queue as @3.
	S._ultra_bot_rotation_tick(8)
	_check(_online(S, "DawnPatrolMisaka") and not _queued(S, "DawnPatrolMisaka"), "rotation@8: DawnPatrolMisaka online, NOT queued yet (pause armed on activation)")
	_check(not _online(S, "MiddayHunter") and not _online(S, "PlusUltraPal"), "rotation@8: the 17:00 pair rotated OFFLINE")
	S._ultra_bot_next_queue_at.clear()
	S._ultra_bot_rotation_tick(8)
	_check(_queued(S, "DawnPatrolMisaka"), "rotation@8: queues after the re-queue pause elapses")

	# ---- the kill-switch ----
	S._ultra_bot_rotation_enabled = false
	S._ultra_bot_rotation_tick(3)   # would normally bring NightOwlNaru back; disabled -> no change
	_check(not _online(S, "NightOwlNaru"), "rotation disabled: tick is a no-op")
	S._ultra_bot_rotation_enabled = true

	# ---- pairing preference: bots fill gaps, never steal a human opponent ----
	var now := 9000000
	var HA = _cand(1000000001, 1200, now, 20000)   # human A
	var HB = _cand(1000000002, 1400, now, 20000)   # human B
	var BOT = _cand(-1000000050, 1205, now, 20000) # bot, rating-closest to A
	# A-BOT delta is 5 (closest by rating), but the human-human A-B pair must win anyway.
	var pref = S._best_gated_ranked_pair([HA, HB, BOT], now)
	var peers := []
	for c in pref: peers.append(int(c["peer"]))
	_check(pref.size() == 2 and 1000000001 in peers and 1000000002 in peers, "pairing: human-human wins over a rating-closer human-bot pair")
	# a LONE human still pairs with the bot instantly (no human-human option)
	var lone = S._best_gated_ranked_pair([HA, BOT], now)
	_check(lone.size() == 2, "pairing: a lone human still pairs with a bot (no one waits)")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
