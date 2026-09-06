extends Node

# Kishou Arima full-kit probe.
#   godot --headless --path . res://training/tests/arima_kit_probe.tscn

var fails := 0
func _check(c, l, detail := ""):
	if c: print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l + ("  (" + detail + ")" if detail != "" else ""))

func _build(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	for n in names: p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _battle(seed, p1n = ["arima", "gray", "gon"], p2n = ["misaka", "byakuya", "aang"]):
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 = _build("ZZ_A" + str(seed), p1n, false)
	var p2 = _build("ZZ_B" + str(seed), p2n, true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, seed, BattleManager.MatchType.BOT)
	return [m, p1, p2]

func _use(actor, ability, targets):
	actor.targeter.targets = targets
	actor.targeter.main_target = targets[0] if targets.size() > 0 else null
	actor.used_ability = ability
	ability.execute(actor, actor.battle)

func _install_passive(arima, m):
	arima.moveset.base_abilities[4].execute(arima, m)   # SSS Ukaku Quinque (idempotent)

func _counter(arima) -> int:
	var c = arima.has_effect("SSS Ukaku Quinque", EffectType.Type.MARK, arima)
	return c.stack_count() if c else -1

func _ready():
	print("=== arima kit probe ===")
	var TT = EffectType.Type
	var DT = DamageType.Type

	# ===== PASSIVE: install + skill counter =====
	var r = _battle(6001)
	var m = r[0]; var arima = r[1].team.characters[0]; var e0 = r[2].team.characters[0]
	_install_passive(arima, m)
	_check(_counter(arima) == 0, "[Passive] skills-used counter installed at 0 (-> %d)" % _counter(arima))
	arima.targeter.targets = []; arima.check_ability_use_triggers(m, arima.moveset.base_abilities[0])
	_check(_counter(arima) == 1, "[Passive] counter increments on a skill use (-> %d)" % _counter(arima))
	# every 3rd skill -> Owl Slash swaps over slot 0
	arima.check_ability_use_triggers(m, arima.moveset.base_abilities[0])
	arima.check_ability_use_triggers(m, arima.moveset.base_abilities[0])   # now 3
	var slot0 = arima.moveset.get_active_abilities(arima)[0]
	_check(_counter(arima) == 3 and slot0.ability_name == "Owl Slash", "[Passive] every 3rd skill swaps Owl Slash over slot 0 (slot0=%s)" % slot0.ability_name)

	# ===== NARUKAMI SWORD: damage + charge =====
	var r2 = _battle(6002)
	var m2 = r2[0]; var ar = r2[1].team.characters[0]; var en = r2[2].team.characters[0]
	_install_passive(ar, m2)
	var sword = ar.moveset.base_abilities[0]
	en.health.hp = 100
	_use(ar, sword, [en])
	_check(en.health.hp == 85, "[Sword] deals 15 (-> %d)" % en.health.hp)
	var charge = ar.has_effect("Narukami Charge", TT.MARK, ar)
	_check(charge != null and charge.stack_count() == 1, "[Sword] adds 1 Narukami Charge")
	_use(ar, sword, [en])
	charge = ar.has_effect("Narukami Charge", TT.MARK, ar)
	_check(charge.stack_count() == 2, "[Sword] Narukami Charge stacks to 2")

	# ===== NARUKAMI BLAST: channel + reactive watcher + charge consume =====
	var blast = ar.moveset.base_abilities[1]
	en.health.hp = 100
	# give enemy a shield to prove Blast destroys it
	var esh = Effect.shield_effect(30, -1); esh.set_source(en.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(en, m2), en, en, esh)
	_use(ar, blast, [en])
	_check(ar.has_effect("Narukami Blast", TT.CHANNEL_CANCEL, ar) != null, "[Blast] channel started on Arima")
	_check(en.has_effect("Narukami Blast", TT.ACTION_USE_TRIGGER, ar) != null, "[Blast] reactive watcher planted on the enemy")
	var wtc = en.has_effect("Narukami Blast", TT.ACTION_USE_TRIGGER, ar)
	_check("30 damage" in wtc.description.call(wtc), "[Blast] watcher tooltip states the actual damage (20 + 10 charge)")
	_check(ar.has_effect("Narukami Charge", TT.MARK, ar) == null, "[Blast] consumed the Narukami Charge (2 stacks -> +10)")
	# enemy uses a skill -> watcher fires: shatter shield + 20 + 10(charge)
	en.check_ability_use_triggers(m2, en.moveset.base_abilities[0])
	_check(en.get_shield_effects().size() == 0, "[Blast] enemy skill destroyed their Shield")
	_check(en.health.hp == 70, "[Blast] reactive hit deals 20 + 10 charge = 30 (100 -> %d)" % en.health.hp)
	# "ignore non-damage while channeling" present AND visible (doubles as the warning tooltip)
	_check(ar.has_effect("SSS Ukaku Quinque", TT.IGNORE_NON_DAMAGE, ar) != null, "[Blast] Arima ignores non-damage while channeling")
	_check(ar.has_effect("SSS Ukaku Quinque", TT.IGNORE_NON_DAMAGE, ar).display_system, "[Blast] the ignore-non-damage warning is visible")

	# ===== NARUKAMI SWORD cancels an active Narukami Blast -> 15 Shield =====
	var pre_shield = 0
	for s in ar.get_shield_effects(): pre_shield += s.mag
	ar.cancel_channels()   # the real pre-execute step: Sword is a normal skill, cancels the Blast channel
	_use(ar, sword, [en])
	_check(ar.has_effect("Narukami Blast", TT.CHANNEL_CANCEL, ar) == null, "[Sword] cancels the active Narukami Blast channel")
	var post_shield = 0
	for s in ar.get_shield_effects(): post_shield += s.mag
	_check(post_shield - pre_shield == 15, "[Sword] +15 Shield for cancelling Blast (gained %d)" % (post_shield - pre_shield))
	_check(ar.has_effect("SSS Ukaku Quinque", TT.IGNORE_NON_DAMAGE, ar) == null, "[Sword] channel teardown removed the ignore-non-damage")

	# ===== IXA SHIELD (directional immunity) + engine edit =====
	var r3 = _battle(6003)
	var m3 = r3[0]; var a3 = r3[1].team.characters[0]; var foe = r3[2].team.characters[0]; var foe2 = r3[2].team.characters[1]
	_install_passive(a3, m3)
	var ixashield = a3.moveset.base_abilities[3]
	_use(a3, ixashield, [foe])
	_check(a3.has_effect("Ixa Shield", TT.CHANNEL_CANCEL, a3) != null, "[IxaShield] channel started")
	_check(foe.has_effect("Ixa Shield", TT.MARK, a3) != null, "[IxaShield] marks the ignored enemy so the other side can see whose damage is shrugged")
	var ixa_ig = a3.has_effect("SSS Ukaku Quinque", TT.IGNORE_NON_DAMAGE, a3)
	_check(ixa_ig != null and ixa_ig.display_system, "[IxaShield] ignore-non-damage warning is visible while channeling")
	# damage from the shielded-against enemy is ignored; damage from another enemy lands
	a3.health.hp = 100
	foe.used_ability = foe.moveset.base_abilities[0]
	Character.resolve_damage(QueryContext.from_game_state(foe, m3), a3, 20, DT.NORMAL)
	_check(a3.health.hp == 100, "[IxaShield] ignores ALL damage from the target enemy (-> %d)" % a3.health.hp)
	foe2.used_ability = foe2.moveset.base_abilities[0]
	Character.resolve_damage(QueryContext.from_game_state(foe2, m3), a3, 20, DT.NORMAL)
	_check(a3.health.hp == 80, "[IxaShield] still takes damage from OTHER enemies (-> %d)" % a3.health.hp)

	# ===== IXA PARRY: invuln + mark; cancels Ixa Shield -> ignore all harmful =====
	var parry = a3.moveset.base_abilities[2]
	a3.cancel_channels()   # the real pre-execute step: Parry is a normal skill, cancels the Ixa Shield channel
	_use(a3, parry, [a3])
	_check(a3.is_invuln(parry) or a3.has_effect("Ixa Parry", TT.INVULNERABILITY, a3) != null, "[Parry] grants Invulnerability")
	_check(a3.marked_by("Ixa Parry", a3) != null, "[Parry] leaves the 'used Ixa Parry' mark")
	# Ixa Shield was cancelled by Parry -> ignore all harmful (ignore_damage + ignore_non_damage)
	_check(a3.has_effect("Ixa Shield", TT.CHANNEL_CANCEL, a3) == null, "[Parry] cancelled the active Ixa Shield channel")
	_check(a3.get_effects_by_type(TT.IGNORE_DAMAGE).size() > 0 and a3.get_effects_by_type(TT.IGNORE_NON_DAMAGE).size() > 0, "[Parry] cancelling Ixa Shield grants ignore-all-harmful")

	# ===== IXA SHIELD after IXA PARRY -> team 75% DR =====
	# Parry mark is present (just cast). Use Ixa Shield -> team percent_dr instead of channel.
	_use(a3, ixashield, [foe])
	var team_dr = true
	for ally in a3.team.characters:
		if ally.get_effects_by_type(TT.PERCENT_DR).size() == 0: team_dr = false
	_check(team_dr, "[IxaShield] used after Ixa Parry gives the whole team percent DR")
	_check(a3.has_effect("Ixa Shield", TT.CHANNEL_CANCEL, a3) == null, "[IxaShield] team-DR variant does NOT start a channel")

	# ===== OWL SLASH: scaling + overkill -> permanent Shield =====
	var r4 = _battle(6004)
	var m4 = r4[0]; var a4 = r4[1].team.characters[0]; var v = r4[2].team.characters[0]
	_install_passive(a4, m4)
	var owlslash = a4.moveset.base_abilities[5]
	v.health.hp = 10   # 35 base kills with 25 overkill
	var pre_sh = 0
	for s in a4.get_shield_effects(): pre_sh += s.mag
	_use(a4, owlslash, [v])
	_check(v.dead or v.health.hp == 0, "[OwlSlash] 35 Piercing kills the 10-HP target")
	var gained = 0
	for s in a4.get_shield_effects(): gained += s.mag
	_check(gained - pre_sh == 25, "[OwlSlash] overkill (35-10=25) becomes permanent Shield (gained %d)" % (gained - pre_sh))
	# a SURVIVING target grants no overkill Shield
	var v2 = r4[2].team.characters[1]; v2.health.hp = 100
	var shb = 0
	for s in a4.get_shield_effects(): shb += s.mag
	_use(a4, owlslash, [v2])
	var sha = 0
	for s in a4.get_shield_effects(): sha += s.mag
	_check(not v2.dead and sha == shb, "[OwlSlash] a surviving target grants NO overkill Shield")
	# a target IGNORING damage takes 0 and grants no overkill Shield
	var v3 = r4[2].team.characters[2]; v3.health.hp = 5
	var ig = Effect.ignore_damage_effect(2); ig.set_source(v3.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(v3, m4), v3, v3, ig)
	var shb2 = 0
	for s in a4.get_shield_effects(): shb2 += s.mag
	_use(a4, owlslash, [v3])
	var sha2 = 0
	for s in a4.get_shield_effects(): sha2 += s.mag
	_check(not v3.dead and sha2 == shb2, "[OwlSlash] a target ignoring damage takes 0 and grants NO overkill Shield")

	# ===== OWL FINISHER: execute + ally energy + targeting =====
	var r5 = _battle(6005)
	var m5 = r5[0]; var a5 = r5[1].team.characters[0]; var ally = r5[1].team.characters[1]; var foeF = r5[2].team.characters[0]; var healthy = r5[2].team.characters[1]
	_install_passive(a5, m5)
	var finisher = a5.moveset.base_abilities[6]
	# targeting: only <=15 HP enemy/ally selectable (not healthy, not self)
	foeF.health.hp = 15; ally.health.hp = 15; healthy.health.hp = 100; a5.health.hp = 15
	for c in m5.all_characters(): c.targeted = false
	finisher.target(a5, m5)
	_check(foeF.targeted and ally.targeted and not healthy.targeted and not a5.targeted, "[Finisher] targets <=15 HP enemy + non-self ally, not healthy, not self")
	# execute an enemy
	_use(a5, finisher, [foeF])
	_check(foeF.dead, "[Finisher] executes the <=15 HP enemy")
	# execute an ally -> +2 Red energy
	var red_before = a5.team.energy.pool.get(Energy.Type.RED, 0)
	_use(a5, finisher, [ally])
	_check(ally.dead, "[Finisher] executes the <=15 HP ally")
	var red_after = a5.team.energy.pool.get(Energy.Type.RED, 0)
	_check(red_after - red_before == 2, "[Finisher] ally execution grants Arima 2 Red energy (%d -> %d)" % [red_before, red_after])

	# ===== PASSIVE: Owl Finisher two-way conditional swap (novel toggle) =====
	var r6 = _battle(6006)
	var a6 = r6[1].team.characters[0]; var lowfoe = r6[2].team.characters[0]
	_install_passive(a6, r6[0])
	var passive6 = a6.moveset.base_abilities[4]
	passive6._do_finisher_swap(a6)   # nobody <=15
	_check(a6.moveset.get_active_abilities(a6)[2].ability_name == "Ixa Parry", "[Passive] slot 2 is Ixa Parry when nobody is <=15 HP")
	lowfoe.health.hp = 15
	passive6._do_finisher_swap(a6)   # an enemy is now <=15
	_check(a6.moveset.get_active_abilities(a6)[2].ability_name == "Owl Finisher", "[Passive] Owl Finisher swaps over slot 2 while a character is <=15 HP")
	lowfoe.health.hp = 50
	passive6._do_finisher_swap(a6)   # healed above 15 -> reverts
	_check(a6.moveset.get_active_abilities(a6)[2].ability_name == "Ixa Parry", "[Passive] reverts to Ixa Parry once nobody is <=15 HP (two-way toggle)")
	# a SOLO-low Arima must keep Ixa Parry (Owl Finisher can't target himself)
	a6.health.hp = 10
	passive6._do_finisher_swap(a6)
	_check(a6.moveset.get_active_abilities(a6)[2].ability_name == "Ixa Parry", "[Passive] a solo-low Arima keeps Ixa Parry (Owl Finisher can't target self)")

	# ===== Sword/Parry are NORMAL skills: cancel ANY channel, bonus ONLY on the named partner =====
	var r7 = _battle(6007)
	var m7 = r7[0]; var a7 = r7[1].team.characters[0]; var f7 = r7[2].team.characters[0]
	_install_passive(a7, m7)
	_use(a7, a7.moveset.base_abilities[3], [f7])   # start an Ixa Shield channel
	_check(a7.has_effect("Ixa Shield", TT.CHANNEL_CANCEL, a7) != null, "[SwordCancel] setup: Ixa Shield channeling")
	var sh_pre = 0
	for s in a7.get_shield_effects(): sh_pre += s.mag
	a7.cancel_channels(); _use(a7, a7.moveset.base_abilities[0], [f7])   # cast Narukami Sword
	_check(a7.has_effect("Ixa Shield", TT.CHANNEL_CANCEL, a7) == null, "[SwordCancel] a normal Sword cast cancels a NON-partner Ixa Shield channel too")
	var sh_post = 0
	for s in a7.get_shield_effects(): sh_post += s.mag
	_check(sh_post == sh_pre, "[SwordCancel] cancelling a NON-partner channel grants NO 15 Shield")

	# ===== A cleanse/buff-strip of the channeler tears down the enemy-side riders (no stranded watcher) =====
	var r8 = _battle(6008)
	var m8 = r8[0]; var a8 = r8[1].team.characters[0]; var f8 = r8[2].team.characters[0]
	_install_passive(a8, m8)
	_use(a8, a8.moveset.base_abilities[1], [f8])   # Narukami Blast channel -> watcher on f8
	_check(a8.has_effect("Narukami Blast", TT.CHANNEL_CANCEL, a8) != null, "[Cleanse] setup: Blast channel up")
	_check(f8.has_effect("Narukami Blast", TT.ACTION_USE_TRIGGER, a8) != null, "[Cleanse] setup: watcher planted on enemy")
	a8.effects.cleanse_all_ally_effects(a8, f8)   # enemy buff-strips Arima -> removes the channel master
	_check(a8.has_effect("Narukami Blast", TT.CHANNEL_CANCEL, a8) == null, "[Cleanse] buff-strip removes the channel master")
	_check(f8.has_effect("Narukami Blast", TT.ACTION_USE_TRIGGER, a8) == null, "[Cleanse] the enemy-side watcher is torn down, not stranded")
	# Ixa Shield's enemy tag is likewise torn down when its master is cleansed.
	var r9 = _battle(6009)
	var m9 = r9[0]; var a9 = r9[1].team.characters[0]; var f9 = r9[2].team.characters[0]
	_install_passive(a9, m9)
	_use(a9, a9.moveset.base_abilities[3], [f9])   # Ixa Shield channel -> tag on f9
	_check(f9.has_effect("Ixa Shield", TT.MARK, a9) != null, "[Cleanse] setup: Ixa Shield tags the enemy")
	a9.effects.cleanse_all_ally_effects(a9, f9)
	_check(f9.has_effect("Ixa Shield", TT.MARK, a9) == null, "[Cleanse] Ixa Shield's enemy tag is torn down with the cleansed channel")

	print("=== arima kit probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
