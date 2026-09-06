extends Node

# ============================================================================
# CREATOR — the block `counter`/`reflect` EXCLUDE class-filter.
#   godot --headless --path <repo> res://training/tests/creator_counter_exclude_probe.tscn
#
# The SECOND gap Creator Roulette 09 (Saitama) found. The block `counter`/`reflect` kinds could
# filter by an INCLUSION class list (`scope` -> class_targets) but could NOT exclude a class, so an
# authored counter of "Harmful skills EXCEPT Strategic" was unbuildable — _build_counter/_build_reflect
# hardcoded the exclusion list (counter_effect's 6th arg) to []. saitama4 (Serious Side-Hops) is
# exactly that shape: counter_effect(..., ["Harmful"], ["Strategic"]).
#
# The engine ALREADY honours exclusion_targets (Condition.action_countered returns false when the
# incoming skill carries an excluded class — scripts/condition.gd ~:260-263). This probe proves the
# authored `exclude` field now threads through to it, on BOTH counter and reflect, via the SAME
# countered()/reflect_check() the battle manager calls — nothing is unit-tested in isolation.
#
# Structure, per kind: a NEGATIVE (a Harmful+Strategic skill is let through), a POSITIVE control
# (a plain Harmful skill is still caught), and a HAND-REVERSE (drop the `exclude` — author a counter
# WITHOUT it, i.e. the runner passes [] again — and confirm the Harmful+Strategic skill is now WRONGLY
# caught: the assertion flips, proving the field is load-bearing). Plus prose + validator envelope.
# ============================================================================

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

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

func _runner(ab, m, who):
	return load("res://blocks/block_runner.gd").new(ab, m, who)

# The carrier ability the counter/reflect effect is SOURCED from — a real moveset member, because
# apply_effect couples an effect to its source ability and the counter/reflect factory reads it.
func _carrier(name, owner):
	var a := ScriptedAbility.new()
	a.ability_name = name
	a.blocks = []
	a.classes = Ability.default_classes()
	a.user = owner
	owner.moveset.add_ability(a)
	return a

# A single-target enemy attack carrying the given extra classes. Always Harmful + Instant and never
# Uncounterable (Uncounterable short-circuits both countered() and reflect_check() before any scope is
# read). target "enemy" == SINGLE, which keeps reflect_trigger on its safe single-target re-aim branch.
func _attack(name, owner, extra_classes: Array):
	var a := ScriptedAbility.new()
	a.configure({"name": name, "target": "enemy", "blocks": [{"op": "damage", "amount": 5, "to": "target"}]})
	a.ability_name = name
	a.classes = Ability.default_classes()
	a.classes["Harmful"] = true
	a.classes["Instant"] = true
	for c in extra_classes:
		a.classes[c] = true
	a.user = owner
	owner.moveset.add_ability(a)
	return a

# Aim the attacker at the defender, ask the ENGINE whether the skill is countered (the exact call
# battle_manager makes), then clear the transient aim.
func _driven_countered(attacker, defender, attack, m) -> bool:
	attacker.targeter.targets = [defender]
	attacker.targeter.main_target = defender
	attacker.used_ability = attack
	var r: bool = attacker.countered(m, attack)
	attacker.used_ability = null
	attacker.targeter.targets = []
	return r

func _driven_reflected(attacker, defender, attack, m) -> bool:
	attacker.targeter.targets = [defender]
	attacker.targeter.main_target = defender
	attacker.used_ability = attack
	var r: bool = attacker.reflect_check(m, attack)
	attacker.used_ability = null
	attacker.targeter.targets = []
	return r

func _clear(ch, type):
	for e in ch.effects.get_effects_by_type(type):
		ch.effects.erase_effect(e)

func _ready():
	print("=== creator counter/reflect exclude probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("BotEnemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 11, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	var me = p1.team.characters[0]   # defender: carries the counter/reflect
	var foe = p2.team.characters[0]  # attacker: drives skills into it

	var plain = _attack("Plain Harmful", foe, [])            # Harmful, NOT Strategic
	var strat = _attack("Strategic Poke", foe, ["Strategic"])  # Harmful AND Strategic

	_test_counter_exclude(m, me, foe, plain, strat)
	_test_reflect_exclude(m, me, foe, plain, strat)
	_test_prose()
	_test_validator()

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------------------
# 1. COUNTER with exclude — the saitama4 shape.
# ---------------------------------------------------------------------------
func _test_counter_exclude(m, me, foe, plain, strat):
	print("-- counter: Harmful except Strategic --")
	var carrier = _carrier("Side-Hops", me)

	# (a) Plant the counter WITH the exclusion. exclusion_targets must carry ["Strategic"].
	_clear(me, EffectType.Type.COUNTER_RECEIVE)
	_runner(carrier, m, me).run([{"op": "apply", "to": "user", "effect": {
		"kind": "counter", "scope": "harmful", "exclude": ["Strategic"], "turns": 1,
		"then": [{"op": "damage", "amount": 1, "to": "target"}]}}])
	var ce = me.has_effect("Side-Hops", EffectType.Type.COUNTER_RECEIVE, me)
	_check(ce != null, "the counter applied as COUNTER_RECEIVE")
	if ce == null:
		return
	_check(ce.class_targets == ["Harmful"], "scope 'harmful' -> class_targets ['Harmful'] (got %s)" % str(ce.class_targets))
	_check(ce.exclusion_targets == ["Strategic"], "exclude ['Strategic'] -> exclusion_targets ['Strategic'] (got %s)" % str(ce.exclusion_targets))

	# (b) NEGATIVE: a Harmful+Strategic skill is EXCLUDED — it is NOT countered, and the counter is
	#     not spent (an interception that never fired). This is what was impossible before.
	var strat_caught: bool = _driven_countered(foe, me, strat, m)
	_check(not strat_caught, "a Harmful+Strategic skill is NOT countered (the exclusion let it through)")
	_check(me.has_effect("Side-Hops", EffectType.Type.COUNTER_RECEIVE, me) != null,
		"...and the counter survived (it never fired)")

	# (c) POSITIVE control: a plain Harmful skill (no excluded class) IS still countered, and spent.
	var plain_caught: bool = _driven_countered(foe, me, plain, m)
	_check(plain_caught, "a plain Harmful skill is STILL countered (the exclusion subtracts, it does not replace)")
	_check(me.has_effect("Side-Hops", EffectType.Type.COUNTER_RECEIVE, me) == null,
		"...and default_counter_trigger spent it on the successful counter")

	# (d) HAND-REVERSE: author the SAME counter with NO `exclude` — the runner resolves it to [] and
	#     passes [] to counter_effect exactly as it did before this field existed. The identical
	#     Harmful+Strategic skill is now WRONGLY countered. The assertion flips vs (b): proof the
	#     exclude wiring — not some other filter — is what spared the strategic skill.
	_clear(me, EffectType.Type.COUNTER_RECEIVE)
	_runner(carrier, m, me).run([{"op": "apply", "to": "user", "effect": {
		"kind": "counter", "scope": "harmful", "turns": 1,
		"then": [{"op": "damage", "amount": 1, "to": "target"}]}}])
	var rev = me.has_effect("Side-Hops", EffectType.Type.COUNTER_RECEIVE, me)
	_check(rev != null and rev.exclusion_targets == [],
		"hand-reverse: with no `exclude`, exclusion_targets is [] (today's byte-for-byte behaviour)")
	var strat_caught_rev: bool = _driven_countered(foe, me, strat, m)
	_check(strat_caught_rev, "HAND-REVERSE FLIPS: without exclude the Harmful+Strategic skill is (wrongly) countered")

# ---------------------------------------------------------------------------
# 2. REFLECT with exclude — the same subtraction, on the reflect check.
# ---------------------------------------------------------------------------
func _test_reflect_exclude(m, me, foe, plain, strat):
	print("-- reflect: Harmful except Strategic --")
	var carrier = _carrier("Mirror", me)

	# Plant an unlimited (charges -1) reflect WITH the exclusion. It persists across fires, so both
	# drives read the same instance.
	_clear(me, EffectType.Type.REFLECT_RECEIVE)
	_runner(carrier, m, me).run([{"op": "apply", "to": "user", "effect": {
		"kind": "reflect", "scope": "harmful", "exclude": ["Strategic"], "destination": "attacker", "charges": -1, "turns": 2}}])
	var re = me.has_effect("Mirror", EffectType.Type.REFLECT_RECEIVE, me)
	_check(re != null, "the reflect applied as REFLECT_RECEIVE")
	if re == null:
		return
	_check(re.exclusion_targets == ["Strategic"], "reflect exclude ['Strategic'] -> exclusion_targets ['Strategic'] (got %s)" % str(re.exclusion_targets))

	var strat_reflected: bool = _driven_reflected(foe, me, strat, m)
	_check(not strat_reflected, "a Harmful+Strategic skill is NOT reflected (the exclusion let it through)")
	var plain_reflected: bool = _driven_reflected(foe, me, plain, m)
	_check(plain_reflected, "a plain Harmful skill is STILL reflected")

	# HAND-REVERSE: a reflect with no `exclude` (runner passes [] again) reflects the strategic skill.
	_clear(me, EffectType.Type.REFLECT_RECEIVE)
	_runner(carrier, m, me).run([{"op": "apply", "to": "user", "effect": {
		"kind": "reflect", "scope": "harmful", "destination": "attacker", "charges": -1, "turns": 2}}])
	var rev = me.has_effect("Mirror", EffectType.Type.REFLECT_RECEIVE, me)
	_check(rev != null and rev.exclusion_targets == [], "hand-reverse: no `exclude` -> exclusion_targets [] (byte-for-byte today)")
	var strat_reflected_rev: bool = _driven_reflected(foe, me, strat, m)
	_check(strat_reflected_rev, "HAND-REVERSE FLIPS: without exclude the Harmful+Strategic skill is (wrongly) reflected")

# ---------------------------------------------------------------------------
# 3. Generated prose — the exclude reads naturally, and the no-exclude sentence is UNCHANGED.
# ---------------------------------------------------------------------------
func _test_prose():
	print("-- generated prose --")
	var with_ex := ScriptedAbility.new()
	with_ex.ability_name = "Excl"
	with_ex.blocks = [
		{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful", "exclude": ["Strategic"], "turns": 1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}},
		{"op": "apply", "to": "user", "effect": {"kind": "reflect", "scope": "harmful", "exclude": ["Strategic"], "charges": -1, "turns": 2}},
	]
	var segs = with_ex.split_desc()
	var counter_line := str(segs[0][0]) if segs[0] is Array else str(segs[0])
	var reflect_line := str(segs[1][0]) if segs[1] is Array else str(segs[1])
	print("        counter -> " + counter_line)
	print("        reflect -> " + reflect_line)
	_check("(except Strategic)" in counter_line, "counter prose names the exclusion: '(except Strategic)'")
	_check("skill (except Strategic)" in counter_line, "...as a tail off 'skill' (reads: 'harmful skill (except Strategic)')")
	_check("(except Strategic)" in reflect_line, "reflect prose names the exclusion too")
	_check("skills (except Strategic)" in reflect_line, "...after the pluralised noun (reads: 'harmful skills (except Strategic)')")
	with_ex.free()

	# The no-exclude sentence must be BYTE-FOR-BYTE what it was before the field existed.
	var no_ex := ScriptedAbility.new()
	no_ex.ability_name = "Plain"
	no_ex.blocks = [{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful", "turns": 1,
		"then": [{"op": "damage", "amount": 1, "to": "target"}]}}]
	var plain_line := str(no_ex.split_desc()[0][0]) if no_ex.split_desc()[0] is Array else str(no_ex.split_desc()[0])
	print("        no-exclude -> " + plain_line)
	_check(not ("except" in plain_line), "a counter with NO exclude prints no 'except' clause (unchanged)")
	_check("harmful skill used on" in plain_line, "...and the sentence is exactly today's ('harmful skill used on ...')")
	no_ex.free()

# ---------------------------------------------------------------------------
# 4. Validator envelope — a valid exclude passes, an unknown excluded class is rejected, on BOTH kinds.
# ---------------------------------------------------------------------------
func _test_validator():
	print("-- validator --")
	var base := {"name": "T", "target": "self", "cost": {}, "classes": ["Harmful"], "blocks": []}

	# POSITIVE: exclude present and valid, both as a class list and as a shortcut name.
	var ok := [
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful", "exclude": ["Strategic"], "turns": 1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "counter exclude as a class list"],
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "any", "exclude": "damaging", "turns": 1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "counter exclude as a shortcut name"],
		[{"op": "apply", "to": "user", "effect": {"kind": "reflect", "scope": "harmful", "exclude": ["Strategic"], "charges": -1, "turns": 2}}, "reflect exclude as a class list"],
	]
	for pair in ok:
		var spec := base.duplicate(true)
		spec["blocks"] = [pair[0]]
		var errs := BlockValidator.validate_ability(spec)
		_check(errs.is_empty(), "accepts " + str(pair[1]) + " (%s)" % str(errs))

	# NEGATIVE: an unknown excluded class is a hard rejection (paired with each positive above).
	var bad := [
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful", "exclude": ["Nonsense"], "turns": 1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "counter excluding an unknown class"],
		[{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful", "exclude": "everything", "turns": 1,
			"then": [{"op": "damage", "amount": 1, "to": "target"}]}}, "counter exclude naming an unknown shortcut"],
		[{"op": "apply", "to": "user", "effect": {"kind": "reflect", "scope": "harmful", "exclude": ["Nonsense"], "charges": -1, "turns": 2}}, "reflect excluding an unknown class"],
	]
	for pair in bad:
		var spec := base.duplicate(true)
		spec["blocks"] = [pair[0]]
		_check(not BlockValidator.validate_ability(spec).is_empty(), "SAFETY: rejects " + str(pair[1]))
