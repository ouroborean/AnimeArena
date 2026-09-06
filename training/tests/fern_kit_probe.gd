extends Node

# Fern kit probe. Her whole identity is the leftover-energy read, which is only meaningful against
# the REAL turn pipeline, so the energy checks drive the team pool directly and the volley checks
# drive real turn boundaries.
#   godot --headless --path <repo> res://training/tests/fern_kit_probe.tscn

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build_player(u, names):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	var is_enemy = (u == "BotEnemy")
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _cast(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.used_ability = ab
	ab.execute(caster, m)
	return ab

func _pass_turn(m):
	m.end_of_turn_effect_handling()

# TICKING_TRIGGERs do NOT fire from end_of_turn_effect_handling — battle_manager collects them into
# the turn's execution_order (get_ticking_effect_information) and start_round_loop runs them through
# execute_ticking_effect. Drive that path explicitly for the ACTING side, the way the real turn does.
func _run_ticks(m, for_enemy: bool):
	var info = m.get_ticking_effect_information(for_enemy)
	for key in info.keys():
		for eff in info[key]:
			m.execute_ticking_effect(eff)

func _to_fern_turn(m):
	for _i in range(4):
		if not m.waiting_for_turn:
			return
		m.end_of_turn_effect_handling()

func _set_pool(team, green, blue, white, red):
	team.energy.pool[Energy.Type.GREEN] = green
	team.energy.pool[Energy.Type.BLUE] = blue
	team.energy.pool[Energy.Type.WHITE] = white
	team.energy.pool[Energy.Type.RED] = red
	team.energy.clear_promised_pool()

func _revive(p):
	for c in p.team.characters:
		c.dead = false
		c.banished = false
		c.health.hp = c.health.max_hp

# Drive a real skill use through the pipeline that runs Talented Child's watcher: the watcher is an
# ACTION_USE_TRIGGER on the ACTING character, dispatched by check_ability_use_triggers.
func _uses(m, actor, ability_idx, targets):
	var ab = actor.moveset.base_abilities[ability_idx]
	actor.targeter.targets = targets
	actor.targeter.main_target = targets[0] if targets.size() > 0 else null
	actor.used_ability = ab
	actor.check_ability_use_triggers(m, ab)
	return ab

# Sum only the SPECIFIC-colour pips of a cost — what the passive is supposed to count.
func _colored(cost: Dictionary) -> int:
	var n := 0
	for color in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		n += int(cost.get(color, 0))
	return n

# Credit the passive directly with a synthetic colour cost, for the arithmetic checks.
func _spend(f, cost: Dictionary):
	f.moveset.base_abilities[4]._credit(f, _colored(cost))

func _mana_on(f) -> bool:
	return f.marked_by("Mana Control", f) != null

func _ready():
	print("=== fern kit probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["fern", "naruto", "gon"])
	var p2 = _build_player("BotEnemy", ["killua", "misaka", "gray"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	var f = p1.team.characters[0]
	var foe = p2.team.characters[0]
	var foe2 = p2.team.characters[1]
	var ally = p1.team.characters[1]
	# The probe drives execute() directly, so bot_character would make fern1/fern3 subtract their
	# own cost (the bot-path correction). Clear it to exercise the human-path read.
	for c in p1.team.characters:
		c.bot_character = false

	# ---- registration ----
	_check(f.character_name == "Fern", "character builds (%s)" % f.character_name)
	_check(f.health.max_hp == 100, "max HP is 100")
	var names: Array = []
	for a in f.moveset.base_abilities:
		names.append(a.ability_name)
	_check(names == ["Zoltraak Beam", "Mana Control", "Zoltraak Blasts", "Protective Barrier", "Talented Child"],
		"5 abilities in order: %s" % [names])
	_check(f.moveset.base_abilities[4].classes["Passive"], "Talented Child is the Passive")
	_check(f.moveset.base_abilities[3].classes["Helpful"], "Protective Barrier is Helpful")

	# ---- Mana Control is a toggle ----
	_check(not _mana_on(f), "Mana Control starts off")
	_cast(m, f, 1, [f])
	_check(_mana_on(f), "casting it turns it on")
	_cast(m, f, 1, [f])
	_check(not _mana_on(f), "casting it again turns it OFF")
	_cast(m, f, 1, [f])
	_check(_mana_on(f), "and on again")

	# ---- Zoltraak Beam ----
	var beam = f.moveset.base_abilities[0]
	_set_pool(p1.team, 1, 2, 1, 0)      # 4 storable energy, nothing promised
	_check(beam.leftover_energy(f) == 4, "leftover reads 4 (got %d)" % beam.leftover_energy(f))
	p1.team.energy.promised_pool[Energy.Type.RANDOM] = 1
	_check(beam.leftover_energy(f) == 3, "a RANDOM promise holds a colour hostage (got %d)" % beam.leftover_energy(f))
	p1.team.energy.clear_promised_pool()

	var hp0 = foe.health.hp
	_cast(m, f, 0, [foe])
	_check(hp0 - foe.health.hp == 20 * 4, "enhanced Beam deals 20 per leftover energy (dealt %d, expect 80)" % (hp0 - foe.health.hp))

	_revive(p2)
	_cast(m, f, 1, [f])                  # toggle OFF
	_check(not _mana_on(f), "Mana Control off for the flat test")
	hp0 = foe.health.hp
	_cast(m, f, 0, [foe])
	_check(hp0 - foe.health.hp == 45, "unenhanced Beam deals a flat 45 (dealt %d)" % (hp0 - foe.health.hp))

	# ---- Zoltraak Blasts ----
	_revive(p2)
	_set_pool(p1.team, 0, 0, 0, 0)
	# "For 3 turns, deals 10" must land its FIRST 10 on the CAST turn. The engine snapshots a side's
	# ticking effects BEFORE that turn's abilities run, so a volley created by this cast cannot tick
	# on this turn -- the opening instance has to be fired by hand or the whole window is a turn late.
	var before_total := 0
	for c in p2.team.characters:
		before_total += c.health.hp
	_cast(m, f, 2, [f])                  # unenhanced: 10 to a random enemy, 3 instances
	var after_cast := 0
	for c in p2.team.characters:
		after_cast += c.health.hp
	_check(before_total - after_cast == 10,
		"the FIRST 10 lands on the cast turn, not a turn later (dealt %d)" % (before_total - after_cast))
	var volleys: int = f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER).size()
	_check(volleys == 1, "one volley effect planted (got %d)" % volleys)

	_pass_turn(m)   # enemy turn
	_pass_turn(m)   # back to Fern
	var before_t2 := 0
	for c in p2.team.characters:
		before_t2 += c.health.hp
	_run_ticks(m, false)   # her turn's ticking effects -- instance 2
	var after_t2 := 0
	for c in p2.team.characters:
		after_t2 += c.health.hp
	_check(before_t2 - after_t2 == 10, "instance 2 hit exactly one enemy for 10 (total %d)" % (before_t2 - after_t2))

	# ...and exactly ONE more after that, for three in total.
	_pass_turn(m)
	_pass_turn(m)
	var before_t3 := 0
	for c in p2.team.characters:
		before_t3 += c.health.hp
	_run_ticks(m, false)
	var after_t3 := 0
	for c in p2.team.characters:
		after_t3 += c.health.hp
	_check(before_t3 - after_t3 == 10, "instance 3 landed (total %d)" % (before_t3 - after_t3))
	_pass_turn(m)
	_pass_turn(m)
	var before_t4 := 0
	for c in p2.team.characters:
		before_t4 += c.health.hp
	_run_ticks(m, false)
	var after_t4 := 0
	for c in p2.team.characters:
		after_t4 += c.health.hp
	_check(before_t4 - after_t4 == 0, "and NO fourth instance (dealt %d)" % (before_t4 - after_t4))

	# Recasting STACKS rather than refreshing (owner ruling). Start clean and recast inside the
	# window -- the walk above deliberately ran the first volley to expiry.
	for e in f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER):
		e.end_effect()
	_revive(p2)
	_to_fern_turn(m)
	_cast(m, f, 2, [f])
	_check(f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER).size() == 1, "one volley up")
	_pass_turn(m)
	_pass_turn(m)
	_cast(m, f, 2, [f])
	_check(f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER).size() == 2,
		"a recast STACKS a second volley (got %d)" % f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER).size())

	# Enhanced mode is ONE immediate team-wide burst -- no volley, nothing to tick, nothing to stack.
	# (The exhaustive version of this, including "no further damage for four turns", is further down;
	# this is the early check that the two shapes really are different.)
	for e in f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER):
		e.end_effect()
	_revive(p2)
	if not _mana_on(f):
		_cast(m, f, 1, [f])
	_set_pool(p1.team, 1, 1, 1, 0)       # 3 leftover -> 5 + 5*3 = 20 to ALL, once
	var hp_a = foe.health.hp
	var hp_b = foe2.health.hp
	_cast(m, f, 2, [f])
	_check(hp_a - foe.health.hp == 20 and hp_b - foe2.health.hp == 20,
		"enhanced Blasts hits ALL enemies for 5+5*3 = 20 immediately (%d / %d)" % [hp_a - foe.health.hp, hp_b - foe2.health.hp])
	_check(f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER).is_empty(),
		"...and leaves NO volley behind (found %d)" % f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER).size())
	_set_pool(p1.team, 0, 0, 0, 0)       # same pool state the following sections used to inherit

	# ---- Protective Barrier ----
	_to_fern_turn(m)
	for e in ally.effects.get_effects_by_type(EffectType.Type.SHIELD):
		e.end_effect()
	_check(ally.get_shield_effects().is_empty(), "ally starts unshielded")
	_cast(m, f, 3, [ally])
	var sh = ally.get_shield_effects()
	_check(sh.size() == 1 and sh[0].mag == 20 and sh[0].duration == 2,
		"first barrier is 20 Shield for 1 turn (dur %d)" % (sh[0].duration if sh.size() > 0 else -99))
	_cast(m, f, 3, [ally])
	sh = ally.get_shield_effects()
	var permanent := 0
	var total_mag := 0
	for s in sh:
		total_mag += int(s.mag)
		if s.duration == -1:
			permanent += 1
	_check(sh.size() == 2, "the second barrier did NOT merge into the first (got %d effects)" % sh.size())
	_check(permanent == 1, "exactly one of them is permanent (got %d)" % permanent)
	_check(total_mag == 40, "40 Shield total (got %d)" % total_mag)

	# ---- Talented Child ----
	var counter = f.has_effect("Talented Child", EffectType.Type.MARK, f)
	_check(counter != null, "the passive installed its spend counter")
	var pool_before := 0
	for k in p1.team.energy.pool:
		pool_before += int(p1.team.energy.pool[k])
	_spend(f, {Energy.Type.WHITE: 3})
	_check(int(counter.mag) == 3, "3 spent -> remainder 3, no grant yet (got %d)" % int(counter.mag))
	var pool_mid := 0
	for k in p1.team.energy.pool:
		pool_mid += int(p1.team.energy.pool[k])
	_check(pool_mid == pool_before, "...and no energy was granted yet")
	_spend(f, {Energy.Type.BLUE: 2})
	_check(int(counter.mag) == 1, "5 spent total -> one grant, remainder 1 (got %d)" % int(counter.mag))
	var pool_after := 0
	for k in p1.team.energy.pool:
		pool_after += int(p1.team.energy.pool[k])
	_check(pool_after == pool_before + 1, "exactly one energy was generated (%d -> %d)" % [pool_before, pool_after])
	# Under Mana Control the grant is White or Blue; otherwise Red or Green.
	_check(_mana_on(f), "Mana Control still on for the colour check")
	var w0 = int(p1.team.energy.pool[Energy.Type.WHITE]) + int(p1.team.energy.pool[Energy.Type.BLUE])
	_spend(f, {Energy.Type.RED: 4})
	var w1 = int(p1.team.energy.pool[Energy.Type.WHITE]) + int(p1.team.energy.pool[Energy.Type.BLUE])
	_check(w1 == w0 + 1, "enhanced grant went to White or Blue (%d -> %d)" % [w0, w1])
	_cast(m, f, 1, [f])   # toggle off
	var rg0 = int(p1.team.energy.pool[Energy.Type.RED]) + int(p1.team.energy.pool[Energy.Type.GREEN])
	_spend(f, {Energy.Type.WHITE: 4})
	var rg1 = int(p1.team.energy.pool[Energy.Type.RED]) + int(p1.team.energy.pool[Energy.Type.GREEN])
	_check(rg1 == rg0 + 1, "unenhanced grant went to Red or Green (%d -> %d)" % [rg0, rg1])
	# ---- only SPECIFIC-colour pips count; a Random pip is paid from the same pool but must not ----
	var counter2 = f.has_effect("Talented Child", EffectType.Type.MARK, f)
	counter2.mag = 0
	# Zoltraak Beam costs 1 Blue + 1 White -> 2 colour.
	_uses(m, f, 0, [foe])
	_check(int(counter2.mag) == 2, "a 1 Blue + 1 White skill credits 2 (got %d)" % int(counter2.mag))
	# Mana Control costs 1 RANDOM and nothing else -> credits 0.
	counter2.mag = 0
	_uses(m, f, 1, [f])
	_check(int(counter2.mag) == 0, "a pure 1 Random skill credits NOTHING (got %d)" % int(counter2.mag))
	# Zoltraak Blasts costs 1 White -> 1.
	counter2.mag = 0
	_uses(m, f, 2, [f])
	_check(int(counter2.mag) == 1, "a 1 White skill credits 1 (got %d)" % int(counter2.mag))
	# A teammate's skill counts too, but only its colour pips.
	counter2.mag = 0
	var mate_cost = _colored(ally.moveset.base_abilities[0].cost())
	_uses(m, ally, 0, [foe])
	_check(int(counter2.mag) == mate_cost,
		"a teammate's skill credits only its colour pips (%d, expected %d)" % [int(counter2.mag), mate_cost])
	# An ENEMY acting must not feed her at all.
	counter2.mag = 0
	_uses(m, foe, 0, [f])
	_check(int(counter2.mag) == 0, "an ENEMY acting does not feed Talented Child (got %d)" % int(counter2.mag))

	# ---- the Mana Control modes SPEND the bank they scale off ----
	if not _mana_on(f):
		_cast(m, f, 1, [f])
	_revive(p2)
	_set_pool(p1.team, 1, 1, 1, 0)        # 3 storable
	var beam_hp = foe.health.hp
	_cast(m, f, 0, [foe])
	_check(beam_hp - foe.health.hp == 60, "enhanced Beam hit for 20*3 = 60 (dealt %d)" % (beam_hp - foe.health.hp))
	var left_after := 0
	for k in p1.team.energy.pool:
		left_after += int(p1.team.energy.pool[k])
	_check(left_after == 0, "enhanced Beam consumed the whole pool (%d left)" % left_after)
	# Unenhanced must NOT burn it.
	_cast(m, f, 1, [f])                   # toggle off
	_set_pool(p1.team, 1, 1, 1, 0)
	_cast(m, f, 0, [foe])
	var left_plain := 0
	for k in p1.team.energy.pool:
		left_plain += int(p1.team.energy.pool[k])
	_check(left_plain == 3, "the unenhanced Beam leaves the pool alone (%d left)" % left_plain)
	# ---- enhanced Blasts is ONE burst on the whole enemy team, and plants nothing ----
	_cast(m, f, 1, [f])                   # toggle back on
	for e in f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER):
		e.end_effect()
	_revive(p2)
	_set_pool(p1.team, 1, 1, 0, 1)        # 3 storable -> 5 + 5*3 = 20 per enemy
	var foes_before := []
	for c in p2.team.characters:
		foes_before.append(c.health.hp)
	_cast(m, f, 2, [f])
	var hit := 0
	for i in range(p2.team.characters.size()):
		var dealt: int = foes_before[i] - p2.team.characters[i].health.hp
		_check(dealt == 20, "enhanced Blasts hit enemy %d for 5 + 5*3 = 20 (dealt %d)" % [i, dealt])
		if dealt > 0:
			hit += 1
	_check(hit == p2.team.characters.size(), "...every living enemy was hit (%d of %d)" % [hit, p2.team.characters.size()])
	var left_blasts := 0
	for k in p1.team.energy.pool:
		left_blasts += int(p1.team.energy.pool[k])
	_check(left_blasts == 0, "enhanced Blasts consumed the whole pool (%d left)" % left_blasts)
	# The whole point of this change: NO lingering volley, so nothing ticks on a later turn.
	_check(f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER).is_empty(),
		"enhanced Blasts plants NO ticking volley (found %d)" % f.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER).size())
	# ...and it stays that way across the following turns - the burst really was one instance.
	var after_burst := []
	for c in p2.team.characters:
		after_burst.append(c.health.hp)
	for _t in range(4):
		_run_ticks(m, m.waiting_for_turn)
		_pass_turn(m)
	for i in range(p2.team.characters.size()):
		_check(p2.team.characters[i].health.hp == after_burst[i],
			"enemy %d took no further damage over the next turns (%d -> %d)" % [i, after_burst[i], p2.team.characters[i].health.hp])
	if _mana_on(f):
		_cast(m, f, 1, [f])

	# =====================================================================================
	# Regression: Talented Child must survive Fern's death and a revive. Her remainder counter is
	# death-cleansed with everything else she cast, and startup_passives never re-runs, so the
	# passive used to go silently dead for the rest of the match.
	# =====================================================================================
	_check(f.has_effect("Talented Child", EffectType.Type.MARK, f) != null, "counter present before death")
	f.die(foe, null)
	_check(f.dead, "Fern died")
	_check(f.has_effect("Talented Child", EffectType.Type.MARK, f) == null,
		"the counter was death-cleansed (the engine's normal behaviour)")
	f.dead = false
	f.health.hp = f.health.max_hp
	var pool_r0 := 0
	for k in p1.team.energy.pool:
		pool_r0 += int(p1.team.energy.pool[k])
	_spend(f, {Energy.Type.WHITE: 4})
	var pool_r1 := 0
	for k in p1.team.energy.pool:
		pool_r1 += int(p1.team.energy.pool[k])
	_check(f.has_effect("Talented Child", EffectType.Type.MARK, f) != null,
		"a revived Fern rebuilds her counter on the next spend")
	_check(pool_r1 == pool_r0 + 1, "...and the passive grants again (%d -> %d)" % [pool_r0, pool_r1])

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
