extends Node

# End-to-end probe for a FULLY AUTHORED character: no character/<name>.gd, no
# .tscn, no ability scripts — just a validated JSON spec. It must load, fight,
# gate its skills, run its passive, and be indistinguishable to the engine.
# Run: godot --headless --path <repo> res://training/tests/authored_character_probe.tscn

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

# The fixture lives under authored/, which is gitignored user data — so the probe
# writes it itself rather than depending on a file that a cleanup can delete.
# It still exercises the real load-from-disk + validate-on-load path below.
func _write_fixture() -> void:
	var spec := {
		"id": "auth_testchar", "name": "Test Construct", "author": "ZZ_V3E2E_65569",
		"status": "testing", "colors": [0, 2], "description": "Probe fixture.",
		"abilities": [
			{"name": "Fracture Strike", "target": "enemy", "cooldown": 0, "cost": {"2": 1},
			 "classes": ["Physical", "Instant", "Harmful", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "damage", "amount": 20, "damage_type": "NORMAL"},
				{"op": "apply", "to": "target", "effect": {"kind": "mark", "turns": 3}}]},
			{"name": "Execute", "target": "enemy", "cooldown": 2, "cost": {"0": 1},
			 "classes": ["Physical", "Instant", "Harmful", "Damaging"],
			 "requires": [{"cond": "has_effect", "name": "Fracture Strike", "on": "target"}],
			 "blocks": [{"op": "damage", "amount": 35, "damage_type": "PIERCING"}]},
			{"name": "Bulwark", "target": "self", "cooldown": 3, "cost": {"4": 1},
			 "classes": ["Strategic", "Instant", "Helpful"], "requires": [],
			 "blocks": [
				{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 20, "turns": 2}},
				{"op": "apply", "to": "user", "effect": {"kind": "reactive", "trigger": "on_harmful_received",
					"turns": 2, "then": [{"op": "damage", "amount": 10, "to": "target"}]}}]},
			{"name": "Rally", "target": "ally", "cooldown": 2, "cost": {"4": 1},
			 "classes": ["Strategic", "Instant", "Helpful"], "requires": [],
			 "blocks": [
				{"op": "heal", "to": "target", "amount": 15},
				{"op": "apply", "to": "target", "effect": {"kind": "damage_boost", "amount": 5, "turns": 2}}]},
			{"name": "Iron Frame", "target": "self", "cooldown": 0, "cost": {},
			 "classes": ["Passive"], "requires": [],
			 "blocks": [{"op": "apply", "to": "user", "effect": {"kind": "damage_reduction", "amount": 5, "turns": -1}}]},
		],
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://authored"))
	var f := FileAccess.open("res://authored/auth_testchar.json", FileAccess.WRITE)
	if f == null:
		printerr("  could not write the probe fixture")
		return
	f.store_string(JSON.stringify(spec, "\t"))
	f.close()

func _ready():
	print("=== Authored character: end-to-end ===")
	_write_fixture()
	AuthoredRegistry.load_all(true)

	var spec = AuthoredRegistry.get_spec("auth_testchar")
	_check(spec != null, "authored spec loaded from disk (and passed load-time validation)")
	if spec == null:
		print("=== probe done: %d failure(s) ===" % fails); get_tree().quit(fails); return
	_check(AuthoredRegistry.validate_character(spec).is_empty(), "spec validates cleanly")

	# --- permissions --------------------------------------------------------
	# OWNER RULING (2026): authored characters are ADMIN-ONLY to field (approved or not); the
	# normal-player pipeline is deferred. can_use's 4th arg is is_admin, computed at the call site.
	_check(not AuthoredRegistry.can_use("auth_testchar", "ZZ_V3E2E_65569", true, false),
		"author (non-admin) may NOT field their 'testing' character even in bot/private")
	_check(not AuthoredRegistry.can_use("auth_testchar", "ZZ_V3E2E_65569", false, false),
		"author (non-admin) may NOT take a 'testing' character into quick/ranked")
	_check(not AuthoredRegistry.can_use("auth_testchar", "SomeoneElse", true, false),
		"another non-admin player may NOT use an authored character at all")
	_check(AuthoredRegistry.can_use("auth_testchar", "ZZ_V3E2E_65569", true, true),
		"an ADMIN MAY field an authored character (the only path allowed right now)")

	# --- construction -------------------------------------------------------
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["auth_testchar", "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 909, BattleManager.MatchType.BOT)

	var hero = p1.team.characters[0]
	var foe = p2.team.characters[0]
	_check(hero is AuthoredCharacter, "Character.from_character_name built an AuthoredCharacter")
	_check(hero.character_name == "Test Construct", "name applied: %s" % hero.character_name)
	_check(hero.moveset.base_abilities.size() == 5, "5 abilities built (%d)" % hero.moveset.base_abilities.size())
	_check(hero.health.hp == 100, "starts at full HP (%d)" % hero.health.hp)

	# --- passive ran at battle start ---------------------------------------
	var dr = hero.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)
	_check(dr.size() == 1 and dr[0].mag == 5, "Passive auto-ran via startup_passives (permanent 5 DR)")

	# --- usage gating (requires) -------------------------------------------
	var strike = hero.moveset.base_abilities[0]
	var execute_skill = hero.moveset.base_abilities[1]
	_check(not execute_skill.extra_usable(hero), "'Execute' is gated OFF before its mark exists")

	hero.used_ability = strike
	hero.targeter.targets = [foe]
	hero.targeter.main_target = foe
	var hp0 = foe.health.hp
	strike.execute(hero, m)
	_check(foe.health.hp == hp0 - 20, "Fracture Strike dealt 20 (%d -> %d)" % [hp0, foe.health.hp])
	_check(execute_skill.extra_usable(hero), "'Execute' is gated ON once the target is marked")

	hero.used_ability = execute_skill
	var hp1 = foe.health.hp
	execute_skill.execute(hero, m)
	_check(foe.health.hp == hp1 - 35, "Execute dealt 35 Piercing (%d -> %d)" % [hp1, foe.health.hp])

	# --- self-buff + reactive ----------------------------------------------
	var bulwark = hero.moveset.base_abilities[2]
	hero.used_ability = bulwark
	hero.targeter.targets = [hero]
	hero.targeter.main_target = hero
	bulwark.execute(hero, m)
	_check(hero.get_shield_effects().size() == 1, "Bulwark shield applied to self")
	var foe_hp = foe.health.hp
	foe.used_ability = foe.moveset.base_abilities[0]
	foe.targeter.targets = [hero]
	foe.targeter.main_target = hero
	hero.check_harmful_receive_triggers(m, foe.used_ability)
	_check(foe.health.hp == foe_hp - 10, "authored reactive retaliated for 10 (%d -> %d)" % [foe_hp, foe.health.hp])

	# --- ally support -------------------------------------------------------
	var rally = hero.moveset.base_abilities[3]
	var ally = p1.team.characters[1]
	ally.health.hp = 60
	hero.used_ability = rally
	hero.targeter.targets = [ally]
	hero.targeter.main_target = ally
	rally.execute(hero, m)
	_check(ally.health.hp == 75, "Rally healed the ally 15 (60 -> %d)" % ally.health.hp)
	_check(ally.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD).size() == 1, "Rally applied a damage boost")

	# --- generated presentation + bot integration ---------------------------
	var segs = strike.split_desc()
	_check(segs.size() >= 2, "description auto-generated for an authored skill")
	print("        -> " + str(segs))
	print("        -> Execute: " + str(execute_skill.split_desc()))
	_check(execute_skill.bot_damage_hint() == 35, "bot damage hint derived (%d)" % execute_skill.bot_damage_hint())
	var ctx = QueryContext.from_game_state(hero, m)
	_check(strike.custom_behavior(ctx).size() > 0, "bot can score the authored skill (custom_behavior)")

	# --- the character survives a real serialized turn -----------------------
	var snap = m.serialize_wire_snapshot()
	var found := false
	for side in snap["sides"]:
		for c in side["team"]:
			if str(c["path_name"]) == "auth_testchar":
				found = true
				_check(c["abilities"].size() >= 4, "authored kit serializes to the wire (%d abilities)" % c["abilities"].size())
	_check(found, "authored character appears in the wire snapshot the client consumes")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
