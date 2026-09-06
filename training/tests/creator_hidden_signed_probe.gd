extends Node

# Creator probe for the two rules the Creator was enforcing that the GAME does not have:
#   godot --headless --path <repo> res://training/tests/creator_hidden_signed_probe.tscn
#
#   1. "exactly 4 skills" — 137 of the 173 shipped characters have MORE than four. The UI
#      has four SLOTS; the extras are HIDDEN and swapped in (frieza5/yoruichi5/kid6).
#   2. cost_change / cooldown_change as positive-only — 35 shipped ability files apply a
#      NEGATIVE one (mercury1 shaves 3 turns off its own cooldown).
#
# Both are asserted on observable consequences, not on the code that was edited: the
# moveset index a swap resolves to, the resolved Blue cost of a real skill, whether an
# INVULNERABLE ally keeps a discount cast on them, and what the generated prose says.

var fails := 0
var passes := 0

func _check(c, l):
	if c:
		passes += 1
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _skill(nm: String, hidden := false, passive := false) -> Dictionary:
	var d := {"name": nm, "target": "enemy", "cooldown": 0, "cost": {},
		"classes": (["Passive"] if passive else ["Instant", "Harmful", "Damaging"]),
		"blocks": [{"op": "damage", "amount": 10, "damage_type": "NORMAL"}], "requires": []}
	if passive:
		# Phase A3: a Passive is run once at battle start, before anyone has clicked a target,
		# so its blocks need an explicit `to`. These fixtures are about moveset SHAPE (how many
		# visible / hidden / passive skills a character may have), not about the aim.
		d["blocks"][0]["to"] = "all_enemies"
	if hidden:
		d["hidden"] = true
	return d

func _spec(abilities: Array) -> Dictionary:
	return {"id": "auth_probe1", "name": "Probe", "author": "probe", "status": "draft",
		"description": "", "colors": [2], "abilities": abilities}

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

func _mk(nm: String, owner):
	var a = load("res://blocks/scripted_ability.gd").new()
	a.ability_name = nm
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
	print("=== creator hidden-skills / signed-modifier probe ===")
	_counts()
	_ordering()
	_swap_reach()
	_signed_validation()
	_signed_prose_and_tags()
	_signed_runtime()
	print("=== probe done: %d passed, %d failure(s) ===" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

# =====================================================================================
# The count rule is now about SLOTS, not skills.
# =====================================================================================
func _counts():
	print("-- ability counts --")
	var four := [_skill("A"), _skill("B"), _skill("C"), _skill("D")]
	_check(AuthoredRegistry.validate_character(_spec(four.duplicate())).is_empty(),
		"4 visible actives is still valid")

	var with_hidden := four.duplicate()
	for i in range(5):
		with_hidden.append(_skill("H%d" % i, true))
	with_hidden.append(_skill("P", false, true))
	_check(AuthoredRegistry.validate_character(_spec(with_hidden)).is_empty(),
		"4 visible + 5 hidden + 1 Passive is valid (this was the rejected shape)")

	var five_visible := four.duplicate()
	five_visible.append(_skill("E"))
	_check(not AuthoredRegistry.validate_character(_spec(five_visible)).is_empty(),
		"5 VISIBLE actives is still rejected — there are only 4 slots")

	var cap: int = int(BlockSchema.LIMITS["max_abilities"])
	var over := four.duplicate()
	for i in range(cap - 3):
		over.append(_skill("X%d" % i, true))
	var over_errs := AuthoredRegistry.validate_character(_spec(over))
	_check(over.size() == cap + 1 and not over_errs.is_empty(),
		"%d abilities exceeds the ceiling (max_abilities = %d)" % [cap + 1, cap])
	var at_cap := four.duplicate()
	for i in range(cap - 4):
		at_cap.append(_skill("Y%d" % i, true))
	_check(at_cap.size() == cap and AuthoredRegistry.validate_character(_spec(at_cap)).is_empty(),
		"...and exactly %d is accepted (well past the roster's own 14)" % cap)

	# TWO Passives is legal: Character.startup_passives iterates every Passive-classed
	# ability, and gatomon (gatomon9 + gatomon14) and aiohto (aiohto5 + aiohto6) ship two.
	var two_passives := four.duplicate()
	two_passives.append(_skill("P1", false, true))
	two_passives.append(_skill("P2", false, true))
	_check(AuthoredRegistry.validate_character(_spec(two_passives)).is_empty(),
		"two Passives is accepted (gatomon and aiohto each ship two)")

# =====================================================================================
# The built moveset must be indexed the way the validator numbered it, or `swap` names a
# different skill than the one that was approved. Asserted against the REAL character.
# =====================================================================================
func _ordering():
	print("-- moveset order --")
	# Author order deliberately interleaved: hidden and Passive are NOT last in the spec.
	var defs := [_skill("V1"), _skill("H1", true), _skill("V2"), _skill("PAS", false, true),
		_skill("V3"), _skill("H2", true), _skill("V4")]
	var spec := _spec(defs)
	_check(AuthoredRegistry.validate_character(spec).is_empty(), "(setup) the interleaved spec validates")

	var want := ["V1", "V2", "V3", "V4", "PAS", "H1", "H2"]
	var ordered: Array = []
	for a in BlockValidator.moveset_order(defs):
		ordered.append(str(a.get("name", "")))
	_check(ordered == want, "moveset_order = visible, Passive, hidden (got %s)" % str(ordered))

	var c = load("res://blocks/authored_character.tscn").instantiate()
	add_child(c)
	c.configure(spec)
	var built: Array = []
	for a in c.moveset.base_abilities:
		built.append(str(a.ability_name))
	_check(built == want, "the BUILT character indexes the same way (got %s)" % str(built))
	var shown: Array = []
	for a in c.moveset.display_abilities():
		shown.append(str(a.ability_name))
	_check(shown == ["V1", "V2", "V3", "V4"],
		"display_abilities() shows only the 4 visible actives (got %s)" % str(shown))
	c.queue_free()

# =====================================================================================
# `swap`.into must be able to REACH a hidden skill — that is the entire point — while
# still refusing a Passive and anything off this character.
# =====================================================================================
func _swap_reach():
	print("-- swap reach --")
	# order: 0..3 visible, 4 Passive, 5 hidden
	var defs := [_skill("V1"), _skill("V2"), _skill("V3"), _skill("V4"),
		_skill("PAS", false, true), _skill("SECRET", true)]
	var swapper := _skill("V1")
	swapper["blocks"] = [{"op": "apply", "to": "user",
		"effect": {"kind": "swap", "slot": 0, "into": 5, "turns": 2}}]
	defs[0] = swapper
	_check(BlockValidator.validate_ability(swapper, defs).is_empty(),
		"swap into a HIDDEN skill (index 5) is accepted — it was unreachable before")

	swapper["blocks"][0]["effect"]["into"] = 4
	_check(not BlockValidator.validate_ability(swapper, defs).is_empty(),
		"swap into the Passive is still refused")
	swapper["blocks"][0]["effect"]["into"] = 6
	_check(not BlockValidator.validate_ability(swapper, defs).is_empty(),
		"swap into an index this character does not have is still refused")
	swapper["blocks"][0]["effect"]["into"] = 5
	swapper["blocks"][0]["effect"]["slot"] = 4
	_check(not BlockValidator.validate_ability(swapper, defs).is_empty(),
		"swap TARGET slot is still limited to the 4 visible slots")

# =====================================================================================
# Signed amounts.
# =====================================================================================
func _signed_validation():
	print("-- signed cost/cooldown validation --")
	var mk := func(kind: String, amt) -> Dictionary:
		var eff := {"kind": kind, "amount": amt, "turns": 2}
		if kind == "cost_change":
			eff["colour"] = "random"
		return {"name": "S", "target": "enemy", "cooldown": 0, "cost": {},
			"classes": ["Instant", "Harmful"], "requires": [],
			"blocks": [{"op": "apply", "to": "target", "effect": eff}]}
	for kind in ["cost_change", "cooldown_change"]:
		_check(BlockValidator.validate_ability(mk.call(kind, 1)).is_empty(), "%s +1 accepted" % kind)
		_check(BlockValidator.validate_ability(mk.call(kind, 2)).is_empty(), "%s +2 accepted" % kind)
		_check(BlockValidator.validate_ability(mk.call(kind, -1)).is_empty(),
			"%s -1 accepted — a DISCOUNT, which the old 1..2 range rejected outright" % kind)
		_check(BlockValidator.validate_ability(mk.call(kind, -2)).is_empty(), "%s -2 accepted" % kind)
		_check(not BlockValidator.validate_ability(mk.call(kind, 0)).is_empty(),
			"%s 0 rejected as a no-op" % kind)
		# -3 is mercury1's shipped Effect.cooldown_mod(-3, 3, ["Shine Aqua Illusion"]) — the
		# very ability the signed range was written for, and outside the old -2..2 bound.
		_check(BlockValidator.validate_ability(mk.call(kind, 3)).is_empty(), "%s +3 accepted" % kind)
		_check(BlockValidator.validate_ability(mk.call(kind, -3)).is_empty(), "%s -3 accepted (mercury1)" % kind)
		var cap: int = int(BlockSchema.LIMITS["max_amount"])
		_check(not BlockValidator.validate_ability(mk.call(kind, cap + 1)).is_empty(),
			"%s past the sanity clamp (%d) rejected" % [kind, cap])

func _signed_prose_and_tags():
	print("-- signed prose / bot tags --")
	var render := func(eff: Dictionary) -> String:
		var a = load("res://blocks/scripted_ability.gd").new()
		a.ability_name = "Probe"
		a.classes = {"Passive": false}
		a.configure({"blocks": [{"op": "apply", "to": "target", "effect": eff}], "target": "enemy"})
		return a.describe(null)

	var tax: String = render.call({"kind": "cost_change", "amount": 1, "colour": "random", "turns": 2})
	var cut: String = render.call({"kind": "cost_change", "amount": -1, "colour": "random", "turns": 2})
	_check(tax.contains("1 more Random energy"), "cost tax reads '1 more Random energy' (%s)" % tax)
	_check(cut.contains("1 less Random energy") and not cut.contains("-1"),
		"cost discount reads '1 less Random energy', not a minus sign (%s)" % cut)

	var slow: String = render.call({"kind": "cooldown_change", "amount": 2, "turns": 2})
	var fast: String = render.call({"kind": "cooldown_change", "amount": -2, "turns": 2})
	_check(slow.contains("cooldowns increased by 2"), "cooldown tax reads 'increased by 2' (%s)" % slow)
	_check(fast.contains("cooldowns reduced by 2") and not fast.contains("-2"),
		"cooldown discount reads 'reduced by 2' (%s)" % fast)

	var tags := func(eff: Dictionary) -> int:
		var a = load("res://blocks/scripted_ability.gd").new()
		a.configure({"blocks": [{"op": "apply", "to": "target", "effect": eff}]})
		return int(a.bot_tags)
	var pos: int = tags.call({"kind": "cost_change", "amount": 1, "colour": "random", "turns": 2})
	var neg: int = tags.call({"kind": "cost_change", "amount": -1, "colour": "random", "turns": 2})
	_check(pos & ScriptedAbility.TAG_CONTROL, "a cost TAX is tagged CONTROL for the bot")
	_check(not (neg & ScriptedAbility.TAG_CONTROL),
		"a cost DISCOUNT is not tagged CONTROL (no bit describes a tempo buff — see the comment)")

# =====================================================================================
# The routing consequence: the hostile path refuses an effect an invulnerable character
# does not want. A DISCOUNT is not something an ally should be able to refuse.
# =====================================================================================
func _signed_runtime():
	print("-- signed routing --")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("ProbePlayer", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("ProbeEnemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 11, BattleManager.MatchType.BOT)
	for c in p1.team.characters + p2.team.characters:
		c.bot_character = false
	var me = p1.team.characters[0]
	var ally = p1.team.characters[1]
	var foe = p2.team.characters[0]
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	# The quantity the engine actually reads. A discount off 0 is indistinguishable from
	# doing nothing, so find a skill that genuinely costs the colour being discounted.
	var ally_skill = null
	var colour_name := ""
	var colour_id := -1
	for cand in ally.moveset.base_abilities:
		for pair in [["green", Energy.Type.GREEN], ["blue", Energy.Type.BLUE],
				["white", Energy.Type.WHITE], ["red", Energy.Type.RED]]:
			if int(cand.cost()[pair[1]]) >= 1:
				ally_skill = cand
				colour_name = str(pair[0])
				colour_id = int(pair[1])
				break
		if ally_skill != null:
			break
	_check(ally_skill != null, "(setup) found an ally skill with a non-zero coloured cost")
	if ally_skill != null:
		var before: int = int(ally_skill.cost()[colour_id])
		var boon = _mk("Boon", me)
		_runner(boon, m, me).run([{"op": "apply", "to": "other_allies",
			"effect": {"kind": "cost_change", "amount": -1, "colour": colour_name, "turns": 3}}])
		_check(int(ally_skill.cost()[colour_id]) == before - 1,
			"a negative cost_change LOWERED the ally's resolved %s cost %d -> %d"
				% [colour_name, before, int(ally_skill.cost()[colour_id])])

	# The routing itself: make the ally invulnerable, then cast the discount on them.
	# add_hostile_effect would drop it (can_apply_hostile_effect fails on invuln);
	# add_allied_effect does not consult invulnerability at all.
	var ally2 = p1.team.characters[2]
	var ward = _mk("Ward", me)
	_runner(ward, m, me).run([{"op": "apply", "to": "user", "effect": {"kind": "invulnerable", "turns": 3}}])
	_runner(ward, m, ally2).run([{"op": "apply", "to": "user", "effect": {"kind": "invulnerable", "turns": 3}}])
	_check(ally2.is_invuln(), "(setup) the ally is Invulnerable")
	var gift = _mk("Gift", me)
	_runner(gift, m, me).run([{"op": "apply", "to": "other_allies",
		"effect": {"kind": "cost_change", "amount": -1, "colour": "red", "turns": 3}}])
	_check(ally2.has_effect("Gift", EffectType.Type.COST_MOD, me) != null,
		"a DISCOUNT lands on an invulnerable ALLY — it takes the allied path, not the hostile one")

	var curse = _mk("Curse", me)
	_runner(curse, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cost_change", "amount": 1, "colour": "red", "turns": 3}}])
	_check(foe.has_effect("Curse", EffectType.Type.COST_MOD, me) != null,
		"a TAX still lands on a normal enemy through the hostile path")
	var ward2 = _mk("Ward2", me)
	_runner(ward2, m, foe).run([{"op": "apply", "to": "user", "effect": {"kind": "invulnerable", "turns": 3}}])
	_check(foe.is_invuln(), "(setup) the enemy is Invulnerable")
	var curse2 = _mk("Curse2", me)
	_runner(curse2, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cost_change", "amount": 2, "colour": "red", "turns": 3}}])
	_check(foe.has_effect("Curse2", EffectType.Type.COST_MOD, me) == null,
		"...and a TAX is still REFUSED by an invulnerable enemy — the hostile gating is intact")
