extends Node

# Creator hardening, Phase A — group A1 + A6.
#   godot --headless --path <repo> res://training/tests/creator_hardening_a1a6_probe.tscn
#
# A1  RESERVED NAMES. Effect.effect_name() is `name_override` or the SOURCE ABILITY'S NAME, and
#     Character.marked_by() asks only for a MARK with a given name from ANY source. An author picks
#     both strings, and `mark` is in the shipped palette — so an authored ability called
#     "Plasmantle" that self-marks takes zero Harmful damage in two blocks. The probe first shows
#     the ENGINE hole is real (it still is — A1 is validator-only), then that
#     AuthoredRegistry.validate_character now refuses to store a spec that could reach it.
#
# A6  BANISH DESYNC. Character.banish_character set `banished = true` unconditionally, AFTER an
#     add_*_effect that can be REFUSED (invuln / ignore / shrug). check_win_condition counts
#     `banished` as eliminated, so a refused banish on the last living enemy read as a victory.

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build_player(u, names, is_enemy) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	return p

# A source Ability for hand-built effects. A ScriptedAbility is the honest stand-in: it is exactly
# what an authored skill becomes, and its classes default to all-false (so nothing here is
# accidentally Bypassing or Helpful).
func _authored_source(nm: String):
	var a = load("res://blocks/scripted_ability.gd").new()
	a.ability_name = nm
	a.blocks = []
	add_child(a)
	return a

# A minimal, VALID authored character: 4 visible actives + a Passive. Every A1 case is this spec
# with one string changed, so a rejection can only be about that string.
func _base_spec() -> Dictionary:
	return {
		"id": "auth_a1probe", "name": "Reserved Name Probe", "author": "ProbeAuthor",
		"status": "draft", "colors": [0], "description": "A1 fixture.",
		"abilities": [
			{"name": "Probe Strike", "target": "enemy", "cooldown": 0, "cost": {"0": 1},
			 "classes": ["Physical", "Instant", "Harmful", "Damaging"], "requires": [],
			 "blocks": [{"op": "damage", "amount": 20, "damage_type": "NORMAL"}]},
			{"name": "Probe Guard", "target": "self", "cooldown": 1, "cost": {"4": 1},
			 "classes": ["Strategic", "Instant", "Helpful"], "requires": [],
			 "blocks": [{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 3}}]},
			{"name": "Probe Mend", "target": "ally", "cooldown": 1, "cost": {"4": 1},
			 "classes": ["Strategic", "Instant", "Helpful"], "requires": [],
			 "blocks": [{"op": "heal", "to": "target", "amount": 10}]},
			{"name": "Probe Watch", "target": "self", "cooldown": 2, "cost": {"4": 1},
			 "classes": ["Strategic", "Instant", "Helpful"], "requires": [],
			 "blocks": [{"op": "apply", "to": "user", "effect": {
				"kind": "trigger", "trigger": "on_harmful_received", "turns": 2,
				"then": [{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 10, "turns": 2}}]}}]},
			{"name": "Probe Frame", "target": "self", "cooldown": 0, "cost": {},
			 "classes": ["Passive"], "requires": [],
			 "blocks": [{"op": "apply", "to": "user", "effect": {"kind": "damage_reduction", "amount": 5, "turns": -1}}]},
		],
	}

func _errs_mentioning(spec: Dictionary, needle: String) -> bool:
	for e in AuthoredRegistry.validate_character(spec):
		if str(e).find(needle) != -1:
			return true
	return false


func _ready():
	print("=== creator hardening A1 + A6 probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 := _build_player("BotPlayer", ["naruto", "sasuke", "sakura"], false)
	var p2 := _build_player("BotEnemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var me = p1.team.characters[0]
	var foe = p2.team.characters[0]

	# =====================================================================================
	# A1 — the ENGINE hole, so the validator rule is anchored to a real behaviour and not to
	#      a taste judgement. This block passes both before and after the fix: A1 is
	#      validator-only and deliberately does NOT change the engine.
	# =====================================================================================
	var harmful = null
	for ab in me.moveset.base_abilities:
		if ab.classes["Harmful"] and not ab.classes["Passive"]:
			harmful = ab
			break
	_check(harmful != null, "found a Harmful ability on the attacker to test with")

	# Control first: without the mark, the hit lands. Without this the next assertion could
	# pass for the wrong reason (a target that simply cannot be damaged).
	var control_hp: int = foe.health.hp
	me.deal_ability_damage(harmful, 25, foe, DamageType.Type.NORMAL)
	_check(foe.health.hp < control_hp,
		"control: an unmarked defender TAKES the hit (%d -> %d)" % [control_hp, foe.health.hp])

	# Now exactly what an authored `name_override: "Plasmantle"` produces.
	var plasma = Effect.mark(-1, "authored self-mark")
	plasma.name_override = "Plasmantle"
	plasma.set_source(_authored_source("Totally Normal Skill"))
	Character.add_allied_effect(QueryContext.from_game_state(foe, m), foe, foe, plasma)
	_check(foe.marked_by("Plasmantle") != null, "the authored-shaped mark is on the defender")
	var marked_hp: int = foe.health.hp
	me.deal_ability_damage(harmful, 25, foe, DamageType.Type.NORMAL)
	_check(foe.health.hp == marked_hp,
		"THE HOLE IS REAL: a 'Plasmantle'-named mark takes zero Harmful damage (%d -> %d)" % [marked_hp, foe.health.hp])
	foe.effects.erase_effect(foe.marked_by("Plasmantle"))

	# =====================================================================================
	# A1 — the validator rule.
	# =====================================================================================
	_check(AuthoredRegistry.validate_character(_base_spec()).is_empty(),
		"the base authored spec validates cleanly (no reserved name in it)")

	for confirmed in ["Nirvana", "Plasmantle", "Blood Spear"]:
		_check(Character.RESERVED_EFFECT_NAMES.has(confirmed),
			"RESERVED_EFFECT_NAMES carries the confirmed name '%s'" % confirmed)

	var s_name := _base_spec()
	s_name["abilities"][1]["name"] = "Plasmantle"
	_check(_errs_mentioning(s_name, "Plasmantle"),
		"an ABILITY named 'Plasmantle' is rejected, and the error names it")

	# The nested case: the name is buried in a trigger payload, three levels down.
	var s_over := _base_spec()
	s_over["abilities"][3]["blocks"][0]["effect"]["then"][0]["effect"]["name_override"] = "Nirvana"
	_check(_errs_mentioning(s_over, "Nirvana"),
		"a name_override 'Nirvana' inside a trigger payload is rejected (the walk recurses)")

	# ...and a top-level name_override, which is the common shape.
	var s_top := _base_spec()
	s_top["abilities"][1]["blocks"][0]["effect"]["name_override"] = "Iron Maiden"
	_check(_errs_mentioning(s_top, "Iron Maiden"),
		"a top-level name_override 'Iron Maiden' is rejected")

	# EXACTNESS. effect_name() compares with `==`, so only an exact string can collide. A near
	# miss must stay legal — rejecting it would invent a restriction the game does not have.
	var s_near := _base_spec()
	s_near["abilities"][1]["name"] = "Plasmantle Strike"
	_check(AuthoredRegistry.validate_character(s_near).is_empty(),
		"'Plasmantle Strike' is still ALLOWED — the check is exact, not a substring match")
	var s_case := _base_spec()
	s_case["abilities"][1]["name"] = "plasmantle"
	_check(AuthoredRegistry.validate_character(s_case).is_empty(),
		"'plasmantle' is still ALLOWED — lower case cannot collide with the engine's literal")

	# =====================================================================================
	# A6 — a REFUSED banish must not read as an elimination.
	#
	# Board: every enemy but one is dead, so the survivor's status alone decides the match.
	# =====================================================================================
	p2.team.characters[1].dead = true
	p2.team.characters[2].dead = true
	_check(not m.check_win_condition(), "setup: one living enemy left, so the match is NOT over")

	var invuln = Effect.invuln_effect(4)
	invuln.set_source(_authored_source("Probe Invulnerability"))
	Character.add_allied_effect(QueryContext.from_game_state(foe, m), foe, foe, invuln)
	_check(foe.is_invuln(null), "the last living enemy is Invulnerable")

	var banish_src = _authored_source("Probe Banish")
	me.banish_character(QueryContext.from_game_state(me, m), foe, banish_src, 4)

	_check(not foe.is_banished(), "the banish EFFECT was refused by invulnerability (nothing applied)")
	_check(not foe.banished, "...and the banished FLAG was not set either (this is the A6 fix)")
	_check(not m.check_win_condition(),
		"THE CONSEQUENCE: a refused banish on the last living enemy does NOT win the match")
	_check(not m.check_match_over(), "check_match_over agrees — the match is still running")
	_check(not m.match_over, "...and no end_match fired")

	# The positive control: with the invulnerability gone the same call must still work, or the
	# fix would have broken banish outright.
	for e in foe.effects.get_effects_by_type(EffectType.Type.INVULN):
		foe.effects.erase_effect(e)
	_check(not foe.is_invuln(null), "the invulnerability is gone")
	me.banish_character(QueryContext.from_game_state(me, m), foe, banish_src, 4)
	_check(foe.is_banished(), "a banish that is NOT refused still applies its effect")
	_check(foe.banished, "...and still sets the flag")
	_check(m.check_win_condition(), "...and banishing the last living enemy still wins the match")

	# ------------------------------------------------------------------------------------------
	# THE VALIDATOR MUST NOT ABORT ON A MISSING KEY. A1 is a validator rule, so it is only worth
	# what validate_character is worth. `a.get("classes", []) is Array and "Passive" in a["classes"]`
	# read as safe and was not: the guard passed on the DEFAULT [], then the subscript hit a missing
	# key, aborting the whole function and returning an EMPTY error list. Any spec omitting `classes`
	# on any ability therefore validated CLEAN — disarming this reserved-name check, the id
	# path-safety check, and every block check, while save_spec writes DIR + id + ".json" on an
	# empty list. Found by the Phase A judge, reproduced, fixed. This asserts it stays fixed.
	# ------------------------------------------------------------------------------------------
	var no_classes := {"id": "zz_nc", "name": "ZZ NC", "abilities": [
		{"name": "Plasmantle", "blocks": [{"op": "damage", "amount": 10, "to": "target"}]}]}
	var nc_errs = AuthoredRegistry.validate_character(no_classes)
	_check(nc_errs.size() > 0,
		"a spec omitting `classes` still VALIDATES (no abort): %d error(s)" % nc_errs.size())
	var named := false
	for e in nc_errs:
		if "Plasmantle" in str(e):
			named = true
	_check(named, "...and the reserved-name rejection still fires through it")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
