extends Node
# Defensive: _pick_bot_team never fields a BOT_EXCLUDED_CHARS member — from the trained pool (filtered at load
# + re-guarded at the draw) or the random draft. Bare ServerConnection.
#   godot --headless --path <repo> res://training/tests/bot_team_filter_probe.tscn

const SC = preload("res://components/server_connection.gd")
var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _ready():
	print("=== bot team exclusion filter probe ===")
	var S = SC.new()
	var excl: Array = SC.BOT_EXCLUDED_CHARS
	var pool_bad := 0; var pool_wrongsize := 0
	for i in range(300):
		var t: Array = S._pick_bot_team(true)   # trained pool
		if t.size() != 3: pool_wrongsize += 1
		for c in t:
			if c in excl: pool_bad += 1
	_check(pool_bad == 0, "trained-pool draws: no excluded char in 300 draws")
	_check(pool_wrongsize == 0, "trained-pool draws: every team is exactly 3 characters")
	var rnd_bad := 0
	for i in range(150):
		var t2: Array = S._pick_bot_team(false)  # random colour-balanced draft
		for c in t2:
			if c in excl: rnd_bad += 1
	_check(rnd_bad == 0, "random-draft draws: no excluded char in 150 draws")
	_check(S._load_bot_team_pool().size() > 0, "the trained pool actually loaded (guard isn't just hitting the fallback)")
	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
