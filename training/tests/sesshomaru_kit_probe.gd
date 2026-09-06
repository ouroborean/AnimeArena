extends Node

# Sesshomaru full-kit probe.
#   godot --headless --path . res://training/tests/sesshomaru_kit_probe.tscn

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

func _battle(seed, p1n = ["sesshomaru", "gray", "gon"], p2n = ["misaka", "byakuya", "aang"]):
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

func _install_passive(s, m):
	s.moveset.base_abilities[4].execute(s, m)   # Perfect Daiyoukai (idempotent)

func _ready():
	print("=== sesshomaru kit probe ===")
	var TT = EffectType.Type
	var DT = DamageType.Type

	# ===== BAKUSAIGA: 20 Piercing + Destructive Corrosion =====
	var r = _battle(7001)
	var m = r[0]; var s = r[1].team.characters[0]; var e = r[2].team.characters[0]
	_install_passive(s, m)
	var dc = s.moveset.base_abilities[5]
	e.health.hp = 100
	_use(s, s.moveset.base_abilities[0], [e])
	_check(e.health.hp == 80, "[Bakusaiga] deals 20 Piercing (-> %d)" % e.health.hp)
	_check(e.has_effect("Destructive Corrosion", TT.MARK, s) != null, "[Bakusaiga] applies the Destructive Corrosion mark")
	_check(dc.is_affected(e, s), "[DC] is_affected() true once corroded")
	_check(e.has_effect("Destructive Corrosion", TT.HEALING_RECEIVED_MOD, s) != null, "[DC] heal-reduction rider present")
	_check(e.has_effect("Destructive Corrosion", TT.HEALING_RECEIVED_TRIGGER, s) != null, "[DC] heal-punish rider present")
	_check(e.has_effect("Destructive Corrosion", TT.HEALTH_CHANGE_TRIGGER, s) != null, "[DC] execute watcher present")

	# ===== DC: -10 incoming healing AND 10 Affliction on heal (both fire on one heal) =====
	var hm = e.has_effect("Destructive Corrosion", TT.HEALING_RECEIVED_MOD, s)
	_check(hm != null and hm.mag == -10, "[DC] heal-reduction is a flat -10 (mag=%s)" % (str(hm.mag) if hm else "nil"))
	# --- tooltip shape: mark = execute-only, heal riders visible to the enemy, execute watchers system-hidden ---
	var dcmark = e.has_effect("Destructive Corrosion", TT.MARK, s)
	var mtxt = dcmark.description.call(dcmark) if dcmark else ""
	_check("Executed" in mtxt and not ("reduced by 10" in mtxt), "[DC] the mark describes ONLY the execute (no summary)")
	_check(hm != null and not hm.invisible and not hm.system, "[DC] heal-reduction rider is visible to the enemy")
	var hpr = e.has_effect("Destructive Corrosion", TT.HEALING_RECEIVED_TRIGGER, s)
	_check(hpr != null and not hpr.invisible and not hpr.system, "[DC] heal-punish rider is visible to the enemy")
	var ew = e.has_effect("Destructive Corrosion", TT.HEALTH_CHANGE_TRIGGER, s)
	_check(ew != null and ew.system and not ew.display_system, "[DC] execute watcher is system-hidden (no stray duration chip)")
	e.health.hp = 50
	e.receive_healing(30, e, e.moveset.base_abilities[0])   # 30 heal -> -10 reduce = +20 -> 70 -> -10 punish -> 60
	_check(e.health.hp == 60, "[DC] heal 30 nets +10 (-10 heal-cut then -10 Affliction punish) (-> %d)" % e.health.hp)
	# a heal reduced to 0 NET still fires the 10 Affliction punish (it triggers on being TARGETED by a heal,
	# not the net amount) — and must NOT cause a raw HP-loss inversion from the -10 (only the punish lands)
	e.health.hp = 60
	e.receive_healing(8, e, e.moveset.base_abilities[0])   # 8 - 10 = 0 net -> punish 10 Affliction -> 50 (no raw -2)
	_check(e.health.hp == 50, "[DC] a 0-net heal still fires the 10 Affliction punish, no raw HP-loss inversion (-> %d)" % e.health.hp)
	# and that punish (fired even at 0 net heal) can push a low corroded enemy into the <=20 execute
	e.health.hp = 25
	e.receive_healing(3, e, e.moveset.base_abilities[0])   # 3 - 10 = 0 net -> punish 10 -> 15 -> Executed
	_check(e.dead, "[DC] a 0-net heal's punish can drop a low corroded enemy into the execute")

	# ===== DC: execute at <=20 HP (real HP drop via a hit) =====
	var r2 = _battle(7002)
	var m2 = r2[0]; var s2 = r2[1].team.characters[0]; var e2 = r2[2].team.characters[0]
	_install_passive(s2, m2)
	e2.health.hp = 100
	_use(s2, s2.moveset.base_abilities[0], [e2])   # corrode
	e2.health.hp = 25
	s2.used_ability = s2.moveset.base_abilities[0]
	Character.resolve_damage(QueryContext.from_game_state(s2, m2), e2, 10, DT.NORMAL)   # 25 -> 15 -> execute
	_check(e2.dead, "[DC] a corroded enemy dropped to <=20 HP is Executed")

	# cast-time execute: corroding an already-low enemy kills immediately
	var e2b = r2[2].team.characters[1]
	e2b.health.hp = 12
	s2.moveset.base_abilities[5].apply_corrosion(QueryContext.from_game_state(s2, m2), s2, e2b)
	_check(e2b.dead, "[DC] corroding an enemy already at <=20 HP Executes on application")

	# ===== POISON CLAW: 15 Affliction + DoT; +5 initial while corroded =====
	var r3 = _battle(7003)
	var m3 = r3[0]; var s3 = r3[1].team.characters[0]; var f = r3[2].team.characters[0]
	_install_passive(s3, m3)
	f.health.hp = 100
	_use(s3, s3.moveset.base_abilities[1], [f])   # Poison Claw, no DC yet
	_check(f.health.hp == 85, "[PoisonClaw] 15 Affliction initial with no Corrosion (-> %d)" % f.health.hp)
	var dot = f.has_effect("Poison Claw", TT.DAMAGE, s3)
	_check(dot != null and dot.mag == 10 and dot.damage_type == DT.AFFLICTION, "[PoisonClaw] leaves a 10 Affliction DoT")
	_check(dot != null and dot.duration == 5, "[PoisonClaw] DoT dur 5 = 2 future ticks (dur=%s)" % (str(dot.duration) if dot else "nil"))
	# one manual tick deals 10 (mechanism check; count follows the jack2 convention)
	if dot != null:
		m3.execute_ticking_effect(dot)
		_check(f.health.hp == 75, "[PoisonClaw] a DoT tick deals 10 Affliction (-> %d)" % f.health.hp)
	# +5 initial while corroded
	var f2 = r3[2].team.characters[1]
	f2.health.hp = 100
	_use(s3, s3.moveset.base_abilities[0], [f2])   # Bakusaiga -> corrode
	f2.health.hp = 100
	_use(s3, s3.moveset.base_abilities[1], [f2])   # Poison Claw on corroded
	_check(f2.health.hp == 80, "[PoisonClaw] corroded target takes 20 initial (15+5) (-> %d)" % f2.health.hp)

	# ===== WHIP OF LIGHT: 15 Piercing + Blind; conditional invuln bypass =====
	var r4 = _battle(7004)
	var m4 = r4[0]; var s4 = r4[1].team.characters[0]; var g = r4[2].team.characters[0]; var g2 = r4[2].team.characters[1]
	_install_passive(s4, m4)
	g.health.hp = 100
	_use(s4, s4.moveset.base_abilities[2], [g])
	_check(g.health.hp == 85, "[Whip] deals 15 Piercing (-> %d)" % g.health.hp)
	_check(g.has_effect("Whip of Light", TT.BLIND, s4) != null, "[Whip] Blinds the target")
	# invuln bypass only vs corroded: corrode g2, make BOTH g2 and g invuln, check targetability
	_use(s4, s4.moveset.base_abilities[0], [g2])   # corrode g2
	var inv1 = Effect.invuln_effect(4); inv1.set_source(g.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(g, m4), g, g, inv1)
	var inv2 = Effect.invuln_effect(4); inv2.set_source(g2.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(g2, m4), g2, g2, inv2)
	for c in m4.all_characters(): c.targeted = false
	s4.moveset.base_abilities[2].target(s4, m4)
	_check(g2.targeted and not g.targeted, "[Whip] bypasses Invuln vs a corroded enemy but not a non-corroded one (g2=%s g=%s)" % [str(g2.targeted), str(g.targeted)])
	# against the corroded+invuln enemy, BOTH the 15 damage AND the Blind must land (not just the damage)
	g2.health.hp = 100
	_use(s4, s4.moveset.base_abilities[2], [g2])
	_check(g2.health.hp == 85, "[Whip] damage pierces Invuln on a corroded enemy (-> %d)" % g2.health.hp)
	_check(g2.has_effect("Whip of Light", TT.BLIND, s4) != null, "[Whip] the Blind ALSO pierces Invuln on a corroded enemy")

	# ===== TENSAIGA: self Invulnerability =====
	var r5 = _battle(7005)
	var m5 = r5[0]; var s5 = r5[1].team.characters[0]
	_install_passive(s5, m5)
	_use(s5, s5.moveset.base_abilities[3], [s5])
	_check(s5.has_effect("Tensaiga", TT.INVULN, s5) != null, "[Tensaiga] grants self Invulnerability")

	# ===== PERFECT DAIYOUKAI: stun reduction + cooldown =====
	var r6 = _battle(7006)
	var m6 = r6[0]; var s6 = r6[1].team.characters[0]; var en = r6[2].team.characters[0]
	_install_passive(s6, m6)
	var pd6 = s6.moveset.base_abilities[4]
	# a visible "active" indicator (permanent MARK) is present when ready
	var ready0 = s6.has_effect("Perfect Daiyoukai", TT.MARK, s6)
	_check(ready0 != null and ready0.duration == -1, "[Daiyoukai] shows a permanent 'active' indicator when ready")
	_check(not pd6.stun_on_cooldown(s6), "[Daiyoukai] not on cooldown initially")
	var ctx6 = QueryContext.from_game_state(en, m6)
	# a 2-turn stun (dur 4) is shortened to 1 turn (dur 2)
	var stun1 = Effect.stun_effect(4); stun1.set_source(en.moveset.base_abilities[0])
	Character.add_hostile_effect(ctx6, en, s6, stun1)
	var got1 = s6.has_effect(en.moveset.base_abilities[0].ability_name, TT.STUN, en)
	_check(got1 != null and got1.duration == 2, "[Daiyoukai] a 2-turn stun is shortened to 1 turn (dur %s)" % (str(got1.duration) if got1 else "none"))
	# shortening a stun swaps the indicator to a ticking "recharging" MARK and puts it on cooldown
	_check(pd6.stun_on_cooldown(s6), "[Daiyoukai] on cooldown after shortening a Stun")
	var rc = s6.has_effect("Perfect Daiyoukai", TT.MARK, s6)
	_check(rc != null and rc.duration == 6, "[Daiyoukai] shows a ticking 'recharging' indicator (dur 6 = 3 turns)")
	# cooldown: a second stun immediately is NOT reduced
	var stun2 = Effect.stun_effect(4); stun2.set_source(en.moveset.base_abilities[1])
	Character.add_hostile_effect(ctx6, en, s6, stun2)
	var got2 = s6.has_effect(en.moveset.base_abilities[1].ability_name, TT.STUN, en)
	_check(got2 != null and got2.duration == 4, "[Daiyoukai] a 2nd stun within the cooldown lands at full duration (dur %s)" % (str(got2.duration) if got2 else "none"))
	# after the cooldown clears (recharging indicator gone), a 1-turn stun (dur 2) is fully negated
	var rc2 = s6.has_effect("Perfect Daiyoukai", TT.MARK, s6)
	if rc2 != null: s6.effects.erase_effect(rc2)
	var stun3 = Effect.stun_effect(2); stun3.set_source(en.moveset.base_abilities[2])
	Character.add_hostile_effect(ctx6, en, s6, stun3)
	_check(s6.has_effect(en.moveset.base_abilities[2].ability_name, TT.STUN, en) == null, "[Daiyoukai] a 1-turn stun is reduced to 0 and fully blocked")

	# ===== PERFECT DAIYOUKAI: ignore enemy damage-reducers below 50 HP =====
	var r7 = _battle(7007)
	var m7 = r7[0]; var s7 = r7[1].team.characters[0]; var foe7 = r7[2].team.characters[0]
	_install_passive(s7, m7)
	# enemy debuff: Sesshomaru deals 10 less damage
	var debuff = Effect.damage_mod_effect(-10, -1); debuff.set_source(foe7.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(foe7, m7), foe7, s7, debuff)
	s7.used_ability = s7.moveset.base_abilities[0]
	# HP 100 (>50): debuff applies -> 20 base becomes 10
	s7.health.hp = 100
	s7.moveset.base_abilities[4].on_turn_start(QueryContext.from_effect_end(s7.has_effect("Perfect Daiyoukai", TT.START_OF_TURN_TRIGGER, s7)))
	var dmg_high = s7.moveset.base_abilities[0].get_true_damage(s7, foe7, 20, null, DT.PIERCING)
	_check(dmg_high == 10, "[Daiyoukai] above 50 HP, an enemy damage-reducer applies (20 -> %d)" % dmg_high)
	# HP 50 (<=50): the reducer is ignored -> full 20
	s7.health.hp = 50
	s7.moveset.base_abilities[4].on_turn_start(QueryContext.from_effect_end(s7.has_effect("Perfect Daiyoukai", TT.START_OF_TURN_TRIGGER, s7)))
	_check(s7.has_effect("Perfect Daiyoukai", TT.IGNORE_EFFECT, s7) != null, "[Daiyoukai] at <=50 HP the damage-ignore buff is active")
	var dmg_low = s7.moveset.base_abilities[0].get_true_damage(s7, foe7, 20, null, DT.PIERCING)
	_check(dmg_low == 20, "[Daiyoukai] at <=50 HP the enemy damage-reducer is ignored (full %d)" % dmg_low)
	# back above 50: buff toggles off, reducer applies again
	s7.health.hp = 100
	s7.moveset.base_abilities[4].on_turn_start(QueryContext.from_effect_end(s7.has_effect("Perfect Daiyoukai", TT.START_OF_TURN_TRIGGER, s7)))
	_check(s7.has_effect("Perfect Daiyoukai", TT.IGNORE_EFFECT, s7) == null, "[Daiyoukai] healed above 50 HP -> damage-ignore toggles off (two-way)")

	# ===== Destructive Corrosion is not castable =====
	_check(dc.extra_usable(s) == false, "[DC] Destructive Corrosion is not usable from the kit")

	print("=== sesshomaru kit probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
