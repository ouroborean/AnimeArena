extends Node

# Creator (block authoring) palette-expansion probe.
#   godot --headless --path <repo> res://training/tests/creator_expansion_probe.tscn
#
# Every new block kind / op / condition is exercised against a LIVE battle rather than
# unit-tested in isolation, because the whole premise of the Creator is that authored
# content funnels into the same engine primitives as hand-written kits — a block that
# builds a valid Effect but never reaches the engine is exactly the failure mode the
# _op_damage reactive bug was. Each section also checks the validator's rejections, so
# the safety envelope and the runtime arm can never drift apart.

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build_player(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	return p

# An authored ability that is REALLY in the character's moveset. `swap` needs this:
# apply_effect drops an ABILITY_SWAP whose source is not in the applier's base_abilities.
func _mk(name: String, owner):
	var a = load("res://blocks/scripted_ability.gd").new()
	a.ability_name = name
	a.blocks = []
	a.classes = {"Physical": false, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": false, "Harmful": true, "Helpful": false, "Instant": true, "Action": false,
		"Control": false, "Channeled": false, "Uncounterable": false, "Bypassing": false,
		"Stealthed": false, "Passive": false, "Preserves Channel": false, "Damaging": true}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _runner(ab, m, who):
	return load("res://blocks/block_runner.gd").new(ab, m, who)

func _ready():
	print("=== creator expansion probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("BotEnemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 7, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	var me = p1.team.characters[0]
	var foe = p2.team.characters[0]
	var foe2 = p2.team.characters[1]
	# The "target" selector reads the caster's live targeter, so a probe that never
	# aims resolves every to:"target" block to an empty list and silently no-ops.
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	_test_stacks(m, me, foe)
	_test_swap(m, me)
	_test_counter(m, me, foe)
	_test_compare(m, me, foe, foe2)
	_test_restriction(m, me, foe)
	_test_smaller(m, me, foe)
	_test_descriptions()
	_test_validator()

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# =========================================================================================
# 1. Stacks as a resource.
# =========================================================================================
func _test_stacks(m, me, foe):
	print("-- stacks --")
	var ab = _mk("Tally", me)
	var r = _runner(ab, m, me)
	var apply_two = {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 8, "text": "Tally", "stacks": 2, "max": 5, "show_stacks": true}}
	r.run([apply_two])
	var mk = me.has_effect("Tally", EffectType.Type.MARK, me)
	_check(mk != null, "a declared-resource mark applies")
	if mk == null:
		return
	_check(mk.stackable and mk.display_stacks, "it is stackable and displays its pips")
	_check(mk.stack_count() == 2, "it starts at the authored `stacks` (2, got %d)" % mk.stack_count())
	r.run([apply_two])
	_check(mk.stack_count() == 4, "a second cast accumulates (4, got %d)" % mk.stack_count())
	r.run([apply_two])
	_check(mk.stack_count() == 5, "a third cast CLAMPS at `max` 5 (got %d) — add_effect's merge cannot do this itself" % mk.stack_count())

	_check(r.check_condition_public({"cond": "stacks_at_least", "name": "Tally", "value": 5, "on": "user"}),
		"stacks_at_least(5) reads the same mark")
	_check(not r.check_condition_public({"cond": "stacks_at_least", "name": "Tally", "value": 6, "on": "user"}),
		"stacks_at_least(6) is correctly false")

	# There is no `stack` OP. Stacking is emergent — re-applying the effect is what banks a
	# stack (above), and the condition reads the result. The op is off the palette entirely.
	_check(not BlockSchema.OPS.has("stack"), "the `stack` op is off the palette")
	var stack_op := {"name": "T", "target": "enemy", "cost": {}, "classes": ["Harmful"],
		"blocks": [{"op": "stack", "name": "Tally", "delta": 1, "to": "user"}]}
	_check(not BlockValidator.validate_ability(stack_op).is_empty(), "...and the validator rejects it")
	var held: int = mk.stack_count()
	r.run([{"op": "stack", "name": "Tally", "delta": -3, "to": "user"}])
	_check(mk.stack_count() == held, "...and the runner has no branch for it (still %d)" % mk.stack_count())
	mk.end_effect()

# =========================================================================================
# 2. Ability swap.
# =========================================================================================
func _test_swap(m, me):
	print("-- swap --")
	var ab = _mk("Transform", me)
	var r = _runner(ab, m, me)
	r.run([{"op": "apply", "to": "user",
		"effect": {"kind": "swap", "slot": 1, "into": 2, "turns": 3}}])
	var sw = me.has_effect("Transform", EffectType.Type.ABILITY_SWAP, me)
	_check(sw != null, "the swap applied (set_source put it in base_abilities, so apply_effect kept it)")
	if sw == null:
		return
	_check(sw.duration == 7, "\"3 turns\" for a SWAP is duration 7, not 6 (got %d) — the 2N+1 rule" % sw.duration)
	_check(sw.mag == Vector2(2, 1), "mag is Vector2(swap_in, slot_replace) = (2,1), got %s" % str(sw.mag))
	_check(BlockSchema.swap_turns_to_duration(1) == 3 and BlockSchema.swap_turns_to_duration(-1) == -1,
		"swap_turns_to_duration: 1 -> 3, permanent -> -1")

# =========================================================================================
# 3. Counters. A counter INTERCEPTS — Character.countered() must return true and the
#    payload must run.
# =========================================================================================
func _test_counter(m, me, foe):
	print("-- counter --")
	var ab = _mk("Parry", me)
	var r = _runner(ab, m, me)
	r.run([{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful", "turns": 1,
		"then": [{"op": "damage", "amount": 15, "to": "target"}]}}])
	var ce = me.has_effect("Parry", EffectType.Type.COUNTER_RECEIVE, me)
	_check(ce != null, "the counter applied as COUNTER_RECEIVE")
	if ce == null:
		return
	_check(ce.class_targets == ["Harmful"], "scope 'harmful' became class_targets ['Harmful'], got %s" % str(ce.class_targets))
	_check(ce.duration == 2, "\"1 turn\" is duration 2 (got %d)" % ce.duration)

	# Drive a real harmful skill into it.
	var attack = null
	for a in foe.moveset.base_abilities:
		if a.classes.get("Harmful", false) and not a.classes.get("Uncounterable", false):
			attack = a
			break
	if attack == null:
		_check(false, "(setup) the enemy has a counterable Harmful skill")
		return
	foe.targeter.targets = [me]
	foe.targeter.main_target = me
	foe.used_ability = attack
	var foe_hp: int = foe.health.hp
	var was_countered: bool = foe.countered(m, attack)
	_check(was_countered, "the incoming Harmful skill was COUNTERED (cancelled, not merely reacted to)")
	_check(foe.health.hp == foe_hp - 15, "the `then` payload hit the attacker for 15 (%d -> %d)" % [foe_hp, foe.health.hp])
	_check(me.has_effect("Parry", EffectType.Type.COUNTER_RECEIVE, me) == null,
		"default_counter_trigger spent the counter — without it the cancel is half-done")
	foe.used_ability = null
	foe.targeter.targets = []

# =========================================================================================
# 4. Relational conditions.
# =========================================================================================
func _test_compare(m, me, foe, foe2):
	print("-- compare --")
	var ab = _mk("Reader", me)
	var r = _runner(ab, m, me)
	for c in [foe, foe2]:
		c.health.hp = 100
	m.enemy.team.characters[2].health.hp = 100
	_check(r.check_condition_public({"cond": "compare", "of": "all_enemies", "value": "hp", "op": "all_equal"}),
		"all_equal is true across an untouched enemy team")
	foe.health.hp = 60
	_check(not r.check_condition_public({"cond": "compare", "of": "all_enemies", "value": "hp", "op": "all_equal"}),
		"...and false once one of them is hurt")
	_check(r.check_condition_public({"cond": "compare", "of": "all_enemies", "value": "hp", "op": "any_differ"}),
		"any_differ is its complement")
	_check(r.check_condition_public({"cond": "compare", "of": "target", "value": "hp", "op": "lt", "than": 70}),
		"gt/lt/eq compare the first resolved character against a constant")
	_check(r.check_condition_public({"cond": "compare", "of": "user", "value": "hp", "op": "gt", "vs": "target"}),
		"...or against the first of a second selector")
	_check(r.check_condition_public({"cond": "compare", "of": "all_enemies", "value": "alive_count", "op": "eq", "than": 3}),
		"alive_count reads the SELECTION's size, not a member's HP")
	_check(r.check_condition_public({"cond": "compare", "of": "target", "value": "hp_percent", "op": "lt", "than": 70}),
		"hp_percent divides by the live max_hp")

# =========================================================================================
# 5. Action restriction.
# =========================================================================================
func _test_restriction(m, me, foe):
	print("-- cost / cooldown / paralyze / stun exclusions --")
	var ab = _mk("Shackle", me)
	var r = _runner(ab, m, me)
	r.run([
		{"op": "apply", "to": "target", "effect": {"kind": "cost_change", "amount": 1, "colour": "random", "turns": 2}},
		{"op": "apply", "to": "target", "effect": {"kind": "cooldown_change", "amount": 1, "turns": 2}},
		{"op": "apply", "to": "target", "effect": {"kind": "paralyze", "turns": 1}},
		{"op": "apply", "to": "target", "effect": {"kind": "taunt", "turns": 1}},
	])
	_check(foe.has_effect("Shackle", EffectType.Type.COST_MOD, me) != null, "cost_change -> COST_MOD")
	_check(foe.has_effect("Shackle", EffectType.Type.COOLDOWN_MOD, me) != null, "cooldown_change -> COOLDOWN_MOD")
	_check(foe.has_effect("Shackle", EffectType.Type.PARALYZE, me) != null, "paralyze -> PARALYZE")
	_check(foe.has_effect("Shackle", EffectType.Type.TAUNT, me) != null, "taunt -> TAUNT")
	var cm = foe.has_effect("Shackle", EffectType.Type.COST_MOD, me)
	if cm != null:
		_check(cm.cost_change_element == Energy.Type.RANDOM, "the cost colour reached the effect")

	var ab2 = _mk("Selective Lock", me)
	var r2 = _runner(ab2, m, me)
	r2.run([{"op": "apply", "to": "target",
		"effect": {"kind": "stun", "turns": 1, "exclude_classes": ["Physical"]}}])
	var st = foe.has_effect("Selective Lock", EffectType.Type.STUN, me)
	_check(st != null and st.exclusion_targets == ["Physical"],
		"stun's new exclude_classes reaches stun_effect's third argument")

	var ab3 = _mk("Unbreakable", me)
	_runner(ab3, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "effect_immunity", "turns": 2, "effect": "STUN"}}])
	var ie = me.has_effect("Unbreakable", EffectType.Type.IGNORE_EFFECT, me)
	_check(ie != null and ie.mag == EffectType.Type.STUN, "effect_immunity -> IGNORE_EFFECT carrying the whitelisted type")

# =========================================================================================
# 6. The smaller additions.
# =========================================================================================
func _test_smaller(m, me, foe):
	print("-- boost skills / break / cleanse / energy / on_skill_used --")
	var ab = _mk("Focus", me)
	var r = _runner(ab, m, me)
	r.run([{"op": "apply", "to": "user", "effect": {"kind": "damage_boost", "amount": 5, "turns": 2, "skills": ["Rasengan"]}}])
	var dm = me.has_effect("Focus", EffectType.Type.DAMAGE_MOD, me)
	_check(dm != null and dm.ability_targets == ["Rasengan"], "damage_boost's `skills` reached ability_targets")

	# break must go through shatter_*, which is what fires the break contingencies.
	var ab2 = _mk("Sunder", me)
	var r2 = _runner(ab2, m, me)
	r2.run([{"op": "apply", "to": "target", "effect": {"kind": "shield", "amount": 30, "turns": 3}}])
	_check(foe.get_shield_effects().size() > 0, "(setup) the target has a shield")
	r2.run([{"op": "break", "what": "both", "to": "target"}])
	_check(foe.get_shield_effects().size() == 0, "break destroyed the shield through shatter_shields")

	# Filtered cleanse. Two hostile marks on the foe; remove exactly one by name.
	var ab3 = _mk("Rot", me)
	var ab4 = _mk("Wither", me)
	_runner(ab3, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "turns": 4}}])
	_runner(ab4, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "turns": 4}}])
	var cleanser = _runner(_mk("Purge", me), m, me)
	cleanser.run([{"op": "cleanse", "to": "target", "name": "Rot"}])
	_check(foe.has_effect("Rot", EffectType.Type.VULNERABILITY, me) == null, "a named cleanse removed the named effect")
	_check(foe.has_effect("Wither", EffectType.Type.VULNERABILITY, me) != null, "...and left the other one alone")
	cleanser.run([{"op": "cleanse", "to": "target"}])
	_check(foe.has_effect("Wither", EffectType.Type.VULNERABILITY, me) == null,
		"an unqualified cleanse still strips everything (today's behaviour, unchanged)")

	# Coloured energy.
	var pool = me.team.energy.pool
	var blue_before: int = pool[Energy.Type.BLUE]
	_runner(_mk("Charge", me), m, me).run([{"op": "gain_energy", "amount": 2, "colour": "blue"}])
	_check(pool[Energy.Type.BLUE] == blue_before + 2, "gain_energy with a colour banks that colour (%d -> %d)" % [blue_before, pool[Energy.Type.BLUE]])

	_check(BlockSchema.trigger_hook_id("on_skill_used") == EffectType.Type.ACTION_USE_TRIGGER,
		"on_skill_used maps to ACTION_USE_TRIGGER")
	var ab5 = _mk("Watcher", me)
	_runner(ab5, m, me).run([{"op": "apply", "to": "user", "effect": {"kind": "reactive",
		"trigger": "on_skill_used", "turns": 3, "text": "watching",
		"then": [{"op": "heal", "amount": 5, "to": "user"}]}}])
	_check(me.has_effect("Watcher", EffectType.Type.ACTION_USE_TRIGGER, me) != null, "...and installs as a real trigger")

# =========================================================================================
# 7. Generated prose. Every new block must say something readable — an authored skill
#    with a blank line in its tooltip is indistinguishable from a broken one.
# =========================================================================================
func _test_descriptions():
	print("-- generated descriptions --")
	var SA = load("res://blocks/scripted_ability.gd")
	var a = SA.new()
	a.ability_name = "Everything"
	a.blocks = [
		{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 5, "text": "t", "stacks": 1, "max": 4, "show_stacks": true}},
		{"op": "break", "what": "both", "to": "target"},
		{"op": "cleanse", "to": "target", "name": "Rot", "scope": "own", "count": 2},
		{"op": "gain_energy", "amount": 1, "colour": "red"},
		{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 0, "into": 1, "turns": 2}},
		{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "damaging", "turns": 1,
			"then": [{"op": "damage", "amount": 10, "to": "target"}]}},
		{"op": "apply", "to": "target", "effect": {"kind": "cost_change", "amount": 1, "colour": "random", "turns": 2}},
		{"op": "apply", "to": "target", "effect": {"kind": "cooldown_change", "amount": 2, "turns": 2, "skills": ["A", "B"]}},
		{"op": "apply", "to": "target", "effect": {"kind": "paralyze", "turns": 1}},
		{"op": "apply", "to": "target", "effect": {"kind": "taunt", "turns": 1}},
		{"op": "apply", "to": "user", "effect": {"kind": "effect_immunity", "turns": 2, "effect": "SILENCE"}},
		{"op": "apply", "to": "target", "effect": {"kind": "stun", "turns": 1, "exclude_classes": ["Physical"]}},
		{"op": "apply", "to": "user", "effect": {"kind": "damage_boost", "amount": 5, "turns": 2, "skills": ["A"]}},
		{"op": "damage", "amount": 5, "to": "target",
			"when": {"cond": "compare", "of": "all_enemies", "value": "hp", "op": "any_differ"}},
		{"op": "heal", "amount": 5, "to": "user",
			"when": {"cond": "compare", "of": "user", "value": "hp_percent", "op": "lt", "than": 50}},
	]
	var segs = a.split_desc()
	var blanks := 0
	for s in segs:
		var txt: String = str(s[0]) if s is Array else str(s)
		if txt.strip_edges().is_empty():
			blanks += 1
	_check(blanks == 0, "every block produced prose (%d segments, %d blank)" % [segs.size(), blanks])
	_check(segs.size() == a.blocks.size(), "one segment per block (%d/%d)" % [segs.size(), a.blocks.size()])
	for s in segs:
		print("        -> " + (str(s[0]) if s is Array else str(s)))

	var tags: int = a.bot_tags
	_check(tags & SA.TAG_CONTROL != 0, "bot_tags: CONTROL set by the stun/paralyze/taunt blocks")
	_check(tags & SA.TAG_REACTIVE != 0, "bot_tags: REACTIVE set by the counter")
	_check(tags & SA.TAG_AMPLIFY != 0, "bot_tags: AMPLIFY set by the damage_boost / break")
	_check(tags & SA.TAG_MARK != 0, "bot_tags: MARK set by the mark")
	a.free()

# =========================================================================================
# 8. The safety envelope. Every new field has to be range-checked, and unknown fields
#    have to be rejections rather than shrugs.
# =========================================================================================
func _test_validator():
	print("-- validator --")
	var base := {"name": "T", "target": "enemy", "cost": {}, "classes": ["Harmful"], "blocks": []}

	var good := base.duplicate(true)
	good["blocks"] = [
		{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 3, "stacks": 2, "max": 5, "show_stacks": true}},
		{"op": "break", "what": "barrier", "to": "target"},
		{"op": "cleanse", "to": "user", "scope": "any", "count": 2, "name": "X"},
		{"op": "gain_energy", "amount": 1, "colour": "green"},
		{"op": "apply", "to": "target", "bypassing": true, "effect": {"kind": "stun", "turns": 1, "exclude_classes": ["Physical"]}},
		{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "any", "turns": 1,
			"then": [{"op": "damage", "amount": 10, "to": "target"}]}},
		{"op": "apply", "to": "target", "effect": {"kind": "cost_change", "amount": 2, "colour": "random", "turns": 2, "skills": ["A"]}},
		{"op": "apply", "to": "target", "effect": {"kind": "cooldown_change", "amount": 1, "turns": 2}},
		{"op": "apply", "to": "target", "effect": {"kind": "paralyze", "turns": 2}},
		{"op": "apply", "to": "target", "effect": {"kind": "taunt", "turns": 2}},
		{"op": "apply", "to": "user", "effect": {"kind": "effect_immunity", "turns": 2, "effect": "STUN"}},
		{"op": "damage", "amount": 1, "to": "target", "when": {"cond": "compare", "of": "all_enemies", "value": "alive_count", "op": "gt", "than": 1}},
	]
	var errs := BlockValidator.validate_ability(good)
	_check(errs.is_empty(), "a tree using every new block validates clean (%s)" % str(errs))

	var bad := [
		[{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 3, "max": 999}}, "mark max above the cap"],
		[{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 3, "stacks": 4, "max": 2}}, "starting stacks above max"],
		[{"op": "stack", "name": "T", "delta": 1, "to": "user"}, "the removed `stack` op"],
		[{"op": "break", "what": "everything", "to": "target"}, "unknown break target"],
		[{"op": "cleanse", "to": "user", "scope": "everyone"}, "unknown cleanse scope"],
		[{"op": "cleanse", "to": "user", "count": 0}, "cleanse count of zero"],
		[{"op": "gain_energy", "amount": 1, "colour": "random"}, "gain_energy of RANDOM (not a storable colour)"],
		[{"op": "gain_energy", "amount": 1, "colour": "purple"}, "unknown energy colour"],
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "everything", "turns": 1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "unknown counter scope"],
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": ["Nonsense"], "turns": 1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "a counter scoped to an unknown class"],
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "any", "turns": 1, "then": []}}, "a counter with an empty payload"],
		[{"op": "apply", "to": "target", "effect": {"kind": "cost_change", "amount": 1, "colour": "puce", "turns": 2}}, "unknown cost colour"],
		[{"op": "apply", "to": "target", "effect": {"kind": "cooldown_change", "amount": 1, "turns": 2, "skills": []}}, "an empty skills list"],
		[{"op": "apply", "to": "user", "effect": {"kind": "effect_immunity", "turns": 2, "effect": "NOT_A_REAL_EFFECT"}}, "immunity to a type the engine does not have"],
		[{"op": "apply", "to": "user", "effect": {"kind": "effect_immunity", "turns": 2, "effect": "MISSION_TRIGGER_ON_KILL"}}, "immunity to a mission bookkeeping hook"],
		[{"op": "apply", "to": "target", "effect": {"kind": "stun", "turns": 1, "exclude_classes": ["Nonsense"]}}, "an unknown excluded class"],
		[{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 9, "into": 0, "turns": 2}}, "a swap slot outside 0-3"],
		# STANDALONE validation (no siblings) can only range-check `into`, and the range is
		# now 0..max_abilities-1 because a character may legitimately carry up to 14 skills
		# and `into` is how a HIDDEN one is reached. 9 used to be out of range; it is a real
		# index now, so the rejection case has to sit above the ceiling.
		[{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 0, "into": 99, "turns": 2}}, "a swap into a nonexistent skill"],
		[{"op": "damage", "amount": 1, "to": "target", "when": {"cond": "compare", "of": "user", "value": "hp", "op": "gt"}}, "compare gt with neither than nor vs"],
		[{"op": "damage", "amount": 1, "to": "target", "when": {"cond": "compare", "of": "user", "value": "hp", "op": "gt", "than": 1, "vs": "target"}}, "compare with both than and vs"],
		[{"op": "damage", "amount": 1, "to": "target", "when": {"cond": "compare", "of": "user", "value": "alive_count", "op": "all_equal"}}, "all_equal over alive_count"],
		[{"op": "damage", "amount": 1, "to": "target", "when": {"cond": "compare", "of": "user", "value": "morale", "op": "gt", "than": 1}}, "an unknown compare value"],
		[{"op": "damage", "amount": 1, "to": "target", "when": {"cond": "compare", "of": "nowhere", "value": "hp", "op": "gt", "than": 1}}, "an unknown compare selector"],
	]
	for pair in bad:
		var spec := base.duplicate(true)
		spec["blocks"] = [pair[0]]
		_check(not BlockValidator.validate_ability(spec).is_empty(), "SAFETY: rejects " + str(pair[1]))

	# UNGROUNDED BOUNDS THAT ARE GONE. Every one of these is a shape the SHIPPED roster
	# already has and the Creator used to refuse. They are asserted as ACCEPTED so the
	# restrictions cannot quietly come back.
	var now_ok := [
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful", "turns": -1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "a permanent counter (author-controlled duration)"],
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful", "ticks": 5,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "broly2's engine-duration-5 counter"],
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": ["Strategic", "Mental"], "turns": 1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "tokoyami3's class-filtered counter scope"],
		[{"op": "apply", "to": "target", "effect": {"kind": "cost_change", "amount": 4, "colour": "red", "turns": 2}}, "a cost_change of 4"],
		[{"op": "apply", "to": "target", "effect": {"kind": "cooldown_change", "amount": -3, "turns": 3, "skills": ["Shine Aqua Illusion"]}}, "mercury1's cooldown_mod(-3)"],
		[{"op": "apply", "to": "target", "effect": {"kind": "paralyze", "ticks": 3}}, "rimuru2's odd-duration paralyze"],
		[{"op": "apply", "to": "user", "effect": {"kind": "effect_immunity", "turns": 2, "effect": "SHIELD"}}, "bakugo2/jaden6 SHIELD immunity"],
		[{"op": "apply", "to": "user", "effect": {"kind": "effect_immunity", "turns": 2, "effect": "COUNTER_RECEIVE"}}, "kakashi5 COUNTER_RECEIVE immunity"],
		[{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 0, "into": 1, "ticks": 20}}, "yoh1's engine-duration-20 swap"],
		[{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 0, "into": 1, "turns": 999}}, "a 999-turn swap (duration is author-controlled — the old max_turns cap is gone)"],
		[{"op": "apply", "to": "target", "effect": {"kind": "damage_over_time", "amount": 5, "ticks": 9}}, "kurotsuchi6's odd-duration DoT"],
		[{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": -1, "max": 50, "stacks": 1}}, "astolfo1's unbounded permanent stack counter"],
	]
	for pair in now_ok:
		var spec := base.duplicate(true)
		spec["blocks"] = [pair[0]]
		var e := BlockValidator.validate_ability(spec)
		_check(e.is_empty(), "accepts " + str(pair[1]) + " (%s)" % str(e))

	# xanxus2 costs 6 (1 green + 5 Random) and yuno7 costs 6 — the old total-5 / per-colour-4
	# check made both unauthorable.
	var xanxus_cost := base.duplicate(true)
	xanxus_cost["cost"] = {"0": 1, "4": 5}
	xanxus_cost["blocks"] = [{"op": "damage", "amount": 10, "to": "target"}]
	_check(BlockValidator.validate_ability(xanxus_cost).is_empty(), "accepts xanxus2's 6-energy cost (5 of one colour)")

	# Invisible / Unstunnable are real class strings on 15 shipped abilities.
	var flagged := base.duplicate(true)
	flagged["classes"] = ["Harmful", "Invisible", "Unstunnable", "Uncounterable", "Control"]
	flagged["blocks"] = [{"op": "damage", "amount": 10, "to": "target"}]
	_check(BlockValidator.validate_ability(flagged).is_empty(), "accepts the Invisible / Unstunnable / Uncounterable / Control classes")

	# A Passive may carry a cost (cooler6 does) and a `requires` (inert, never consulted).
	var costed_passive := base.duplicate(true)
	costed_passive["classes"] = ["Passive"]
	costed_passive["cost"] = {"0": 1}
	costed_passive["cooldown"] = 0
	costed_passive["requires"] = [{"cond": "hp_below", "value": 50, "on": "user"}]
	costed_passive["blocks"] = [{"op": "heal", "amount": 5, "to": "user"}]
	_check(BlockValidator.validate_ability(costed_passive).is_empty(), "accepts cooler6's costed Passive (and an inert `requires`)")

	# Swap cross-references need the whole moveset. CHAINS ARE LEGAL: cooler1 swaps in cooler5
	# and cooler5 re-applies the same swap to extend itself, so a swap whose `into` is itself
	# a swap is a shipped kit shape, not an error.
	var chainer := {"name": "A", "target": "self", "cost": {}, "classes": [], "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 0, "into": 1, "turns": 2}}]}
	var chained := {"name": "B", "target": "self", "cost": {}, "classes": [], "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 1, "into": 0, "turns": 2}}]}
	var plain := {"name": "C", "target": "enemy", "cost": {}, "classes": [], "blocks": [
		{"op": "damage", "amount": 10, "to": "target"}]}
	_check(BlockValidator.validate_ability(chainer, [chainer, chained]).is_empty(),
		"accepts a swap into a skill that is itself a swap (cooler1 -> cooler5 chain)")
	_check(BlockValidator.validate_ability(chainer, [chainer, plain]).is_empty(),
		"...and a swap into an ordinary sibling")
	var passive := {"name": "P", "target": "self", "cost": {}, "classes": ["Passive"], "blocks": [
		{"op": "heal", "amount": 5, "to": "user"}]}
	_check(not BlockValidator.validate_ability(chainer, [chainer, passive]).is_empty(),
		"SAFETY: rejects a swap into the Passive (it never occupies a slot)")
