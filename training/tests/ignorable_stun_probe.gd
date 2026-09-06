extends Node
# Verifies the `ignorable` effect flag + the conversion of Mahapadma / Swords of Revealing Light from
# skill_seal MARKs to NON-ignorable STUNs.
#   - a non-ignorable stun bypasses every stun escape hatch (Unstunnable, ignore-all-non-damage) but
#     still honours its own class scope AND name exemption;
#   - because they are now stuns, they interrupt Action skills + channels through the ONE is_stunned gate;
#   - ordinary (ignorable) stuns are completely unchanged.
#   godot --headless --path <repo> res://training/tests/ignorable_stun_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

const STUN := EffectType.Type.STUN

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy: bool = (u == "BotEnemy")
	for cn in names: p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _fresh(p1n, p2n) -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", p1n)
	var p2 := _build_player("BotEnemy", p2n)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "p1": p1.team.characters, "p2": p2.team.characters}

# Apply a raw stun (as a hostile effect from `caster`) with a chosen ignorable/scope.
func _stun(caster, target, dur, ignorable, class_targets := [], excl_names := []):
	var s = Effect.stun_effect(dur, class_targets)
	s.ignorable = ignorable
	s.exclusion_names = excl_names
	s.set_source(caster.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(caster, caster.battle), caster, target, s)
	return s

func _exec(m, caster, ab, targets):
	caster.used_ability = ab
	caster.targeter.targets = targets.duplicate()
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)

func _ready():
	print("=== IGNORABLE-STUN / Mahapadma+Swords conversion probe ===")

	# ============ 1. GENERAL: a non-ignorable stun bypasses the Unstunnable flag ============
	var a = _fresh(["esdeath","goku"], ["cooler","gon"])
	var a_cast = a.p1[0]; var a_foe = a.p2[0]
	var a_ab = a_foe.moveset.base_abilities[0]
	a_ab.stunnable = false
	_stun(a_cast, a_foe, 4, true)            # ordinary stun
	_check(not a_foe.is_stunned(a_ab), "control: an IGNORABLE stun does NOT stun an Unstunnable skill")

	var b = _fresh(["esdeath","goku"], ["cooler","gon"])
	var b_cast = b.p1[0]; var b_foe = b.p2[0]
	var b_ab = b_foe.moveset.base_abilities[0]
	b_ab.stunnable = false
	_stun(b_cast, b_foe, 4, false)           # non-ignorable stun
	_check(b_foe.is_stunned(b_ab), "non-ignorable stun DOES stun an Unstunnable skill (bypasses the flag)")

	# ============ 2. GENERAL: application drop vs "ignore all non-damage effects" ============
	var c = _fresh(["esdeath","goku"], ["cooler","gon"])
	var c_cast = c.p1[0]; var c_foe = c.p2[0]
	var ig = Effect.ignore_non_damage_effect(8)   # grants true_ignoring -> shrug_off_type(STUN)
	ig.set_source(c_foe.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(c_foe, c.m), c_foe, c_foe, ig)
	_stun(c_cast, c_foe, 4, true)
	_check(c_foe.get_effects_by_type(STUN).size() == 0, "control: an IGNORABLE stun is DROPPED at application by ignore-all-non-damage")
	_stun(c_cast, c_foe, 4, false)
	_check(c_foe.get_effects_by_type(STUN).size() >= 1, "non-ignorable stun LANDS despite ignore-all-non-damage (drop respects ignorable)")
	_check(c_foe.is_stunned(c_foe.moveset.base_abilities[0]), "...and the landed non-ignorable stun actually STUNS through the shrug")

	# ============ 3. MAHAPADMA (real): stuns everyone, incl. Unstunnable; interrupts Action + channel ============
	var d = _fresh(["esdeath","gohan"], ["cooler","gon","killua"])
	var esd = d.p1[0]; var ally = d.p1[1]
	var maha = esd.moveset.base_abilities[1]      # esdeath2 "Mahapadma"
	var enemies = d.p2
	# a channel + an Action skill on an enemy, to prove interruption through is_stunned:
	var chan_foe = enemies[0]
	var chan_src = chan_foe.moveset.base_abilities[0]
	var chan = Effect.channel_cancel(6, "Test Channel", [])
	chan.set_source(chan_src)
	Character.add_allied_effect(QueryContext.from_game_state(chan_foe, d.m), chan_foe, chan_foe, chan)
	var action_foe = enemies[1]
	var action_ab = action_foe.moveset.base_abilities[0]
	action_ab.classes["Action"] = true
	_check(chan_foe.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 1, "setup: enemy is channelling")

	var others = []
	for ch in d.m.all_characters():
		if ch != esd: others.append(ch)
	_exec(d.m, esd, maha, others)

	for e in enemies:
		_check(e.is_stunned(e.moveset.base_abilities[0]), "Mahapadma stuns enemy %s" % e.path_name)
	_check(ally.is_stunned(ally.moveset.base_abilities[0]), "Mahapadma stuns allies too (all OTHER characters)")
	_check(not esd.is_stunned(esd.moveset.base_abilities[0]), "Esdeath is NOT stunned by her own Mahapadma")
	var un_ab = enemies[2].moveset.base_abilities[0]; un_ab.stunnable = false
	_check(enemies[2].is_stunned(un_ab), "Mahapadma stuns even an Unstunnable enemy skill (non-ignorable)")
	_check(not action_foe.moveset.base_abilities[0].authoritative_usable(action_foe, true), "a Mahapadma-stunned skill is NOT usable() (energy ignored)")
	# THE ORIGINAL BUG: an Action skill's tick is gated on is_stunned(source) — now true under Mahapadma.
	_check(action_foe.is_stunned(action_ab), "ACTION skill is now paused by Mahapadma (is_stunned true — the original bug)")
	# Channel broke: the STUN landing ran check_cancels, which ended the channel.
	_check(chan_foe.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 0, "Mahapadma BREAKS the enemy channel (check_cancels via the stun)")

	# recoil: when a target's Mahapadma ends, Esdeath is stunned — once.
	esd.effects  # (ensure node valid)
	maha.timeout_trigger(QueryContext.from_game_state(esd, d.m))
	_check(esd.is_stunned(esd.moveset.base_abilities[0]), "Mahapadma recoil: Esdeath is stunned after the effect ends")
	var recoil_n = esd.get_effects_by_type(STUN).size()
	maha.timeout_trigger(QueryContext.from_game_state(esd, d.m))
	_check(esd.get_effects_by_type(STUN).size() == recoil_n, "recoil applies only ONCE (guard holds across multiple expiries)")

	# ============ 4. SWORDS OF REVEALING LIGHT (real): Harmful-only, name exemption, ends via a card ============
	var s = _fresh(["yugi","gohan"], ["cooler","gon","killua"])
	var yugi = s.p1[0]
	var swords = yugi.moveset.base_abilities[2]      # yugi3
	var dm_girl = yugi.moveset.base_abilities[1]     # yugi2 "Dark Magician Girl"
	var dm = yugi.moveset.base_abilities[4]          # yugi5 "Dark Magician"
	var obliterate = yugi.moveset.base_abilities[6]  # yugi7 "Obliterate!" (Harmful, NOT a card)
	var se = s.p2
	var h_ab = se[0].moveset.base_abilities[0]; h_ab.classes["Harmful"] = true; h_ab.stunnable = true
	var n_ab = se[1].moveset.base_abilities[0]; n_ab.classes["Harmful"] = false
	var hu_ab = se[2].moveset.base_abilities[0]; hu_ab.classes["Harmful"] = true; hu_ab.stunnable = false

	var alls = s.m.all_characters()
	_exec(s.m, yugi, swords, alls)

	_check(se[0].is_stunned(h_ab), "Swords stuns a Harmful enemy skill")
	_check(not se[1].is_stunned(n_ab), "Swords does NOT stun a non-Harmful enemy skill")
	_check(se[2].is_stunned(hu_ab), "Swords stuns a Harmful UNSTUNNABLE enemy skill (name exemption is the ONLY escape)")
	_check(not yugi.is_stunned(dm), "Yugi's Dark Magician (Harmful) is NAME-exempt from his own Swords")
	_check(not yugi.is_stunned(dm_girl), "Yugi's Dark Magician Girl is NAME-exempt from Swords")
	_check(yugi.is_stunned(obliterate), "Yugi's Obliterate! (Harmful, not a card) IS stunned by his own Swords")
	_check(dm.authoritative_usable(yugi, true), "Dark Magician is usable() under Swords (name exemption reaches usable, energy ignored)")
	_check(not obliterate.authoritative_usable(yugi, true), "Obliterate! is NOT usable() under Swords (energy ignored)")

	# Dark Magician Girl ends Swords (STUN-probe path in yugi2):
	_exec(s.m, yugi, dm_girl, [se[0]])
	var still := 0
	for ch in s.m.all_characters():
		still += ch.get_effects_by_type(STUN).filter(func(e): return e.effect_name() == "Swords of Revealing Light").size()
	_check(still == 0, "Dark Magician Girl ENDS Swords for everyone (STUN removed)")

	# ============ 5. REGRESSION: ordinary stuns unchanged ============
	var r = _fresh(["esdeath","goku"], ["cooler","gon"])
	var r_cast = r.p1[0]; var r_foe = r.p2[0]
	var norm = r_foe.moveset.base_abilities[0]      # stunnable (default)
	var unstun = r_foe.moveset.base_abilities[1]; unstun.stunnable = false
	_stun(r_cast, r_foe, 4, true)                   # ordinary stun-all
	_check(r_foe.is_stunned(norm), "regression: an ordinary stun still stuns a normal skill")
	_check(not r_foe.is_stunned(unstun), "regression: an ordinary stun still spares an Unstunnable skill")

	# ============ 6. REGRESSION: the skill_seal system still works (Itachi's Totsuka) ============
	var t = _fresh(["itachi","goku"], ["cooler","gon"])
	var it = t.p1[0]; var t_foe = t.p2[0]
	var seal = Effect.mark(4, "sealed")
	seal.skill_seal = true
	seal.set_source(it.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(it, t.m), it, t_foe, seal)
	_check(t_foe.moveset.base_abilities[0].is_sealed_out(t_foe), "regression: a skill_seal MARK still seals via is_sealed_out (Totsuka intact)")
	_check(not t_foe.is_stunned(t_foe.moveset.base_abilities[0]), "regression: a skill_seal is NOT a stun (is_stunned stays blind to it)")

	# ============ 7. non-ignorable stun is NOT escapable by stun-received triggers ============
	# Horohoro (horohoro1) shrugs a stun off + heals 20; Shokuhou (shokuhou2) cleanses it + counter-stuns.
	# A non-ignorable Mahapadma must fire NEITHER (check_stun_received_triggers gated on ignorable).
	var g = _fresh(["horohoro","shokuhou","goku"], ["esdeath","cooler","gon"])
	var horo = g.p1[0]; var shok = g.p1[1]; var esd2 = g.p2[0]
	var maha2 = esd2.moveset.base_abilities[1]
	_exec(g.m, horo, horo.moveset.base_abilities[0], [horo])   # horohoro1 -> installs stun-shrug trigger
	_exec(g.m, shok, shok.moveset.base_abilities[1], [shok])   # shokuhou2 -> installs cleanse trigger
	horo.health.hp = 50
	var horo_hp0 = int(horo.health.hp)
	var g_others = []
	for ch in g.m.all_characters():
		if ch != esd2: g_others.append(ch)
	_exec(g.m, esd2, maha2, g_others)
	_check(horo.get_effects_by_type(STUN).size() >= 1, "non-ignorable Mahapadma STAYS on Horohoro (stun-shrug trigger did NOT fire)")
	_check(int(horo.health.hp) == horo_hp0, "Horohoro did NOT heal off the non-ignorable stun")
	_check(shok.get_effects_by_type(STUN).size() >= 1, "non-ignorable Mahapadma STAYS on Shokuhou (her cleanse trigger did NOT fire)")
	_check(esd2.get_effects_by_type(STUN).size() == 0, "Esdeath was NOT counter-stunned by Shokuhou (trigger suppressed)")

	# CONTROL: an ORDINARY stun DOES fire Horohoro's shrug (his kit is unbroken vs normal stuns).
	var g2 = _fresh(["horohoro","goku"], ["cooler","gon"])
	var horo2 = g2.p1[0]; var foe_c = g2.p2[0]
	_exec(g2.m, horo2, horo2.moveset.base_abilities[0], [horo2])
	horo2.health.hp = 50
	_stun(foe_c, horo2, 4, true)                               # ordinary stun
	_check(horo2.get_effects_by_type(STUN).size() == 0, "control: an ORDINARY stun IS shrugged by Horohoro (trigger fires, stun erased)")
	_check(int(horo2.health.hp) == 70, "control: Horohoro heals 20 off an ordinary stun (kit intact)")

	# ============ 8. has_stuns() agrees with is_stunned() for a non-ignorable stun on a shrug target ============
	var h = _fresh(["esdeath","goku"], ["cooler","gon"])
	var h_cast = h.p1[0]; var h_foe = h.p2[0]
	var ig2 = Effect.ignore_non_damage_effect(8); ig2.set_source(h_foe.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(h_foe, h.m), h_foe, h_foe, ig2)
	_check(not h_foe.has_stuns(), "control: has_stuns() false on an ignore-all-non-damage target with no non-ignorable stun")
	_stun(h_cast, h_foe, 4, false)
	_check(h_foe.has_stuns(), "has_stuns() TRUE for a non-ignorable stun on a shrug target (agrees with is_stunned)")
	_check(h_foe.is_stunned(h_foe.moveset.base_abilities[0]), "...and is_stunned() also true (the two agree)")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
