extends Node

# Faction-aware Harmful/Helpful for counter / reflect / trigger checks.
# A skill classed BOTH Harmful and Helpful (edward2) must only count as Harmful when aimed at an enemy,
# and only as Helpful when aimed at an ally — so a helpful use no longer trips a "next Harmful skill"
# counter/reflect/trigger (and vice versa). Purely-classed skills (edward1 = Harmful) are unchanged.
#   godot --headless --path . res://training/tests/faction_class_probe.tscn

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _battle(seed):
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 = _build("ZA" + str(seed), ["gray", "gon", "aang"], false)
	var p2 = _build("ZB" + str(seed), ["misaka", "byakuya", "tanjiro"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, seed, BattleManager.MatchType.BOT)
	return [m, p1, p2]

func _use_counter(actor, applier, ctype, classes):
	# A COUNTER_USE / REFLECT_USE on `actor`, applied by an enemy `applier` (so action_countered's
	# user_hostile gate holds), matching `classes`.
	var qc = QueryContext.from_game_state(actor, actor.battle)
	var e = Effect.counter_effect(Trigger.always(func(_c): pass), ctype, -1, "test", classes)
	e.set_source(applier.moveset.base_abilities[0]); e.waiting = false
	Character.add_hostile_effect(qc, applier, actor, e)
	return e

func _use_trigger(holder, applier, ttype, counter_arr):
	var qc = QueryContext.from_game_state(holder, holder.battle)
	var t = Effect.trigger_effect(Trigger.always(func(_c): counter_arr[0] += 1), ttype, -1, "test")
	t.set_source(applier.moveset.base_abilities[0]); t.waiting = false
	if holder.is_hostile(applier):
		Character.add_hostile_effect(qc, applier, holder, t)
	else:
		Character.add_allied_effect(qc, applier, holder, t)
	return t

func _ready():
	print("=== faction class probe ===")
	var TT = EffectType.Type
	var r = _battle(11001)
	var m = r[0]
	var actor = r[1].team.characters[0]    # gray
	var ally = r[1].team.characters[1]     # gon
	var enemy = r[2].team.characters[0]    # misaka (applier)
	var enemy2 = r[2].team.characters[1]   # byakuya (harmful target)

	var dual = Ability.from_database("edward2"); dual.user = actor
	var pureh = Ability.from_database("edward1"); pureh.user = actor
	_check(dual.classes["Harmful"] and dual.classes["Helpful"], "[setup] edward2 is dual-classed")
	_check(pureh.classes["Harmful"] and not pureh.classes["Helpful"], "[setup] edward1 is purely Harmful")

	# === COUNTER_USE ["Harmful"] ===
	var cuh = _use_counter(actor, enemy, TT.COUNTER_USE, ["Harmful"])
	_check(actor.has_effect("Defensive Alchemy", TT.COUNTER_USE, enemy) != null or actor.effects.get_effects_by_type(TT.COUNTER_USE).size() > 0, "[setup] COUNTER_USE applied to actor")
	actor.targeter.targets = [ally]
	_check(not actor.countered(m, dual), "[Counter/Harmful] dual used on ALLY (helpful) is NOT countered")
	actor.targeter.targets = [enemy2]
	_check(actor.countered(m, dual), "[Counter/Harmful] dual used on ENEMY (harmful) IS countered")
	actor.targeter.targets = [enemy2]
	_check(actor.countered(m, pureh), "[Counter/Harmful] purely-Harmful skill on enemy still countered (no regression)")
	actor.effects.erase_effect(cuh)

	# === COUNTER_USE ["Helpful"] ===
	var cuhelp = _use_counter(actor, enemy, TT.COUNTER_USE, ["Helpful"])
	actor.targeter.targets = [ally]
	_check(actor.countered(m, dual), "[Counter/Helpful] dual used on ALLY (helpful) IS countered")
	actor.targeter.targets = [enemy2]
	_check(not actor.countered(m, dual), "[Counter/Helpful] dual used on ENEMY (harmful) is NOT countered")
	actor.effects.erase_effect(cuhelp)

	# === REFLECT_USE ["Harmful"] (shares action_countered) ===
	var ru = _use_counter(actor, enemy, TT.REFLECT_USE, ["Harmful"])
	actor.targeter.targets = [ally]
	_check(not actor.reflect_check(m, dual), "[Reflect/Harmful] dual used on ALLY is NOT reflected")
	actor.targeter.targets = [enemy2]
	_check(actor.reflect_check(m, dual), "[Reflect/Harmful] dual used on ENEMY IS reflected")
	actor.effects.erase_effect(ru)

	# === HARMFUL_USE_TRIGGER (on the actor) ===
	var fH = [0]
	var hut = _use_trigger(actor, actor, TT.HARMFUL_USE_TRIGGER, fH)
	actor.targeter.targets = [ally]; fH[0] = 0; hut.triggered = false
	actor.check_ability_use_triggers(m, dual)
	_check(fH[0] == 0, "[Trigger] HARMFUL_USE does NOT fire on a helpful use of a dual skill")
	actor.targeter.targets = [enemy2]; fH[0] = 0; hut.triggered = false
	actor.check_ability_use_triggers(m, dual)
	_check(fH[0] == 1, "[Trigger] HARMFUL_USE fires on a harmful use")
	actor.effects.erase_effect(hut)

	# === HELPFUL_USE_TRIGGER (on the actor) ===
	var fHe = [0]
	var het = _use_trigger(actor, actor, TT.HELPFUL_USE_TRIGGER, fHe)
	actor.targeter.targets = [ally]; fHe[0] = 0; het.triggered = false
	actor.check_ability_use_triggers(m, dual)
	_check(fHe[0] == 1, "[Trigger] HELPFUL_USE fires on a helpful use of a dual skill")
	actor.targeter.targets = [enemy2]; fHe[0] = 0; het.triggered = false
	actor.check_ability_use_triggers(m, dual)
	_check(fHe[0] == 0, "[Trigger] HELPFUL_USE does NOT fire on a harmful use")
	actor.effects.erase_effect(het)

	# === HARMFUL_RECEIVE_TRIGGER (receive triggers keep existing applier-team handling — unchanged) ===
	var fR2 = [0]
	var hrt2 = _use_trigger(enemy2, enemy2, TT.HARMFUL_RECEIVE_TRIGGER, fR2)
	actor.targeter.targets = [enemy2]; fR2[0] = 0; hrt2.triggered = false
	actor.check_ability_use_triggers(m, dual)
	_check(fR2[0] == 1, "[Receive] HARMFUL_RECEIVE still fires on an enemy hit harmfully by a dual skill")
	enemy2.effects.erase_effect(hrt2)

	# === BUG1: a PURELY-Harmful skill always counts as Harmful, even self-targeted (regression guard) ===
	var cu2 = _use_counter(actor, enemy, TT.COUNTER_USE, ["Harmful"])
	actor.targeter.targets = [actor]   # simulate a self-targeted purely-Harmful skill (Eren Rampage etc.)
	_check(actor.countered(m, pureh), "[BUG1] self-targeted purely-Harmful skill still counts as Harmful (countered)")
	_check(not actor.countered(m, dual), "[BUG1] self-targeted DUAL skill does NOT count as Harmful (self = ally)")
	actor.effects.erase_effect(cu2)

	# === BUG2: the use-trigger reads the PRE-REFLECT targets, not the post-reflect targeter ===
	var fB = [0]
	var hutB = _use_trigger(actor, actor, TT.HARMFUL_USE_TRIGGER, fB)
	actor.targeter.targets = [actor]   # simulate reflect having repointed the targeter to self
	fB[0] = 0; hutB.triggered = false
	actor.check_ability_use_triggers(m, dual, false, [enemy2])   # acting_targets = the real (enemy) aim
	_check(fB[0] == 1, "[BUG2] dual HARMFUL_USE fires from pre-reflect targets though targeter now points at self")
	fB[0] = 0; hutB.triggered = false
	actor.check_ability_use_triggers(m, pureh)   # purely-Harmful, self targeter, no acting_targets
	_check(fB[0] == 1, "[BUG2] purely-Harmful HARMFUL_USE fires even with a self targeter")
	actor.effects.erase_effect(hutB)

	# === BUG3: the taunt-redirect gate uses ability_acts_harmful (helper the gate calls) ===
	actor.targeter.targets = [ally]
	_check(not Character.ability_acts_harmful(dual), "[BUG3] dual used helpfully is NOT Harmful -> taunt won't redirect")
	actor.targeter.targets = [enemy2]
	_check(Character.ability_acts_harmful(dual), "[BUG3] dual used harmfully IS Harmful -> taunt redirects normally")
	_check(Character.ability_acts_harmful(pureh), "[BUG3] purely-Harmful is Harmful for the taunt gate regardless of targets")

	print("=== faction class probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
