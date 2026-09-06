extends Node

# Balance-patch probe. Drives the riskiest mechanics from the 2026-08-29 balance batch.
# NOTE: everything runs inside _ready(), so every `var`/`for` name shares one function scope — keep
# loop/temp names unique or GDScript aborts with "already a variable named ... in this scope".
#   godot --headless --path . res://training/tests/balance_patch_probe.tscn

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

func _battle(p1_names, p2_names, seed := 4242):
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_A" + str(seed), p1_names, false)
	var p2 = _build("ZZ_B" + str(seed), p2_names, true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, seed, BattleManager.MatchType.BOT)
	return [m, p1, p2]

func _use(actor, ability, targets):
	actor.targeter.targets = targets
	actor.targeter.main_target = targets[0] if targets.size() > 0 else null
	actor.used_ability = ability
	ability.execute(actor, actor.battle)

func _cost_total(ability):
	var c = ability.cost()
	var t = 0
	for k in c.keys():
		t += int(c[k])
	return t

func _dr_total(ch):
	var s = 0
	for de in ch.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION):
		s += int(de.mag)
	return s

func _clear_dr(ch):
	for de in ch.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION):
		ch.effects.erase_effect(de)

func _ready():
	print("=== balance patch probe ===")
	var TT = EffectType.Type

	# ============ KORRA ============
	var rk = _battle(["korra", "gray", "gon"], ["aang", "misaka", "byakuya"])
	var mk = rk[0]; var korra = rk[1].team.characters[0]; var kfoe = rk[2].team.characters[0]
	var fire_control = korra.moveset.base_abilities[0]
	_use(korra, fire_control, [kfoe])
	var active = korra.moveset.get_active_abilities(korra)
	var slot_names = []
	for a in active.slice(0, 4):
		slot_names.append(a.ability_name)
	_check(slot_names == ["Fire Fist", "Air Wave", "Earth Area Attack", "Water Arm Stun"],
		"[Korra] using Fire Control swaps ALL slots to elemental attacks", str(slot_names))
	var fire_fist = korra.moveset.base_abilities[4]
	var base_cost = _cost_total(fire_fist)
	var aff = null
	for a in kfoe.moveset.base_abilities:
		if a.classes["Affliction"] and a.classes["Harmful"]:
			aff = a; break
	if aff != null:
		kfoe.targeter.targets = [korra]; kfoe.targeter.main_target = korra; kfoe.used_ability = aff
		kfoe.countered(mk, aff)
		_check(_cost_total(fire_fist) == base_cost - 1, "[Korra] a successful counter discounts Fire Fist by 1 Random (%d -> %d)" % [base_cost, _cost_total(fire_fist)])
	else:
		print("  SKIP  no Affliction skill on the foe to exercise Korra's counter")
	var earth = korra.moveset.base_abilities[6]
	var ke1 = rk[2].team.characters[1]
	kfoe.health.hp = 100; ke1.health.hp = 100
	korra.targeter.targets = [kfoe, ke1]; korra.targeter.main_target = kfoe; korra.used_ability = earth
	earth.execute(korra, mk)
	_check(kfoe.health.hp == 70 and ke1.health.hp == 85, "[Korra] Earth Area Attack deals 30 main / 15 splash (%d, %d)" % [kfoe.health.hp, ke1.health.hp])

	# ============ TOPH ============
	var rt = _battle(["toph", "gray", "gon"], ["gon", "misaka", "byakuya"], 77)
	var mt = rt[0]; var toph = rt[1].team.characters[0]; var tfoe = rt[2].team.characters[0]
	var pillar = toph.moveset.base_abilities[0]
	var earth_wall = toph.moveset.base_abilities[3]
	var metal = toph.moveset.base_abilities[2]
	_check(pillar.cost().get(Energy.Type.GREEN, 0) == 1 and pillar.cost().get(Energy.Type.RANDOM, 0) == 0, "[Toph] Stone Pillar starts at 1 Green")
	_use(toph, pillar, [tfoe])
	_check(pillar.cost().get(Energy.Type.RANDOM, 0) == 1 and pillar.cost().get(Energy.Type.GREEN, 0) == 0, "[Toph] after use, Stone Pillar costs 1 Random")
	toph.targeter.targets = [toph]; toph.used_ability = earth_wall
	earth_wall.execute(toph, mt)
	toph.check_ability_use_triggers(mt, earth_wall)
	_check(pillar.cost().get(Energy.Type.GREEN, 0) == 1 and pillar.cost().get(Energy.Type.RANDOM, 0) == 0, "[Toph] a different skill resets Stone Pillar's cost to Green")
	toph.targeter.targets = [toph]; toph.used_ability = metal
	metal.execute(toph, mt)
	tfoe.health.hp = 100
	toph.targeter.targets = [tfoe]; toph.targeter.main_target = tfoe; toph.used_ability = pillar
	pillar.execute(toph, mt)
	_check(tfoe.health.hp == 75, "[Toph] Stone Pillar deals 20+5=25 while Toph holds Metal Armor (100 -> %d)" % tfoe.health.hp)

	# ============ KATARA ============
	var rc = _battle(["kitara", "gray", "gon"], ["gon", "misaka", "byakuya"], 88)
	var mc = rc[0]; var kat = rc[1].team.characters[0]; var cfoe = rc[2].team.characters[0]
	var waves = kat.moveset.base_abilities[0]
	cfoe.health.hp = 100
	_use(kat, waves, [cfoe])
	_check(cfoe.health.hp == 90, "[Katara] Slicing Water Waves opens at 10 (100 -> %d)" % cfoe.health.hp)
	var wave_eff = null
	for we in cfoe.effects.get_effects_by_type(TT.TICKING_TRIGGER):
		if we.source == waves:
			wave_eff = we; break
	_check(wave_eff != null and int(wave_eff.mag) == 15, "[Katara] the next tick is primed to 15 after the opening hit")
	if wave_eff != null:
		var ch1 = cfoe.health.hp
		mc.execute_ticking_effect(wave_eff)
		await get_tree().process_frame
		_check(ch1 - cfoe.health.hp == 15, "[Katara] first tick deals 15 (dealt %d)" % (ch1 - cfoe.health.hp))
		var ch2 = cfoe.health.hp
		mc.execute_ticking_effect(wave_eff)
		await get_tree().process_frame
		_check(ch2 - cfoe.health.hp == 20, "[Katara] second tick ramps to 20 (dealt %d)" % (ch2 - cfoe.health.hp))

	# ============ NOBARA ============
	var rn = _battle(["nobara", "gray", "gon"], ["esdeath", "misaka", "byakuya"], 99)
	var mn = rn[0]; var nob = rn[1].team.characters[0]; var nenemy = rn[2].team.characters[0]
	var embrace = nob.moveset.base_abilities[3]
	nob.health.hp = 50
	nob.targeter.targets = [nob]; nob.used_ability = embrace
	embrace.execute(nob, mn)
	var ntick = null
	for te in nob.effects.get_effects_by_type(TT.TICKING_TRIGGER):
		if te.source == embrace:
			ntick = te; break
	_clear_dr(nob)
	nob.health.hp = 50
	if ntick != null:
		mn.execute_ticking_effect(ntick)
		await get_tree().process_frame
		_check(nob.health.hp == 65 and _dr_total(nob) == 10, "[Nobara] Embrace Pain heals 15 + 10 DR with no negative effect (hp %d, dr %d)" % [nob.health.hp, _dr_total(nob)])
		_clear_dr(nob)
		var nblind = Effect.blind_effect(4)
		nblind.set_source(nenemy.moveset.base_abilities[0])
		Character.add_hostile_effect(QueryContext.from_game_state(nenemy, mn), nenemy, nob, nblind, true)
		nob.health.hp = 50
		mn.execute_ticking_effect(ntick)
		await get_tree().process_frame
		_check(nob.health.hp == 80 and _dr_total(nob) == 20, "[Nobara] boosted to 30 HP + 20 DR with a negative non-damage effect (hp %d, dr %d)" % [nob.health.hp, _dr_total(nob)])

	# ============ MASH ============
	var rm = _battle(["mashburnedead", "gray", "gon"], ["gon", "misaka", "byakuya"], 111)
	var mm = rm[0]; var mash = rm[1].team.characters[0]; var mfoe = rm[2].team.characters[0]
	var ballista = mash.moveset.base_abilities[1]
	var hellfall = mash.moveset.base_abilities[2]
	var dash = Effect.mark(-1, "Big Bang Dash"); dash.name_override = "Big Bang Dash"; dash.set_source(mash.moveset.base_abilities[0])
	mash.apply_effect(dash, mash)
	var foe_dr = Effect.damage_reduction_effect(15, 6); foe_dr.set_source(hellfall)
	mfoe.apply_effect(foe_dr, mfoe)
	mfoe.health.hp = 100
	mash.targeter.targets = [mfoe]; mash.targeter.main_target = mfoe; mash.used_ability = ballista
	ballista.execute(mash, mm)
	_check(mfoe.get_effects_by_type(TT.DAMAGE_REDUCTION).is_empty(), "[Mash] Ballista Knuckle strips Damage Reduction when enhanced")
	_check(mfoe.health.hp == 70, "[Mash] Ballista deals 20+10 (DR removed) = 30 (100 -> %d)" % mfoe.health.hp)
	mfoe.health.hp = 100
	mash.used_ability = hellfall
	mash.targeter.targets = [mfoe]; mash.targeter.main_target = mfoe
	hellfall.execute(mash, mm)
	_check(mfoe.health.hp == 65, "[Mash] Hell Fall deals 25+10 (no Shield/DR) = 35 (100 -> %d)" % mfoe.health.hp)

	# ============ KEN / BROLY / INUYASHA ============
	var rb = _battle(["ken", "broly", "inuyasha"], ["gon", "misaka", "byakuya"], 222)
	var mb = rb[0]; var ken = rb[1].team.characters[0]; var broly = rb[1].team.characters[1]; var inu = rb[1].team.characters[2]; var bfoe = rb[2].team.characters[0]
	var rampage = ken.moveset.base_abilities[2]
	ken.targeter.targets = [ken]; ken.used_ability = rampage
	rampage.execute(ken, mb)
	_check(_dr_total(ken) == 5, "[Ken] Bloodthirsty Rampage grants 5 DR (%d)" % _dr_total(ken))
	var eraser = broly.moveset.base_abilities[1]
	bfoe.health.hp = 100
	broly.targeter.targets = [bfoe]; broly.targeter.main_target = bfoe; broly.used_ability = eraser
	eraser.execute(broly, mb)
	var beam = null
	for be in bfoe.effects.get_effects_by_type(TT.DAMAGE):
		if be.source == eraser:
			beam = be; break
	_check(beam != null and int(beam.duration) == 3, "[Broly] Eraser Cannon beam duration is 3 (2 turns) (%s)" % (str(beam.duration) if beam else "none"))
	var blades_passive = inu.moveset.base_abilities[4]
	if inu.has_effect("Blades of Blood", TT.DAMAGE_RECEIVE_TRIGGER, inu) == null:
		blades_passive.execute(inu, mb)
	var recv = inu.has_effect("Blades of Blood", TT.DAMAGE_RECEIVE_TRIGGER, inu)
	if recv != null:
		for i in range(6):
			blades_passive.damage_trigger(QueryContext.from_game_state(inu, mb))
		_check(int(recv.mag) == 3, "[Inuyasha] Blades of Blood stacks cap at 3 (%d)" % recv.mag)
	else:
		print("  SKIP  Blades of Blood receive trigger not seeded")

	# ============ MUZAN (refresh, not stack) ============
	var rz = _battle(["muzan", "gray", "gon"], ["gon", "misaka", "byakuya"], 333)
	var mz = rz[0]; var muzan = rz[1].team.characters[0]; var zfoe = rz[2].team.characters[0]
	var blood_gash = muzan.moveset.base_abilities[0]
	zfoe.health.hp = 200
	muzan.targeter.targets = [zfoe]; muzan.targeter.main_target = zfoe; muzan.used_ability = blood_gash
	blood_gash.execute(muzan, mz)
	muzan.targeter.targets = [zfoe]; muzan.targeter.main_target = zfoe; muzan.used_ability = blood_gash
	blood_gash.execute(muzan, mz)
	var bleed_count = 0
	for be2 in zfoe.effects.get_effects_by_type(TT.DAMAGE):
		if be2.user == muzan and be2.damage_type == DamageType.Type.BLEED:
			bleed_count += 1
	_check(bleed_count == 1, "[Muzan] recasting Blood Gash REFRESHES the bleed (1 DoT, not stacked) — found %d" % bleed_count)

	# ============ KUROTSUCHI (Deadly Gas swaps back to Ashisogi Jizo) ============
	var rq = _battle(["kurotsuchi", "gray", "gon"], ["gon", "misaka", "byakuya"], 444)
	var mq = rq[0]; var mayuri = rq[1].team.characters[0]
	var bankai = mayuri.moveset.base_abilities[4]
	var deadly_gas = mayuri.moveset.base_abilities[5]
	# install the Bankai swap (slot 0 -> Deadly Gas) the way release_bankai does
	var kswap = Effect.ability_swap_effect(5, 0, mayuri, 8)
	kswap.set_source(bankai)
	Character.add_allied_effect(QueryContext.from_game_state(mayuri, mq), mayuri, mayuri, kswap)
	_check(mayuri.moveset.get_active_abilities(mayuri)[0].ability_name == "Deadly Gas", "[Kurotsuchi] Bankai swaps slot 0 to Deadly Gas")
	mayuri.targeter.targets = rq[2].team.characters; mayuri.targeter.main_target = rq[2].team.characters[0]; mayuri.used_ability = deadly_gas
	deadly_gas.execute(mayuri, mq)
	_check(mayuri.moveset.get_active_abilities(mayuri)[0].ability_name == "Ashisogi Jizo", "[Kurotsuchi] using Deadly Gas swaps slot 0 back to Ashisogi Jizo")

	# ============ NEFERPITOU (Post-Mortem immortality ends at end of turn) ============
	var rp = _battle(["neferpitou", "gray", "gon"], ["gon", "misaka", "byakuya"], 555)
	var mp = rp[0]; var nef = rp[1].team.characters[0]; var pfoe = rp[2].team.characters[0]
	var postmortem = nef.moveset.base_abilities[4]
	nef.targeter.targets = [nef]; nef.used_ability = postmortem
	postmortem.execute(nef, mp)
	_check(nef.marked_by("Post-Mortem Nen") != null, "[Neferpitou] Post-Mortem Nen installs its death-save mark")
	nef.health.hp = 10
	nef.die(pfoe, pfoe.moveset.base_abilities[0])
	_check(not nef.dead and not nef.get_effects_by_type(TT.IMMORTALITY).is_empty(), "[Neferpitou] the killing blow is converted to Immortality (survives)")
	# the immortality is a 1-turn duration removed by the universal end-of-turn tick_durations()
	mp.tick_durations()
	_check(nef.get_effects_by_type(TT.IMMORTALITY).is_empty(), "[Neferpitou] end-of-turn tick_durations lifts the Immortality (same-turn, any side)")

	print("=== balance patch probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
