extends Node
# P1 live combat heuristics: BotPolicyV3.combat_verdict (kill / absorbed / waste) + the lethal-secure path in
# perform_turn_v3(combat_heuristics=true). Real BattleManager, real candidates, real effects.
#   godot --headless --path <repo> res://training/tests/bot_combat_heuristics_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _bp(u, names, enemy) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	for cn in names: p.recruit_character(Character.from_character_name(cn), enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _fill_energy(p):
	for color in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		p.team.energy.pool[color] = 20

# first damaging candidate (from any un-acted char) that can target `foe`; {} if none
func _dmg_cand_at(obs, chars, foe) -> Dictionary:
	for ch in chars:
		for cand in obs.own_candidates(ch):
			var ab = cand["ability"]
			if ab.classes.get("Damaging", false) and int(ab.bot_damage_hint()) > 0 and foe in cand["targets"]:
				return {"ch": ch, "cand": cand}
	return {}

func _ready():
	print("=== Bot combat heuristics probe (P1) ===")
	var policy = load("res://training/bot_policy.gd").new()   # BotPolicyV3; combat_verdict needs no weights
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _bp("BotPlayer", ["naruto", "sakura", "hinata"], false)
	var p2 := _bp("BotEnemy", ["eren", "misaka", "gray"], true)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)   # first=true -> p1 (bot) acts turn 1
	_fill_energy(p1)

	# ---- (1) guaranteed kill: an enemy at 1 HP ----
	var enemy0 = p2.team.characters[0]
	enemy0.health.hp = 1
	var obs := BotObservation.for_player(m, p1)
	var k := _dmg_cand_at(obs, p1.team.characters, enemy0)
	_check(not k.is_empty(), "found a damaging candidate that can target the 1-HP enemy")
	if not k.is_empty():
		var v: Dictionary = policy.combat_verdict(obs, k["ch"], k["cand"], enemy0)
		_check(v["is_enemy"] == true, "combat_verdict: target flagged as enemy")
		_check(v["kill"] == true, "combat_verdict: 1-HP enemy is a guaranteed kill")
		_check(v["penalty"] == 0.0, "combat_verdict: a clean kill carries no penalty")

	# ---- (2) absorbed damage: a huge shield eats the hit ----
	var enemy1 = p2.team.characters[1]
	var sh = Effect.shield_effect(9999, 5)
	sh.set_source(enemy1.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(enemy1, m), enemy1, enemy1, sh, true)
	obs = BotObservation.for_player(m, p1)
	var a := _dmg_cand_at(obs, p1.team.characters, enemy1)
	_check(not a.is_empty(), "found a damaging candidate into the 9999-shield enemy")
	if not a.is_empty():
		var v2: Dictionary = policy.combat_verdict(obs, a["ch"], a["cand"], enemy1)
		_check(v2["penalty"] >= BotPolicyV3.HEUR_PENALTY_ABSORBED, "combat_verdict: fully-absorbed damage is penalized (pen=%s)" % str(v2["penalty"]))
		_check(v2["kill"] == false, "combat_verdict: a fully-shielded enemy is NOT a kill")
		_check(v2["waste"] == false, "combat_verdict: absorbed DAMAGE is penalized, not vetoed (may carry a debuff)")

	# ---- (3) end-to-end lethal-secure: the 1-HP enemy must die on the bot's turn ----
	_check(not enemy0.dead, "setup: the 1-HP enemy is still alive before the bot's turn")
	var rng := RandomNumberGenerator.new(); rng.set_seed(99)
	await p1.perform_turn_v3(m, policy, rng, 0.0, null, false, true)   # combat_heuristics = true
	_check(enemy0.dead or int(enemy0.health.hp) <= 0, "lethal-secure: the bot finished the 1-HP enemy this turn")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
