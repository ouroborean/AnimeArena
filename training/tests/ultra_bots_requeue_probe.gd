extends Node
# Ultra Bots human-like RE-QUEUE PAUSE (owner 2026-08-16): after ACTIVATING or FINISHING a game a bot waits
# a random 15-180s before the rotation tick re-queues it, STRETCHED to 180-600s when NO human is online at
# all — so the bots don't churn through bot-vs-bot games with nobody watching. Bare ServerConnection
# (off-tree; _ready does not boot a server; the sweep is suppressed so an enqueue can't seat a match).
#   godot --headless --path <repo> res://training/tests/ultra_bots_requeue_probe.tscn

const SC = preload("res://components/server_connection.gd")

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _queued(S, name) -> bool:
	return (name in S._ultra_bot_peers) and not S._find_ranked_entry(S._ultra_bot_peers[name]).is_empty()

func _ready():
	print("=== Ultra Bots re-queue pause probe ===")
	var S = SC.new()
	S._gate_tick_running = true   # suppress the sweep so an enqueue can't seat a match (no tree here)
	S._ultra_bot_deployed = true  # the rotation tick is a no-op until the fleet is deployed (admin switch)

	# ---- _any_human_online: excludes bot peers + disconnected sessions ----
	_check(not S._any_human_online(), "no sessions -> no human online")
	var bot_sess = SC.ServerSession.new("BotX", -1000000050, null)   # negative peer -> _is_bot_peer
	S.sessions["BotX"] = bot_sess
	_check(not S._any_human_online(), "a bot-peer session is NOT a human")
	var human = SC.ServerSession.new("HumanA", 1000000005, null)     # positive peer -> human, ONLINE by default
	S.sessions["HumanA"] = human
	_check(S._any_human_online(), "an online human session counts")
	human.status = SC.ServerSession.ConnectionState.DISCONNECTED
	_check(not S._any_human_online(), "a DISCONNECTED human does NOT count")
	human.status = SC.ServerSession.ConnectionState.ONLINE

	# ---- arm ranges: 15-180s with a human online, 180-600s without ----
	var now := Time.get_ticks_msec()
	S._ultra_bot_arm_requeue_delay("BotX")                            # HumanA online -> short range
	var d_busy: int = int(S._ultra_bot_next_queue_at["BotX"]) - now
	_check(d_busy >= 15000 and d_busy <= 181000, "human online -> pause in [15,180]s (got %dms)" % d_busy)
	S.sessions.erase("HumanA")                                        # ladder now empty of humans
	var now2 := Time.get_ticks_msec()
	S._ultra_bot_arm_requeue_delay("BotX")
	var d_idle: int = int(S._ultra_bot_next_queue_at["BotX"]) - now2
	_check(d_idle >= 180000 and d_idle <= 601000, "no human online -> pause in [180,600]s (got %dms)" % d_idle)

	# ---- the rotation tick honors the pause: activation does NOT queue; expiry does ----
	# Fixed test roster (decoupled from the shipped ultra_bots.json). NightOwlNaru is online at hour 3.
	S._ultra_bot_roster_override = [
		{"username": "NightOwlNaru", "rating": 1150, "preferred_team": ["naruto", "sakura", "hinata"], "online_windows": [[0, 6], [22, 24]]},
	]
	for entry in S._load_ultra_bot_roster():
		var bot = S._build_ultra_bot_player(entry)
		if bot != null: S.players[bot.username] = bot
	S._ultra_bot_rotation_tick(3)   # hour 3 -> NightOwlNaru activates
	_check("NightOwlNaru" in S._ultra_bot_peers, "activation: NightOwlNaru online")
	_check("NightOwlNaru" in S._ultra_bot_next_queue_at, "activation: a re-queue pause was armed")
	_check(not _queued(S, "NightOwlNaru"), "activation: NOT queued on the activation tick (pause honored)")
	S._ultra_bot_next_queue_at["NightOwlNaru"] = 0   # force the pause to have elapsed
	S._ultra_bot_rotation_tick(3)
	_check(_queued(S, "NightOwlNaru"), "after the pause elapses, the next tick queues it")

	# ---- offline clears the pause (a fresh one is armed on the next activation) ----
	S._ultra_bot_offline("NightOwlNaru")
	_check(not ("NightOwlNaru" in S._ultra_bot_next_queue_at), "offline clears the pause")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
