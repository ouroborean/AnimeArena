extends Node
# Ultra Bots DEPLOY switch — the persistent master on/off. Undeployed => the rotation tick is fully dormant
# (no online, no queue, no play); deploy => activates; undeploy => drains bots offline. The choice persists to
# a flag file. Bare ServerConnection (off-tree). NOTE: writes/removes ultra_bots_deployed.flag; runner deletes it.
#   godot --headless --path <repo> res://training/tests/ultra_bots_deploy_probe.tscn

const SC = preload("res://components/server_connection.gd")
var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _online(S, n) -> bool:
	return n in S._ultra_bot_peers

func _ready():
	print("=== Ultra Bots deploy switch probe ===")
	var S = SC.new()
	S._gate_tick_running = true
	S._ultra_bot_roster_override = [{"username": "DeployBot", "rating": 1000, "preferred_team": ["naruto", "sakura", "hinata"], "online_windows": [[0, 24]]}]
	for entry in S._load_ultra_bot_roster():
		var b = S._build_ultra_bot_player(entry)
		if b != null: S.players[b.username] = b

	# ---- default: NOT deployed -> tick is a no-op (bot stays dormant) ----
	S._ultra_bot_deployed = false
	S._ultra_bot_rotation_tick(3)
	_check(not _online(S, "DeployBot"), "undeployed: the rotation tick does NOT bring the bot online")

	# ---- deployed -> the bot comes online ----
	S._ultra_bot_deployed = true
	S._ultra_bot_rotation_tick(3)
	_check(_online(S, "DeployBot"), "deployed: the rotation tick brings the bot online")

	# ---- undeployed -> a still-online bot is drained by the tick ----
	S._ultra_bot_deployed = false
	S._ultra_bot_rotation_tick(3)
	_check(not _online(S, "DeployBot"), "undeployed: the tick drains a lingering online bot")

	# ---- _ultra_bot_deploy(false) helper: online bot -> stood down immediately (no seeding path) ----
	S._ultra_bot_deployed = true
	S._ultra_bot_rotation_tick(3)
	_check(_online(S, "DeployBot"), "setup: re-deployed and online")
	S._ultra_bot_deploy(false)
	_check(not _online(S, "DeployBot") and S._ultra_bot_deployed == false, "_ultra_bot_deploy(false): stands the fleet down + flips the flag")

	# ---- persistence: the flag survives a fresh load ----
	S._ultra_bot_deployed = true
	S._persist_ultra_bot_deployed()
	var S2 = SC.new(); S2._load_ultra_bot_deployed()
	_check(S2._ultra_bot_deployed == true, "persistence: a deployed flag reloads as deployed")
	S._ultra_bot_deployed = false
	S._persist_ultra_bot_deployed()   # leave it OFF so the live server default stays dormant
	var S3 = SC.new(); S3._load_ultra_bot_deployed()
	_check(S3._ultra_bot_deployed == false, "persistence: a stood-down flag reloads as dormant")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
