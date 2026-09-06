extends Node

# Muzan Kibutsuji full-kit probe.
#   1. King of Blood (passive) seeds its triggers at startup.
#   2. Blood Gash / Assimilation: enemy takes the immediate Bleed + a Bleed DoT; ally is healed + a HoT.
#   3. King of Blood: Muzan heals 5 whenever he deals Bleed (immediate AND each DoT tick) or heals an ally.
#   4. Lab Experiment: bleeds an ally, grants energy, stores a +10 stack consumed by the next blood skill.
#   5. King of Blood: a character carrying Muzan's bleed/HoT that acts gets +1 turn (+2 dur) on it.
#   6. Threatening Glare: self-Invulnerable.
#   godot --headless --path <repo> res://training/tests/muzan_kit_probe.tscn

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

func _muzan_bleed(target, muzan):
	for e in target.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if e.user == muzan and e.damage_type == DamageType.Type.BLEED:
			return e
	return null

func _muzan_hot(target, muzan):
	for e in target.effects.get_effects_by_type(EffectType.Type.HEALING):
		if e.user == muzan:
			return e
	return null

func _ready():
	print("=== muzan kit probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Muzan", ["muzan", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["killua", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var muzan = p1.team.characters[0]
	var A = p1.team.characters[1]
	var B = p1.team.characters[2]
	var E = p2.team.characters[0]
	var TT = EffectType.Type
	var blood_gash = muzan.moveset.base_abilities[0]
	var assim = muzan.moveset.base_abilities[1]
	var lab = muzan.moveset.base_abilities[2]
	var glare = muzan.moveset.base_abilities[3]
	var kob = muzan.moveset.base_abilities[4]

	# passive may already have run in start_battle; ensure it's active exactly once
	if muzan.has_effect("King of Blood", TT.DAMAGE_DEALT_TRIGGER, muzan) == null:
		kob.execute(muzan, m)

	# === 1. passive setup ===
	_check(muzan.has_effect("King of Blood", TT.DAMAGE_DEALT_TRIGGER, muzan) != null, "[passive] Muzan has the Bleed-heal trigger")
	_check(muzan.has_effect("King of Blood", TT.HEALING_GIVEN_TRIGGER, muzan) != null, "[passive] Muzan has the heal-heal trigger")
	_check(E.has_effect("King of Blood", TT.ACTION_USE_TRIGGER, muzan) != null, "[passive] an enemy carries the action watcher")

	# === 2. Blood Gash on an enemy: immediate 15 Bleed + a DoT, and Muzan self-heals 5 ===
	muzan.health.hp = 50
	var e0 = E.health.hp
	muzan.targeter.targets = [E]; muzan.targeter.main_target = E; muzan.used_ability = blood_gash
	blood_gash.execute(muzan, m)
	_check(e0 - E.health.hp == 15, "[Blood Gash] 15 Bleed to the enemy (dealt %d)" % (e0 - E.health.hp))
	_check(_muzan_bleed(E, muzan) != null, "[Blood Gash] a Bleed DoT is left on the enemy")
	_check(muzan.health.hp == 55, "[King of Blood] Muzan heals 5 on dealing Bleed (50 -> %d)" % muzan.health.hp)

	# === 3. DoT tick deals 5 AND heals Muzan 5 again ===
	var dot = _muzan_bleed(E, muzan)
	var e1 = E.health.hp
	muzan.health.hp = 50
	m.execute_ticking_effect(dot)
	await get_tree().process_frame
	_check(e1 - E.health.hp == 5, "[DoT] the Bleed tick deals 5 (dealt %d)" % (e1 - E.health.hp))
	_check(muzan.health.hp == 55, "[King of Blood] Muzan heals 5 on the Bleed tick too (50 -> %d)" % muzan.health.hp)

	# === 4. Blood Gash on an ally: heals 15 + a HoT, and Muzan heals 5 (healed an ally) ===
	A.health.hp = 40
	muzan.health.hp = 50
	muzan.targeter.targets = [A]; muzan.targeter.main_target = A; muzan.used_ability = blood_gash
	blood_gash.execute(muzan, m)
	_check(A.health.hp == 55, "[Blood Gash] heals the ally 15 (40 -> %d)" % A.health.hp)
	_check(_muzan_hot(A, muzan) != null, "[Blood Gash] a HoT is left on the ally")
	_check(muzan.health.hp == 55, "[King of Blood] Muzan heals 5 on healing an ally (50 -> %d)" % muzan.health.hp)

	# === 5. Lab Experiment: bleeds ally B, grants energy, stores a +10 stack ===
	var b0 = B.health.hp
	muzan.targeter.targets = [B]; muzan.targeter.main_target = B; muzan.used_ability = lab
	lab.execute(muzan, m)
	_check(b0 - B.health.hp == 15, "[Lab Experiment] 15 Bleed to the ally (dealt %d)" % (b0 - B.health.hp))
	var stack = muzan.has_effect("Lab Experiment", TT.MARK, muzan)
	_check(stack != null and stack.stack_count() == 1, "[Lab Experiment] Muzan stores a +10 stack")

	# === 6. next Blood Gash consumes the stack: 15 + 10 = 25, stack gone ===
	var e2 = E.health.hp
	muzan.targeter.targets = [E]; muzan.targeter.main_target = E; muzan.used_ability = blood_gash
	blood_gash.execute(muzan, m)
	_check(e2 - E.health.hp == 25, "[Lab boost] boosted Blood Gash deals 15+10=25 (dealt %d)" % (e2 - E.health.hp))
	_check(muzan.has_effect("Lab Experiment", TT.MARK, muzan) == null, "[Lab boost] the stack was consumed")

	# === 7. duration extension when an affected enemy acts ===
	var dot2 = _muzan_bleed(E, muzan)
	var dur0 = int(dot2.duration)
	E.check_ability_use_triggers(m, E.moveset.base_abilities[0], false)
	_check(int(dot2.duration) == dur0 + 2, "[King of Blood] a bleeding enemy acting extends the DoT +1 turn (%d -> %d)" % [dur0, int(dot2.duration)])

	# === 8. Threatening Glare: self-Invulnerable ===
	muzan.targeter.targets = [muzan]; muzan.used_ability = glare
	glare.execute(muzan, m)
	_check(muzan.is_invuln(blood_gash), "[Threatening Glare] Muzan is Invulnerable")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
