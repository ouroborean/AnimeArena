extends Node

# ============================================================================
# CREATOR — the SIGNED, DAMAGE-TYPE-FILTERABLE `damage_boost` kind.
#   godot --headless --path <repo> res://training/tests/creator_damage_weaken_probe.tscn
#
# The gap Creator Roulette 10 (LadyDevimon) found. The block `damage_boost` kind could only
# BOOST an ally's damage (hostile:false, amount clamped 0..max) and its only filter was `skills`
# (an ability NAME list). ladydevimon3 (Darkness Spear) needs the opposite AND a type filter:
#   Effect.damage_mod_effect(-10, 2, [], [], [DamageType.Type.AFFLICTION])
# a HOSTILE weaken (negative mag) that reduces every NON-Affliction hit the ENEMY deals.
#
# The engine factory ALREADY has every axis — get_true_damage sums a negative DAMAGE_MOD off the
# damager (ability_component.gd:730-789), honours class_targets as an INCLUDE damage-type list
# (:737) and exclusion_targets as an EXCLUDE one (:749). This build EXPOSES those axes on the block
# kind: `amount` is now signed (HOSTILE_BY_SIGN, mirroring cost_change), and include_types /
# exclude_types thread class_targets / exclusion_targets. This probe proves the authored kind lands
# a real, correctly FILTERED damage number through get_true_damage — the exact call resolve_damage
# makes — nothing unit-tested in isolation.
#
# Structure: a NEGATIVE weaken with exclude_types (Affliction is spared, everything else is cut), a
# POSITIVE control (an unfiltered ally boost still lifts every type), an include_types axis (only the
# named type is cut), and a HAND-REVERSE (drop exclude_types -> the runner passes [] and the Affliction
# hit is now WRONGLY reduced too, the assertion flips — proof the type wiring is load-bearing). Plus
# prose (positive/unfiltered byte-identical; negative+filter reads as a weaken) and the validator envelope.
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

# The carrier ability the DAMAGE_MOD effect is SOURCED from — a real moveset member, because
# apply_effect couples an effect to its source ability and has_effect keys on the source name.
func _carrier(name, owner):
	var a := ScriptedAbility.new()
	a.ability_name = name
	a.blocks = []
	a.classes = Ability.default_classes()
	a.user = owner
	owner.moveset.add_ability(a)
	return a

# A plain single-target enemy attack, used only as the damager's used_ability so get_true_damage has
# a source name to read. The block amount is irrelevant — the probe passes its own base damage in.
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

func _clear(ch):
	for e in ch.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD):
		ch.effects.erase_effect(e)

# Aim `caster` at `victim`, run the given apply block through the runner (hostile routing is decided
# per-candidate by user.is_hostile, exactly as _op_apply does), then clear the transient aim.
func _apply_to(caster, victim, m, carrier, effect_spec):
	caster.targeter.targets = [victim]
	caster.targeter.main_target = victim
	_runner(carrier, m, caster).run([{"op": "apply", "to": "target", "effect": effect_spec}])
	caster.targeter.targets = []

# The damage `damager` would actually deal for a hit of `dtype`, through the SAME get_true_damage
# resolve_damage calls. `base` is the pre-modifier amount.
func _dealt(damager, target, attack, base, dtype) -> int:
	damager.used_ability = attack
	var r: int = attack.get_true_damage(damager, target, base, null, dtype)
	damager.used_ability = null
	return r

func _ready():
	print("=== creator signed/filterable damage_boost probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("ZZ_Caster", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("ZZ_Enemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 11, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	var me = p1.team.characters[0]    # caster: applies the weaken / boost
	var foe = p2.team.characters[0]   # the ENEMY damager the weaken sits on
	var foe_atk = _attack("Foe Strike", foe)
	var my_atk = _attack("My Strike", me)

	_test_negative_weaken_excludes(m, me, foe, foe_atk)
	_test_positive_boost_unfiltered(m, me, my_atk)
	_test_include_types_axis(m, me, foe, foe_atk)
	_test_hand_reverse(m, me, foe, foe_atk)
	_test_prose()
	_test_validator()

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------------------
# 1. NEGATIVE weaken with exclude_types — the ladydevimon3 shape.
#    -10 to every NON-Affliction hit; the Affliction hit is untouched.
# ---------------------------------------------------------------------------
func _test_negative_weaken_excludes(m, me, foe, foe_atk):
	print("-- negative weaken, exclude_types [AFFLICTION] --")
	var carrier = _carrier("Darkness Spear", me)
	_clear(foe)
	_apply_to(me, foe, m, carrier, {"kind": "damage_boost", "amount": -10, "exclude_types": ["AFFLICTION"], "turns": 1})

	var w = foe.has_effect("Darkness Spear", EffectType.Type.DAMAGE_MOD, me)
	_check(w != null, "the weaken applied to the ENEMY as a hostile DAMAGE_MOD")
	if w == null:
		return
	_check(w.mag == -10, "a negative amount became a negative mag (%d)" % w.mag)
	_check(w.exclusion_targets == [DamageType.Type.AFFLICTION],
		"exclude_types ['AFFLICTION'] -> exclusion_targets [AFFLICTION] (got %s)" % str(w.exclusion_targets))
	_check(w.class_targets == [], "include_types absent -> class_targets [] (no include filter)")

	# The real damage numbers through get_true_damage.
	var normal := _dealt(foe, me, foe_atk, 20, DamageType.Type.NORMAL)
	var phys := _dealt(foe, me, foe_atk, 20, DamageType.Type.PHYSICAL)
	var affl := _dealt(foe, me, foe_atk, 20, DamageType.Type.AFFLICTION)
	_check(normal == 10, "a 20 NORMAL hit is reduced to 10 (weakened)")
	_check(phys == 10, "a 20 PHYSICAL hit is reduced to 10 (weakened — the exclusion is only Affliction)")
	_check(affl == 20, "a 20 AFFLICTION hit is UNCHANGED (the excluded type is spared)")

# ---------------------------------------------------------------------------
# 2. POSITIVE control — an unfiltered self/ally boost still lifts EVERY type,
#    byte-for-byte today's behaviour (this is what must not change).
# ---------------------------------------------------------------------------
func _test_positive_boost_unfiltered(m, me, my_atk):
	print("-- positive boost, no filter (control) --")
	var carrier = _carrier("Power Up", me)
	_clear(me)
	# to:"user" -> a positive (allied) boost on the caster itself.
	_runner(carrier, m, me).run([{"op": "apply", "to": "user", "effect": {"kind": "damage_boost", "amount": 10, "turns": 1}}])
	var b = me.has_effect("Power Up", EffectType.Type.DAMAGE_MOD, me)
	_check(b != null and b.mag == 10, "a positive amount is an allied boost with mag +10")
	_check(b != null and b.class_targets == [] and b.exclusion_targets == [],
		"no filters -> both type lists empty (unfiltered, today's behaviour)")
	var normal := _dealt(me, me, my_atk, 20, DamageType.Type.NORMAL)
	var affl := _dealt(me, me, my_atk, 20, DamageType.Type.AFFLICTION)
	_check(normal == 30, "a 20 NORMAL hit is boosted to 30")
	_check(affl == 30, "a 20 AFFLICTION hit is ALSO boosted to 30 (unfiltered boost touches every type)")

# ---------------------------------------------------------------------------
# 3. include_types axis — only the named type is modified; others are untouched.
# ---------------------------------------------------------------------------
func _test_include_types_axis(m, me, foe, foe_atk):
	print("-- negative weaken, include_types [NORMAL] --")
	var carrier = _carrier("Focused Weaken", me)
	_clear(foe)
	_apply_to(me, foe, m, carrier, {"kind": "damage_boost", "amount": -10, "include_types": ["NORMAL"], "turns": 1})
	var w = foe.has_effect("Focused Weaken", EffectType.Type.DAMAGE_MOD, me)
	_check(w != null and w.class_targets == [DamageType.Type.NORMAL],
		"include_types ['NORMAL'] -> class_targets [NORMAL] (got %s)" % (str(w.class_targets) if w else "null"))
	var normal := _dealt(foe, me, foe_atk, 20, DamageType.Type.NORMAL)
	var phys := _dealt(foe, me, foe_atk, 20, DamageType.Type.PHYSICAL)
	_check(normal == 10, "a 20 NORMAL hit is reduced to 10 (the included type IS modified)")
	_check(phys == 20, "a 20 PHYSICAL hit is UNCHANGED (a type outside the include list is not touched)")

# ---------------------------------------------------------------------------
# 4. HAND-REVERSE — author the SAME weaken with NO exclude_types. The runner
#    resolves it to [] and passes [] to the factory exactly as before this field
#    existed, so the Affliction hit is now WRONGLY reduced. The assertion FLIPS
#    vs (1): proof the exclude_types wiring — not some other filter — spared it.
# ---------------------------------------------------------------------------
func _test_hand_reverse(m, me, foe, foe_atk):
	print("-- hand-reverse: drop exclude_types --")
	var carrier = _carrier("Unfiltered Weaken", me)
	_clear(foe)
	_apply_to(me, foe, m, carrier, {"kind": "damage_boost", "amount": -10, "turns": 1})
	var w = foe.has_effect("Unfiltered Weaken", EffectType.Type.DAMAGE_MOD, me)
	_check(w != null and w.exclusion_targets == [],
		"with no exclude_types, exclusion_targets is [] (today's byte-for-byte behaviour)")
	var affl := _dealt(foe, me, foe_atk, 20, DamageType.Type.AFFLICTION)
	_check(affl == 10, "HAND-REVERSE FLIPS: without exclude_types the AFFLICTION hit is (wrongly) reduced to 10")

# ---------------------------------------------------------------------------
# 5. Generated prose — negative+filter reads as a weaken; positive/unfiltered UNCHANGED.
# ---------------------------------------------------------------------------
func _test_prose():
	print("-- generated prose --")
	var weak := ScriptedAbility.new()
	weak.ability_name = "W"
	weak.blocks = [{"op": "apply", "to": "target", "effect": {"kind": "damage_boost", "amount": -10, "exclude_types": ["AFFLICTION"], "turns": 1}}]
	var wline := str(weak.split_desc()[0][0]) if weak.split_desc()[0] is Array else str(weak.split_desc()[0])
	print("        weaken -> " + wline)
	_check("less" in wline, "a negative amount reads 'less' (a weaken)")
	_check("non-Affliction" in wline, "the exclude_types filter reads 'non-Affliction'")
	_check(not ("-10" in wline), "the magnitude prints as 10, never '-10 less'")
	weak.free()

	# The positive / unfiltered sentence must be BYTE-FOR-BYTE what it was before signed/filter support.
	var boost := ScriptedAbility.new()
	boost.ability_name = "B"
	boost.blocks = [{"op": "apply", "to": "user", "effect": {"kind": "damage_boost", "amount": 10, "turns": 1}}]
	var bline := str(boost.split_desc()[0][0]) if boost.split_desc()[0] is Array else str(boost.split_desc()[0])
	print("        boost  -> " + bline)
	_check("10 more damage" in bline, "an unfiltered positive boost still reads 'X more damage' (unchanged)")
	_check(not ("non-" in bline) and not ("less" in bline), "...with no filter/weaken words leaking in")
	boost.free()

# ---------------------------------------------------------------------------
# 6. Validator envelope — signed amount + valid types pass; 0 and unknown types rejected.
# ---------------------------------------------------------------------------
func _test_validator():
	print("-- validator --")
	var base := {"name": "T", "target": "enemy", "cost": {}, "classes": ["Harmful"], "blocks": []}

	var ok := [
		[{"op": "apply", "to": "target", "effect": {"kind": "damage_boost", "amount": -10, "exclude_types": ["AFFLICTION"], "turns": 1}}, "negative weaken with exclude_types"],
		[{"op": "apply", "to": "target", "effect": {"kind": "damage_boost", "amount": -10, "include_types": ["NORMAL", "PHYSICAL"], "turns": 1}}, "negative weaken with include_types"],
		[{"op": "apply", "to": "user", "effect": {"kind": "damage_boost", "amount": 15, "turns": 1}}, "plain positive boost, no filter"],
	]
	for pair in ok:
		var spec := base.duplicate(true)
		spec["blocks"] = [pair[0]]
		var errs := BlockValidator.validate_ability(spec)
		_check(errs.is_empty(), "accepts " + str(pair[1]) + " (%s)" % str(errs))

	var bad := [
		[{"op": "apply", "to": "target", "effect": {"kind": "damage_boost", "amount": -10, "exclude_types": ["NONSENSE"], "turns": 1}}, "exclude_types naming an unknown damage type"],
		[{"op": "apply", "to": "target", "effect": {"kind": "damage_boost", "amount": -10, "include_types": ["Harmful"], "turns": 1}}, "include_types naming an ability class (not a damage type)"],
		[{"op": "apply", "to": "user", "effect": {"kind": "damage_boost", "amount": 0, "turns": 1}}, "a 0 amount (signed kinds reject the inert value)"],
		[{"op": "apply", "to": "target", "effect": {"kind": "damage_boost", "amount": -10, "exclude_types": [], "turns": 1}}, "an EMPTY exclude_types list (a filter that names nothing)"],
	]
	for pair in bad:
		var spec := base.duplicate(true)
		spec["blocks"] = [pair[0]]
		_check(not BlockValidator.validate_ability(spec).is_empty(), "SAFETY: rejects " + str(pair[1]))
