extends Node
# P2: an Ultra bot never chats and never accepts — it silently AUTO-DECLINES a friend request after a random
# delay, so the request resolves instead of pending forever. Bare ServerConnection (off-tree). Writes two
# throwaway ausers/UB_PROBE_*.dat so the decline's resave path is exercised; the runner deletes them after.
#   godot --headless --path <repo> res://training/tests/ultra_bots_decline_probe.tscn

const SC = preload("res://components/server_connection.gd")
var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _plain(u) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u)
	return p

func _ready():
	print("=== Ultra Bots friend auto-decline probe (P2) ===")
	var S = SC.new()
	var BOT := "UB_PROBE_BOT"; var REQ := "UB_PROBE_REQ"; var key := BOT + "|" + REQ
	S._ultra_bot_roster_override = [{"username": BOT, "rating": 0, "preferred_team": ["naruto", "sakura", "hinata"], "online_windows": [[0, 24]]}]
	var bot: Player = S._build_ultra_bot_player(S._load_ultra_bot_roster()[0])
	S.players[BOT] = bot
	var req := _plain(REQ)
	S.players[REQ] = req
	S.save_player(bot, "probehash")   # persist both so the decline's resave_player has a hash to preserve
	S.save_player(req, "probehash")

	# ---- arm: delay in range + idempotent ----
	var now := Time.get_ticks_msec()
	S._ultra_bot_arm_decline(BOT, REQ)
	_check(S._ultra_bot_decline_at.has(key), "arm: a decline timer was created")
	var d := int(S._ultra_bot_decline_at[key]) - now
	_check(d >= SC.ULTRA_BOT_DECLINE_MIN_SEC * 1000 and d <= SC.ULTRA_BOT_DECLINE_MAX_SEC * 1000 + 1000, "arm: delay in [2min, 2h] (got %dms)" % d)
	var first := int(S._ultra_bot_decline_at[key])
	S._ultra_bot_arm_decline(BOT, REQ)
	_check(int(S._ultra_bot_decline_at[key]) == first, "arm: idempotent (a re-arm never changes the deadline)")

	# ---- simulate a pending request ----
	S._ultra_bot_decline_at.clear()
	bot.friend_requests_in = [REQ]
	req.friend_requests_out = [BOT]

	# process: an un-armed request gets armed, and is NOT declined before the delay elapses
	S._ultra_bot_process_declines()
	_check(S._ultra_bot_decline_at.has(key), "process: an un-armed pending request gets armed")
	_check(REQ in bot.friend_requests_in and BOT in req.friend_requests_out, "process: NOT declined before the delay elapses")

	# force the delay to have elapsed -> it declines
	S._ultra_bot_decline_at[key] = 0
	S._ultra_bot_process_declines()
	_check(not (REQ in bot.friend_requests_in), "decline: request removed from the bot's inbox")
	_check(not (BOT in req.friend_requests_out), "decline: the requester's outgoing entry is cleared")
	_check(not (REQ in bot.friends) and not (BOT in req.friends), "decline: NEVER accepted (no friendship formed)")
	_check(not S._ultra_bot_decline_at.has(key), "decline: the timer is cleared after firing")

	# ---- prune: a cancelled request's dangling timer is dropped ----
	S._ultra_bot_decline_at["UB_PROBE_BOT|ghost"] = 999999999
	S._ultra_bot_process_declines()
	_check(not S._ultra_bot_decline_at.has("UB_PROBE_BOT|ghost"), "prune: a timer with no backing request is dropped")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
