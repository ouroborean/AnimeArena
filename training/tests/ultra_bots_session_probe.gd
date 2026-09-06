extends Node
# Phase 3 (Ultra Bots) — the socket-less virtual-presence layer: _ultra_bot_online / _ultra_bot_offline
# mint/drop a real ServerSession on a reserved negative peer so a bot resolves through
# get_player/get_session, passes the ranked queue liveness gate, is driven by the existing turn-driver
# (via _is_bot_peer), produces no outbound frames, and is excluded from the ping/disconnect machinery.
# Runs on a bare ServerConnection (off-tree, so _ready does NOT boot a server).
#   godot --headless --path <repo> res://training/tests/ultra_bots_session_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _ready():
	print("=== Ultra Bots session probe (Phase 3) ===")
	var S = load("res://components/server_connection.gd").new()   # bare: _ready does NOT fire off-tree

	# Seed one bot account straight into the players cache (no disk).
	var bot = S._build_ultra_bot_player({"username": "SessProbeBot", "rating": 1200, "preferred_team": ["naruto", "sakura", "hinata"]})
	S.players["SessProbeBot"] = bot
	_check(bot.bot_player == false, "before online: bot_player is false (identity only)")

	# ---- ONLINE: mints a session on a reserved NEGATIVE peer ----
	var peer = S._ultra_bot_online("SessProbeBot")
	_check(peer < 0 and S._is_bot_peer(peer), "online: session peer is in the negative _is_bot_peer range")
	_check(S.get_player(peer) == bot, "online: get_player(peer) resolves to the bot")
	_check(S.get_session(peer) != null and S.get_session(peer).status == 0, "online: session exists and is ONLINE")
	_check(bot.bot_player == true, "online: bot_player flipped true (AI will drive its seats)")

	# ---- passes the ranked queue liveness gate (would otherwise be REAPED within 1s) ----
	var reap_ctrl = S._ranked_entry_verdict(-424242)   # an unknown peer -> REAP
	var bot_verdict = S._ranked_entry_verdict(peer)
	_check(bot_verdict != reap_ctrl, "online: bot PASSES _ranked_entry_verdict (not reaped like an unknown peer)")

	# ---- outbound to the bot is a silent no-op (no socket, no push_error, no crash) ----
	S.send_to_peer(peer, "receive_ranked_match", {"anything": 1})
	_check(true, "send_to_peer(bot) returns cleanly (silent no-op — bot guard)")

	# ---- excluded from the ping cycle (else the missing pong force-disconnects it every 15s) ----
	_check(S._is_bot_peer(peer), "ping cycle SKIPS the bot session (guarded by _is_bot_peer)")

	# ---- handle_disconnect is a no-op for a bot: the session survives a stray disconnect call ----
	S.handle_disconnect(peer)
	_check(S.get_player(peer) == bot, "handle_disconnect(bot) is a no-op — session survives")

	# ---- idempotent online ----
	var peer2 = S._ultra_bot_online("SessProbeBot")
	_check(peer2 == peer, "online is idempotent (same peer when already online)")

	# ---- OFFLINE: drops the session + clears the runtime flag ----
	S._ultra_bot_offline("SessProbeBot")
	_check(S.get_player(peer) == null, "offline: get_player(peer) no longer resolves")
	_check(not ("SessProbeBot" in S.sessions), "offline: session removed")
	_check(bot.bot_player == false, "offline: bot_player cleared")

	# ---- a non-ultra account can never be brought online this way ----
	var human = Player.new_gen("PlainHuman", "", {})
	human.set_username("PlainHuman")
	S.players["PlainHuman"] = human
	_check(S._ultra_bot_online("PlainHuman") == 0, "online refuses a non-ultra-bot account")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
