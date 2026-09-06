extends Node

# Trafalgar Law full-kit probe.
#   1. ROOM: swaps slot 0 -> Shambles, installs the per-turn marker, unlocks the other skills.
#   2. The per-turn marker tags exactly one random ally + one random enemy with ROOM.
#   3. Amputate: 30 True to the ROOM-marked enemy.
#   4. Surgeon of Death: 20 True to an enemy / 25 heal an ally + invuln-bypass on a ROOM-marked target.
#   5. Takt: Blinds all enemies (invisibly).
#   6. Shambles (the novel one): a marked enemy's next Harmful skill is redirected to the ROOM-marked
#      enemy, and their next Helpful skill to the ROOM-marked ally — caster-side targeter surgery.
#   godot --headless --path <repo> res://training/tests/law_kit_probe.tscn

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

func _mark_room(m, law, target):
	var law1 = law.moveset.base_abilities[0]
	var mark = Effect.mark(2, "Marked with ROOM.")
	mark.set_source(law1)
	mark.refresh = true
	var qc = QueryContext.from_game_state(law, m)
	if target in law.team.characters:
		Character.add_allied_effect(qc, law, target, mark)
	else:
		Character.add_hostile_effect(qc, law, target, mark)

func _clear_room(m, law):
	for c in m.all_characters():
		c.effects.remove_effect("ROOM", EffectType.Type.MARK, law)

func _ready():
	print("=== law kit probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Law", ["law", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["killua", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var law = p1.team.characters[0]
	var ally_A = p1.team.characters[1]
	var ally_B = p1.team.characters[2]
	var E = p2.team.characters[0]
	var Z = p2.team.characters[1]
	var W = p2.team.characters[2]
	var TT = EffectType.Type

	var room = law.moveset.base_abilities[0]
	var amputate = law.moveset.base_abilities[1]
	var surgeon = law.moveset.base_abilities[2]
	var takt = law.moveset.base_abilities[3]
	var shambles = law.moveset.base_abilities[4]

	# === 1. ROOM ===
	_check(not surgeon.extra_usable(law), "[gate] Surgeon is LOCKED before ROOM")
	law.targeter.targets = [law]; law.targeter.main_target = law; law.used_ability = room
	room.execute(law, m)
	_check(law.has_effect("ROOM", TT.START_OF_TURN_TRIGGER, law) != null, "[ROOM] per-turn marker installed")
	_check(law.has_effect("ROOM", TT.ABILITY_SWAP, law) != null, "[ROOM] slot 0 swapped to Shambles")
	_check(surgeon.extra_usable(law) and takt.extra_usable(law), "[gate] Surgeon + Takt UNLOCKED after ROOM")

	# === 2. Per-turn marking ===
	m.waiting_for_turn = false      # Law is on m.player's team -> his team is the acting team
	var trig = law.has_effect("ROOM", TT.START_OF_TURN_TRIGGER, law)
	room.room_tick(QueryContext.from_effect_end(trig))
	var ma = 0; var me = 0
	for c in m.all_characters():
		if c.marked_by("ROOM", law):
			if c in law.team.characters: ma += 1
			else: me += 1
	_check(ma == 1 and me == 1, "[marker] tagged exactly 1 ally + 1 enemy (ally=%d enemy=%d)" % [ma, me])
	var some_mark = null
	for c in m.all_characters():
		var mk = c.has_effect("ROOM", TT.MARK, law)
		if mk: some_mark = mk
	_check(some_mark != null and some_mark.unique_render_id == 1, "[marker] ROOM mark carries the unique render id (=1)")
	_clear_room(m, law)

	# === 3. Amputate ===
	_mark_room(m, law, Z)
	var z0 = Z.health.hp
	law.targeter.targets = [law]; law.targeter.main_target = law; law.used_ability = amputate
	amputate.execute(law, m)
	_check(z0 - Z.health.hp == 30, "[Amputate] 30 True to the ROOM-marked enemy (%d -> %d)" % [z0, Z.health.hp])

	# === 4. Surgeon of Death ===
	var e0 = E.health.hp
	law.targeter.targets = [E]; law.targeter.main_target = E; law.used_ability = surgeon
	surgeon.execute(law, m)
	_check(e0 - E.health.hp == 20, "[Surgeon] 20 True to a target enemy (dealt %d)" % (e0 - E.health.hp))
	ally_B.health.hp = maxi(1, ally_B.health.hp - 40)
	var b0 = ally_B.health.hp
	law.targeter.targets = [ally_B]; law.targeter.main_target = ally_B; law.used_ability = surgeon
	surgeon.execute(law, m)
	_check(ally_B.health.hp - b0 == 25, "[Surgeon] heals a target ally 25 (healed %d)" % (ally_B.health.hp - b0))
	# invuln-bypass: Z is ROOM-marked (from sec.3), W is not
	for c in [Z, W]:
		var iv = Effect.invuln_effect(2); iv.set_source(surgeon)
		Character.add_allied_effect(QueryContext.from_game_state(c, m), c, c, iv)
	for c in m.all_characters(): c.targeted = false
	law.used_ability = surgeon
	surgeon.target(law, m)
	_check(Z.targeted, "[Surgeon bypass] a ROOM-marked INVULN enemy is targetable")
	_check(not W.targeted, "[Surgeon bypass] a non-ROOM INVULN enemy is NOT targetable")
	# drop the test-invuln — INVULN blocks hostile effect application, which would (correctly) stop
	# Takt's Blind and ROOM's mark from landing on Z/W in the sections below.
	for c in [Z, W]:
		for e in c.effects.get_effects_by_type(TT.INVULN):
			c.effects.erase_effect(e)

	# === 5. Takt ===
	law.targeter.targets = [E, Z, W]; law.used_ability = takt
	takt.execute(law, m)
	var blinded = 0; var invis = true
	for e in [E, Z, W]:
		var bl = e.effects.get_effects_by_type(TT.BLIND)
		if bl.size() > 0:
			blinded += 1
			if not bl[0].invisible: invis = false
	_check(blinded == 3, "[Takt] all 3 enemies Blinded (%d)" % blinded)
	_check(invis, "[Takt] the Blind is Invisible")
	var fresh_blind = Effect.blind_effect(2)
	var e_blind = E.effects.get_effects_by_type(TT.BLIND)
	_check(e_blind.size() > 0 and e_blind[0].wrapup_func != fresh_blind.wrapup_func, "[Takt] the Blind reveals on expiry (custom wrapup)")

	# === 6. Shambles redirect ===
	_clear_room(m, law)
	_mark_room(m, law, ally_A)      # the ROOM-marked ally
	_mark_room(m, law, Z)           # the ROOM-marked enemy
	law.targeter.targets = [E]; law.targeter.main_target = E; law.used_ability = shambles
	shambles.execute(law, m)
	_check(E.effects.get_effects_by_type(TT.REFLECT_USE).size() > 0, "[Shambles] REFLECT_USE mark applied to the enemy")

	# E uses a HARMFUL skill aimed at Law -> redirected to the ROOM-marked enemy Z
	var harmful = Ability.from_database("astolfo1"); harmful.user = E
	E.used_ability = harmful; E.targeter.targets = [law]; E.targeter.main_target = law
	E.reflect_check(m, harmful)
	_check(E.targeter.targets.size() == 1 and E.targeter.targets[0] == Z,
		"[Shambles] E's HARMFUL skill redirected to ONLY the ROOM-marked enemy")

	# re-apply (one-shot consumed), then E uses a HELPFUL skill -> redirected to the ROOM-marked ally
	law.targeter.targets = [E]; law.targeter.main_target = E; law.used_ability = shambles
	shambles.execute(law, m)
	var helpful = Ability.from_database("astolfo3"); helpful.user = E
	E.used_ability = helpful; E.targeter.targets = [W]; E.targeter.main_target = W
	E.reflect_check(m, helpful)
	_check(E.targeter.targets.size() == 1 and E.targeter.targets[0] == ally_A,
		"[Shambles] E's HELPFUL skill redirected to ONLY the ROOM-marked ally")

	# === 7. Amputate respects Invulnerability (review fix) ===
	_clear_room(m, law)
	_mark_room(m, law, W)
	var wiv = Effect.invuln_effect(2); wiv.set_source(amputate)
	Character.add_allied_effect(QueryContext.from_game_state(W, m), W, W, wiv)
	_check(not amputate.extra_usable(law), "[Amputate fix] unusable when the only ROOM-enemy is Invulnerable")

	# === 8. Surgeon reaches an ISOLATED ROOM-marked ally (targeting + heal bypass) ===
	_clear_room(m, law)
	for c in m.all_characters():
		for e in c.effects.get_effects_by_type(TT.INVULN): c.effects.erase_effect(e)
	_mark_room(m, law, ally_A)
	var iso = Effect.isolate(4); iso.set_source(E.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(ally_A, m), E, ally_A, iso, true)
	_check(ally_A.is_isolated(), "[setup] ally_A is Isolated + ROOM-marked")
	for c in m.all_characters(): c.targeted = false
	law.used_ability = surgeon
	surgeon.target(law, m)
	_check(ally_A.targeted, "[Surgeon iso] an Isolated ROOM-marked ally IS targetable")
	ally_A.health.hp = maxi(1, ally_A.health.hp - 40)
	var a0 = ally_A.health.hp
	law.targeter.targets = [ally_A]; law.targeter.main_target = ally_A; law.used_ability = surgeon
	surgeon.execute(law, m)
	_check(ally_A.health.hp - a0 == 25, "[Surgeon iso] heals the Isolated ROOM-ally 25 (healed %d)" % (ally_A.health.hp - a0))
	# control: an Isolated ally NOT ROOM-marked is not healed
	var iso2 = Effect.isolate(4); iso2.set_source(E.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(ally_B, m), E, ally_B, iso2, true)
	ally_B.health.hp = maxi(1, ally_B.health.hp - 40)
	var b1 = ally_B.health.hp
	law.targeter.targets = [ally_B]; law.targeter.main_target = ally_B; law.used_ability = surgeon
	surgeon.execute(law, m)
	_check(ally_B.health.hp == b1, "[Surgeon iso] an Isolated NON-ROOM ally is NOT healed (control)")

	# === 9. ROOM mark lands through Invulnerability (bypassing application) ===
	_clear_room(m, law)
	for c in [E, Z, W]:
		if not (c.dead or c.banished):
			var iv = Effect.invuln_effect(6); iv.set_source(room)
			Character.add_allied_effect(QueryContext.from_game_state(c, m), c, c, iv)
	m.waiting_for_turn = false
	room.room_tick(QueryContext.from_effect_end(trig))
	var inv_marked = 0
	for c in [E, Z, W]:
		if c.marked_by("ROOM", law): inv_marked += 1
	_check(inv_marked >= 1, "[ROOM bypass] the ROOM mark lands on an Invulnerable enemy (%d marked)" % inv_marked)

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
