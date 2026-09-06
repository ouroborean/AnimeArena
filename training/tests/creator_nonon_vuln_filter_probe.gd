extends Node

# ============================================================================
# CREATOR — the DAMAGE-TYPE-FILTERABLE `vulnerability` kind.
#   godot --headless --path <repo> res://training/tests/creator_nonon_vuln_filter_probe.tscn
#
# The gap Creator Roulette 11 (Nonon Jakuzure) found. The block `vulnerability` kind could only make
# the target take `amount` more of EVERY damage type. nonon1 (Flute Missile) needs the FILTERED shape:
#   Effect.vulnerability_effect(5, 4, [], [], [DamageType.Type.AFFLICTION])
# +5 to every NON-Affliction hit the target receives (Affliction is spared).
#
# The engine factory + get_true_damage ALREADY have the axis: a VULNERABILITY effect's class_targets is
# honoured as an INCLUDE damage-type list and exclusion_targets as an EXCLUDE one (ability_component.gd
# :800-811), BYTE-FOR-BYTE the DAMAGE_MOD arm at :737-751. This build EXPOSES those two axes on the
# block kind by REUSING the damage_boost machinery whole (_damage_type_list / _validate_damage_type_list
# / _damage_type_phrase / the creatorDamageTypeList editor). UNLIKE damage_boost there is NO sign axis:
# a vulnerability is always "more damage taken", so `amount` stays unsigned and `hostile` stays true.
#
# This probe proves the authored kind lands a real, correctly FILTERED number through get_true_damage —
# the exact call resolve_damage makes. Structure: the nonon1 shape (Affliction spared, everything else
# +5), an unfiltered POSITIVE control (still lifts every type — today's byte-for-byte behaviour), an
# include_types axis (only the named type is raised), a HAND-REVERSE (drop exclude_types -> the runner
# passes [] and the Affliction hit is now WRONGLY raised too, the assertion flips — proof the wiring is
# load-bearing), the generated prose, and the validator envelope.
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

# The carrier ability the VULNERABILITY effect is SOURCED from — a real moveset member, because
# apply_effect couples an effect to its source ability and has_effect keys on the source name.
func _carrier(name, owner):
	var a := ScriptedAbility.new()
	a.ability_name = name
	a.blocks = []
	a.classes = Ability.default_classes()
	a.user = owner
	owner.moveset.add_ability(a)
	return a

# A plain single-target attack, used only as the damager's used_ability so get_true_damage has a source
# name to read. The block amount is irrelevant — the probe passes its own base damage in.
func _attack(name, owner):
	var a := ScriptedAbility.new()
	a.configure({"name": name, "target": "enemy", "blocks": [{"op": "damage", "amount": 5, "to": "target"}]})
	a.ability_name = name
	a.classes = Ability.default_classes()
	a.classes["Harmful"] = true
	a.classes["Instant"] = true
	a.user = owner
	owner.moveset.add_ability(a)
	return a

# A VULNERABILITY sits on the VICTIM (get_true_damage reads target.effects), so this clears the victim.
func _clear_vuln(ch):
	for e in ch.effects.get_effects_by_type(EffectType.Type.VULNERABILITY):
		ch.effects.erase_effect(e)

# Aim `caster` at `victim`, run the apply block through the runner (hostile routing decided per-candidate
# by user.is_hostile, exactly as _op_apply does), then clear the transient aim.
func _apply_to(caster, victim, m, carrier, effect_spec):
	caster.targeter.targets = [victim]
	caster.targeter.main_target = victim
	_runner(carrier, m, caster).run([{"op": "apply", "to": "target", "effect": effect_spec}])
	caster.targeter.targets = []

# The damage `damager` would actually deal to `target` for a hit of `dtype`, through the SAME
# get_true_damage resolve_damage calls. `base` is the pre-modifier amount.
func _dealt(damager, target, attack, base, dtype) -> int:
	damager.used_ability = attack
	var r: int = attack.get_true_damage(damager, target, base, null, dtype)
	damager.used_ability = null
	return r

func _ready():
	print("=== creator filterable vulnerability probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("ZZ_Caster", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("ZZ_Enemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 11, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	var me = p1.team.characters[0]    # caster + damager: applies the vulnerability, then hits
	var foe = p2.team.characters[0]   # the VICTIM the vulnerability sits on
	var my_atk = _attack("My Strike", me)

	_test_nonon1_excludes(m, me, foe, my_atk)
	_test_unfiltered_control(m, me, foe, my_atk)
	_test_include_types_axis(m, me, foe, my_atk)
	_test_hand_reverse(m, me, foe, my_atk)
	_test_prose()
	_test_validator()

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------------------
# 1. The nonon1 "Flute Missile" shape — +5 to every NON-Affliction hit the victim
#    takes; the Affliction hit is untouched.
# ---------------------------------------------------------------------------
func _test_nonon1_excludes(m, me, foe, my_atk):
	print("-- nonon1: vulnerability, exclude_types [AFFLICTION] --")
	var carrier = _carrier("Flute Missile", me)
	_clear_vuln(foe)
	_apply_to(me, foe, m, carrier, {"kind": "vulnerability", "amount": 5, "exclude_types": ["AFFLICTION"], "turns": 2})

	var v = foe.has_effect("Flute Missile", EffectType.Type.VULNERABILITY, me)
	_check(v != null, "the vulnerability applied to the VICTIM as a hostile VULNERABILITY")
	if v == null:
		return
	_check(v.mag == 5, "an unsigned amount became mag +5 (%d)" % v.mag)
	_check(v.exclusion_targets == [DamageType.Type.AFFLICTION],
		"exclude_types ['AFFLICTION'] -> exclusion_targets [AFFLICTION] (got %s)" % str(v.exclusion_targets))
	_check(v.class_targets == [], "include_types absent -> class_targets [] (no include filter)")

	# The real damage numbers through get_true_damage.
	var normal := _dealt(me, foe, my_atk, 20, DamageType.Type.NORMAL)
	var phys := _dealt(me, foe, my_atk, 20, DamageType.Type.PHYSICAL)
	var affl := _dealt(me, foe, my_atk, 20, DamageType.Type.AFFLICTION)
	_check(normal == 25, "a 20 NORMAL hit is raised to 25 (vulnerable)")
	_check(phys == 25, "a 20 PHYSICAL hit is raised to 25 (the exclusion is only Affliction)")
	_check(affl == 20, "a 20 AFFLICTION hit is UNCHANGED (the excluded type is spared)")

# ---------------------------------------------------------------------------
# 2. UNFILTERED control — a plain vulnerability still raises EVERY type,
#    byte-for-byte today's behaviour (this is what must not change).
# ---------------------------------------------------------------------------
func _test_unfiltered_control(m, me, foe, my_atk):
	print("-- unfiltered vulnerability (control) --")
	var carrier = _carrier("Plain Weakness", me)
	_clear_vuln(foe)
	_apply_to(me, foe, m, carrier, {"kind": "vulnerability", "amount": 5, "turns": 2})
	var v = foe.has_effect("Plain Weakness", EffectType.Type.VULNERABILITY, me)
	_check(v != null and v.mag == 5, "a plain vulnerability has mag +5")
	_check(v != null and v.class_targets == [] and v.exclusion_targets == [],
		"no filters -> both type lists empty (unfiltered, today's behaviour)")
	var normal := _dealt(me, foe, my_atk, 20, DamageType.Type.NORMAL)
	var affl := _dealt(me, foe, my_atk, 20, DamageType.Type.AFFLICTION)
	_check(normal == 25, "a 20 NORMAL hit is raised to 25")
	_check(affl == 25, "a 20 AFFLICTION hit is ALSO raised to 25 (unfiltered vulnerability touches every type)")

# ---------------------------------------------------------------------------
# 3. include_types axis — only the named type takes more; others are untouched.
# ---------------------------------------------------------------------------
func _test_include_types_axis(m, me, foe, my_atk):
	print("-- vulnerability, include_types [NORMAL] --")
	var carrier = _carrier("Normal Weakness", me)
	_clear_vuln(foe)
	_apply_to(me, foe, m, carrier, {"kind": "vulnerability", "amount": 5, "include_types": ["NORMAL"], "turns": 2})
	var v = foe.has_effect("Normal Weakness", EffectType.Type.VULNERABILITY, me)
	_check(v != null and v.class_targets == [DamageType.Type.NORMAL],
		"include_types ['NORMAL'] -> class_targets [NORMAL] (got %s)" % (str(v.class_targets) if v else "null"))
	var normal := _dealt(me, foe, my_atk, 20, DamageType.Type.NORMAL)
	var phys := _dealt(me, foe, my_atk, 20, DamageType.Type.PHYSICAL)
	_check(normal == 25, "a 20 NORMAL hit is raised to 25 (the included type IS modified)")
	_check(phys == 20, "a 20 PHYSICAL hit is UNCHANGED (a type outside the include list is not touched)")

# ---------------------------------------------------------------------------
# 4. HAND-REVERSE — author the SAME vulnerability with NO exclude_types. The runner
#    resolves it to [] and passes [] to the factory exactly as before this field
#    existed, so the Affliction hit is now WRONGLY raised. The assertion FLIPS vs
#    (1): proof the exclude_types wiring — not some other filter — spared it.
# ---------------------------------------------------------------------------
func _test_hand_reverse(m, me, foe, my_atk):
	print("-- hand-reverse: drop exclude_types --")
	var carrier = _carrier("Unfiltered Missile", me)
	_clear_vuln(foe)
	_apply_to(me, foe, m, carrier, {"kind": "vulnerability", "amount": 5, "turns": 2})
	var v = foe.has_effect("Unfiltered Missile", EffectType.Type.VULNERABILITY, me)
	_check(v != null and v.exclusion_targets == [],
		"with no exclude_types, exclusion_targets is [] (today's byte-for-byte behaviour)")
	var affl := _dealt(me, foe, my_atk, 20, DamageType.Type.AFFLICTION)
	_check(affl == 25, "HAND-REVERSE FLIPS: without exclude_types the AFFLICTION hit is (wrongly) raised to 25")

# ---------------------------------------------------------------------------
# 5. Generated prose — filtered reads "non-Affliction"; unfiltered UNCHANGED.
# ---------------------------------------------------------------------------
func _test_prose():
	print("-- generated prose --")
	var flute := ScriptedAbility.new()
	flute.ability_name = "F"
	flute.blocks = [{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "exclude_types": ["AFFLICTION"], "turns": 2}}]
	var fline := str(flute.split_desc()[0][0]) if flute.split_desc()[0] is Array else str(flute.split_desc()[0])
	print("        filtered   -> " + fline)
	_check("5 more non-Affliction damage" in fline, "the exclude_types filter reads '5 more non-Affliction damage'")
	flute.free()

	# The unfiltered sentence must be BYTE-FOR-BYTE what it was before the filter fields existed.
	var plain := ScriptedAbility.new()
	plain.ability_name = "P"
	plain.blocks = [{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "turns": 2}}]
	var pline := str(plain.split_desc()[0][0]) if plain.split_desc()[0] is Array else str(plain.split_desc()[0])
	print("        unfiltered -> " + pline)
	_check("5 more damage" in pline, "an unfiltered vulnerability still reads 'X more damage' (unchanged)")
	_check(not ("non-" in pline), "...with no filter words leaking into the unfiltered sentence")
	plain.free()

# ---------------------------------------------------------------------------
# 6. Validator envelope — valid types pass; unknown types, ability classes and an
#    empty list rejected. (amount stays unsigned — no sign axis to test.)
# ---------------------------------------------------------------------------
func _test_validator():
	print("-- validator --")
	var base := {"name": "T", "target": "enemy", "cost": {}, "classes": ["Harmful"], "blocks": []}

	var ok := [
		[{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "exclude_types": ["AFFLICTION"], "turns": 2}}, "vulnerability with exclude_types (nonon1)"],
		[{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "include_types": ["NORMAL", "PHYSICAL"], "turns": 2}}, "vulnerability with include_types"],
		[{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "turns": 2}}, "plain unfiltered vulnerability"],
	]
	for pair in ok:
		var spec := base.duplicate(true)
		spec["blocks"] = [pair[0]]
		var errs := BlockValidator.validate_ability(spec)
		_check(errs.is_empty(), "accepts " + str(pair[1]) + " (%s)" % str(errs))

	var bad := [
		[{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "exclude_types": ["NONSENSE"], "turns": 2}}, "exclude_types naming an unknown damage type"],
		[{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "include_types": ["Harmful"], "turns": 2}}, "include_types naming an ability class (not a damage type)"],
		[{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "exclude_types": [], "turns": 2}}, "an EMPTY exclude_types list (a filter that names nothing)"],
	]
	for pair in bad:
		var spec := base.duplicate(true)
		spec["blocks"] = [pair[0]]
		_check(not BlockValidator.validate_ability(spec).is_empty(), "SAFETY: rejects " + str(pair[1]))
