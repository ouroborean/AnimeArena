extends Node

# Balance patch 2 probe: Frankenstein (Galvanism +5 to Bridal Chest/Rampage), King (Chastifold cost),
# Impmon (Warp threshold 60, Badaboom 2-turn DoT), Venus (Burning Love consume-heal).
#   godot --headless --path . res://training/tests/balance_patch2_probe.tscn

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

func _battle(seed, p1n, p2n):
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
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

func _ready():
	print("=== balance patch 2 probe ===")
	var TT = EffectType.Type
	var FOE = ["gon", "misaka", "byakuya"]

	# ===== FRANKENSTEIN: Galvanism +5 to Bridal Chest / Bridal Rampage =====
	var rf = _battle(5001, ["frankenstein", "gray", "gon"], FOE)
	var mf = rf[0]; var frank = rf[1].team.characters[0]; var fe = rf[2].team.characters[0]
	var chest = frank.moveset.base_abilities[0]
	var rampage = frank.moveset.base_abilities[1]
	var galv = frank.moveset.base_abilities[3]
	fe.health.hp = 100
	_use(frank, chest, [fe])
	_check(fe.health.hp == 80, "[Frank] Bridal Chest deals 20 without Galvanism (-> %d)" % fe.health.hp)
	frank.targeter.targets = [frank]; frank.used_ability = galv
	galv.execute(frank, mf)
	_check(frank.marked_by("Galvanism", frank) != null, "[Frank] Galvanism mark active")
	fe.health.hp = 100
	_use(frank, chest, [fe])
	_check(fe.health.hp == 75, "[Frank] Bridal Chest deals 25 during Galvanism (-> %d)" % fe.health.hp)
	var fe2 = rf[2].team.characters[1]; fe2.health.hp = 100
	frank.targeter.targets = rf[2].team.characters; frank.targeter.main_target = fe2; frank.used_ability = rampage
	rampage.execute(frank, mf)
	_check(fe2.health.hp == 75, "[Frank] Bridal Rampage AoE deals 25 during Galvanism (-> %d)" % fe2.health.hp)

	# ===== KING: True Spirit Spear Chastifold cost 1 Blue 1 Random =====
	var rk = _battle(5002, ["king", "gray", "gon"], FOE)
	var chastifold = rk[1].team.characters[0].moveset.base_abilities[2]
	var kc = chastifold.cost()
	_check(kc.get(Energy.Type.BLUE, 0) == 1 and kc.get(Energy.Type.RANDOM, 0) == 1 and kc.get(Energy.Type.RED, 0) == 0,
		"[King] Chastifold costs 1 Blue + 1 Random (blue=%d red=%d rand=%d)" % [kc.get(Energy.Type.BLUE,0), kc.get(Energy.Type.RED,0), kc.get(Energy.Type.RANDOM,0)])

	# ===== IMPMON: Warp threshold 60, Badaboom 2-turn DoT =====
	var ri = _battle(5003, ["impmon", "gray", "gon"], FOE)
	var mi = ri[0]; var impmon = ri[1].team.characters[0]; var ie = ri[2].team.characters[0]
	var warp = impmon.moveset.base_abilities[2]
	impmon.health.hp = 60
	_check(warp.extra_usable(impmon), "[Impmon] Warp Digivolve usable at 60 HP")
	impmon.health.hp = 61
	_check(not warp.extra_usable(impmon), "[Impmon] Warp Digivolve NOT usable at 61 HP")
	var bada = impmon.moveset.base_abilities[0]
	ie.health.hp = 100
	impmon.targeter.targets = [ie]; impmon.targeter.main_target = ie; impmon.used_ability = bada
	bada.execute(impmon, mi)
	_check(ie.health.hp == 90, "[Impmon] Badaboom deals 10 immediately (-> %d)" % ie.health.hp)
	var idot = null
	for e in ie.effects.get_effects_by_type(TT.DAMAGE):
		if e.user == impmon and e.damage_type == DamageType.Type.ENERGY:
			idot = e; break
	_check(idot != null, "[Impmon] Badaboom leaves a lingering DoT (2 turns)")
	if idot != null:
		var ih = ie.health.hp
		idot.duration = 1
		mi.execute_ticking_effect(idot)
		await get_tree().process_frame
		_check(ih - ie.health.hp == 10, "[Impmon] Badaboom DoT ticks 10 (dealt %d)" % (ih - ie.health.hp))

	# ===== VENUS: consuming Burning Love stacks heals 10 + 5/stack =====
	var rv = _battle(5004, ["venus", "gray", "gon"], FOE)
	var mv = rv[0]; var venus = rv[1].team.characters[0]; var ve = rv[2].team.characters[0]
	var vpassive = venus.moveset.base_abilities[4]
	var vshock = venus.moveset.base_abilities[0]
	var qc = QueryContext.from_game_state(venus, mv)
	for i in range(3):   # mirror three Harmful-skill procs -> 3 stacks of Venus Burning Love
		var boost = Effect.damage_mod_effect(5, -1)
		boost.set_source(vpassive)
		boost.stackable = true
		boost.stack_mag = true
		boost.display_stacks = true
		Character.add_allied_effect(qc, venus, venus, boost)
	var bl = venus.has_effect("Venus Burning Love", TT.DAMAGE_MOD)
	_check(bl != null and bl.stack_count() == 3, "[Venus] 3 stacks of Venus Burning Love built")
	venus.health.hp = 50
	ve.health.hp = 100
	_use(venus, vshock, [ve])
	_check(venus.health.hp == 75, "[Venus] consuming 3 stacks heals 10 + 5*3 = 25 (50 -> %d)" % venus.health.hp)
	_check(venus.has_effect("Venus Burning Love", TT.DAMAGE_MOD) == null, "[Venus] the stacks were consumed")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
