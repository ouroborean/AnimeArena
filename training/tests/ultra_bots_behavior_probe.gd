extends Node
# Phase 6 (Ultra Bots) — behaviour layer: variable think-time, surrender-if-behind (board-state only),
# and the 75/25 enhanced energy roll. Pure helpers run on a bare ServerConnection; the energy test runs
# on a real seeded BattleManager and checks the distribution.
#   godot --headless --path <repo> res://training/tests/ultra_bots_behavior_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy: bool = (u == "BotEnemy")
	for cn in names: p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _fresh_char():
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["piccolo", "naruto", "sakura"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "gray"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return p1.team.characters[0]

func _ready():
	print("=== Ultra Bots behaviour probe (Phase 6) ===")
	var S = load("res://components/server_connection.gd").new()   # bare: _ready does NOT boot a server

	# ---- variable think-time: clamped, and busier boards think longer ----
	_check(S._think_seconds_for(0) >= 2.5 and S._think_seconds_for(0) <= 11.0, "think: within the [2.5, 11] band")
	_check(S._think_seconds_for(50) <= 11.0, "think: clamped at the ceiling for a huge board")
	var min3 := 99.0
	var min0 := 99.0
	for i in 250:
		min3 = minf(min3, S._think_seconds_for(3))
		min0 = minf(min0, S._think_seconds_for(0))
	_check(min3 > min0 + 1.0, "think: a fuller board (3 actors) thinks longer than an empty one")

	# ---- surrender pressure: BOARD STATE only, 0 while competitive ----
	_check(S._surrender_pressure(300, 3, 300, 3) == 0.0, "surrender: even 3v3 -> never concede")
	_check(S._surrender_pressure(280, 3, 300, 3) == 0.0, "surrender: slightly behind but full team -> never")
	_check(S._surrender_pressure(50, 1, 300, 3) == 0.6, "surrender: down 2 chars + crushed HP -> 0.6")
	_check(S._surrender_pressure(150, 1, 300, 3) == 0.35, "surrender: down 2 chars, behind HP -> 0.35")
	_check(S._surrender_pressure(60, 1, 200, 2) == 0.3, "surrender: last character, well behind -> 0.3")
	_check(S._surrender_pressure(0, 0, 300, 3) == 0.0, "surrender: already wiped -> 0 (match ends anyway)")

	# ---- enhanced energy: 75% a colour the character uses, 25% fully random ----
	var c = _fresh_char()
	c.character_colors = [0, 3]   # GREEN(0), RED(3)
	var own := 0
	var N := 500
	for i in N:
		var col = c.generate_energy(true)[0]
		if col == Energy.Type.GREEN or col == Energy.Type.RED: own += 1
	var frac := float(own) / float(N)
	_check(frac > 0.72, "enhanced: own-colour fraction ~0.87 (got %.2f)" % frac)
	var own2 := 0
	for i in N:
		var col = c.generate_energy(false)[0]
		if col == Energy.Type.GREEN or col == Energy.Type.RED: own2 += 1
	var frac2 := float(own2) / float(N)
	_check(frac2 < 0.65, "non-enhanced: ~uniform, own-colour ~0.5 (got %.2f)" % frac2)
	c.character_colors = []
	var ce = c.generate_energy(true)[0]
	_check(ce in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED], "enhanced with no own colours -> valid uniform colour (never RANDOM)")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
