extends Node
# DEEPER Mash Burnedead test: real-turn timing + death survival that the unit probe can't reach.
# Chiefly proves the tuned Big Bang Dash enhancement (mark dur 3) is STILL active on Mash's NEXT
# actionable turn and gone the turn after, by advancing actual turns; plus that the permanent Muscle
# Magic machinery survives the death-cleanse, and drain immunity works through Character.lose_energy.
#   godot --headless --path <repo> res://training/tests/mashburnedead_integration_probe.tscn

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

func _fresh() -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["mashburnedead", "naruto", "sakura"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "gray"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)   # first=true -> Mash (p1) acts turn 1
	return {"m": m, "mash": p1.team.characters[0], "foes": p2.team.characters}

func _cast(m, caster, ab, targets):
	caster.used_ability = ab
	caster.targeter.targets = targets.duplicate()
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	m.execute_ability(ab)

func _end_turn(m):
	m.end_of_turn_effect_handling()

func _bbd_mark(mash):
	return mash.has_effect("Big Bang Dash", EffectType.Type.MARK, mash)

func _shield_total(c) -> int:
	var t := 0
	for s in c.get_shield_effects(): t += int(s.mag)
	return t

func _pool_sum(c) -> int:
	var t := 0
	for v in c.team.energy.pool.values(): t += int(v)
	return t

func _shield_on(target, m, mag):
	var sh = Effect.shield_effect(mag, -1)
	sh.set_source(target.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(target, m), target, target, sh)

func _ready():
	print("=== MASH BURNEDEAD integration probe (real turns) ===")

	# ============================================================================================
	# G. Big Bang Dash enhancement (mark dur 3) must still be ACTIVE on Mash's NEXT actionable turn
	#    (the whole point of the dur-2 -> dur-3 tuning) and GONE the turn after.
	# ============================================================================================
	var s = _fresh(); var m = s["m"]; var mash = s["mash"]; var foe = s["foes"][0]
	var bbd = mash.moveset.base_abilities[0]
	var ballista = mash.moveset.base_abilities[1]
	# Turn 1 (Mash): cast Big Bang Dash
	_cast(m, mash, bbd, [mash])
	_check(_bbd_mark(mash) != null, "G. turn 1: enhancement mark applied")
	_check(_bbd_mark(mash) != null and int(_bbd_mark(mash).duration) == 3, "G. turn 1: enhancement mark duration is 3")
	_end_turn(m)   # end of Mash's turn -> dur 3 -> 2
	_check(_bbd_mark(mash) != null and int(_bbd_mark(mash).duration) == 2, "G. after Mash turn 1: enhancement present (dur 2)")
	_end_turn(m)   # end of enemy turn -> dur 2 -> 1
	_check(_bbd_mark(mash) != null and int(_bbd_mark(mash).duration) == 1, "G. after enemy turn: enhancement STILL present on the eve of Mash's next turn (dur 1)")
	# Turn 3 (Mash's NEXT actionable turn): enhanced Ballista must fire the bonus.
	_shield_on(foe, m, 15)
	var hp0 = int(foe.health.hp)
	_cast(m, mash, ballista, [foe])
	_check(_shield_total(foe) == 0, "G. turn 3: enhanced Ballista shattered the enemy's Shield")
	_check(hp0 - int(foe.health.hp) == 30, "G. turn 3: enhanced Ballista dealt 20 + 10 = 30 (enhancement survived to here)")
	_end_turn(m)   # end of Mash turn 3 -> dur 1 -> 0 -> removed
	_check(_bbd_mark(mash) == null, "G. after Mash turn 3: enhancement expired (does NOT enhance a second Mash turn)")

	# ============================================================================================
	# H. Muscle Magic (passive) permanent machinery survives the death-cleanse (so a revive keeps it).
	# ============================================================================================
	s = _fresh(); m = s["m"]; mash = s["mash"]; foe = s["foes"][0]
	_check(mash.has_effect("Muscle Magic", EffectType.Type.MARK, mash) != null, "H. baseline: drain-immunity mark installed")
	_check(mash.shrug_off_type(EffectType.Type.BARRIER), "H. baseline: shrugs BARRIER (Nullify)")
	mash.die(foe)
	_check(mash.dead, "H. Mash is dead after die()")
	_check(mash.has_effect("Muscle Magic", EffectType.Type.MARK, mash) != null, "H. after death: Muscle Magic mark SURVIVED the death-cleanse")
	_check(mash.has_effect("Muscle Magic", EffectType.Type.IGNORE_EFFECT, mash) != null, "H. after death: BARRIER ignore SURVIVED the death-cleanse")
	_check(mash.shrug_off_type(EffectType.Type.BARRIER), "H. after death: still shrugs BARRIER (machinery intact for a revive)")

	# ============================================================================================
	# I. Energy-drain immunity through the real Character.lose_energy entry point (shipped drains
	#    route through target.lose_energy(user)).
	# ============================================================================================
	s = _fresh(); m = s["m"]; mash = s["mash"]; foe = s["foes"][0]
	for i in 3: mash.gain_bonus_energy(Energy.Type.GREEN)
	var pool0 = _pool_sum(mash)
	mash.lose_energy(foe, 1)                       # ENEMY drainer -> blocked
	_check(_pool_sum(mash) == pool0, "I. an enemy cannot drain Mash's energy")
	mash.lose_energy(mash, 1)                      # friendly source -> still spends
	_check(_pool_sum(mash) < pool0, "I. a friendly source can still spend Mash's energy")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
