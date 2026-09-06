extends Node

# Hinata S4 "My Turn To Protect" one-shot regression.
# Bug (reported): the counter intercepted EVERY Harmful skill used on the protected ally that turn,
# not just the next one — protect_counter never consumed the counter. Fix: end protect_counter with
# default_counter_trigger(context) (notifies + removes the counter), the gasai3 Harmful-path idiom.
#   godot --headless --path . res://training/tests/hinata_counter_probe.tscn

var fails := 0

func _check(c, l, detail := ""):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l + ("  (" + detail + ")" if detail != "" else ""))

func _build(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _battle(seed):
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_A" + str(seed), ["hinata", "gray", "aang"], false)
	var p2 = _build("ZZ_B" + str(seed), ["gon", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, seed, BattleManager.MatchType.BOT)
	return [m, p1, p2]

func _harmful_of(character):
	for cand in character.moveset.base_abilities:
		if cand != null and cand.classes["Harmful"] and not cand.classes["Strategic"] and not cand.classes["Uncounterable"]:
			return cand
	return null

func _ready():
	print("=== hinata counter probe ===")
	var TT = EffectType.Type
	var r = _battle(7001)
	var m = r[0]
	var hinata = r[1].team.characters[0]
	var ally = r[1].team.characters[1]
	var e1 = r[2].team.characters[0]
	var e2 = r[2].team.characters[1]
	var protect = hinata.moveset.base_abilities[3]

	# Cast My Turn To Protect on the ally.
	hinata.targeter.targets = [ally]; hinata.targeter.main_target = ally; hinata.used_ability = protect
	protect.execute(hinata, m)
	_check(ally.has_effect("My Turn To Protect", TT.COUNTER_RECEIVE, hinata) != null, "[Hinata] counter placed on the ally")

	# First Harmful skill on the ally -> countered, attacker taunted, counter consumed.
	var atk1 = _harmful_of(e1)
	e1.targeter.targets = [ally]; e1.targeter.main_target = ally; e1.used_ability = atk1
	var c1 = e1.countered(m, atk1)
	_check(c1, "[Hinata] first Harmful skill on the ally IS countered")
	_check(e1.has_effect("My Turn To Protect", TT.TAUNT, hinata) != null, "[Hinata] the countered attacker is permanently Taunted")
	_check(ally.has_effect("My Turn To Protect", TT.COUNTER_RECEIVE, hinata) == null, "[Hinata] counter is CONSUMED after firing once")
	_check(hinata.has_effect("My Turn To Protect", TT.ABILITY_SWAP, hinata) != null, "[Hinata] slot swaps to Gentle Step: Twin Lions Fist")

	# Second Harmful skill on the ally the SAME turn -> NOT countered (the reported bug).
	# Reuse a known-valid Harmful ability (atk1) with a fresh, un-taunted attacker; the counter check
	# only reads the ability's classes and the ally's remaining counters, so the attacker's own kit is
	# irrelevant — this keeps the test from depending on which base skills e2 happens to have.
	var atk2 = _harmful_of(e2)
	if atk2 == null:
		atk2 = atk1
	e2.targeter.targets = [ally]; e2.targeter.main_target = ally; e2.used_ability = atk2
	var c2 = e2.countered(m, atk2)
	_check(not c2, "[Hinata] second Harmful skill on the ally is NOT countered (one-shot)")
	_check(e2.has_effect("My Turn To Protect", TT.TAUNT, hinata) == null, "[Hinata] the second attacker is NOT taunted")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
