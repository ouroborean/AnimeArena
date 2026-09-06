extends Node
# END-TO-END bot-vs-bot battle. Drives a REAL shadow battle with BOTH seats bot-controlled via the
# ServerConnection's ACTUAL _run_shadow_bot_turn — the exact code the live turn-driver calls — with no
# tree timers (the think-time delay lives in _drive_bot_if_acting, which we bypass). This is the ground
# truth for the P4 bot-vs-bot generalization + the energy-latch fix (owner CRITICAL 2026-08-15): both
# seats must generate energy every round and get to ACT, the turn must alternate, and the game must reach
# a real terminal result — so a bot-vs-bot ladder game actually completes and reaches
# handle_server_match_ended's bookkeeping (where the is_ephemeral gates then move real rating/record/AP).
#   godot --headless --path <repo> res://training/tests/ultra_bots_battle_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _build_bot(u, names, is_enemy) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	for cn in names:
		p.recruit_character(Character.from_character_name(cn), is_enemy)
	# DELIBERATELY leave bot_character UNSET on the p1 seat — start_bot_match sets it only on the p2
	# (ephemeral) seat, so a lone Ultra bot seated at p1 has no bot_character. This proves it still acts
	# (own_candidates uses authoritative_usable, which lacks usable()'s waiting_for_turn/bot_character gate).
	if is_enemy:
		for c in p.team.characters:
			c.bot_character = true
	return p

func _hp_deficit(team) -> int:
	var d := 0
	for c in team.characters:
		d += int(c.health.max_hp) - int(c.health.hp)
	return d

func _ready():
	print("=== Ultra Bots end-to-end bot-vs-bot battle probe ===")
	var S = load("res://components/server_connection.gd").new()   # bare: off-tree, no server boot
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 := _build_bot("BotAlpha", ["naruto", "sakura", "hinata"], false)   # p1: NO bot_character
	var p2 := _build_bot("BotBravo", ["eren", "misaka", "gray"], true)        # p2: bot_character set
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.RANKED)

	var CAP := 300
	var turns := 0
	var p1_turns := 0
	var p2_turns := 0
	while not m.match_over and turns < CAP:
		if m.waiting_for_turn:   # true => enemy/p2 holds the turn
			p2_turns += 1
		else:
			p1_turns += 1
		await S._run_shadow_bot_turn(m)   # generates the acting team's energy, runs its AI, ends the turn
		turns += 1

	_check(m.match_over, "game reached a real terminal result (match_over) in %d turns (cap %d)" % [turns, CAP])
	_check(p1_turns >= 2 and p2_turns >= 2, "BOTH seats took multiple turns (p1=%d, p2=%d) — the driver alternates, neither froze" % [p1_turns, p2_turns])
	# ENERGY-LATCH proof: if the p2/enemy seat starved for energy from turn 2 (the exact bug the latch
	# reset fixes) it could never afford a damaging skill, so p1 would sit at FULL health forever. Both
	# teams taking damage over a full game proves BOTH seats received energy every round they acted.
	var p1_def := _hp_deficit(p1.team)
	var p2_def := _hp_deficit(p2.team)
	_check(p1_def > 0, "p1 (no bot_character) took damage (%d) — the p2 bot had energy and acted offensively" % p1_def)
	_check(p2_def > 0, "p2 took damage (%d) — the p1 bot (no bot_character) still acted via authoritative_usable" % p2_def)

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
