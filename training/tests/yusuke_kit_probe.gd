extends Node

# Yusuke Urameshi kit probe. Covers the stack->transform system, Mega Spirit Gun True damage, Spirit
# Fist silence/drain, Spirit Charge (DR + empower + stack), and every Empowered bonus.
#   godot --headless --path . res://training/tests/yusuke_kit_probe.tscn

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
	var p1 = _build("ZZ_A" + str(seed), ["yusuke", "gray", "aang"], false)
	var p2 = _build("ZZ_B" + str(seed), ["gon", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, seed, BattleManager.MatchType.BOT)
	return [m, p1, p2]

func _use(actor, ability, targets):
	actor.targeter.targets = targets
	actor.targeter.main_target = targets[0] if targets.size() > 0 else null
	actor.used_ability = ability
	ability.execute(actor, actor.battle)

func _ready():
	print("=== yusuke kit probe ===")
	var TT = EffectType.Type
	var DT = DamageType.Type

	var r = _battle(9001)
	var m = r[0]; var y = r[1].team.characters[0]
	var e0 = r[2].team.characters[0]
	var sg = y.moveset.base_abilities[0]
	var mega = y.moveset.base_abilities[4]

	# === 1. Spirit Gun: scaling + 2-stack transform ===
	e0.health.hp = 100
	_use(y, sg, [e0])
	_check(e0.health.hp == 80, "[SG] first cast deals 20 (-> %d)" % e0.health.hp)
	_check(y.call_unique("yusuke", "spirit_gun_stacks", []) == 1, "[SG] +1 Spirit Gun stack")
	e0.health.hp = 100
	_use(y, sg, [e0])
	_check(e0.health.hp == 70, "[SG] second cast deals 30 (+10/stack) (-> %d)" % e0.health.hp)
	_check(y.call_unique("yusuke", "spirit_gun_stacks", []) == 2, "[SG] 2 Spirit Gun stacks")
	_check(y.has_effect("Spirit Gun", TT.DAMAGE_MOD, y) != null, "[SG] stacks are a DAMAGE_MOD, not a mark")
	_check(y.has_effect("Spirit Gun", TT.MARK, y) == null, "[SG] no leftover Spirit Gun mark")
	_check(y.has_effect("Mega Mode", TT.ABILITY_SWAP, y) != null, "[SG] transforms at 2 stacks")
	_check(y.moveset.get_active_abilities(y)[0].ability_name == "Mega Spirit Gun", "[SG] slot 0 now displays Mega Spirit Gun")

	# === 2. Mega Spirit Gun: True damage (ignores DR) + capped stack ===
	e0.health.hp = 100
	var dr = Effect.damage_reduction_effect(50, 3); dr.set_source(mega)
	Character.add_allied_effect(QueryContext.from_game_state(e0, m), e0, e0, dr)
	_use(y, mega, [e0])
	_check(e0.health.hp == 80, "[MSG] deals 20 True through 50 DR (-> %d)" % e0.health.hp)
	_check(y.call_unique("yusuke", "mega_spirit_gun_stacks", []) == 1, "[MSG] +1 Mega stack")
	e0.health.hp = 100
	_use(y, mega, [e0])
	_check(e0.health.hp == 60, "[MSG] second cast deals 40 (+20/stack) (-> %d)" % e0.health.hp)
	_check(y.call_unique("yusuke", "mega_spirit_gun_stacks", []) == 1, "[MSG] Mega stacks cap at 1")
	_check(y.has_effect("Mega Spirit Gun", TT.DAMAGE_MOD, y) != null, "[MSG] Mega stack is a DAMAGE_MOD, not a mark")

	# === 3. Spirit Fist: silence, then drain on re-hit ===
	var r2 = _battle(9002)
	var m2 = r2[0]; var y2 = r2[1].team.characters[0]; var t = r2[2].team.characters[0]
	var fist = y2.moveset.base_abilities[1]
	t.health.hp = 100
	_use(y2, fist, [t])
	_check(t.health.hp == 90, "[Fist] deals 10 (-> %d)" % t.health.hp)
	_check(t.has_effect("Spirit Fist", TT.SILENCE, y2) != null, "[Fist] Silences the target")
	var eteam = r2[2].team
	eteam.energy.change_energy(0, 3); eteam.energy.change_energy(1, 3)
	var before = eteam.energy.total_available()
	t.health.hp = 100
	_use(y2, fist, [t])
	_check(eteam.energy.total_available() == before - 1, "[Fist] re-hit on Silenced enemy drains 1 energy (%d -> %d)" % [before, eteam.energy.total_available()])
	_check(t.health.hp == 90, "[Fist] re-hit still deals its 10 (-> %d)" % t.health.hp)

	# === 4. Spirit Charge: 35% DR + Empowered + active-gun stack ===
	var r3 = _battle(9003)
	var m3 = r3[0]; var y3 = r3[1].team.characters[0]
	var charge = y3.moveset.base_abilities[3]
	y3.targeter.targets = [y3]; y3.targeter.main_target = y3; y3.used_ability = charge
	charge.execute(y3, m3)
	_check(y3.get_effects_by_type(TT.PERCENT_DR).size() >= 1, "[Charge] grants percent Damage Reduction")
	_check(y3.marked_by("Empowered", y3) != null, "[Charge] grants Empowered")
	_check(y3.call_unique("yusuke", "spirit_gun_stacks", []) == 1, "[Charge] banks 1 Spirit Gun stack (active gun)")

	# === 5. Empowered bonuses ===
	# 5a: Spirit Gun -> Piercing (ignores flat DR). At 0 stacks, empowered SG deals full 20 through 10 DR
	# (a NORMAL hit would be reduced to 10). Grant Empowered directly so Spirit Charge's stack doesn't
	# change the base damage.
	var r4 = _battle(9004)
	var m4 = r4[0]; var y4 = r4[1].team.characters[0]; var f0 = r4[2].team.characters[0]
	var sg4 = y4.moveset.base_abilities[0]
	var fdr = Effect.damage_reduction_effect(10, 5); fdr.set_source(sg4)
	Character.add_allied_effect(QueryContext.from_game_state(f0, m4), f0, f0, fdr)
	var emp = Effect.mark(-1, ""); emp.name_override = "Empowered"; emp.set_source(y4.moveset.base_abilities[3])
	Character.add_allied_effect(QueryContext.from_game_state(y4, m4), y4, y4, emp)
	f0.health.hp = 100
	_use(y4, sg4, [f0])
	_check(f0.health.hp == 80, "[Emp] empowered Spirit Gun Pierces flat DR: full 20, not 10 (-> %d)" % f0.health.hp)
	_check(y4.marked_by("Empowered", y4) == null, "[Emp] Empowered consumed by one Harmful skill")

	# 5b: Spirit Fist empowered -> strikes twice, self-combos (silence from hit 1, drain from hit 2), Silence dur 4
	var r5 = _battle(9005)
	var m5 = r5[0]; var y5 = r5[1].team.characters[0]; var f1 = r5[2].team.characters[0]
	var eteam5 = r5[2].team
	var fist5 = y5.moveset.base_abilities[1]; var charge5 = y5.moveset.base_abilities[3]
	y5.targeter.targets = [y5]; y5.used_ability = charge5; charge5.execute(y5, m5)
	eteam5.energy.change_energy(0, 3); eteam5.energy.change_energy(1, 3)
	var e_before5 = eteam5.energy.total_available()
	f1.health.hp = 100
	_use(y5, fist5, [f1])
	_check(f1.health.hp == 80, "[Emp] empowered Spirit Fist strikes twice for 20 (-> %d)" % f1.health.hp)
	var sil = f1.has_effect("Spirit Fist", TT.SILENCE, y5)
	_check(sil != null and sil.duration == 3, "[Emp] Silence stays dur 3 even when Empowered (from hit 1) (-> %s)" % (str(sil.duration) if sil else "none"))
	_check(eteam5.energy.total_available() == e_before5 - 1, "[Emp] empowered Spirit Fist self-combos: hit 2 drains 1 energy (%d -> %d)" % [e_before5, eteam5.energy.total_available()])

	# 5c: Spirit Shotgun empowered -> stun primary
	var r6 = _battle(9006)
	var m6 = r6[0]; var y6 = r6[1].team.characters[0]
	var g0 = r6[2].team.characters[0]; var g1 = r6[2].team.characters[1]
	var shot = y6.moveset.base_abilities[2]; var charge6 = y6.moveset.base_abilities[3]
	y6.targeter.targets = [y6]; y6.used_ability = charge6; charge6.execute(y6, m6)
	for gg in r6[2].team.characters: gg.health.hp = 100
	y6.targeter.targets = r6[2].team.characters; y6.targeter.main_target = g0; y6.used_ability = shot
	shot.execute(y6, m6)
	_check(g0.has_effect("Spirit Shotgun", TT.STUN, y6) != null, "[Emp] empowered Spirit Shotgun stuns the primary target")
	_check(g1.has_effect("Spirit Shotgun", TT.STUN, y6) == null, "[Emp] non-primary target is NOT stunned")

	# 5d: Mega Spirit Gun empowered -> bypasses Invulnerability (at targeting)
	var r7 = _battle(9007)
	var m7 = r7[0]; var y7 = r7[1].team.characters[0]; var iv = r7[2].team.characters[0]
	# force Mega mode: two Spirit Gun stacks via two casts
	var sg7 = y7.moveset.base_abilities[0]; var mega7 = y7.moveset.base_abilities[4]; var charge7 = y7.moveset.base_abilities[3]
	iv.health.hp = 100; _use(y7, sg7, [iv]); iv.health.hp = 100; _use(y7, sg7, [iv])
	# make the enemy invulnerable
	var invuln = Effect.invuln_effect(4); invuln.set_source(charge7)
	Character.add_allied_effect(QueryContext.from_game_state(iv, m7), iv, iv, invuln)
	# target() sets each valid target's `targeted` flag (it does NOT populate targeter.targets), so clear
	# the flags and read iv.targeted after each call.
	# without empowered: iv (Invulnerable) must NOT become targetable
	for c in m7.all_characters(): c.targeted = false
	mega7.target(y7, m7)
	var hit_without = iv.targeted
	# empower, then target(): iv should now be targetable
	y7.targeter.targets = [y7]; y7.used_ability = charge7; charge7.execute(y7, m7)
	for c in m7.all_characters(): c.targeted = false
	mega7.target(y7, m7)
	var hit_with = iv.targeted
	_check(not hit_without, "[Emp] Mega Spirit Gun cannot target Invulnerable without Empowered")
	_check(hit_with, "[Emp] empowered Mega Spirit Gun targets through Invulnerability")

	# === 6. Permanent stacks + transform survive Yusuke's own death cleanse (revive must not reset him) ===
	var r8 = _battle(9008)
	var m8 = r8[0]; var y8 = r8[1].team.characters[0]; var e8 = r8[2].team.characters[0]
	var sg8 = y8.moveset.base_abilities[0]; var mega8 = y8.moveset.base_abilities[4]
	e8.health.hp = 100; _use(y8, sg8, [e8]); e8.health.hp = 100; _use(y8, sg8, [e8])   # 2 SG stacks -> transform
	e8.health.hp = 100; _use(y8, mega8, [e8])   # 1 Mega stack
	_check(y8.call_unique("yusuke", "spirit_gun_stacks", []) == 2 and y8.has_effect("Mega Mode", TT.ABILITY_SWAP, y8) != null, "[Death] pre-death: 2 SG stacks + transform present")
	y8.die(e8, e8.moveset.base_abilities[0])
	_check(y8.call_unique("yusuke", "spirit_gun_stacks", []) == 2, "[Death] Spirit Gun stacks survive the death cleanse")
	_check(y8.call_unique("yusuke", "mega_spirit_gun_stacks", []) == 1, "[Death] Mega Spirit Gun stack survives the death cleanse")
	_check(y8.has_effect("Mega Mode", TT.ABILITY_SWAP, y8) != null, "[Death] the Mega Mode transform survives the death cleanse")

	# === 7. Empowered never duplicates (double Spirit Charge with no Harmful skill between) ===
	var r9 = _battle(9009)
	var m9 = r9[0]; var y9 = r9[1].team.characters[0]
	var charge9 = y9.moveset.base_abilities[3]
	y9.targeter.targets = [y9]; y9.used_ability = charge9; charge9.execute(y9, m9)
	y9.targeter.targets = [y9]; y9.used_ability = charge9; charge9.execute(y9, m9)
	var emps = 0
	for e in y9.effects.get_effects_by_type(TT.MARK):
		if e.effect_name() == "Empowered" and e.user == y9:
			emps += 1
	_check(emps == 1, "[Emp] double Spirit Charge yields exactly ONE Empowered, no leak (got %d)" % emps)

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
