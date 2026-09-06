extends Node

# Baki Hanma kit probe (post-fix).
#   S1 Whip Strike / S2 Light Speed Jab: their riders (delayed Affliction, Strategic-low-HP stun, full
#     stun) apply ONLY when the hit actually deals damage — armed DAMAGE_RECEIVE_TRIGGER, so a hit fully
#     absorbed by Nullify / Shield / DR applies nothing.
#   S3 Tiger King (cd 0): delayed 25 lands next turn unless Baki takes non-Affliction damage first, which
#     cancels the strike AND sets Tiger King's cooldown to 1 (Affliction does not cancel; no pending strike
#     means no cooldown penalty).
#   S4 Prehistoric Kenpo: unchanged (invuln + counter + vulnerability) regression.
#   godot --headless --path . res://training/tests/baki_kit_probe.tscn

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
	var p1 = _build("ZZ_Baki" + str(seed), ["baki", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe" + str(seed), ["gon", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, seed, BattleManager.MatchType.BOT)
	return [m, p1, p2]

func _tick_of(target, baki, name):
	for e in target.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER):
		if e.user == baki and e.source.ability_name == name:
			return e
	return null

func _use(actor, ability, targets):
	actor.targeter.targets = targets
	actor.targeter.main_target = targets[0] if targets.size() > 0 else null
	actor.used_ability = ability
	ability.execute(actor, actor.battle)

func _hit_baki(enemy, baki, m, amount, dtype):
	# Directly drive the receive path so the DAMAGE_RECEIVE_TRIGGER on Baki fires with this damage type.
	baki.receive_ability_damage(enemy.moveset.base_abilities[0], amount, enemy, dtype)

func _ready():
	print("=== baki kit probe (post-fix) ===")
	var TT = EffectType.Type

	var r = _battle(4242)
	var m = r[0]
	var baki = r[1].team.characters[0]
	var E = r[2].team.characters[0]
	var whip = baki.moveset.base_abilities[0]
	var jab = baki.moveset.base_abilities[1]
	var tiger = baki.moveset.base_abilities[2]
	var kenpo = baki.moveset.base_abilities[3]

	# === 1. Whip Strike LANDS: 15 Piercing + delayed Affliction armed ===
	E.health.hp = 100
	_use(baki, whip, [E])
	_check(E.health.hp == 85, "[Whip] deals 15 Piercing when unblocked (100 -> %d)" % E.health.hp)
	var wtick = _tick_of(E, baki, "Whip Strike")
	_check(wtick != null, "[Whip] a landed hit arms the delayed Affliction")
	if wtick != null:
		var h0 = E.health.hp
		wtick.duration = 1
		m.execute_ticking_effect(wtick)
		await get_tree().process_frame
		_check(h0 - E.health.hp == 10, "[Whip] delayed hit deals 10 Affliction (dealt %d)" % (h0 - E.health.hp))
	# delayed Affliction pierces Invulnerability (like normal Affliction) — clean battle
	var rv = _battle(4243)
	var mv = rv[0]; var bakiv = rv[1].team.characters[0]; var Ev = rv[2].team.characters[0]
	var whipv = bakiv.moveset.base_abilities[0]
	Ev.health.hp = 100
	_use(bakiv, whipv, [Ev])
	var vtick = _tick_of(Ev, bakiv, "Whip Strike")
	var vinv = Effect.invuln_effect(4)
	vinv.set_source(Ev.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(Ev, mv), Ev, Ev, vinv)
	if vtick != null:
		var vh = Ev.health.hp
		vtick.duration = 1
		mv.execute_ticking_effect(vtick)
		await get_tree().process_frame
		_check(vh - Ev.health.hp == 10, "[Whip] delayed 10 Affliction pierces Invulnerability (dealt %d)" % (vh - Ev.health.hp))

	# === 2. Whip Strike FULLY ABSORBED (Nullify): no rider effects ===
	var E2 = r[2].team.characters[1]
	E2.health.hp = 100
	for s in E2.effects.get_effects_by_type(TT.STUN):
		E2.effects.erase_effect(s)
	var wshield = Effect.shield_effect(100, 6)
	wshield.set_source(E2.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(E2, m), E2, E2, wshield)
	_use(baki, whip, [E2])
	_check(E2.health.hp == 100, "[Whip] 15 Piercing fully absorbed by Shield — no HP lost")
	_check(_tick_of(E2, baki, "Whip Strike") == null, "[Whip] absorbed hit does NOT arm the delayed Affliction")
	_check(E2.has_effect("Whip Strike", TT.STUN, baki) == null, "[Whip] absorbed hit does NOT apply the Strategic stun")

	# === 3. Whip Strike low-HP -> Strategic stun (landed) ===
	var E3 = r[2].team.characters[2]
	E3.health.hp = 30
	_use(baki, whip, [E3])
	_check(E3.health.hp == 15, "[Whip] landed at low HP (30 -> %d)" % E3.health.hp)
	var wstun = E3.has_effect("Whip Strike", TT.STUN, baki)
	_check(wstun != null and wstun.ability_targets == ["Strategic"], "[Whip] <=25 HP landed hit stuns Strategic skills")

	# === 4. Light Speed Jab LANDS -> stun; ABSORBED by Shield -> no stun ===
	E.health.hp = 100
	for s in E.effects.get_effects_by_type(TT.STUN):
		E.effects.erase_effect(s)
	_use(baki, jab, [E])
	_check(E.health.hp == 65 and E.has_effect("Light Speed Jab", TT.STUN, baki) != null, "[Jab] landed 35 -> full stun")
	E2.health.hp = 100
	for s in E2.effects.get_effects_by_type(TT.STUN):
		E2.effects.erase_effect(s)
	var shield = Effect.shield_effect(100, 6)
	shield.set_source(E2.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(E2, m), E2, E2, shield)
	_use(baki, jab, [E2])
	_check(E2.health.hp == 100 and E2.has_effect("Light Speed Jab", TT.STUN, baki) == null, "[Jab] fully absorbed by Shield -> no stun")

	# === 5. Tiger King (cd 0): no damage to Baki -> 25 lands, cooldown untouched ===
	var Ta = r[2].team.characters[0]
	Ta.health.hp = 100
	_check(tiger.cooldown == 0, "[Tiger] base cooldown is 0 (-> %d)" % tiger.cooldown)
	_use(baki, tiger, [Ta])
	_check(Ta.has_effect("Tiger King", TT.STUN, baki) != null, "[Tiger] Strategic stun applied on cast")
	_check(baki.has_effect("Tiger King", TT.DAMAGE_RECEIVE_TRIGGER, baki) != null, "[Tiger] cancel watcher armed on Baki")
	var ttick = _tick_of(Ta, baki, "Tiger King")
	_check(ttick != null and not ttick.storage.get("cancelled", true), "[Tiger] pending strike starts un-cancelled")
	tiger.cooldown_remaining = 0
	if ttick != null:
		var h3 = Ta.health.hp
		ttick.duration = 1
		m.execute_ticking_effect(ttick)
		await get_tree().process_frame
		_check(h3 - Ta.health.hp == 25, "[Tiger] uninterrupted -> delayed 25 lands (dealt %d)" % (h3 - Ta.health.hp))
		_check(tiger.cooldown_remaining == 0, "[Tiger] uninterrupted strike leaves cooldown at 0 (-> %d)" % tiger.cooldown_remaining)

	# === 6. Tiger King cancelled by NON-Affliction damage -> no damage + cooldown set to 1 ===
	var Tb = r[2].team.characters[1]
	Tb.health.hp = 100
	tiger.cooldown_remaining = 0
	_use(baki, tiger, [Tb])
	var ttb = _tick_of(Tb, baki, "Tiger King")
	_hit_baki(Tb, baki, m, 10, DamageType.Type.NORMAL)
	_check(ttb != null and ttb.storage.get("cancelled", false), "[Tiger] non-Affliction damage to Baki cancels the pending strike")
	_check(_tick_of(Tb, baki, "Tiger King") == null, "[Tiger] cancelled strike is REMOVED from the target (tooltip gone)")
	_check(tiger.cooldown_remaining == 1, "[Tiger] cancel sets Tiger King cooldown to 1 (-> %d)" % tiger.cooldown_remaining)
	if ttb != null:
		var hb = Tb.health.hp
		ttb.duration = 1
		m.execute_ticking_effect(ttb)
		await get_tree().process_frame
		_check(hb == Tb.health.hp, "[Tiger] cancelled strike deals no damage (%d -> %d)" % [hb, Tb.health.hp])

	# === 6b. Damage to Baki with NO pending strike must NOT lock the cooldown ===
	tiger.cooldown_remaining = 0
	_hit_baki(Tb, baki, m, 10, DamageType.Type.NORMAL)
	_check(tiger.cooldown_remaining == 0, "[Tiger] taking damage with nothing pending keeps cooldown at 0 (-> %d)" % tiger.cooldown_remaining)

	# === 7. Tiger King NOT cancelled by Affliction damage ===
	var Tc = r[2].team.characters[2]
	Tc.health.hp = 100
	_use(baki, tiger, [Tc])
	var ttc = _tick_of(Tc, baki, "Tiger King")
	_hit_baki(Tc, baki, m, 10, DamageType.Type.AFFLICTION)
	_check(ttc != null and not ttc.storage.get("cancelled", true), "[Tiger] Affliction damage does NOT cancel the strike")
	if ttc != null:
		var hc = Tc.health.hp
		ttc.duration = 1
		m.execute_ticking_effect(ttc)
		await get_tree().process_frame
		_check(hc - Tc.health.hp == 25, "[Tiger] strike still lands 25 after Affliction only (dealt %d)" % (hc - Tc.health.hp))

	# === 7b. Overlapping Tiger King casts don't cross-contaminate (per-cast cancel state) ===
	var rr = _battle(4244)
	var mr = rr[0]; var b2 = rr[1].team.characters[0]; var X1 = rr[2].team.characters[0]; var X2 = rr[2].team.characters[1]
	var tiger2 = b2.moveset.base_abilities[2]
	X1.health.hp = 100; X2.health.hp = 100
	_use(b2, tiger2, [X1])
	_use(b2, tiger2, [X2])
	var tk1 = _tick_of(X1, b2, "Tiger King")
	var tk2 = _tick_of(X2, b2, "Tiger King")
	if tk1 != null and tk2 != null:
		tk1.duration = 1; mr.execute_ticking_effect(tk1); await get_tree().process_frame
		tk2.duration = 1; mr.execute_ticking_effect(tk2); await get_tree().process_frame
		_check(X1.health.hp == 75 and X2.health.hp == 75, "[Tiger] both overlapping strikes land independently (X1=%d X2=%d)" % [X1.health.hp, X2.health.hp])

	# === 8. Prehistoric Kenpo regression: invuln + counter + vulnerability ===
	baki.targeter.targets = [baki]; baki.targeter.main_target = baki; baki.used_ability = kenpo
	kenpo.execute(baki, m)
	_check(baki.is_invuln(whip), "[Kenpo] Baki becomes Invulnerable")
	_check(baki.has_effect("Prehistoric Kenpo", TT.COUNTER_RECEIVE, baki) != null, "[Kenpo] counter set on Baki")
	var atk = null
	for cand in E.moveset.base_abilities:
		if cand != null and cand.classes["Harmful"] and not cand.classes["Strategic"]:
			atk = cand; break
	if atk != null:
		E.dead = false; E.health.hp = 100
		E.targeter.targets = [baki]; E.targeter.main_target = baki; E.used_ability = atk
		var was = E.countered(m, atk)
		_check(was and E.has_effect("Prehistoric Kenpo", TT.VULNERABILITY, baki) != null, "[Kenpo] countered enemy gains the vulnerability")
		E.health.hp = 100
		_use(baki, whip, [E])
		_check(E.health.hp == 75, "[Kenpo] Whip Strike deals 15+10=25 to the vulnerable enemy (100 -> %d)" % E.health.hp)

	# === 9. "Ignore all non-damage effects" does NOT drop a damage-carrying ticking trigger ===
	var ri = _battle(4245)
	var mi = ri[0]; var bakii = ri[1].team.characters[0]; var Ei = ri[2].team.characters[0]
	var ign = Effect.ignore_non_damage_effect(6)
	ign.set_source(Ei.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(Ei, mi), Ei, Ei, ign)
	Ei.health.hp = 100
	_use(bakii, bakii.moveset.base_abilities[0], [Ei])   # Whip Strike
	var itick = _tick_of(Ei, bakii, "Whip Strike")
	_check(itick != null, "[Ignore] Baki's delayed Affliction (damage-carrying trigger) is NOT dropped by ignore-non-damage")
	if itick != null:
		var ih = Ei.health.hp
		itick.duration = 1
		mi.execute_ticking_effect(itick)
		await get_tree().process_frame
		_check(ih - Ei.health.hp == 10, "[Ignore] and it still deals its 10 Affliction (dealt %d)" % (ih - Ei.health.hp))

	# === 10. Toga's S2 Bleed trigger also survives ignore-non-damage ===
	var mg := BattleManager.new()
	mg.name = "BattleManager"
	mg.shadow_mode = true
	add_child(mg)
	var gp1 = _build("ZZ_Toga", ["toga", "gon", "gray"], false)
	var gp2 = _build("ZZ_TogaFoe", ["gon", "misaka", "byakuya"], true)
	mg.random_panel_needed.connect(func(_a, _b, _c): pass)
	mg.start_battle(gp1, gp2, true, 4246, BattleManager.MatchType.BOT)
	var toga = gp1.team.characters[0]; var Eg = gp2.team.characters[0]
	var toga_s2 = toga.moveset.base_abilities[1]
	var ign2 = Effect.ignore_non_damage_effect(6)
	ign2.set_source(Eg.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(Eg, mg), Eg, Eg, ign2)
	Eg.health.hp = 100
	_use(toga, toga_s2, [Eg])
	var gtick = null
	for e in Eg.effects.get_effects_by_type(TT.TICKING_TRIGGER):
		if e.user == toga and e.source == toga_s2:
			gtick = e; break
	_check(gtick != null, "[Ignore] Toga's Twisted-Love Bleed trigger is NOT dropped by ignore-non-damage")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
