extends Node

# Creator palette probe — the OBSERVABLE half of the block-palette expansion.
#   godot --headless --path <repo> res://training/tests/creator_palette_probe.tscn
#
# Deliberately not a mirror of creator_expansion_probe: that one proves the blocks build the
# right Effect objects (field X reached factory argument Y). This one refuses to look at the
# effect at all where it can avoid it, and asserts what a PLAYER would see instead — HP moved,
# a slot shows a different skill, the enemy's skill never resolved, the cost went up. A block
# that constructs a perfect Effect the engine then ignores is exactly the _op_damage bug, and
# only an outcome assertion catches it.
#
# Everything runs against a real BattleManager with real characters, and the enemy's attacks
# go through battle_manager.execute_ability — the same entry point a live match uses.

var fails := 0
var passes := 0

func _check(c, l):
	if c:
		passes += 1
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

# An authored ability really attached to a character. moveset.add_ability appends to the array
# that IS base_abilities (set_base_abilities aliases the two), which is what lets `swap` pass
# apply_effect's "source must be in base_abilities" gate.
func _mk(nm: String, owner, harmful := true, physical := false):
	var a = load("res://blocks/scripted_ability.gd").new()
	a.ability_name = nm
	a.blocks = []
	a.classes = {"Physical": physical, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": false, "Harmful": harmful, "Helpful": false, "Instant": true, "Action": false,
		"Control": false, "Channeled": false, "Uncounterable": false, "Bypassing": false,
		"Stealthed": false, "Passive": false, "Preserves Channel": false, "Damaging": harmful}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _runner(ab, m, who):
	return load("res://blocks/block_runner.gd").new(ab, m, who)

func _heal_full(c):
	c.dead = false
	c.banished = false
	c.health.hp = c.health.max_hp

func _ready():
	print("=== creator palette probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("BotEnemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 11, BattleManager.MatchType.BOT)
	# The probe drives blocks directly, so leave the human path in place.
	for c in p1.team.characters:
		c.bot_character = false
	for c in p2.team.characters:
		c.bot_character = false

	var me = p1.team.characters[0]
	var foe = p2.team.characters[0]
	var foe2 = p2.team.characters[1]
	var foe3 = p2.team.characters[2]
	# "target" reads the caster's live targeter; without this every to:"target" block resolves
	# to an empty list and silently does nothing.
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	_stacks(m, me, foe)
	_swap(m, me)
	_counter(m, me, foe)
	_compare(m, me, foe, foe2, foe3)
	_restrictions(m, me, foe, foe2)
	_boost_filter(m, me, foe3)
	_bypassing(m, me, foe3)
	_taunt(m, me, foe, foe2)
	_immunity_break_cleanse_energy(m, me, foe, foe3)
	_triggers(m, me, foe)
	_trigger_rename_proof(m, me, foe)
	_universal_fields(m, me, foe, foe3)
	_filtered_selectors(m, me, foe, foe2, foe3)
	_remove_op(m, me, foe, foe2, foe3)
	_hidden_slots()
	_signed_modifiers(m, me, p1, foe2)
	# THE AUDIT. Everything below proves the bounds that were removed or raised are
	# really gone, and that the ones deliberately KEPT still bite.
	_removed_bounds_validate()
	_kept_guards()
	_removed_bounds_live(m, me, foe, foe3)
	# LAST on purpose: each stands up its OWN BattleManager, so nothing above can be
	# disturbed by them no matter what start_battle touches.
	_hidden_swap_live()
	_removed_bounds_live_character()

	print("=== probe done: %d passed, %d failure(s) ===" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

# =====================================================================================
# stacks-as-a-resource, and STACKING AS AN EMERGENT PROPERTY. Two claims:
#   (1) `stacks_at_least` is satisfiable at all — Effect.mark leaves stackable false, so no
#       authored mark could ever hold a second stack until the mark branch forced it true.
#   (2) stacking is NOT a mark concept and NOT an operation. There is no `stack` op; a
#       re-application of ANY effect whose `stackable` is true merges into the stored one
#       (effect_storage_component.add_effect), and `stackable` is a universal effect field.
# =====================================================================================
func _stacks(m, me, foe):
	print("-- stacks --")
	var ab = _mk("Charge Mark", me, false)
	var r = _runner(ab, m, me)
	var bank := {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 6, "text": "Charge", "stacks": 1, "max": 3, "show_stacks": true}}
	var at3 := {"cond": "stacks_at_least", "name": "Charge Mark", "value": 3, "on": "user"}

	r.run([bank])
	var mk = me.has_effect("Charge Mark", EffectType.Type.MARK, me)
	_check(mk != null and mk.stack_count() == 1, "one cast banks 1 stack")
	_check(not r.check_condition_public(at3), "stacks_at_least(3) is FALSE at 1 stack")
	r.run([bank])
	_check(mk != null and mk.stack_count() == 2, "a second cast accumulates to 2 (got %d)" % (mk.stack_count() if mk != null else -1))
	_check(not r.check_condition_public(at3), "...still false at 2")
	r.run([bank])
	_check(mk != null and mk.stack_count() == 3, "a third cast reaches 3 (got %d)" % (mk.stack_count() if mk != null else -1))
	# The flip is the assertion: this condition could not be satisfied by ANY authored tree before.
	_check(r.check_condition_public(at3), "stacks_at_least(3) FLIPPED to true — the condition is live")

	r.run([bank])
	_check(mk != null and mk.stack_count() == 3, "a fourth cast clamps at max 3 (got %d)" % (mk.stack_count() if mk != null else -1))

	# --- the `stack` op is GONE -------------------------------------------------
	# Not "deprecated" and not "ignored at runtime only": it is off the palette, the
	# validator refuses it, and the runner has no branch for it. Both halves are asserted,
	# because a palette entry removed while a runner branch survives is exactly the kind of
	# half-removal that leaves a hand-edited file able to reach dead code.
	_check(not BlockSchema.OPS.has("stack"), "the `stack` op is OFF the palette")
	var old_op := _authored("Old Stack Op")
	old_op["blocks"] = [{"op": "stack", "name": "Charge Mark", "delta": 1, "to": "user"}]
	_check(not _valid(old_op), "...the validator REJECTS a block that uses it")
	var held: int = mk.stack_count() if mk != null else -1
	r.run([{"op": "stack", "name": "Charge Mark", "delta": -1, "to": "user"}])
	_check(mk != null and mk.stack_count() == held,
		"...and the runner does not secretly still honour it (still %d)" % (mk.stack_count() if mk != null else -1))
	if mk != null:
		mk.end_effect()

	# --- stacking is EMERGENT, and works for ANY kind ---------------------------
	# DAMAGE_REDUCTION, not a mark and not a shield. The kind matters: the old op could only
	# ever poke a MARK's counter, which is what made stacking look like a mark feature — and
	# Effect.shield_effect/barrier_effect set `stackable` THEMSELVES, so a shield would have
	# stacked with or without this change and would prove nothing. damage_reduction_effect
	# leaves the flag at its false default, so the ONLY thing that can make this merge is the
	# universal `stackable` field arriving from the block.
	var layered = _mk("Layered Ward", me, false)
	var lr = _runner(layered, m, me)
	var stack_ward := {"op": "apply", "to": "user",
		"effect": {"kind": "damage_reduction", "amount": 5, "turns": 6, "stackable": true, "stack_mag": true}}
	lr.run([stack_ward])
	var dr = me.has_effect("Layered Ward", EffectType.Type.DAMAGE_REDUCTION, me)
	_check(dr != null and dr.stack_count() == 1 and dr.mag == 5,
		"(baseline) one cast is 5 reduction at 1 stack (mag %d)" % (dr.mag if dr != null else -1))
	lr.run([stack_ward])
	_check(dr != null and dr.stack_count() == 2,
		"A NON-MARK EFFECT STACKED — damage_reduction accumulated to 2 stacks (got %d)" % (dr.stack_count() if dr != null else -1))
	_check(dr != null and dr.mag == 10,
		"...and stack_mag carried the magnitude with it: 5 -> %d" % (dr.mag if dr != null else -1))

	# The contrast, so the assertion above cannot pass by accident: without `stackable` the
	# identical pair of casts stores two separate effects instead of merging.
	var plain = _mk("Plain Ward", me, false)
	var pr = _runner(plain, m, me)
	var plain_ward := {"op": "apply", "to": "user", "effect": {"kind": "damage_reduction", "amount": 5, "turns": 6}}
	pr.run([plain_ward])
	pr.run([plain_ward])
	var plains := 0
	for e in me.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION):
		if str(e.effect_name()) == "Plain Ward":
			plains += 1
	_check(plains == 2, "...and WITHOUT `stackable` the same two casts do NOT merge (%d effects)" % plains)
	for e in me.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION):
		e.end_effect()

# =====================================================================================
# swap. The observable is the SLOT: what the character can actually press changes.
# =====================================================================================
func _swap(m, me):
	print("-- swap --")
	var form = _mk("Second Form", me, false)
	var morph = _mk("Morph", me, false)
	var into: int = me.moveset.base_abilities.find(form)
	var slot0_before: String = str(me.moveset.get_active_abilities(me)[0].ability_name)
	_check(slot0_before != "Second Form", "(setup) slot 0 starts as %s" % slot0_before)

	_runner(morph, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "swap", "slot": 0, "into": into, "turns": 3}}])
	var sw = me.has_effect("Morph", EffectType.Type.ABILITY_SWAP, me)
	_check(sw != null, "the swap survived apply_effect's base_abilities gate")
	if sw == null:
		return
	_check(str(me.moveset.get_active_abilities(me)[0].ability_name) == "Second Form",
		"SLOT 0 NOW SHOWS 'Second Form' (was %s)" % slot0_before)
	_check(sw.duration == 7, "\"3 turns\" for a swap is duration 7, not 6 (got %d)" % sw.duration)
	sw.end_effect()
	_check(str(me.moveset.get_active_abilities(me)[0].ability_name) == slot0_before,
		"...and ending the swap restores the original slot")

# =====================================================================================
# counter. Not "the trigger ran" — the enemy's skill must never resolve.
# Both attacks go through battle_manager.execute_ability, the live-match entry point.
# =====================================================================================
func _counter(m, me, foe):
	print("-- counter --")
	var strike = _mk("Enemy Strike", foe)
	strike.blocks = [{"op": "damage", "amount": 25, "to": "target"}]

	# Baseline: with no counter up, the very same call takes 25 off me.
	_heal_full(me)
	foe.targeter.targets = [me]
	foe.targeter.main_target = me
	foe.used_ability = strike
	m.execute_ability(strike)
	_check(me.health.hp == me.health.max_hp - 25,
		"(baseline) the enemy skill lands for 25 with no counter up (hp %d)" % me.health.hp)

	# Now put a counter on me and repeat.
	me.used_ability = null
	var parry = _mk("Parry", me, false)
	_runner(parry, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "counter", "scope": "harmful", "turns": 1,
			"then": [{"op": "damage", "amount": 15, "to": "target"}]}}])
	_check(me.has_effect("Parry", EffectType.Type.COUNTER_RECEIVE, me) != null, "(setup) the counter is up")
	_heal_full(me)
	_heal_full(foe)
	foe.acted = false
	foe.was_countered = false
	foe.targeter.targets = [me]
	foe.targeter.main_target = me
	foe.used_ability = strike
	m.execute_ability(strike)
	_check(me.health.hp == me.health.max_hp,
		"THE INCOMING SKILL WAS CANCELLED — no damage reached me (hp %d)" % me.health.hp)
	_check(foe.was_countered, "the engine recorded the counter on the attacker")
	_check(foe.health.hp == foe.health.max_hp - 15,
		"the counter's payload hit the attacker for 15 (hp %d)" % foe.health.hp)
	_check(me.has_effect("Parry", EffectType.Type.COUNTER_RECEIVE, me) == null,
		"the counter was spent, so the next skill gets through")

	foe.used_ability = null
	foe.targeter.targets = []
	me.used_ability = null
	_heal_full(me)
	_heal_full(foe)

# =====================================================================================
# compare. Relational conditions — the only way an authored kit can ask about the SHAPE
# of the board rather than about one character.
# =====================================================================================
func _compare(m, me, foe, foe2, foe3):
	print("-- compare --")
	var reader = _mk("Read the Room", me, false)
	var r = _runner(reader, m, me)
	for c in [foe, foe2, foe3]:
		_heal_full(c)
	var even := {"cond": "compare", "of": "all_enemies", "value": "hp", "op": "all_equal"}
	var uneven := {"cond": "compare", "of": "all_enemies", "value": "hp", "op": "any_differ"}
	_check(r.check_condition_public(even), "all_equal is TRUE when the enemy team is untouched")
	_check(not r.check_condition_public(uneven), "any_differ is its complement (false)")
	foe2.health.hp = 61
	_check(not r.check_condition_public(even), "all_equal is FALSE once one of them is hurt")
	_check(r.check_condition_public(uneven), "...and any_differ is now true")
	_check(r.check_condition_public({"cond": "compare", "of": "user", "value": "hp", "op": "gt", "vs": "target"})
			== (me.health.hp > foe.health.hp),
		"a pairwise `vs` compare agrees with the raw HP reading")
	foe3.dead = true
	_check(r.check_condition_public({"cond": "compare", "of": "all_enemies", "value": "alive_count", "op": "eq", "than": 2}),
		"alive_count follows a real death (3 -> 2)")
	foe3.dead = false
	for c in [foe, foe2, foe3]:
		_heal_full(c)

# =====================================================================================
# cost / cooldown / paralyze / stun exclusions. Each is asserted on the QUANTITY the
# engine actually reads, not on the effect object.
# =====================================================================================
func _restrictions(m, me, foe, foe2):
	print("-- cost / cooldown / paralyze / stun exclusions --")
	var victim_skill = foe.moveset.base_abilities[0]
	var blue_before: int = int(victim_skill.cost()[Energy.Type.BLUE])
	var tax = _mk("Tax", me)
	_runner(tax, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cost_change", "amount": 1, "colour": "blue", "turns": 2}}])
	_check(int(victim_skill.cost()[Energy.Type.BLUE]) == blue_before + 1,
		"cost_change RAISED the enemy skill's resolved Blue cost %d -> %d" % [blue_before, int(victim_skill.cost()[Energy.Type.BLUE])])

	# Cooldown: compare the cooldown a use actually leaves behind, with and without the mod.
	var cd_skill = foe.moveset.base_abilities[1]
	cd_skill.start_cooldown()
	var cd_plain: int = int(cd_skill.cooldown_remaining)
	var drag = _mk("Drag", me)
	_runner(drag, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cooldown_change", "amount": 2, "turns": 3}}])
	cd_skill.start_cooldown()
	_check(int(cd_skill.cooldown_remaining) == cd_plain + 2,
		"cooldown_change added 2 turns to the cooldown a use leaves (%d -> %d)" % [cd_plain, int(cd_skill.cooldown_remaining)])

	# Paralyze freezes the countdown itself.
	cd_skill.cooldown_remaining = 3
	cd_skill.cooldown_started_turn = -1
	foe.moveset.advance_cooldowns(foe)
	_check(int(cd_skill.cooldown_remaining) == 2, "(baseline) an unparalyzed cooldown ticks 3 -> %d" % int(cd_skill.cooldown_remaining))
	var freeze = _mk("Freeze", me)
	_runner(freeze, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "paralyze", "turns": 2}}])
	_check(foe.paralyzed(), "paralyze reached the character's own paralyzed() read")
	cd_skill.cooldown_remaining = 3
	cd_skill.cooldown_started_turn = -1
	foe.moveset.advance_cooldowns(foe)
	_check(int(cd_skill.cooldown_remaining) == 3, "PARALYZED: the cooldown did not tick (still %d)" % int(cd_skill.cooldown_remaining))

	# stun exclude_classes: the excluded class stays usable, everything else does not.
	var fist = _mk("Fist", foe2, true, true)      # Physical
	var spell = _mk("Spell", foe2, true, false)   # not Physical
	_check(not foe2.is_stunned(fist) and not foe2.is_stunned(spell), "(baseline) neither skill is stunned")
	me.targeter.targets = [foe2]
	me.targeter.main_target = foe2
	var lock = _mk("Selective Lock", me)
	_runner(lock, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "stun", "turns": 1, "exclude_classes": ["Physical"]}}])
	_check(foe2.is_stunned(spell), "the non-excluded skill IS stunned")
	_check(not foe2.is_stunned(fist), "the excluded Physical skill is STILL USABLE — exclude_classes works")
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

# =====================================================================================
# damage_boost `skills` filter. Asserted in HP, because the filter lives inside
# get_true_damage and a boost that never applies looks identical from the effect side.
# =====================================================================================
func _boost_filter(m, me, foe3):
	print("-- damage_boost skills filter --")
	me.targeter.targets = [foe3]
	me.targeter.main_target = foe3
	var named = _mk("Named Blast", me)
	var other = _mk("Other Blast", me)
	var focus = _mk("Focus", me, false)
	_runner(focus, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "damage_boost", "amount": 20, "turns": 4, "skills": ["Named Blast"]}}])

	_heal_full(foe3)
	me.used_ability = null
	_runner(named, m, me).run([{"op": "damage", "amount": 10, "to": "target"}])
	var named_dealt: int = foe3.health.max_hp - foe3.health.hp
	_heal_full(foe3)
	me.used_ability = null
	_runner(other, m, me).run([{"op": "damage", "amount": 10, "to": "target"}])
	var other_dealt: int = foe3.health.max_hp - foe3.health.hp
	_check(named_dealt == 30, "the NAMED skill got the +20 (dealt %d)" % named_dealt)
	_check(other_dealt == 10, "the unnamed skill did NOT (dealt %d)" % other_dealt)
	_heal_full(foe3)
	me.used_ability = null

# =====================================================================================
# `bypassing`. Observable = the effect lands on a target that would otherwise refuse it.
# =====================================================================================
func _bypassing(m, me, foe3):
	print("-- bypassing an Invulnerable target --")
	var ward = _mk("Ward", me, false)
	_runner(ward, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "invulnerable", "turns": 3}}])
	_check(foe3.is_invuln(), "(setup) the target is Invulnerable")

	var blocked = _mk("Curse Blocked", me)
	_runner(blocked, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "vulnerability", "amount": 5, "turns": 3}}])
	_check(foe3.has_effect("Curse Blocked", EffectType.Type.VULNERABILITY, me) == null,
		"without `bypassing` the hostile effect is REFUSED by the invuln")

	var pierces = _mk("Curse Bypasses", me)
	_runner(pierces, m, me).run([{"op": "apply", "to": "target", "bypassing": true,
		"effect": {"kind": "vulnerability", "amount": 5, "turns": 3}}])
	_check(foe3.has_effect("Curse Bypasses", EffectType.Type.VULNERABILITY, me) != null,
		"with `bypassing` the SAME effect LANDS on the invulnerable target")

	for e in foe3.effects.get_effects_by_type(EffectType.Type.INVULN):
		e.end_effect()
	_check(not foe3.is_invuln(), "(teardown) invuln cleared")

# =====================================================================================
# taunt. Observable = an attack aimed elsewhere hits the taunter instead.
# =====================================================================================
func _taunt(m, me, foe, foe2):
	print("-- taunt --")
	me.targeter.targets = [foe]
	me.targeter.main_target = foe
	var jeer = _mk("Jeer", me)
	_runner(jeer, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "taunt", "turns": 2}}])
	_check(foe.is_taunted(), "the taunt registers on is_taunted()")

	var strike = null
	for a in foe.moveset.base_abilities:
		if a.ability_name == "Enemy Strike":
			strike = a
	if strike == null:
		_check(false, "(setup) Enemy Strike is on the attacker")
		return
	_heal_full(me)
	_heal_full(foe2)
	foe.acted = false
	foe.targeter.targets = [foe2]          # aiming at an ALLY, not at me
	foe.targeter.main_target = foe2
	foe.used_ability = strike
	m.execute_ability(strike)
	_check(me.health.hp == me.health.max_hp - 25,
		"TAUNTED: the attack was dragged onto me even though I was not targeted (hp %d)" % me.health.hp)
	foe.used_ability = null
	foe.targeter.targets = []
	_heal_full(me)
	_heal_full(foe2)

# =====================================================================================
# effect_immunity / break / named cleanse / coloured energy.
# =====================================================================================
func _immunity_break_cleanse_energy(m, me, foe, foe3):
	print("-- effect_immunity / break / cleanse / gain_energy --")
	me.targeter.targets = [foe3]
	me.targeter.main_target = foe3

	# effect_immunity: a STUN aimed at the holder is dropped, a VULNERABILITY is not.
	var aegis = _mk("Aegis", me, false)
	_runner(aegis, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "effect_immunity", "turns": 4, "effect": "STUN"}}])
	var stunner = _mk("Hammer", me)
	_runner(stunner, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "stun", "turns": 1}}])
	_check(foe3.has_effect("Hammer", EffectType.Type.STUN, me) == null,
		"effect_immunity(STUN) made the incoming stun bounce off")
	var poker = _mk("Poke", me)
	_runner(poker, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "vulnerability", "amount": 5, "turns": 3}}])
	_check(foe3.has_effect("Poke", EffectType.Type.VULNERABILITY, me) != null,
		"...but it is type-specific: a Vulnerability still lands")

	# break: the shield is gone, checked through the character's own shield read.
	var guard = _mk("Guard", me, false)
	_runner(guard, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "shield", "amount": 30, "turns": 3}}])
	_check(foe3.get_shield_effects().size() > 0, "(setup) the target is shielded")
	var sunder = _mk("Sunder", me)
	_runner(sunder, m, me).run([{"op": "break", "what": "both", "to": "target"}])
	_check(foe3.get_shield_effects().size() == 0, "break DESTROYED the shield")

	# Named cleanse: remove exactly one of two same-typed debuffs.
	me.targeter.targets = [foe]
	me.targeter.main_target = foe
	var rot = _mk("Rot", me)
	var wither = _mk("Wither", me)
	_runner(rot, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "turns": 4}}])
	_runner(wither, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "vulnerability", "amount": 5, "turns": 4}}])
	_check(foe.has_effect("Rot", EffectType.Type.VULNERABILITY, me) != null
			and foe.has_effect("Wither", EffectType.Type.VULNERABILITY, me) != null, "(setup) both debuffs are on")
	var purge = _mk("Purge", me, false)
	_runner(purge, m, me).run([{"op": "cleanse", "to": "target", "name": "Rot"}])
	_check(foe.has_effect("Rot", EffectType.Type.VULNERABILITY, me) == null, "the named cleanse removed Rot")
	_check(foe.has_effect("Wither", EffectType.Type.VULNERABILITY, me) != null, "...and left Wither alone")
	# Clear it: a +5 Vulnerability left on the attacker would silently inflate the reactive
	# damage assertion further down, turning a real number into an unexplained one.
	var leftover = foe.has_effect("Wither", EffectType.Type.VULNERABILITY, me)
	if leftover != null:
		leftover.end_effect()

	# Coloured energy goes to the named colour and nowhere else.
	var pool = me.team.energy.pool
	var before := {}
	for k in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		before[k] = int(pool[k])
	_runner(_mk("Charge Up", me, false), m, me).run([{"op": "gain_energy", "amount": 2, "colour": "white"}])
	_check(int(pool[Energy.Type.WHITE]) == before[Energy.Type.WHITE] + 2,
		"gain_energy banked 2 WHITE (%d -> %d)" % [before[Energy.Type.WHITE], int(pool[Energy.Type.WHITE])])
	var spilled := 0
	for k in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.RED]:
		spilled += int(pool[k]) - before[k]
	_check(spilled == 0, "...and nothing spilled into the other colours (%d)" % spilled)

# =====================================================================================
# Triggers (called `reactive` before the rename). on_skill_used must actually fire, and
# damage inside ANY trigger payload must actually land — resolve_damage returns early when
# used_ability is null, which is always the case in a payload, so this block used to be a
# silent no-op.
# =====================================================================================
func _triggers(m, me, foe):
	print("-- trigger effects --")
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	# The NAME. `trigger` is the kind; `reactive` is gone from the palette but must still
	# LOAD, because saved characters on disk (authored/auth_testchar.json) still say it.
	_check(BlockSchema.EFFECT_KINDS.has("trigger"), "the effect kind is named `trigger`")
	_check(not BlockSchema.EFFECT_KINDS.has("reactive"), "...and `reactive` is off the palette")
	_check(BlockSchema.canonical_kind("reactive") == "trigger",
		"...but it still resolves as an ALIAS, or every pre-rename saved character stops loading")

	# on_skill_used -> ACTION_USE_TRIGGER, fired by check_ability_use_triggers on the actor.
	var watcher = _mk("Watcher", me, false)
	_runner(watcher, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "trigger", "trigger": "on_skill_used", "turns": 4, "text": "watching",
			"then": [{"op": "gain_energy", "amount": 1, "colour": "green"}]}}])
	_check(me.has_effect("Watcher", EffectType.Type.ACTION_USE_TRIGGER, me) != null, "(setup) the watcher installed")
	var green_before: int = int(me.team.energy.pool[Energy.Type.GREEN])
	var unrelated = _mk("Unrelated Skill", me, false)
	me.used_ability = null
	me.check_ability_use_triggers(m, unrelated)
	_check(int(me.team.energy.pool[Energy.Type.GREEN]) == green_before + 1,
		"on_skill_used FIRED when a skill was used (%d -> %d green)" % [green_before, int(me.team.energy.pool[Energy.Type.GREEN])])
	me.used_ability = null

	# The _op_damage borrow. A trigger payload runs with used_ability == null; without the
	# borrow resolve_damage returns at its first line and the attacker takes nothing.
	#
	# Written with the LEGACY kind name on purpose: this is the backwards-compatibility
	# assertion with teeth. A saved character full of "reactive" must not merely validate —
	# its payload must still fire and still deal damage.
	var thorns = _mk("Thorns", me, false)
	_runner(thorns, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "reactive", "trigger": "on_harmful_received", "turns": 4, "text": "thorns",
			"then": [{"op": "damage", "amount": 12, "to": "target"}]}}])
	_check(me.has_effect("Thorns", EffectType.Type.HARMFUL_RECEIVE_TRIGGER, me) != null,
		"a LEGACY 'reactive' spec still installs the trigger effect")
	var strike = null
	for a in foe.moveset.base_abilities:
		if a.ability_name == "Enemy Strike":
			strike = a
	if strike == null:
		_check(false, "(setup) Enemy Strike is on the attacker")
		return
	_heal_full(foe)
	me.used_ability = null
	foe.targeter.targets = [me]
	foe.targeter.main_target = me
	foe.used_ability = strike
	foe.check_ability_use_triggers(m, strike)
	_check(foe.health.hp == foe.health.max_hp - 12,
		"DAMAGE INSIDE A REACTIVE PAYLOAD LANDED for 12 (attacker hp %d) — the used_ability borrow" % foe.health.hp)
	_check(me.used_ability == null, "...and the borrow was handed back (used_ability is null again)")
	foe.used_ability = null
	foe.targeter.targets = []

# =====================================================================================
# THE RENAME, both directions at once. `trigger` is the ONLY name the palette, the
# validator's messages and the generated prose speak; `reactive` survives as a READ-SIDE
# alias for exactly one reason — there are player-authored JSON files on disk that say it,
# and every one of them is re-validated on load. So a half-proof is worthless: the CURRENT
# name has to work through the live-match entry point, and the LEGACY name has to still come
# off the disk it really lives on.
# =====================================================================================

# A one-block prose line, built the way the client's ability JSON is built.
func _prose_line(blocks: Array) -> String:
	var a = load("res://blocks/scripted_ability.gd").new()
	a.ability_name = "Prose Probe"
	a.blocks = blocks
	var parts: Array = a.split_desc()
	var line := str(parts[0]) if not parts.is_empty() else ""
	a.free()
	return line

# The shape authored/auth_testchar.json's "Bulwark" really ships: a shield, and beside it an
# effect whose kind is the PRE-RENAME spelling. Written out here as well as read off disk so
# the assertion holds on a machine whose authored/ directory is empty.
func _legacy_reactive_defs() -> Array:
	return [_authored("Fracture Strike"), _authored("Execute"),
		{"name": "Bulwark", "target": "self", "cooldown": 3, "cost": {"4": 1},
			"classes": ["Strategic", "Instant", "Helpful"], "requires": [],
			"blocks": [{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 20, "turns": 2}},
				{"op": "apply", "to": "user", "effect": {"kind": "reactive", "turns": 2,
					"trigger": "on_harmful_received",
					"then": [{"op": "damage", "amount": 10, "to": "target"}]}}]},
		_authored("Rally")]

func _trigger_rename_proof(m, me, foe):
	print("-- the reactive -> trigger rename --")
	_wipe(me)
	_wipe(foe)
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	# --- the CURRENT name, fired by a real cast -------------------------------
	# Not check_ability_use_triggers by hand: battle_manager.execute_ability is what a live
	# match calls, and it is the path that has to reach the hook.
	var bramble = _mk("Bramble", me, false)
	_runner(bramble, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "trigger", "trigger": "on_harmful_received", "turns": 4, "text": "bramble",
			"then": [{"op": "damage", "amount": 9, "to": "target"}]}}])
	_check(me.has_effect("Bramble", EffectType.Type.HARMFUL_RECEIVE_TRIGGER, me) != null,
		"a `trigger` spec installs a HARMFUL_RECEIVE_TRIGGER")
	var strike = _find_ability(foe, "Enemy Strike")
	if strike == null:
		_check(false, "(setup) Enemy Strike is on the attacker")
		return
	me.used_ability = null
	foe.acted = false
	foe.was_countered = false
	foe.targeter.targets = [me]
	foe.targeter.main_target = me
	foe.used_ability = strike
	m.execute_ability(strike)
	_check(me.health.hp == me.health.max_hp - 25,
		"(baseline) the enemy's skill resolved for 25 (hp %d)" % me.health.hp)
	_check(foe.health.hp == foe.health.max_hp - 9,
		"THE TRIGGER FIRED INSIDE A LIVE CAST — its payload hit the attacker for 9 (hp %d)" % foe.health.hp)
	foe.used_ability = null
	foe.targeter.targets = []
	_wipe(me)
	_wipe(foe)
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	# --- the LEGACY name, off the disk it actually lives on -------------------
	# authored/ is gitignored PLAYER DATA. auth_testchar.json was written before the rename
	# and is deliberately never rewritten, so it is the real regression subject.
	var legacy_path := "res://authored/auth_testchar.json"
	if FileAccess.file_exists(legacy_path):
		var raw := FileAccess.get_file_as_string(legacy_path)
		_check(raw.contains("\"reactive\""),
			"authored/auth_testchar.json STILL SAYS \"reactive\" on disk — player data is not rewritten")
		var parsed = JSON.parse_string(raw)
		var perrs: Array = AuthoredRegistry.validate_character(parsed) if parsed is Dictionary else ["not JSON"]
		_check(perrs.is_empty(), "...and the file VALIDATES UNCHANGED (%s)" % str(perrs))
		_check(AuthoredRegistry.get_spec("auth_testchar") != null,
			"...and the registry LOADED it, so load-time revalidation passed too")
	else:
		print("  note: authored/auth_testchar.json is absent here — the fixture below covers the same path")

	# The same shape, machine-independently, through the real write -> load -> revalidate path.
	var legacy_spec := _authored_spec("auth_palette_legacy", _legacy_reactive_defs())
	_check(_char_ok(legacy_spec), "a pre-rename character spec validates (%s)" % _char_errs(legacy_spec))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://authored"))
	var lf := FileAccess.open("res://authored/auth_palette_legacy.json", FileAccess.WRITE)
	if lf != null:
		lf.store_string(JSON.stringify(legacy_spec, "\t"))
		lf.close()
		AuthoredRegistry.load_all(true)
		_check(AuthoredRegistry.get_spec("auth_palette_legacy") != null,
			"...and a file full of \"reactive\" SURVIVES load-time revalidation")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://authored/auth_palette_legacy.json"))
		AuthoredRegistry.load_all(true)
	else:
		_check(false, "(setup) could not write the legacy fixture")

	# The alias is a MAP, not a wildcard: it resolves one dead name onto a live kind, and a
	# name that was never a kind is still an error.
	for k in BlockSchema.KIND_ALIASES.keys():
		_check(BlockSchema.EFFECT_KINDS.has(BlockSchema.canonical_kind(k)),
			"alias '%s' resolves to a REAL palette kind ('%s')" % [str(k), BlockSchema.canonical_kind(k)])
		_check(not BlockSchema.EFFECT_KINDS.has(str(k)),
			"...and '%s' is not itself a palette entry — nothing offers the old name" % str(k))
	_check(not _valid(_apply_skill({"kind": "reactionary", "turns": 2})),
		"an invented kind is still REJECTED — the alias did not open the gate")

	# --- fresh OUTPUT speaks the current name --------------------------------
	var legacy_bad := _apply_skill({"kind": "reactive", "trigger": "on_turn_end", "turns": 2, "text": "x",
		"then": [{"op": "damage", "amount": 1, "to": "target"}], "script_path": "res://evil.gd"})
	# Read the error STRINGS, not str(Array): the array form escapes its own quotes, which
	# would let a message that never said "trigger" slip through a naive substring test.
	var msg := ""
	for e in BlockValidator.validate_ability(legacy_bad):
		msg += str(e) + " "
	_check(msg.contains("for effect 'trigger'") and not msg.contains("reactive"),
		"a FRESH validator message about a LEGACY block names `trigger`, not `reactive`: %s" % msg)

	# --- and so does the generated prose -------------------------------------
	var eff_spec := {"kind": "trigger", "trigger": "on_harmful_received", "turns": 2, "text": "t",
		"then": [{"op": "damage", "amount": 10, "to": "target"}]}
	var legacy_eff: Dictionary = eff_spec.duplicate(true)
	legacy_eff["kind"] = "reactive"
	var new_line := _prose_line([{"op": "apply", "to": "user", "effect": eff_spec}])
	var old_line := _prose_line([{"op": "apply", "to": "user", "effect": legacy_eff}])
	_check(new_line.contains("when a harmful skill is used on them") and new_line.contains("10 damage"),
		"the `trigger` kind generates real prose: \"%s\"" % new_line)
	_check(old_line == new_line and old_line != "",
		"...and a LEGACY spec generates the IDENTICAL sentence, rather than an empty one: \"%s\"" % old_line)
	_check(not old_line.to_lower().contains("reactive"), "...with the retired word nowhere in it")

# =====================================================================================
# UNIVERSAL EFFECT FIELDS. The claim being tested is "every field belongs to every kind":
# there is no per-kind allow-list for anything that is a property of the Effect rather than
# an argument of one factory. Asserted three ways — on the built Effect, on the validator,
# and on the SCHEMA ITSELF against the engine class it is derived from.
# =====================================================================================
func _universal_fields(m, me, foe, foe3):
	print("-- universal effect fields --")
	me.targeter.targets = [foe3]
	me.targeter.main_target = foe3

	# (1) They reach the Effect, on a kind that declares NONE of them. `invulnerable`'s own
	# fields are turns/classes; every field set below is universal.
	var ward = _mk("Universal Ward", me, false)
	_runner(ward, m, me).run([{"op": "apply", "to": "target", "effect": {
		"kind": "invulnerable", "turns": 3,
		"name_override": "Renamed Ward", "system": true, "display_system": true,
		"cleansable": false, "remove_on_death": false, "invisible": true,
		"unique_render_id": 7, "description": "a custom tooltip", "mag": 12,
		"display_mag": true, "stackable": true, "stacks": 4}}])
	var uw = foe3.has_effect("Renamed Ward", EffectType.Type.INVULN, me)
	_check(uw != null, "name_override RENAMED the effect — it is not found under the ability's name")
	_check(foe3.has_effect("Universal Ward", EffectType.Type.INVULN, me) == null,
		"...and the ability-named lookup finds nothing, which is the collision fix working")
	# NOT `return` on a miss. Everything below — the factory-owned check, the validator half,
	# the drift guard, the collision pair — is independent of this one effect, and bailing out
	# swallowed ~70 assertions when the universal pass was neutered for a reversal test. A
	# probe that goes quiet under a regression understates it.
	if uw == null:
		_check(false, "(skipped) the renamed effect was not found, so its fields could not be read back")
	else:
		_check(uw.system and uw.display_system and not uw.cleansable and not uw.remove_on_death,
			"the survival flags landed (system %s / display_system %s / cleansable %s / remove_on_death %s)"
				% [uw.system, uw.display_system, uw.cleansable, uw.remove_on_death])
		_check(uw.invisible and uw.unique_render_id == 7 and uw.display_mag,
			"the presentation flags landed (invisible %s / render id %d / display_mag %s)"
				% [uw.invisible, uw.unique_render_id, uw.display_mag])
		_check(uw.mag == 12 and uw.stacks == 4 and uw.stackable,
			"the magnitude/stack fields landed (mag %d / stacks %d / stackable %s)" % [uw.mag, uw.stacks, uw.stackable])
		_check(str(uw.description) == "a custom tooltip", "the tooltip override landed as a plain String")
		uw.end_effect()

	# (2) A FACTORY-OWNED field still wins. mark's `stacks` is clamped to the mark's own
	# `max`; if the universal pass wrote it a second time that ceiling would be bypassed.
	var capped = _mk("Capped Mark", me, false)
	_runner(capped, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 4, "text": "c", "stacks": 9, "max": 3}}])
	var cm = me.has_effect("Capped Mark", EffectType.Type.MARK, me)
	# The validator refuses stacks > max, so this is the runtime half of that guard.
	_check(cm != null and cm.stack_count() <= 3,
		"mark's `stacks` stays FACTORY-owned — clamped to max 3, got %d" % (cm.stack_count() if cm != null else -1))
	if cm != null:
		cm.end_effect()

	# (3) The validator: universal on every kind, typed, and still closed to junk.
	for kind in ["mark", "shield", "stun", "silence", "counter", "trigger", "swap"]:
		var eff := {"kind": kind, "turns": 1, "invisible": true, "name_override": "N", "cleansable": false}
		if kind == "shield":
			eff["amount"] = 10
		if kind == "counter":
			eff["scope"] = "any"
			eff["then"] = [{"op": "damage", "amount": 1, "to": "target"}]
		if kind == "trigger":
			eff["trigger"] = "on_turn_end"
			eff["then"] = [{"op": "damage", "amount": 1, "to": "target"}]
		if kind == "swap":
			eff["slot"] = 0
			eff["into"] = 1
		if kind == "mark":
			eff["text"] = "t"
		_check(_valid(_apply_skill(eff)), "universal fields validate on '%s' %s" % [kind, _errs(_apply_skill(eff))])
	_check(not _valid(_apply_skill({"kind": "shield", "amount": 5, "turns": 2, "system": "yes"})),
		"KEPT: a universal bool must be a boolean")
	_check(not _valid(_apply_skill({"kind": "shield", "amount": 5, "turns": 2, "name_override": 7})),
		"KEPT: a universal string must be text")
	_check(not _valid(_apply_skill({"kind": "shield", "amount": 5, "turns": 2, "wrapup_func": "res://evil.gd"})),
		"KEPT: a CALLABLE field is NOT universal — code-in-data is still rejected")
	_check(not _valid(_apply_skill({"kind": "shield", "amount": 5, "turns": 2, "duration": 40})),
		"KEPT: engine bookkeeping (duration) is not authorable — turns/ticks are")

	# (4) DRIFT GUARD. Every universal field must still be a real `var` on Effect, and must
	# still hold the type the schema claims. A field renamed or retyped in the engine would
	# otherwise be silently written to nothing by Object.set().
	var probe_eff = load("res://components/effect_component.tscn").instantiate()
	for k in BlockSchema.UNIVERSAL_EFFECT_FIELDS.keys():
		var key := str(k)
		var declared := str(BlockSchema.UNIVERSAL_EFFECT_FIELDS[key])
		var present: bool = key in probe_eff
		_check(present, "universal field '%s' exists on Effect" % key)
		if not present:
			continue
		var v = probe_eff.get(key)
		var ok := false
		match declared:
			"bool": ok = v is bool
			"int": ok = v is int
			"string": ok = v is String
		_check(ok, "...and Effect.%s is really a %s" % [key, declared])
	probe_eff.queue_free()

	# (5) A NON-MARK effect carrying the four fields by name, each read back off the LIVE
	# Effect. damage_over_time's own `fields` are amount/damage_type/turns/delayed — not one of
	# these four — so the universal pass is the only thing that can have delivered them.
	_wipe(me)
	var pulse = _mk("Bleed Pulse", me, false)
	var rot_spec := {"kind": "damage_over_time", "amount": 4, "turns": 3,
		"stackable": true, "display_stacks": true, "invisible": true, "name_override": "Creeping Rot"}
	var pulse_r = _runner(pulse, m, me)
	pulse_r.run([{"op": "apply", "to": "user", "effect": rot_spec}])
	var rot = me.has_effect("Creeping Rot", EffectType.Type.DAMAGE, me)
	_check(rot != null, "name_override took on a DoT — it is stored as 'Creeping Rot'")
	_check(me.has_effect("Bleed Pulse", EffectType.Type.DAMAGE, me) == null,
		"...and NOT under the ability's own name, which is what effect_name() falls back to")
	# Same rule as above: a miss must produce a FAILURE for each field, not silence.
	if rot == null:
		_check(false, "(skipped) the DoT was not found under its override — stackable/display_stacks/invisible unreadable")
	else:
		_check(rot.stackable, "stackable took on a non-mark kind (%s)" % rot.stackable)
		_check(rot.display_stacks, "display_stacks took (%s)" % rot.display_stacks)
		_check(rot.invisible, "invisible took (%s)" % rot.invisible)
		# The flag is not decoration. A second cast MERGES only because of it, which is the
		# behaviour that replaced the deleted `stack` op — on a kind that is not a mark.
		pulse_r.run([{"op": "apply", "to": "user", "effect": rot_spec}])
		_check(rot.stack_count() == 2,
			"...and `stackable` is FUNCTIONAL: a second cast stacked the DoT to 2 (got %d)" % rot.stack_count())
	_wipe(me)

	# (6) THE COLLISION FIX, which is what name_override is FOR. add_effect dedups on
	# (effect_name, effect_type, user) and effect_name() falls back to the SOURCE ABILITY's
	# name — so one ability applying two same-typed effects names them both the same and the
	# second lands on top of the first. (The shipped Mavis passive hits this exact wall.)
	_check(me.get_shield_effects().size() == 0, "(setup) the user carries no shield")
	var fused = _mk("Fused Wards", me, false)
	_runner(fused, m, me).run([
		{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 10, "turns": 3}},
		{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 20, "turns": 3}}])
	var fused_shields: Array = me.get_shield_effects()
	_check(fused_shields.size() == 1 and int(fused_shields[0].mag) == 30,
		"(baseline) two shields from ONE ability COLLIDE into a single 30-point effect (%d effect(s))"
			% fused_shields.size())
	_wipe(me)
	var split = _mk("Split Wards", me, false)
	_runner(split, m, me).run([
		{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 10, "turns": 3, "name_override": "Outer Ward"}},
		{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 20, "turns": 3, "name_override": "Inner Ward"}}])
	var outer = me.has_effect("Outer Ward", EffectType.Type.SHIELD, me)
	var inner = me.has_effect("Inner Ward", EffectType.Type.SHIELD, me)
	_check(outer != null and inner != null and me.get_shield_effects().size() == 2,
		"TWO SAME-TYPED EFFECTS FROM ONE ABILITY COEXIST under different name_overrides (%d shields)"
			% me.get_shield_effects().size())
	_check(outer != null and inner != null and int(outer.mag) == 10 and int(inner.mag) == 20,
		"...each keeping its OWN magnitude rather than merging (%d / %d)"
			% [int(outer.mag) if outer != null else -1, int(inner.mag) if inner != null else -1])
	_wipe(me)

# =====================================================================================
# CONDITION-FILTERED SELECTORS. The claim: any_enemy/any_ally/any_character hit EVERY
# member of their pool the condition holds for, tested ONCE PER CANDIDATE — which is a
# different question from the block-level guard (asked once, all-or-nothing) and from
# random_* (pick one). Asserted in HP, on a board deliberately set up so the two readings
# disagree: some enemies match and some do not.
# =====================================================================================
func _filtered_selectors(m, me, foe, foe2, foe3):
	print("-- condition-filtered selectors --")
	# _wipe, not _heal_full: earlier sections leave Vulnerability on foe3, and a +5 debuff
	# would turn every "took exactly 10" reading below into an unexplained number.
	for c in [foe, foe2, foe3]:
		_wipe(c)
	# Two of three enemies are hurt. A block-level guard would fire for ALL THREE (the
	# condition holds for someone); a per-candidate filter must spare the healthy one.
	foe.health.hp = 40
	foe2.health.hp = 40
	var sweep = _mk("Sweep the Wounded", me)
	me.used_ability = null
	_runner(sweep, m, me).run([{"op": "damage", "amount": 10, "to": "any_enemy",
		"when": {"cond": "hp_below", "value": 50}}])
	_check(foe.health.hp == 30 and foe2.health.hp == 30,
		"both HURT enemies were hit (%d / %d)" % [foe.health.hp, foe2.health.hp])
	_check(foe3.health.hp == foe3.health.max_hp,
		"THE HEALTHY ONE WAS SPARED (%d) — the condition is per candidate, not a block gate" % foe3.health.hp)

	# Nobody matching = nothing happens, rather than "fall back to everyone".
	for c in [foe, foe2, foe3]:
		_heal_full(c)
	me.used_ability = null
	_runner(sweep, m, me).run([{"op": "damage", "amount": 10, "to": "any_enemy",
		"when": {"cond": "hp_below", "value": 5}}])
	_check(foe.health.hp == foe.health.max_hp and foe2.health.hp == foe2.health.max_hp
			and foe3.health.hp == foe3.health.max_hp,
		"nobody matching means NOBODY is hit — it does not degrade into all_enemies")

	# An EXPLICIT `on` still names a fixed selector: the same answer for every candidate,
	# which is how "hit each enemy, but only while I am hurt" is phrased.
	me.health.hp = me.health.max_hp
	me.used_ability = null
	_runner(sweep, m, me).run([{"op": "damage", "amount": 10, "to": "any_enemy",
		"when": {"cond": "hp_below", "value": 50, "on": "user"}}])
	_check(foe.health.hp == foe.health.max_hp and foe3.health.hp == foe3.health.max_hp,
		"an explicit `on: user` gated the whole sweep (the user is healthy, so nobody was hit)")
	me.health.hp = 10
	me.used_ability = null
	_runner(sweep, m, me).run([{"op": "damage", "amount": 10, "to": "any_enemy",
		"when": {"cond": "hp_below", "value": 50, "on": "user"}}])
	_check(foe.health.hp == foe.health.max_hp - 10 and foe3.health.hp == foe3.health.max_hp - 10,
		"...and with the user hurt it hit ALL of them (%d / %d)" % [foe.health.hp, foe3.health.hp])
	_heal_full(me)
	for c in [foe, foe2, foe3]:
		_heal_full(c)

	# any_ally reaches the user's own side, and `apply` filters the same way `damage` does.
	var ally = me.team.characters[1]
	ally.health.hp = 30
	var triage = _mk("Triage", me, false)
	_runner(triage, m, me).run([{"op": "apply", "to": "any_ally", "when": {"cond": "hp_below", "value": 50},
		"effect": {"kind": "shield", "amount": 15, "turns": 3}}])
	_check(ally.get_shield_effects().size() > 0, "any_ally shielded the HURT ally")
	_check(me.get_shield_effects().size() == 0, "...and not the healthy user")
	for e in ally.get_shield_effects():
		e.end_effect()
	_heal_full(ally)

	# any_character spans BOTH teams.
	foe.health.hp = 30
	me.health.hp = 30
	var mend = _mk("Field Mend", me, false)
	me.used_ability = null
	_runner(mend, m, me).run([{"op": "heal", "amount": 5, "to": "any_character",
		"when": {"cond": "hp_below", "value": 50}}])
	_check(me.health.hp == 35 and foe.health.hp == 35,
		"any_character reached both sides (user %d / enemy %d)" % [me.health.hp, foe.health.hp])
	_heal_full(me)
	for c in [foe, foe2, foe3]:
		_heal_full(c)
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	# --- the validator half ---------------------------------------------------
	for sel in BlockSchema.FILTERED_SELECTORS.keys():
		var bare := _authored("Bare " + str(sel))
		bare["blocks"] = [{"op": "damage", "amount": 5, "to": str(sel)}]
		_check(not _valid(bare), "'%s' with NO condition is REJECTED — unlike every other selector" % str(sel))
		var with_cond := _authored("Filtered " + str(sel))
		with_cond["blocks"] = [{"op": "damage", "amount": 5, "to": str(sel), "when": {"cond": "hp_below", "value": 50}}]
		_check(_valid(with_cond), "...and accepted with one %s" % _errs(with_cond))
		# Inside a CONDITION it is an infinite regress, so it stays rejected there.
		var nested := _authored("Nested " + str(sel))
		nested["blocks"] = [{"op": "damage", "amount": 5, "when": {"cond": "hp_below", "value": 50, "on": str(sel)}}]
		_check(not _valid(nested), "...and it is REJECTED inside a condition's `on`")

	# --- the PROSE half -------------------------------------------------------
	# The filter is part of WHO the sentence is about, so it must not print as a separate
	# leading "if ..." clause — that would read as a gate and describe the wrong skill.
	var prose = load("res://blocks/scripted_ability.gd").new()
	prose.ability_name = "Cull"
	prose.blocks = [{"op": "damage", "amount": 10, "to": "any_enemy", "when": {"cond": "hp_below", "value": 40}}]
	var line := str(prose.split_desc()[0])
	_check(line.contains("each enemy") and line.contains("below 40 HP"),
		"the generated prose names the filtered subject: \"%s\"" % line)
	_check(not line.begins_with("If "), "...and does NOT print it as a leading gate clause")
	prose.free()

# =====================================================================================
# `remove` — THE MIRROR OF `apply`.
#
# The op exists because the roster does this by hand constantly: shiro5 spends a stack of
# Ganta Fever, naruto1/naruto2 consume Sage Chakra Gather, asta1 strips Demon-Slayer Sword
# off its target. Until now an authored kit could BANK a resource and never spend it.
#
# Every assertion below is an OUTCOME: the pip is gone, the counter reads a different
# number, the gated skill greys out, the shield's break contingency fired. "The effect
# is gone" on its own is the weak claim — a bare erase_effect passes it — so each removal
# is paired with a consequence of the PATH taken.
# =====================================================================================
func _remove_op(m, me, foe, foe2, foe3):
	print("-- remove --")
	for c in [me, foe, foe2, foe3]:
		_wipe(c)
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	# --- (1) no `stacks` at all = the whole effect ------------------------------
	var brand = _mk("Brand", me, false)
	var br = _runner(brand, m, me)
	var brand_block := {"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 9, "text": "Brand"}}
	br.run([brand_block])
	var mk = me.has_effect("Brand", EffectType.Type.MARK, me)
	_check(mk != null, "(setup) the mark is on the user")
	# A wrapup_func is precisely what a bare erase_effect skips, so hang one on it: this is
	# the difference between "the pip vanished" and "the effect ENDED".
	var fired := [false]
	if mk != null:
		mk.wrapup_func = func(_c): fired[0] = true
	br.run([{"op": "remove", "name": "Brand", "to": "user"}])
	_check(not me.has_any_effect("Brand"), "an omitted `stacks` takes the WHOLE effect away")
	_check(fired[0], "...through the engine's own teardown: its wrapup_func RAN (erase_effect never calls it)")
	br.run([brand_block])
	br.run([{"op": "remove", "name": "Brand", "stacks": "all", "to": "user"}])
	_check(not me.has_any_effect("Brand"), "...and an explicit stacks:'all' is the same act")

	# --- (2) a partial spend, and the LAST stack --------------------------------
	var fever = _mk("Fever", me, false)
	var fr = _runner(fever, m, me)
	var bank := {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 9, "text": "Fever", "stacks": 3, "max": 5, "show_stacks": true}}
	fr.run([bank])
	var fv = me.has_effect("Fever", EffectType.Type.MARK, me)
	_check(fv != null and fv.stack_count() == 3,
		"(setup) 3 stacks banked (got %d)" % (fv.stack_count() if fv != null else -1))
	fr.run([{"op": "remove", "name": "Fever", "stacks": 1, "to": "user"}])
	_check(fv != null and fv.stack_count() == 2,
		"spending 1 of 3 LEAVES 2 (got %d)" % (fv.stack_count() if fv != null else -1))
	_check(me.has_effect("Fever", EffectType.Type.MARK, me) != null, "...and the effect SURVIVES the partial spend")
	fr.run([{"op": "remove", "name": "Fever", "stacks": 1, "to": "user"}])
	_check(fv != null and fv.stack_count() == 1,
		"...spending another leaves 1 (got %d)" % (fv.stack_count() if fv != null else -1))
	fr.run([{"op": "remove", "name": "Fever", "stacks": 1, "to": "user"}])
	# GONE, not parked at zero. An effect sitting at 0 stacks still renders a pip, still
	# answers has_effect, and every "if I still have Fever" read in the game would lie.
	_check(me.has_effect("Fever", EffectType.Type.MARK, me) == null,
		"spending the LAST stack ENDS the effect — it is gone, not sitting at 0")
	_check(_count_named(me, "Fever") == 0,
		"...with nothing left in the storage list (%d)" % _count_named(me, "Fever"))
	_check(fv != null and fv.removed, "...and the engine really tore it down (the removed flag is set)")

	# --- (3) over-spending is not an error --------------------------------------
	fr.run([bank])
	var fv2 = me.has_effect("Fever", EffectType.Type.MARK, me)
	me.used_ability = null
	# The damage block behind it is the assertion that matters: a runtime error inside the
	# op would abort the whole run, so "the next block still landed" is what "cleanly" means.
	fr.run([{"op": "remove", "name": "Fever", "stacks": 99, "to": "user"},
		{"op": "damage", "amount": 7, "to": "target"}])
	_check(not me.has_any_effect("Fever") and fv2 != null and fv2.removed,
		"spending MORE stacks than remain just ends it")
	_check(foe.health.hp == foe.health.max_hp - 7,
		"...and the run CARRIED ON past it — the following block dealt its 7 (hp %d)" % foe.health.hp)
	_heal_full(foe)

	# --- (4) removing what is not there is a silent no-op ------------------------
	me.used_ability = null
	fr.run([{"op": "remove", "name": "Nothing At All", "to": "target"},
		{"op": "remove", "name": "Nothing At All", "stacks": 2, "to": "target"},
		{"op": "damage", "amount": 6, "to": "target"}])
	_check(foe.health.hp == foe.health.max_hp - 6,
		"removing an ABSENT effect (both forms) is a NO-OP: the run continued and dealt 6 (hp %d)" % foe.health.hp)
	# "Matched nothing" has to mean NOTHING, not everything. (Counting effects named "Nothing At
	# All" asserted nothing: no code path anywhere builds one, so that count is 0 unconditionally.
	# What the op could plausibly get wrong is widening a miss into the any-name marker and
	# stripping the target's live effects.) Put one there and watch it survive the miss.
	fr.run([{"op": "apply", "to": "target",
		"effect": {"kind": "mark", "turns": 9, "text": "Bystander", "name_override": "Bystander"}}])
	_check(_count_named(foe, "Bystander") == 1, "(setup) one unrelated effect sits on the target")
	fr.run([{"op": "remove", "name": "Nothing At All", "to": "target"}])
	_check(_count_named(foe, "Bystander") == 1,
		"...and the miss removed NOTHING — the target's unrelated effect is still there (%d)" % _count_named(foe, "Bystander"))
	fr.run([{"op": "remove", "name": "Bystander", "to": "target"}])
	_heal_full(foe)

	# --- (5) the optional effect-type filter -------------------------------------
	# Two effects, ONE name (name_override is a universal authored field), two types — which
	# is exactly what add_effect's (name, type, user) dedup deliberately keeps apart.
	var echo = _mk("Echo", me, false)
	var er = _runner(echo, m, me)
	var echo_mark := {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 9, "text": "Echo", "name_override": "Echo"}}
	var echo_dot := {"op": "apply", "to": "user",
		"effect": {"kind": "damage_over_time", "amount": 5, "turns": 9, "name_override": "Echo"}}
	er.run([echo_mark, echo_dot])
	_check(me.has_effect("Echo", EffectType.Type.MARK, me) != null
			and me.has_effect("Echo", EffectType.Type.DAMAGE, me) != null,
		"(setup) two effects share the name 'Echo' and differ only in TYPE")
	er.run([{"op": "remove", "name": "Echo", "effect": "MARK", "to": "user"}])
	_check(me.has_effect("Echo", EffectType.Type.MARK, me) == null, "naming the TYPE took only the MARK...")
	_check(me.has_effect("Echo", EffectType.Type.DAMAGE, me) != null, "...and left the same-named DoT alone")
	er.run([echo_mark])
	_check(_count_named(me, "Echo") == 2, "(setup) both are back (%d)" % _count_named(me, "Echo"))
	er.run([{"op": "remove", "name": "Echo", "to": "user"}])
	_check(_count_named(me, "Echo") == 0,
		"OMITTING the type takes every type carrying the name (%d left)" % _count_named(me, "Echo"))

	# --- (6) SHIELD routes through the BREAK path --------------------------------
	# The claim under test is not "the shield went away" but "it went away the way a BROKEN
	# shield does". Three paths have to be told apart, and only one assertion can do it:
	#   * a raw erase_effect runs nothing at all;
	#   * the GENERIC teardown (end_effect CANCELLED) runs wrapup_func — so wrapup alone
	#     cannot distinguish it from the shield branch;
	#   * only the SHIELD/BARRIER branch runs Character.check_effect_breaking.
	# check_effect_breaking's Metal Armor clause (character_component.gd:878) erases the BLIND
	# paired with a shield of that name, and nothing else in the engine does that. It is a
	# shipped contingency — the same shape as break_vow / gain_shield_break / break_hero — and
	# it is literally the "paired state stranded" trap the routing exists to avoid.
	var armor = _mk("Metal Armor", me, false)
	var ar = _runner(armor, m, me)
	ar.run([{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 40, "turns": 9}}])
	var sh = me.has_effect("Metal Armor", EffectType.Type.SHIELD, me)
	# The paired half, built with the engine's own factory and applied through
	# Character.apply_effect so it carries the real user/target a shipped Metal Armor has.
	var blind = Effect.blind_effect(6)
	blind.set_source(armor)
	me.apply_effect(blind, me)
	_check(sh != null and sh.mag == 40, "(setup) a 40-point 'Metal Armor' shield is up")
	_check(me.has_effect("Metal Armor", EffectType.Type.BLIND, me) != null,
		"(setup) ...with its paired Blind beside it")
	var broke := [false]
	if sh != null:
		sh.wrapup_func = func(_c): broke[0] = true
	# The type filter is load-bearing: without it `remove` would match the Blind by name too,
	# and its disappearance would prove nothing.
	ar.run([{"op": "remove", "name": "Metal Armor", "effect": "SHIELD", "to": "user"}])
	_check(me.get_shield_effects().size() == 0, "`remove` took the shield down")
	_check(broke[0], "...running its wrapup_func, which a raw erase_effect would have skipped")
	_check(me.has_effect("Metal Armor", EffectType.Type.BLIND, me) == null,
		"...VIA check_effect_breaking: the shipped Metal Armor contingency cleared the paired Blind")
	_check(sh != null and sh.mag == 0,
		"...and the pool was zeroed the way shatter_shields does — the generic CANCELLED branch leaves it at 40 (got %d)"
			% (sh.mag if sh != null else -1))
	_check(sh != null and sh.breaker == me, "...with the remover attributed as the breaker")

	# --- (7) it composes with the condition-filtered selectors --------------------
	for c in [foe, foe2, foe3]:
		_wipe(c)
	var curse = _mk("Curse", me, false)
	var cr = _runner(curse, m, me)
	cr.run([{"op": "apply", "to": "all_enemies", "effect": {"kind": "mark", "turns": 9, "text": "Curse"}}])
	_check(foe.has_any_effect("Curse") and foe2.has_any_effect("Curse") and foe3.has_any_effect("Curse"),
		"(setup) all three enemies carry the mark")
	foe.health.hp = 40
	cr.run([{"op": "remove", "name": "Curse", "to": "any_enemy", "when": {"cond": "hp_below", "value": 50}}])
	_check(not foe.has_any_effect("Curse"), "any_enemy + only-if stripped it off the HURT enemy")
	_check(foe2.has_any_effect("Curse") and foe3.has_any_effect("Curse"),
		"...and SPARED the two healthy ones — the condition is per candidate, not a block gate")
	for c in [foe, foe2, foe3]:
		_wipe(c)
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	# --- (8) the round trip that motivated the op ---------------------------------
	# Shiro banks Ganta Fever with one skill and spends it with another; naruto1 gathers Sage
	# Chakra and naruto2 consumes it. Asserted on the GATE, because that is the player-visible
	# half: the spender is greyed out until the resource is there and greys out again after.
	var gather = _mk("Sage Chakra Gather", me, false)
	var gr = _runner(gather, m, me)
	# name_override, because the resource is named for the RESOURCE and not for the skill that
	# banks it — and because that is the name an author reads off the pip and will type into
	# `remove`, which is why _remove_matching matches on effect_name() rather than the source
	# ability's name.
	var gather_block := {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 21, "text": "Sage Chakra", "name_override": "Sage Chakra",
			"stacks": 1, "max": 3, "show_stacks": true}}
	var spender = _mk("Sage Art", me)
	spender.requires = [{"cond": "stacks_at_least", "name": "Sage Chakra", "value": 3, "on": "user"}]
	spender.blocks = [{"op": "remove", "name": "Sage Chakra", "stacks": 3, "to": "user"},
		{"op": "damage", "amount": 25, "to": "target"}]
	_check(not spender.extra_usable(me), "(setup) the spender is UNUSABLE with nothing banked")
	var banked: Array = []
	for i in range(3):
		gr.run([gather_block])
		var step = me.has_effect("Sage Chakra", EffectType.Type.MARK, me)
		banked.append(step.stack_count() if step != null else -1)
	_check(banked == [1, 2, 3], "three casts of the gatherer bank 1 -> 2 -> 3 stacks (got %s)" % str(banked))
	_check(_count_named(me, "Sage Chakra") == 1,
		"...as ONE effect, not three copies (%d)" % _count_named(me, "Sage Chakra"))
	_check(spender.extra_usable(me), "...which UNLOCKS the spender")
	me.used_ability = null
	spender.execute(me, m)
	_check(not me.has_any_effect("Sage Chakra") and _count_named(me, "Sage Chakra") == 0,
		"using it SPENT the whole resource")
	_check(not spender.extra_usable(me),
		"...and the skill LOCKED ITSELF again — apply banks, remove spends, the gate reads the difference")
	_check(foe.health.hp == foe.health.max_hp - 25,
		"...and the payoff in the same skill still landed (hp %d)" % foe.health.hp)
	_heal_full(foe)

	# --- (9) the validator --------------------------------------------------------
	_check(BlockSchema.OPS.has("remove"), "`remove` is ON the palette")
	var ok := _authored("Spend")
	ok["blocks"] = [{"op": "remove", "name": "Fever", "to": "user"}]
	_check(_valid(ok), "the minimal form validates %s" % _errs(ok))
	var typed := _authored("Spend Typed")
	typed["blocks"] = [{"op": "remove", "name": "Fever", "effect": "MARK", "stacks": 2, "to": "user"}]
	_check(_valid(typed), "the fully-specified form validates %s" % _errs(typed))
	var no_name := _authored("No Name")
	no_name["blocks"] = [{"op": "remove", "stacks": 1, "to": "user"}]
	_check(not _valid(no_name), "a MISSING name is rejected — remove without one would just be `cleanse`")
	var blank := _authored("Blank Name")
	blank["blocks"] = [{"op": "remove", "name": "   ", "to": "user"}]
	_check(not _valid(blank), "...and so is a whitespace-only one")
	var bad_type := _authored("Bad Type")
	bad_type["blocks"] = [{"op": "remove", "name": "Fever", "effect": "NOT_A_TYPE", "to": "user"}]
	_check(not _valid(bad_type), "an unknown effect type is rejected")
	var zero := _authored("Zero Stacks")
	zero["blocks"] = [{"op": "remove", "name": "Fever", "stacks": 0, "to": "user"}]
	_check(not _valid(zero), "stacks: 0 is rejected (the 'all' sentinel is how you say that)")
	var neg := _authored("Negative Stacks")
	neg["blocks"] = [{"op": "remove", "name": "Fever", "stacks": -1, "to": "user"}]
	_check(not _valid(neg), "a NEGATIVE stack count is rejected")
	var unknown := _authored("Unknown Field")
	unknown["blocks"] = [{"op": "remove", "name": "Fever", "count": 2, "to": "user"}]
	_check(not _valid(unknown), "an unknown field is rejected (cleanse's `count` is not remove's `stacks`)")
	# The type vocabulary is DERIVED from EffectType, not restated: remove.effect and
	# effect_immunity.effect must read the same list or one of them will drift off the enum.
	var types := BlockSchema.immunity_effects()
	_check("SHIELD" in types and "MARK" in types,
		"...and the accepted type list is the EffectType-derived one effect_immunity uses")

	for c in [me, foe, foe2, foe3]:
		_wipe(c)
	me.used_ability = null
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

# How many effects on `c` answer to this name, whatever their type. has_effect only ever
# reports ONE, so it cannot tell "removed" from "removed one of two" — and it cannot see an
# effect parked at 0 stacks that never actually ended.
func _count_named(c, nm: String) -> int:
	var n := 0
	for e in c.effects._effects:
		if str(e.effect_name()) == nm:
			n += 1
	return n

# =====================================================================================
# HIDDEN SKILLS. The Creator used to demand exactly four ACTIVES; the game only has
# four SLOTS. Asserted on what a character ends up able to press, not on the count the
# validator happens to keep.
# =====================================================================================
func _authored(nm: String, hidden := false, passive := false) -> Dictionary:
	var d := {"name": nm, "target": "enemy", "cooldown": 0, "cost": {},
		"classes": (["Passive"] if passive else ["Instant", "Harmful", "Damaging"]),
		"requires": [], "blocks": [{"op": "damage", "amount": 10, "damage_type": "NORMAL"}]}
	if passive:
		# A Passive's block needs an explicit `to` (Phase A3): a Passive is run once at battle
		# start, before anyone has clicked a target, so the default "target" is empty and the
		# block is inert. These fixtures are about the ABILITY-level fields, not about the aim.
		d["blocks"][0]["to"] = "all_enemies"
	if hidden:
		d["hidden"] = true
	return d

func _authored_spec(id: String, abilities: Array) -> Dictionary:
	return {"id": id, "name": "Palette Probe", "author": "palette_probe", "status": "testing",
		"description": "", "colors": [2], "abilities": abilities}

# A one-block ability whose only content is a cost/cooldown modifier of `amt`.
func _mod_skill(kind: String, amt) -> Dictionary:
	var eff := {"kind": kind, "amount": amt, "turns": 2}
	if kind == "cost_change":
		eff["colour"] = "blue"
	return {"name": "Modifier", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Instant", "Harmful"], "requires": [],
		"blocks": [{"op": "apply", "to": "target", "effect": eff}]}

func _names(list: Array) -> Array:
	var out: Array = []
	for a in list:
		out.append(str(a.ability_name))
	return out

# The same, for raw spec dictionaries rather than built Ability nodes.
func _names_of_specs(list: Array) -> Array:
	var out: Array = []
	for d in list:
		out.append(str(d.get("name", "")))
	return out

func _hidden_slots():
	print("-- hidden skills / board slots --")
	# (1) 4 visible + 2 hidden. Author order interleaved on purpose: the hidden pair is
	# NOT written last, so a build that just copied the spec order would fail this.
	var four_two := [_authored("Slot A"), _authored("Slot B"), _authored("Ace", true),
		_authored("Slot C"), _authored("Slot D"), _authored("Reserve", true)]
	var spec := _authored_spec("auth_palette_hidden", four_two)
	var errs := AuthoredRegistry.validate_character(spec)
	_check(errs.is_empty(), "4 visible + 2 hidden VALIDATES (%s)" % str(errs))

	var c = load("res://blocks/authored_character.tscn").instantiate()
	add_child(c)
	c.configure(spec)
	_check(c.moveset.base_abilities.size() == 6,
		"...and BUILDS all six skills (%d)" % c.moveset.base_abilities.size())
	var board := _names(c.moveset.display_abilities())
	_check(board == ["Slot A", "Slot B", "Slot C", "Slot D"],
		"the four VISIBLE skills hold slots 0-3 in author order (%s)" % str(board))
	var tail := _names(c.moveset.base_abilities.slice(4))
	_check(tail == ["Ace", "Reserve"],
		"...and the hidden pair sits BEHIND them, off the board (%s)" % str(tail))
	c.queue_free()

	# (2) The four-slot rule is real in the other direction too.
	var three := [_authored("V1"), _authored("V2"), _authored("V3"), _authored("H", true)]
	var three_errs := AuthoredRegistry.validate_character(_authored_spec("auth_palette_three", three))
	_check(not three_errs.is_empty(), "3 visible actives is REJECTED — the four-slot rule is real")
	var named_rule := false
	for e in three_errs:
		if str(e).contains("visible active skills"):
			named_rule = true
	_check(named_rule, "...and the error names the slot rule (%s)" % str(three_errs))
	# A Passive is slotless, so it must not be able to stand in for the missing fourth.
	var three_pas := [_authored("V1"), _authored("V2"), _authored("V3"), _authored("P", false, true)]
	_check(not AuthoredRegistry.validate_character(_authored_spec("auth_palette_threep", three_pas)).is_empty(),
		"...and a Passive does NOT fill the empty slot either")

	# (3) The raised ceiling is not restrictive in practice.
	var many := [_authored("A"), _authored("B"), _authored("C"), _authored("D")]
	for i in range(8):
		many.append(_authored("Form %d" % i, true))
	var many_spec := _authored_spec("auth_palette_many", many)
	var many_errs := AuthoredRegistry.validate_character(many_spec)
	_check(many.size() == 12 and many_errs.is_empty(),
		"4 visible + 8 hidden (12 skills) validates (%s)" % str(many_errs))
	var big = load("res://blocks/authored_character.tscn").instantiate()
	add_child(big)
	big.configure(many_spec)
	_check(big.moveset.base_abilities.size() == 12,
		"...and builds all twelve (%d)" % big.moveset.base_abilities.size())
	_check(_names(big.moveset.display_abilities()) == ["A", "B", "C", "D"],
		"...while the board still shows exactly the four visible ones (%s)" % str(_names(big.moveset.display_abilities())))
	big.queue_free()

	# (7) A signed amount of 0 is a no-op the author did not mean; it is refused for
	# BOTH kinds, in both the "this is new" and "this still works" directions.
	for kind in ["cost_change", "cooldown_change"]:
		_check(not BlockValidator.validate_ability(_mod_skill(kind, 0)).is_empty(),
			"%s amount 0 is REJECTED" % kind)
		_check(BlockValidator.validate_ability(_mod_skill(kind, -1)).is_empty(),
			"%s amount -1 is accepted (%s)" % [kind, str(BlockValidator.validate_ability(_mod_skill(kind, -1)))])
		_check(BlockValidator.validate_ability(_mod_skill(kind, -2)).is_empty(), "%s amount -2 is accepted" % kind)
		_check(BlockValidator.validate_ability(_mod_skill(kind, 1)).is_empty(), "%s amount +1 is still accepted" % kind)
		_check(BlockValidator.validate_ability(_mod_skill(kind, -3)).is_empty(),
			"%s amount -3 is accepted — mercury1 ships cooldown_mod(-3)" % kind)
		_check(not BlockValidator.validate_ability(_mod_skill(kind, int(BlockSchema.LIMITS["max_amount"]) + 1)).is_empty(),
			"%s past the sanity clamp is out of range — the bound is symmetric, not absent" % kind)

# =====================================================================================
# SIGNED cost / cooldown modifiers, asserted on the quantity the engine actually reads
# (Ability.cost() and the cooldown a use leaves behind) and on WHICH APPLICATION PATH
# the effect took — the latter through a target that shrugs off hostile COST_MODs.
# =====================================================================================
func _signed_modifiers(m, me, p1, immune_foe):
	print("-- signed cost / cooldown modifiers --")
	# A discount off a cost of 0 is indistinguishable from doing nothing, so find a real
	# coloured cost on a real teammate rather than assuming one.
	var ally = null
	var ally_skill = null
	var colour_name := ""
	var colour_id := -1
	for cand_char in [p1.team.characters[1], p1.team.characters[2]]:
		for cand in cand_char.moveset.base_abilities:
			for pair in [["green", Energy.Type.GREEN], ["blue", Energy.Type.BLUE],
					["white", Energy.Type.WHITE], ["red", Energy.Type.RED]]:
				if int(cand.cost()[pair[1]]) >= 1:
					ally = cand_char
					ally_skill = cand
					colour_name = str(pair[0])
					colour_id = int(pair[1])
					break
			if ally_skill != null:
				break
		if ally_skill != null:
			break
	_check(ally_skill != null, "(setup) an ally has a skill with a real coloured cost")
	if ally_skill == null:
		return

	# The routing consequence, set up FIRST: add_hostile_effect consults
	# shrug_off_type(effect_type) before anything else and drops the effect outright.
	# So a character immune to COST_MOD is a litmus test for which path was taken.
	me.targeter.targets = [ally]
	me.targeter.main_target = ally
	_runner(_mk("Cost Ward", me, false), m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "effect_immunity", "turns": 6, "effect": "COST_MOD"}}])
	_check(ally.shrug_off_type(EffectType.Type.COST_MOD),
		"(setup) the ally would SHRUG OFF a hostile COST_MOD")

	var cost_before: int = int(ally_skill.cost()[colour_id])
	var boon = _mk("Boon", me, false)
	_runner(boon, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cost_change", "amount": -1, "colour": colour_name, "turns": 3}}])
	# HONEST LABEL: this one is a regression guard, NOT a test of the sign-aware
	# routing. _op_apply only takes the hostile path when `hostile AND
	# user.is_hostile(t)`, and an ally never satisfies the second half — so this
	# assertion passes whether or not _is_hostile_effect consults the sign (verified
	# by reversal: it did not fail when the sign-awareness was removed). The enemy
	# case below is the one that actually pins the routing down.
	_check(ally.has_effect("Boon", EffectType.Type.COST_MOD, me) != null,
		"a DISCOUNT lands on an ally that shrugs off hostile COST_MODs")
	_check(int(ally_skill.cost()[colour_id]) == cost_before - 1,
		"...and it LOWERED the ally's resolved %s cost %d -> %d"
			% [colour_name, cost_before, int(ally_skill.cost()[colour_id])])

	# The sharp end. Same immunity, but on an ENEMY — where _op_apply's own
	# `user.is_hostile(t)` gate is NOT doing the work — so the SIGN is the only thing
	# that can decide the path. A tax is refused; a discount is not.
	me.targeter.targets = [immune_foe]
	me.targeter.main_target = immune_foe
	_runner(_mk("Cost Ward 2", me, false), m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "effect_immunity", "turns": 6, "effect": "COST_MOD"}}])
	_check(immune_foe.shrug_off_type(EffectType.Type.COST_MOD), "(setup) the enemy shrugs off COST_MOD too")
	_runner(_mk("Refused Tax", me), m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cost_change", "amount": 1, "colour": colour_name, "turns": 3}}])
	_check(immune_foe.has_effect("Refused Tax", EffectType.Type.COST_MOD, me) == null,
		"a TAX on that enemy is REFUSED — positive still takes the hostile path")
	_runner(_mk("Gift", me, false), m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cost_change", "amount": -1, "colour": colour_name, "turns": 3}}])
	_check(immune_foe.has_effect("Gift", EffectType.Type.COST_MOD, me) != null,
		"...but a DISCOUNT LANDS on the SAME character — the SIGN, not the kind, picks the path")

	# --- cooldown, both directions off one baseline ---------------------------
	var cd_char = null
	var cd_skill = null
	for cand_char in [p1.team.characters[1], p1.team.characters[2]]:
		for cand in cand_char.moveset.base_abilities:
			if int(cand.cooldown) >= 2:
				cd_char = cand_char
				cd_skill = cand
				break
		if cd_skill != null:
			break
	_check(cd_skill != null, "(setup) an ally has a skill with a printed cooldown")
	if cd_skill == null:
		return
	cd_skill.start_cooldown()
	var cd_plain: int = int(cd_skill.cooldown_remaining)
	me.targeter.targets = [cd_char]
	me.targeter.main_target = cd_char

	var hasten = _mk("Hasten", me, false)
	_runner(hasten, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cooldown_change", "amount": -2, "turns": 3}}])
	cd_skill.start_cooldown()
	_check(int(cd_skill.cooldown_remaining) == cd_plain - 2,
		"a NEGATIVE cooldown_change SHORTENED the cooldown a use leaves (%d -> %d)"
			% [cd_plain, int(cd_skill.cooldown_remaining)])
	# Clear it, so the positive case is measured from the same baseline rather than
	# from the sum of the two.
	var disc = cd_char.has_effect("Hasten", EffectType.Type.COOLDOWN_MOD, me)
	if disc != null:
		disc.end_effect()
	cd_skill.start_cooldown()
	_check(int(cd_skill.cooldown_remaining) == cd_plain, "(teardown) the discount is gone again")

	var slowdown = _mk("Slowdown", me, false)
	_runner(slowdown, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "cooldown_change", "amount": 2, "turns": 3}}])
	cd_skill.start_cooldown()
	_check(int(cd_skill.cooldown_remaining) == cd_plain + 2,
		"a POSITIVE one LENGTHENED it from that same baseline (%d -> %d)"
			% [cd_plain, int(cd_skill.cooldown_remaining)])

# =====================================================================================
# `swap` INTO A HIDDEN SKILL, end to end. `into` used to be range-checked 0-4, which
# put every hidden skill (index >= 4 once the four visible ones are placed) out of
# reach and made the whole feature unreachable. The observable is the BOARD — the wire
# snapshot the client draws its four buttons from — not any internal flag.
# =====================================================================================
func _wire_board(mgr, path_name: String) -> Array:
	var out: Array = []
	var snap = mgr.serialize_wire_snapshot()
	for side in snap["sides"]:
		for c in side["team"]:
			if str(c["path_name"]) == path_name:
				for a in c["abilities"]:
					out.append(str(a["ability_name"]))
	return out

func _hidden_swap_live():
	print("-- swap into a hidden skill (live battle) --")
	# moveset_order: visible 0-3, Passive 4, hidden 5-6. `into` is deliberately 6 — the
	# OLD bound was 0-4, so an index that merely clears the visible four would still
	# have been accepted by it and would prove nothing. 6 is only reachable now.
	var passive := {"name": "Instinct", "target": "self", "cooldown": 0, "cost": {},
		"classes": ["Passive"], "requires": [],
		"blocks": [{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": -1, "text": "Instinct"}}]}
	var defs := [
		{"name": "Awaken", "target": "self", "cooldown": 0, "cost": {},
			"classes": ["Strategic", "Instant", "Helpful"], "requires": [],
			"blocks": [{"op": "apply", "to": "user",
				"effect": {"kind": "swap", "slot": 0, "into": 6, "turns": 3}}]},
		_authored("Jab"), _authored("Hook"), _authored("Cross"),
		passive, _authored("Reserve Stance", true), _authored("Hidden Fang", true)]
	var spec := _authored_spec("auth_palette_swap", defs)
	var errs := AuthoredRegistry.validate_character(spec)
	_check(errs.is_empty(), "a skill that swaps slot 0 into HIDDEN index 6 validates (%s)" % str(errs))
	_check(_names_of_specs(BlockValidator.moveset_order(defs)) ==
			["Awaken", "Jab", "Hook", "Cross", "Instinct", "Reserve Stance", "Hidden Fang"],
		"(setup) index 6 really is the second hidden skill, past the Passive")

	# authored/ is gitignored user data, so the probe writes its own fixture and
	# removes it again — while still going through the real load-and-revalidate path.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://authored"))
	var f := FileAccess.open("res://authored/auth_palette_swap.json", FileAccess.WRITE)
	if f == null:
		_check(false, "(setup) could not write the probe fixture")
		return
	f.store_string(JSON.stringify(spec, "\t"))
	f.close()
	AuthoredRegistry.load_all(true)
	_check(AuthoredRegistry.get_spec("auth_palette_swap") != null,
		"(setup) the fixture loaded and passed load-time validation")

	var m2 := BattleManager.new()
	m2.name = "SwapBattleManager"
	m2.shadow_mode = true
	add_child(m2)
	var p1 = _build_player("SwapPlayer", ["auth_palette_swap", "naruto", "gon"], false)
	var p2 = _build_player("SwapEnemy", ["eren", "misaka", "sakura"], true)
	m2.start_battle(p1, p2, true, 77, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	for c in p2.team.characters:
		c.bot_character = false
	var hero = p1.team.characters[0]
	_check(hero is AuthoredCharacter, "(setup) the authored character joined a real battle")

	var before := _wire_board(m2, "auth_palette_swap")
	_check(before == ["Awaken", "Jab", "Hook", "Cross"],
		"(baseline) the client's board shows the four visible skills (%s)" % str(before))
	_check(not ("Hidden Fang" in before), "(baseline) the hidden skill is NOT on the board")

	var awaken = hero.moveset.base_abilities[0]
	hero.used_ability = awaken
	hero.targeter.targets = [hero]
	hero.targeter.main_target = hero
	awaken.execute(hero, m2)
	var after := _wire_board(m2, "auth_palette_swap")
	_check(after.size() == 4 and after[0] == "Hidden Fang",
		"SLOT 0 NOW SHOWS 'Hidden Fang' ON THE BOARD (%s)" % str(after))
	_check(after.size() == 4 and after.slice(1) == ["Jab", "Hook", "Cross"],
		"...and the other three slots are untouched (%s)" % str(after))

	var sw = hero.has_effect("Awaken", EffectType.Type.ABILITY_SWAP, hero)
	_check(sw != null, "(setup) the swap effect is the thing holding the slot")
	if sw != null:
		sw.end_effect()
		var restored := _wire_board(m2, "auth_palette_swap")
		_check(restored.size() == 4 and restored[0] == "Awaken",
			"...and ending it hands slot 0 back (%s)" % str(restored))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://authored/auth_palette_swap.json"))
	AuthoredRegistry.load_all(true)

# #####################################################################################
# #####################################################################################
# THE BOUND AUDIT.
#
# Every entry below is one line of the audit that found the Creator enforcing a rule
# the shipped game does not have. The rule is proved gone by feeding the validator the
# EXACT SHAPE OF A SHIPPED ABILITY that used to be rejected — xanxus2's 6-energy cost,
# toudou1's duration-3 counter, broly2's duration-5 class-scoped one, cooler1/cooler5's
# self-refreshing swap chain, cooler6's costed Passive, gatomon's two passives, the
# Invisible and Unstunnable classes, mercury1's cooldown_mod(-3).
#
# The assertions are deliberately written so that RESTORING the old bound fails them.
# An assertion phrased as "this shipped thing works" that would also pass with the bound
# back in place proves nothing; each one is annotated with the number it has to break.
# #####################################################################################
# #####################################################################################

# --- small helpers ----------------------------------------------------------
func _valid(spec) -> bool:
	return BlockValidator.validate_ability(spec).is_empty()

func _errs(spec) -> String:
	return str(BlockValidator.validate_ability(spec))

# A one-ability spec whose single block applies `eff`, for validator round-trips.
func _apply_skill(eff: Dictionary) -> Dictionary:
	return {"name": "Probe Skill", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Instant", "Harmful"], "requires": [],
		"blocks": [{"op": "apply", "to": "target", "effect": eff}]}

func _four() -> Array:
	return [_authored("V1"), _authored("V2"), _authored("V3"), _authored("V4")]

# A whole-character spec with `overrides` stamped over the top-level fields.
func _char_with(overrides: Dictionary) -> Dictionary:
	var s := _authored_spec("auth_palette_bounds", _four())
	for k in overrides.keys():
		s[k] = overrides[k]
	return s

func _char_ok(spec) -> bool:
	return AuthoredRegistry.validate_character(spec).is_empty()

func _char_errs(spec) -> String:
	return str(AuthoredRegistry.validate_character(spec))

# _mk with an explicit class list, built from the engine's own CLASS_NAMES so a class
# the roster uses (Affliction, Unstunnable, ...) cannot be missing from the dict.
func _mk_cls(nm: String, owner, cls: Array):
	var a = load("res://blocks/scripted_ability.gd").new()
	a.ability_name = nm
	a.blocks = []
	var d := Ability.default_classes()
	for c in cls:
		d[str(c)] = true
	a.classes = d
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _wipe(c) -> void:
	for e in c.effects._effects.duplicate():
		if not e.system:
			e.end_effect()
	_heal_full(c)

func _find_ability(c, nm: String):
	for a in c.moveset.base_abilities:
		if str(a.ability_name) == nm:
			return a
	return null

# =====================================================================================
# (A) VALIDATION. Every removed / raised bound, fed the shipped value that used to be
# rejected, plus the one-past-the-new-bound case so a RAISE is never mistaken for a
# REMOVAL. Where a bound was kept it is asserted to still bite, in the same breath.
# =====================================================================================
func _removed_bounds_validate():
	print("-- (A) removed/raised bounds: the shipped shapes now VALIDATE --")

	# --- cost: total 5, per-colour 4 -----------------------------------------
	var xanxus := _authored("Bloody Twins")
	xanxus["cost"] = {"0": 1, "4": 5}
	_check(_valid(xanxus), "xanxus2's SIX-energy cost (1 Green + 5 Random) validates %s" % _errs(xanxus))
	var yuno := _authored("Spirit Dive")
	yuno["cost"] = {"1": 4, "4": 2}
	_check(_valid(yuno), "yuno7's six-energy cost (4 Blue + 2 Random) validates %s" % _errs(yuno))
	var five_one := _authored("Five of One")
	five_one["cost"] = {"4": 5}
	_check(_valid(five_one), "...and 5 of a SINGLE colour, which the old 0-4 per-colour bound rejected")
	var over_colour := _authored("Twenty One")
	over_colour["cost"] = {"0": 21}
	_check(not _valid(over_colour), "RAISED, NOT REMOVED: 21 of one colour is still out of range")
	var bad_key := _authored("Bad Key")
	bad_key["cost"] = {"5": 1}
	_check(not _valid(bad_key), "KEPT: cost key 5 is rejected — Energy.Type has exactly five members")

	# --- counter: duration forced to exactly 1 turn --------------------------
	var payload := [{"op": "damage", "amount": 15, "to": "target"}]
	var c_toudou := _apply_skill({"kind": "counter", "scope": "harmful", "ticks": 3, "then": payload})
	_check(_valid(c_toudou), "toudou1's duration-3 counter validates %s" % _errs(c_toudou))
	var c_broly := _apply_skill({"kind": "counter", "scope": ["Harmful"], "ticks": 5, "then": payload})
	_check(_valid(c_broly), "broly2's duration-5 counter validates %s" % _errs(c_broly))
	var c_common := _apply_skill({"kind": "counter", "scope": "harmful", "turns": 2, "then": payload})
	_check(_valid(c_common), "the 30-shipped-counter idiom (2 author turns) validates")
	var c_perm := _apply_skill({"kind": "counter", "scope": "any", "turns": -1, "then": payload})
	_check(_valid(c_perm), "a PERMANENT counter validates — it is SPENT when it fires, so it locks nobody out")
	var c_over := _apply_skill({"kind": "counter", "scope": "any", "turns": 100, "then": payload})
	_check(_valid(c_over), "REMOVED CAP: a 100-turn counter validates — effect durations are author-controlled (owner ruling)")

	# --- counter: scope whitelist (harmful|damaging|any) ---------------------
	for scope in [["Affliction"], ["Mental"], ["Physical"], ["Energy"], ["Strategic", "Mental"], ["Energy", "Affliction"]]:
		var cs := _apply_skill({"kind": "counter", "scope": scope, "ticks": 3, "then": payload})
		_check(_valid(cs), "counter scope %s validates — korra1-4 / tokoyami3 / tsunayoshi2 filter exactly like this %s"
			% [str(scope), _errs(cs)])
	var cs_bad := _apply_skill({"kind": "counter", "scope": ["Kryptonite"], "ticks": 3, "then": payload})
	_check(not _valid(cs_bad), "KEPT: a class list is still validated member by member")

	# --- swap: chains banned, `into` 0-4, duration 1-6 -----------------------
	# cooler1 applies Effect.ability_swap_effect(4, 0, user, 3); cooler5 — the skill it
	# swaps into slot 0 — re-applies the IDENTICAL swap to extend itself. Index 4 here is
	# the same index cooler uses, because the hidden skill lands at 4 in moveset_order.
	var chain_defs := [
		{"name": "Death Chaser", "target": "enemy", "cooldown": 0, "cost": {},
			"classes": ["Physical", "Instant", "Harmful", "Damaging"], "requires": [],
			"blocks": [{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 0, "into": 4, "ticks": 3}}]},
		_authored("V2"), _authored("V3"), _authored("V4"),
		{"name": "Sadistic Tread", "target": "enemy", "cooldown": 0, "cost": {}, "hidden": true,
			"classes": ["Physical", "Instant", "Harmful", "Damaging"], "requires": [],
			"blocks": [{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 0, "into": 4, "ticks": 3}}]}]
	var chain_spec := _authored_spec("auth_palette_chainv", chain_defs)
	_check(_char_ok(chain_spec),
		"cooler1/cooler5's SELF-REFRESHING swap chain validates — the swapped-in skill re-applies its own swap %s"
			% _char_errs(chain_spec))
	var yoh := _apply_skill({"kind": "swap", "slot": 0, "into": 1, "ticks": 20})
	_check(_valid(yoh), "yoh1/yoh2/yoh3's 20-tick swap validates (the old cap was 6 author turns) %s" % _errs(yoh))
	var swap9 := _apply_skill({"kind": "swap", "slot": 0, "into": 1, "turns": 9})
	_check(_valid(swap9), "...and 9 author turns, which swap_turns_to_duration makes 19")
	_check(not _valid(_apply_skill({"kind": "swap", "slot": 4, "into": 1, "turns": 1})),
		"KEPT: slot 4 is rejected — display_abilities() is a hard [0..3] slice")

	# --- classes whitelist ---------------------------------------------------
	for cname in ["Invisible", "Unstunnable", "Uncounterable", "Control", "Channeled", "Stealthed", "Preserves Channel"]:
		var ca := _authored("Class " + cname)
		ca["classes"] = ["Instant", cname]
		_check(_valid(ca), "class '%s' is accepted %s" % [cname, _errs(ca)])
	var bad_class := _authored("Bad Class")
	bad_class["classes"] = ["Invincible"]
	_check(not _valid(bad_class), "KEPT: an unknown class is still rejected")

	# --- signed cost/cooldown magnitude (-2..2) ------------------------------
	for kind in ["cost_change", "cooldown_change"]:
		_check(_valid(_mod_skill(kind, -3)), "%s -3 validates — mercury1 ships cooldown_mod(-3, 3, [...]) " % kind)
		_check(_valid(_mod_skill(kind, -9999)) and _valid(_mod_skill(kind, 9999)),
			"%s reaches the shared +/-max_amount envelope" % kind)
		_check(not _valid(_mod_skill(kind, 10000)), "RAISED, NOT REMOVED: %s 10000 is out of range" % kind)
		_check(not _valid(_mod_skill(kind, 0)), "KEPT: %s 0 is rejected — it is a silently inert effect" % kind)

	# --- effect_immunity whitelist -------------------------------------------
	for et in ["SHIELD", "COUNTER_RECEIVE", "COUNTER_USE", "STUN", "SILENCE", "BLIND", "COST_MOD"]:
		var ie := _apply_skill({"kind": "effect_immunity", "turns": 4, "effect": et})
		_check(_valid(ie), "effect_immunity(%s) validates %s" % [et, _errs(ie)])
	_check(not _valid(_apply_skill({"kind": "effect_immunity", "turns": 4, "effect": "NOT_A_TYPE"})),
		"KEPT: a non-EffectType name is rejected")
	_check(not _valid(_apply_skill({"kind": "effect_immunity", "turns": 4, "effect": "MISSION_TRIGGER_ON_KILL"})),
		"KEPT: the MISSION_TRIGGER_* family stays excluded — they are achievement hooks, not battle effects")

	# --- paralyze duration 1-2 ----------------------------------------------
	_check(_valid(_apply_skill({"kind": "paralyze", "ticks": 3})),
		"rimuru2's ODD duration-3 paralyze validates (the old bound was 1-2 author turns, i.e. 2 or 4)")
	_check(_valid(_apply_skill({"kind": "paralyze", "turns": 6})), "...and a 6-turn paralyze validates")

	# --- Passive: no cost, no requires, at most one --------------------------
	var costed_passive := _authored("Cruel Transformation", false, true)
	costed_passive["cost"] = {"0": 1}
	_check(_valid(costed_passive), "cooler6's COSTED Passive validates %s" % _errs(costed_passive))
	var req_passive := _authored("Gated Passive", false, true)
	req_passive["requires"] = [{"cond": "hp_above", "value": 0, "on": "user"}]
	_check(_valid(req_passive), "a Passive carrying an (inert) `requires` validates %s" % _errs(req_passive))
	var cd_passive := _authored("Cooldown Passive", false, true)
	cd_passive["cooldown"] = 3
	_check(not _valid(cd_passive), "KEPT: a Passive with a cooldown is still rejected (105 shipped passives all ship 0)")
	var two_pas := _four()
	two_pas.append(_authored("Saint Air", false, true))
	two_pas.append(_authored("Eden's Air", false, true))
	_check(_char_ok(_authored_spec("auth_palette_twopas", two_pas)),
		"gatomon's TWO passives validate on one character %s" % _char_errs(_authored_spec("auth_palette_twopas", two_pas)))

	# --- character-level bounds ----------------------------------------------
	_check(_char_ok(_char_with({"name": "The Thompson Sisters (Liz and Patty)"})),
		"the roster's longest name (36 chars) validates — the old bound was 32")
	_check(not _char_ok(_char_with({"name": "x".repeat(65)})), "RAISED, NOT REMOVED: 65 characters is rejected")
	_check(_char_ok(_char_with({"colors": []})),
		"an EMPTY colours list validates — jinwoo/minene/shiro/toga/usopp all ship character_colors = []")
	_check(_char_ok(_char_with({"colors": [3, 4]})),
		"blackwargreymon's [3, 4] validates — 4 is Energy.Type.RANDOM")
	_check(not _char_ok(_char_with({"colors": [5]})), "RAISED, NOT REMOVED: colour 5 is rejected")
	_check(not _char_ok(_char_with({"colors": [0, 1, 2, 3, 4, 0]})), "RAISED, NOT REMOVED: 6 colours is rejected")
	_check(_char_ok(_char_with({"description": "d".repeat(900)})), "a 900-character description validates (old bound 500)")
	_check(not _char_ok(_char_with({"description": "d".repeat(1001)})), "RAISED, NOT REMOVED: 1001 characters is rejected")

	# --- ability-level numeric bounds ----------------------------------------
	var cd12 := _authored("Long Cooldown")
	cd12["cooldown"] = 12
	_check(_valid(cd12), "cooldown 12 validates (old bound 0-10; emiyaarcher2 ships 9)")
	var cd100 := _authored("Absurd Cooldown")
	cd100["cooldown"] = 100
	_check(not _valid(cd100), "RAISED, NOT REMOVED: cooldown 100 is rejected")
	var name64 := _authored("n".repeat(64))
	_check(_valid(name64), "a 64-character ability name validates (old bound 48)")
	_check(not _valid(_authored("n".repeat(65))), "RAISED, NOT REMOVED: 65 characters is rejected")

	var reqs12 := _authored("Twelve Gates")
	reqs12["requires"] = []
	for i in range(12):
		reqs12["requires"].append({"cond": "hp_above", "value": i, "on": "user"})
	_check(_valid(reqs12), "12 usage conditions validate (old bound 4) %s" % _errs(reqs12))
	var reqs13 := _authored("Thirteen Gates")
	reqs13["requires"] = reqs12["requires"].duplicate()
	reqs13["requires"].append({"cond": "hp_above", "value": 99, "on": "user"})
	_check(not _valid(reqs13), "RAISED, NOT REMOVED: a 13th condition is rejected")

	var many_names: Array = []
	for i in range(12):
		many_names.append("Skill %d" % i)
	_check(_valid(_apply_skill({"kind": "damage_boost", "amount": 5, "turns": 2, "skills": many_names})),
		"a modifier may name 12 skills (old bound 8)")
	_check(not _valid(_apply_skill({"kind": "damage_boost", "amount": 5, "turns": 2, "skills": []})),
		"KEPT: an EMPTY skills list is still rejected — it reads as a typo that silently widens the effect")

	var gain25 := _authored("Big Charge")
	gain25["blocks"] = [{"op": "gain_energy", "amount": 25, "colour": "blue"}]
	_check(_valid(gain25), "gain_energy 25 validates (old bound 1-5)")
	var gain26 := _authored("Bigger Charge")
	gain26["blocks"] = [{"op": "gain_energy", "amount": 26}]
	_check(not _valid(gain26), "RAISED, NOT REMOVED: gain_energy 26 is rejected")
	var gain_random := _authored("Random Charge")
	gain_random["blocks"] = [{"op": "gain_energy", "amount": 1, "colour": "random"}]
	_check(not _valid(gain_random), "KEPT: gain_energy may not name Random — the pool holds four real colours")

	_check(_valid(_apply_skill({"kind": "mark", "turns": 4, "text": "R", "stacks": 1, "max": 99})),
		"a 99-stack resource validates (old bound 10; astolfo1 has NO ceiling at all)")
	_check(not _valid(_apply_skill({"kind": "mark", "turns": 4, "text": "R", "stacks": 1, "max": 100})),
		"RAISED, NOT REMOVED: max 100 is rejected")
	# A resource is BANKED by re-applying the effect, not by a `stack` op — so the number
	# that has to be reachable is the STARTING stack count, and 99 is it.
	_check(_valid(_apply_skill({"kind": "mark", "turns": 4, "text": "R", "stacks": 99, "max": 99})),
		"a mark may START at 99 stacks %s" % _errs(_apply_skill({"kind": "mark", "turns": 4, "text": "R", "stacks": 99, "max": 99})))
	_check(not _valid(_apply_skill({"kind": "mark", "turns": 4, "text": "R", "stacks": 100, "max": 99})),
		"KEPT: starting above the mark's own ceiling is rejected")
	# The universal `stacks` obeys the same LIMIT on a kind that has no ceiling of its own.
	_check(_valid(_apply_skill({"kind": "shield", "amount": 5, "turns": 2, "stackable": true, "stacks": 99})),
		"a stacking SHIELD may start at 99 %s" % _errs(_apply_skill({"kind": "shield", "amount": 5, "turns": 2, "stackable": true, "stacks": 99})))
	_check(not _valid(_apply_skill({"kind": "shield", "amount": 5, "turns": 2, "stackable": true, "stacks": 100})),
		"RAISED, NOT REMOVED: 100 stacks is rejected on any kind")

	_check(_valid(_apply_skill({"kind": "shield", "amount": 9999, "turns": 2})),
		"an amount of 9999 validates (old clamp 500 — a plain balance knob dressed as a safety bound)")
	_check(not _valid(_apply_skill({"kind": "shield", "amount": 10000, "turns": 2})),
		"RAISED, NOT REMOVED: 10000 is rejected")
	var neg := _authored("Negative")
	neg["blocks"] = [{"op": "damage", "amount": -1}]
	_check(not _valid(neg), "KEPT: a negative damage amount is rejected — it would invert resolve_damage")
	_check(_valid(_apply_skill({"kind": "mark", "turns": 99, "text": "Long"})), "99 author turns validate (old bound 20)")
	_check(_valid(_apply_skill({"kind": "mark", "turns": 100, "text": "Long"})),
		"REMOVED CAP: 100 author turns validate — effect durations are author-controlled (owner ruling)")

	# --- turns -> duration: half the duration space was unreachable ----------
	# turns_to_duration can only produce 2N. `ticks` is the escape hatch, and it is what
	# makes every ODD engine duration the roster ships expressible at all.
	for pair in [["mark", 1], ["damage_over_time", 9], ["heal_over_time", 9], ["invulnerable", 1],
			["destructible_break", 1], ["paralyze", 3], ["silence", 7], ["stun", 5]]:
		var od := {"kind": str(pair[0]), "ticks": int(pair[1])}
		if str(pair[0]) in ["damage_over_time", "heal_over_time"]:
			od["amount"] = 5
		_check(_valid(_apply_skill(od)), "%s at raw engine duration %d validates" % [str(pair[0]), int(pair[1])])
	_check(_valid(_apply_skill({"kind": "mark", "ticks": -1, "text": "Forever"})), "ticks -1 is permanent")
	_check(_valid(_apply_skill({"kind": "mark", "ticks": 400, "text": "X"})),
		"REMOVED CAP: mark ticks 400 validates — raw engine duration is author-controlled (owner ruling)")

	# --- max_abilities 14 ----------------------------------------------------
	var kit32 := _four()
	for i in range(28):
		kit32.append(_authored("Form %d" % i, true))
	_check(kit32.size() == 32 and _char_ok(_authored_spec("auth_palette_kit32", kit32)),
		"a 32-ability character validates (old bound 14, exactly the roster's own maximum)")
	var kit33 := kit32.duplicate()
	kit33.append(_authored("One Too Many", true))
	_check(not _char_ok(_authored_spec("auth_palette_kit33", kit33)), "RAISED, NOT REMOVED: 33 abilities is rejected")
	# DERIVED from the limit, not hard-coded at 32: raising LIMITS.max_abilities without growing
	# AuthoredAssets.SLOTS would leave the top skills with nowhere to store art, and a `>= 32`
	# check would have sailed straight past it (while printing a mismatched pair in its own label).
	_check(AuthoredAssets.ability_slots().size() == int(BlockSchema.LIMITS["max_abilities"]),
		"...and AuthoredAssets grew with it — %d icon slots for %d abilities"
			% [AuthoredAssets.ability_slots().size(), int(BlockSchema.LIMITS["max_abilities"])])

	# --- target modes --------------------------------------------------------
	var everyone := _authored("Board Wipe")
	everyone["target"] = "everyone"
	_check(_valid(everyone), "target mode 'everyone' validates — 147 shipped abilities are TargetType.ALL, 11 are ALL_FACTION")
	var bogus_mode := _authored("Nonsense")
	bogus_mode["target"] = "count"
	_check(not _valid(bogus_mode), "KEPT: an unknown target mode is rejected (COUNT is deliberately not offered)")

	# --- ability-level engine FLAGS ------------------------------------------
	for flag in BlockValidator.ABILITY_FLAGS:
		var fa := _authored("Flag " + flag)
		fa[flag] = true
		_check(_valid(fa), "ability flag '%s' is authorable %s" % [flag, _errs(fa)])
		var bad_flag := _authored("Bad Flag " + flag)
		bad_flag[flag] = "yes"
		_check(not _valid(bad_flag), "KEPT: '%s' must be a boolean" % flag)

# =====================================================================================
# (B) THE GUARDS THAT WERE KEPT. An engineering guard that no longer guards is worse
# than no guard, because it reads as protection — so each one is asserted to still
# refuse the thing it exists to refuse.
# =====================================================================================
func _kept_guards():
	print("-- (B) kept guards still bite --")

	# max_blocks_per_ability: the runaway guard on a tree walked every cast.
	var cap: int = BlockSchema.LIMITS["max_blocks_per_ability"]
	var at_cap := _authored("At Cap")
	at_cap["blocks"] = []
	for i in range(cap):
		at_cap["blocks"].append({"op": "damage", "amount": 1})
	_check(_valid(at_cap), "%d blocks is accepted %s" % [cap, _errs(at_cap)])
	var over_cap := _authored("Over Cap")
	over_cap["blocks"] = at_cap["blocks"].duplicate()
	over_cap["blocks"].append({"op": "damage", "amount": 1})
	_check(not _valid(over_cap), "KEPT: %d blocks is REJECTED — the runaway guard" % (cap + 1))

	# max_nesting_depth: a trigger whose payload applies a trigger is the one shape
	# that can recurse without bound at runtime, so a payload is charged +2.
	var inner := {"kind": "trigger", "trigger": "on_turn_end", "turns": 2, "text": "i",
		"then": [{"op": "damage", "amount": 1, "to": "target"}]}
	var mid := {"kind": "trigger", "trigger": "on_turn_end", "turns": 2, "text": "m",
		"then": [{"op": "apply", "to": "user", "effect": inner}]}
	var outer := {"kind": "trigger", "trigger": "on_turn_end", "turns": 2, "text": "o",
		"then": [{"op": "apply", "to": "user", "effect": mid}]}
	_check(_valid(_apply_skill(mid)), "two levels of trigger nesting is accepted %s" % _errs(_apply_skill(mid)))
	_check(not _valid(_apply_skill(outer)), "KEPT: three levels is REJECTED — the recursion guard")

	# max_trigger_then_blocks: the hottest authored code path.
	var then_max: int = BlockSchema.LIMITS["max_trigger_then_blocks"]
	var pay: Array = []
	for i in range(then_max):
		pay.append({"op": "damage", "amount": 1, "to": "target"})
	_check(_valid(_apply_skill({"kind": "trigger", "trigger": "on_turn_end", "turns": 2, "text": "p", "then": pay})),
		"a %d-block trigger payload is accepted" % then_max)
	var pay_over := pay.duplicate()
	pay_over.append({"op": "damage", "amount": 1, "to": "target"})
	_check(not _valid(_apply_skill({"kind": "trigger", "trigger": "on_turn_end", "turns": 2, "text": "p", "then": pay_over})),
		"KEPT: a %d-block payload is REJECTED — the hot-path guard" % (then_max + 1))
	# ...and the legacy name is bound by the SAME guard, not waved through as "old content".
	_check(not _valid(_apply_skill({"kind": "reactive", "trigger": "on_turn_end", "turns": 2, "text": "p", "then": pay_over})),
		"KEPT: the pre-rename `reactive` alias is held to that guard too")
	# ...and its POSITIVE half, because the line above is a negative assertion that would also
	# pass if the alias stopped resolving altogether (the block would then be rejected for the
	# NAME instead of the size, and the guard would be untested). Verified by reversal: with
	# canonical_kind neutered this line fails and the one above does not.
	_check(_valid(_apply_skill({"kind": "reactive", "trigger": "on_turn_end", "turns": 2, "text": "p", "then": pay})),
		"...and the SAME alias is ACCEPTED at exactly the bound, so that rejection is about the size")
	_check(not _valid(_apply_skill({"kind": "counter", "scope": "any", "turns": 1, "then": pay_over})),
		"KEPT: ...and the same bound covers a counter's payload")

	# Unknown-field rejection: THE security boundary, at all three levels.
	var sneaky_block := _authored("Sneaky Block")
	sneaky_block["blocks"] = [{"op": "damage", "amount": 5, "script_path": "res://evil.gd"}]
	_check(not _valid(sneaky_block), "KEPT: an unknown field on a BLOCK is rejected — the security boundary")
	_check(not _valid(_apply_skill({"kind": "mark", "turns": 2, "text": "t", "script_path": "res://evil.gd"})),
		"KEPT: ...on an EFFECT too")
	var sneaky_cond := _authored("Sneaky Cond")
	sneaky_cond["blocks"] = [{"op": "damage", "amount": 5,
		"when": {"cond": "chance", "percent": 50, "script_path": "res://evil.gd"}}]
	_check(not _valid(sneaky_cond), "KEPT: ...and on a CONDITION")
	var sneaky_top := _authored("Sneaky Top")
	sneaky_top["blocks"] = [{"op": "group", "blocks": [{"op": "damage", "amount": 1, "nope": 1}]}]
	_check(not _valid(sneaky_top), "KEPT: ...including inside a `group`")

	# id safety: this becomes a filename under authored/ and an asset path key.
	_check(not _char_ok(_char_with({"id": "notauth_probe"})), "KEPT: an id without the auth_ prefix is rejected")
	_check(not _char_ok(_char_with({"id": "auth_../../etc"})), "KEPT: a path-traversal id is rejected")
	_check(not _char_ok(_char_with({"id": "auth_x"})), "KEPT: a too-short id is rejected")
	_check(not _char_ok(_char_with({"id": "auth_" + "x".repeat(40)})), "KEPT: an over-long id is rejected")

	# image upload envelope (socket frame budget + decoded-bitmap bound).
	_check(not AuthoredAssets.begin("palette_probe", "auth_probe_x", "portrait", AuthoredAssets.MAX_BYTES + 1, 4).is_empty(),
		"KEPT: an over-size image upload is refused (%d bytes)" % (AuthoredAssets.MAX_BYTES + 1))
	_check(not AuthoredAssets.begin("palette_probe", "auth_probe_x", "portrait", 1024, AuthoredAssets.MAX_CHUNKS + 1).is_empty(),
		"KEPT: too many upload chunks is refused")
	_check(not AuthoredAssets.begin("palette_probe", "auth_probe_x", "not_a_slot", 1024, 4).is_empty(),
		"KEPT: an unknown image slot is refused")

	# whitelists that are exact mirrors of an engine enum.
	var bad_dt := _authored("Holy Damage")
	bad_dt["blocks"] = [{"op": "damage", "amount": 5, "damage_type": "HOLY"}]
	_check(not _valid(bad_dt), "KEPT: an unknown damage_type is rejected (DAMAGE_TYPES mirrors DamageType.Type exactly)")
	var bad_break := _authored("Break Soul")
	bad_break["blocks"] = [{"op": "break", "what": "soul", "to": "target"}]
	_check(not _valid(bad_break), "KEPT: break targets are shield|barrier|both — the engine's only two teardown paths")
	var bad_sel := _authored("Bad Selector")
	bad_sel["blocks"] = [{"op": "damage", "amount": 5, "to": "everyone_everywhere"}]
	_check(not _valid(bad_sel), "KEPT: an unknown selector is rejected")
	for pct in [0, 101]:
		var ch := _authored("Chance %d" % pct)
		ch["blocks"] = [{"op": "damage", "amount": 5, "when": {"cond": "chance", "percent": pct}}]
		_check(not _valid(ch), "KEPT: chance %d%% is rejected" % pct)
	var cl := _authored("Big Cleanse")
	cl["blocks"] = [{"op": "cleanse", "to": "target", "count": 101}]
	_check(not _valid(cl), "KEPT: a cleanse count of 101 is rejected — the loop guard (0 already means unlimited)")

	# character-level rules that mirror something the engine really enforces.
	var dupes := _four()
	dupes[1]["name"] = "V1"
	_check(not _char_ok(_authored_spec("auth_palette_dupes", dupes)),
		"KEPT: two abilities with the same name are rejected — named-skill targeting resolves by name")
	var into_passive := [_authored("V1"), _authored("V2"), _authored("V3"),
		{"name": "Morph", "target": "self", "cooldown": 0, "cost": {}, "classes": ["Instant", "Helpful"],
			"requires": [], "blocks": [{"op": "apply", "to": "user",
				"effect": {"kind": "swap", "slot": 0, "into": 4, "turns": 2}}]},
		_authored("P", false, true)]
	_check(not _char_ok(_authored_spec("auth_palette_intopas", into_passive)),
		"KEPT: swapping a Passive into a board slot is rejected — it would be a dead button")

# =====================================================================================
# (C) LIVE. The removed bounds that are observable inside a running battle, asserted on
# what a PLAYER would see: the enemy's skill never resolved, the cooldown did not tick,
# the pool holds 25 more energy, the hit was absorbed.
# =====================================================================================
func _removed_bounds_live(m, me, foe, foe3):
	print("-- (C) removed bounds, live in a real battle --")
	for c in [me, foe, foe3]:
		_wipe(c)
	me.used_ability = null
	foe.used_ability = null
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	var strike = _find_ability(foe, "Enemy Strike")
	if strike == null:
		_check(false, "(setup) Enemy Strike is on the attacker")
		return

	# --- toudou1's duration-3 counter, in turns -------------------------------
	var parry3 = _mk("Long Parry", me, false)
	_runner(parry3, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "counter", "scope": "harmful", "ticks": 3,
			"then": [{"op": "damage", "amount": 15, "to": "target"}]}}])
	var c3 = me.has_effect("Long Parry", EffectType.Type.COUNTER_RECEIVE, me)
	_check(c3 != null and c3.duration == 3,
		"a counter really is at ODD engine duration 3, like toudou1 (got %d)" % (c3.duration if c3 != null else -99))
	if c3 != null:
		c3.tick_effect()
		c3.tick_effect()
	_check(me.has_effect("Long Parry", EffectType.Type.COUNTER_RECEIVE, me) != null,
		"...and it is STILL UP after two turn ticks — the old 'exactly 1 turn' rule (duration 2) had it gone by now")
	_heal_full(me)
	_heal_full(foe)
	foe.acted = false
	foe.was_countered = false
	foe.targeter.targets = [me]
	foe.targeter.main_target = me
	foe.used_ability = strike
	m.execute_ability(strike)
	_check(me.health.hp == me.health.max_hp,
		"THE THIRD-TURN COUNTER STILL INTERCEPTED — no damage reached me (hp %d)" % me.health.hp)
	_check(foe.health.hp == foe.health.max_hp - 15, "...and its payload hit the attacker for 15 (hp %d)" % foe.health.hp)
	foe.used_ability = null
	_wipe(me)
	_wipe(foe)

	# --- broly2's duration-5 counter, scoped to a CLASS the shortcuts cannot name
	me.targeter.targets = [foe]
	me.targeter.main_target = foe
	var venom = _mk_cls("Venom Fang", foe, ["Affliction", "Harmful", "Instant", "Damaging"])
	venom.blocks = [{"op": "damage", "amount": 20, "to": "target"}]
	var iron = _mk_cls("Iron Fist", foe, ["Physical", "Harmful", "Instant", "Damaging"])
	iron.blocks = [{"op": "damage", "amount": 20, "to": "target"}]
	var trap = _mk("Poison Trap", me, false)
	_runner(trap, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "counter", "scope": ["Affliction"], "ticks": 5,
			"then": [{"op": "damage", "amount": 10, "to": "target"}]}}])
	var c5 = me.has_effect("Poison Trap", EffectType.Type.COUNTER_RECEIVE, me)
	_check(c5 != null and c5.duration == 5, "broly2's duration-5 counter is live (got %d)" % (c5.duration if c5 != null else -99))
	_check(c5 != null and c5.class_targets == ["Affliction"],
		"...watching only [\"Affliction\"], like korra1 (got %s)" % str(c5.class_targets if c5 != null else []))

	me.used_ability = null
	_heal_full(me)
	foe.acted = false
	foe.was_countered = false
	foe.targeter.targets = [me]
	foe.targeter.main_target = me
	foe.used_ability = iron
	m.execute_ability(iron)
	_check(me.health.hp == me.health.max_hp - 20,
		"a PHYSICAL skill walks straight through the Affliction counter for 20 (hp %d)" % me.health.hp)
	_check(me.has_effect("Poison Trap", EffectType.Type.COUNTER_RECEIVE, me) != null, "...and the counter was not spent")
	foe.used_ability = null
	_heal_full(me)
	_heal_full(foe)
	foe.acted = false
	foe.was_countered = false
	foe.targeter.targets = [me]
	foe.targeter.main_target = me
	foe.used_ability = venom
	m.execute_ability(venom)
	_check(me.health.hp == me.health.max_hp,
		"THE AFFLICTION SKILL WAS CANCELLED — a class-scoped counter fires only on its class (hp %d)" % me.health.hp)
	_check(foe.health.hp == foe.health.max_hp - 10, "...and its payload landed for 10 (hp %d)" % foe.health.hp)
	foe.used_ability = null
	foe.targeter.targets = []
	_wipe(me)
	_wipe(foe)

	# --- rimuru2's ODD duration-3 paralyze ------------------------------------
	me.targeter.targets = [foe]
	me.targeter.main_target = foe
	var cd_skill = foe.moveset.base_abilities[1]
	var freeze = _mk("Deep Freeze", me)
	_runner(freeze, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "paralyze", "ticks": 3}}])
	var par = foe.has_effect("Deep Freeze", EffectType.Type.PARALYZE, me)
	_check(par != null and par.duration == 3,
		"paralyze at raw engine duration 3 — unreachable through `turns`, which only makes 2N (got %d)"
			% (par.duration if par != null else -99))
	if par != null:
		par.tick_effect()
	cd_skill.cooldown_remaining = 3
	cd_skill.cooldown_started_turn = -1
	foe.moveset.advance_cooldowns(foe)
	_check(int(cd_skill.cooldown_remaining) == 3,
		"...and after one tick it is STILL freezing cooldowns (remaining %d)" % int(cd_skill.cooldown_remaining))
	_wipe(foe)

	# --- effect_immunity types the old whitelist had no room for --------------
	me.targeter.targets = [foe3]
	me.targeter.main_target = foe3
	_wipe(foe3)
	var aegis = _mk("Shield Ward", me, false)
	_runner(aegis, m, me).run([{"op": "apply", "to": "target",
		"effect": {"kind": "effect_immunity", "turns": 4, "effect": "SHIELD"}}])
	_check(foe3.shrug_off_type(EffectType.Type.SHIELD),
		"effect_immunity(SHIELD) reaches the engine's own shrug_off_type read — aiohto1 / bakugo2 / jaden6 ship this")
	var gift = Effect.shield_effect(30, 4)
	gift.set_source(aegis)
	Character.add_hostile_effect(QueryContext.from_game_state(me, m), me, foe3, gift)
	_check(foe3.get_shield_effects().size() == 0, "...and a hostile SHIELD really is refused by it")
	for et in [EffectType.Type.COUNTER_RECEIVE, EffectType.Type.COUNTER_USE]:
		var nm := "Ward " + str(et)
		var w = _mk(nm, me, false)
		_runner(w, m, me).run([{"op": "apply", "to": "target",
			"effect": {"kind": "effect_immunity", "turns": 4, "effect": EffectType.Type.keys()[et]}}])
		_check(foe3.shrug_off_type(et), "effect_immunity(%s) is live — kakashi5 ships both" % EffectType.Type.keys()[et])
	_wipe(foe3)

	# --- the raised numeric envelopes, in quantities a player can see ---------
	var pool = me.team.energy.pool
	var blue_before: int = int(pool[Energy.Type.BLUE])
	_runner(_mk("Overcharge", me, false), m, me).run([{"op": "gain_energy", "amount": 25, "colour": "blue"}])
	_check(int(pool[Energy.Type.BLUE]) == blue_before + 25,
		"gain_energy banked 25 Blue in one block (old bound 5): %d -> %d" % [blue_before, int(pool[Energy.Type.BLUE])])

	var res = _mk("Deep Reserve", me, false)
	var r = _runner(res, m, me)
	# Banked by RE-APPLYING the effect — there is no stack op — 25 at a time, so the fourth
	# cast overshoots and the ceiling has to catch it.
	var bank25 := {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 6, "text": "Reserve", "stacks": 25, "max": 99, "show_stacks": true}}
	for i in range(4):
		r.run([bank25])
	var deep = me.has_effect("Deep Reserve", EffectType.Type.MARK, me)
	_check(deep != null and deep.stack_count() == 99,
		"four 25-stack casts reached the 99 ceiling (old bounds: 3 per cast, ceiling 10) — got %d"
			% (deep.stack_count() if deep != null else -1))
	if deep != null:
		deep.end_effect()

	me.targeter.targets = [foe3]
	me.targeter.main_target = foe3
	_heal_full(foe3)
	var bulwark = _mk("Bulwark", me, false)
	_runner(bulwark, m, me).run([{"op": "apply", "to": "target", "effect": {"kind": "shield", "amount": 9999, "turns": 4}}])
	_check(foe3.get_shield_effects().size() > 0, "(setup) a 9999-point shield is up")
	me.used_ability = null
	_runner(_mk("Meteor", me), m, me).run([{"op": "damage", "amount": 700, "to": "target"}])
	_check(foe3.health.hp == foe3.health.max_hp,
		"a 700-damage block was absorbed by the 9999 shield — BOTH numbers are past the old 500 clamp (hp %d)" % foe3.health.hp)
	_check(foe3.get_shield_effects().size() > 0, "...and the shield survived it")
	_wipe(foe3)
	me.used_ability = null
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	# A swap at an EVEN engine duration. swap_turns_to_duration is ALWAYS 2N+1, so an even
	# number is reachable only through `ticks`. Added because the reversal that strips
	# `ticks` back out left the duration-3 swap assertion passing — 3 is what turns:1
	# produces anyway, so that assertion alone could not tell the two apart.
	var alt = _mk("Alternate Stance", me, false)
	var alt_idx: int = me.moveset.base_abilities.find(alt)
	var slot0_was: String = str(me.moveset.get_active_abilities(me)[0].ability_name)
	var shift = _mk("Shift", me, false)
	_runner(shift, m, me).run([{"op": "apply", "to": "user",
		"effect": {"kind": "swap", "slot": 0, "into": alt_idx, "ticks": 4}}])
	var sw4 = me.has_effect("Shift", EffectType.Type.ABILITY_SWAP, me)
	_check(sw4 != null and sw4.duration == 4,
		"a swap at EVEN engine duration 4 — swap_turns_to_duration only ever makes 2N+1, so `ticks` is the only route (got %d)"
			% (sw4.duration if sw4 != null else -99))
	_check(str(me.moveset.get_active_abilities(me)[0].ability_name) == "Alternate Stance",
		"...and it really moved the slot (was %s)" % slot0_was)
	if sw4 != null:
		sw4.end_effect()

# =====================================================================================
# (D) LIVE, AS AN AUTHORED CHARACTER IN A REAL BATTLE. One character carrying the exact
# shapes the audit found unauthorable: xanxus2's 6-energy cost, gatomon's two passives
# (one of them costed, like cooler6), the Invisible and Unstunnable classes, the
# `everyone` target mode, the engine's ability flags, and cooler1/cooler5's
# self-refreshing swap chain — asserted on the WIRE BOARD the client draws.
# =====================================================================================
func _removed_bounds_live_character():
	print("-- (D) the shipped shapes, live on an authored character --")
	var swap_block := {"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 0, "into": 6, "ticks": 3}}
	var defs := [
		# visible 0 — xanxus2's cost, and cooler1's swap.
		{"name": "Death Chaser", "target": "enemy", "cooldown": 0, "cost": {"0": 1, "4": 5},
			"classes": ["Physical", "Instant", "Harmful", "Damaging"], "requires": [],
			"blocks": [{"op": "damage", "amount": 10, "to": "target"}, swap_block]},
		# visible 1 — the Unstunnable class, which the old whitelist rejected outright.
		{"name": "Unblockable Blow", "target": "enemy", "cooldown": 0, "cost": {},
			"classes": ["Physical", "Instant", "Harmful", "Damaging", "Unstunnable"], "requires": [],
			"blocks": [{"op": "damage", "amount": 10, "to": "target"}]},
		# visible 2 — the Invisible class.
		{"name": "Ghost Step", "target": "self", "cooldown": 0, "cost": {},
			"classes": ["Strategic", "Instant", "Helpful", "Invisible"], "requires": [],
			"blocks": [{"op": "heal", "amount": 5, "to": "user"}]},
		# visible 3 — TargetType.ALL, and a cooldown past the old 0-10.
		{"name": "Board Wipe", "target": "everyone", "cooldown": 12, "cost": {},
			"classes": ["Energy", "Instant", "Harmful", "Damaging"], "requires": [],
			"blocks": [{"op": "damage", "amount": 5, "to": "all_enemies"}]},
		# TWO passives (gatomon9 + gatomon14), the first COSTED and gated (cooler6).
		{"name": "Saint Air", "target": "self", "cooldown": 0, "cost": {"0": 1},
			"classes": ["Passive"], "requires": [{"cond": "hp_above", "value": 0, "on": "user"}],
			"blocks": [{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": -1, "text": "Saint Air"}}]},
		{"name": "Eden's Air", "target": "self", "cooldown": 0, "cost": {},
			"classes": ["Passive"], "requires": [],
			"blocks": [{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": -1, "text": "Eden's Air"}}]},
		# hidden 6 — cooler5: the skill the swap brings in, re-applying its OWN swap.
		{"name": "Sadistic Tread", "target": "enemy", "cooldown": 0, "cost": {}, "hidden": true,
			"classes": ["Physical", "Instant", "Harmful", "Damaging"], "requires": [],
			"blocks": [{"op": "damage", "amount": 10, "to": "target"}, swap_block]},
		# hidden 7 — the engine flags, on a skill that never reaches the wire. `and_targeter`
		# was here until Phase A5 retired it (BlockValidator.RETIRED_ABILITY_FLAGS); it is
		# rejected on save now, and creator_hardening_a3a5_probe asserts that.
		{"name": "Flagged Reserve", "target": "enemy", "cooldown": 0, "cost": {}, "hidden": true,
			"classes": ["Physical", "Instant", "Harmful", "Damaging"], "requires": [],
			"selfless": true, "accurate": true, "invisible": true,
			"blocks": [{"op": "damage", "amount": 10, "to": "target"}]}]
	var spec := {"id": "auth_palette_bounds", "name": "The Thompson Sisters (Liz and Patty)",
		"author": "palette_probe", "status": "testing", "description": "d".repeat(900),
		"colors": [3, 4], "abilities": defs}

	var errs := AuthoredRegistry.validate_character(spec)
	_check(errs.is_empty(), "the whole 'every removed bound at once' character validates (%s)" % str(errs))
	_check(_names_of_specs(BlockValidator.moveset_order(defs)) ==
			["Death Chaser", "Unblockable Blow", "Ghost Step", "Board Wipe",
			"Saint Air", "Eden's Air", "Sadistic Tread", "Flagged Reserve"],
		"(setup) index 6 is 'Sadistic Tread', past BOTH passives")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://authored"))
	var f := FileAccess.open("res://authored/auth_palette_bounds.json", FileAccess.WRITE)
	if f == null:
		_check(false, "(setup) could not write the probe fixture")
		return
	f.store_string(JSON.stringify(spec, "\t"))
	f.close()
	AuthoredRegistry.load_all(true)
	_check(AuthoredRegistry.get_spec("auth_palette_bounds") != null,
		"(setup) the fixture passed load-time revalidation")

	var m3 := BattleManager.new()
	m3.name = "BoundsBattleManager"
	m3.shadow_mode = true
	add_child(m3)
	var p1 = _build_player("BoundsPlayer", ["auth_palette_bounds", "naruto", "gon"], false)
	var p2 = _build_player("BoundsEnemy", ["eren", "misaka", "sakura"], true)
	m3.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	for c in p2.team.characters:
		c.bot_character = false
	var hero = p1.team.characters[0]
	var villain = p2.team.characters[0]
	var built: bool = hero is AuthoredCharacter and hero.moveset.base_abilities.size() == 8
	_check(built, "(setup) the 8-skill authored character joined a real battle (%d skills)"
		% (hero.moveset.base_abilities.size() if hero != null else -1))
	if not built:
		# Bail rather than crash. A reversal that restores a validator bound stops the
		# fixture loading at all, and an index error here would hide the rest of the run.
		_check(false, "(aborted) the rest of section (D) could not run — see the validation failure above")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://authored/auth_palette_bounds.json"))
		AuthoredRegistry.load_all(true)
		return

	# --- xanxus2's 6-energy cost, read off the live Ability -------------------
	var chaser = hero.moveset.base_abilities[0]
	var cost = chaser.cost()
	var total := 0
	for k in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED, Energy.Type.RANDOM]:
		total += int(cost[k])
	_check(total == 6 and int(cost[Energy.Type.RANDOM]) == 5 and int(cost[Energy.Type.GREEN]) == 1,
		"xanxus2's cost survived to a live Ability.cost(): total %d, 5 Random + 1 Green" % total)

	# --- gatomon's TWO passives both ran at battle start ----------------------
	_check(hero.has_effect("Saint Air", EffectType.Type.MARK, hero) != null,
		"the FIRST passive ran at battle start — and it carries cooler6's energy cost and an inert `requires`")
	_check(hero.has_effect("Eden's Air", EffectType.Type.MARK, hero) != null,
		"THE SECOND PASSIVE RAN TOO — the old 'at most one Passive' rule made gatomon unauthorable")

	# --- the Unstunnable class is a real mechanism, not a label ---------------
	var unblockable = hero.moveset.base_abilities[1]
	_check(unblockable.stunnable == false and chaser.stunnable == true,
		"the Unstunnable CLASS wrote through to the `stunnable` FLAG character_component.is_stunned() reads")
	var stunner = _mk_cls("Hammer Blow", villain, ["Physical", "Instant", "Harmful", "Damaging"])
	villain.targeter.targets = [hero]
	villain.targeter.main_target = hero
	_runner(stunner, m3, villain).run([{"op": "apply", "to": "target", "effect": {"kind": "stun", "turns": 2}}])
	_check(hero.is_stunned(chaser), "(setup) the stun landed — an ordinary skill IS stunned")
	_check(not hero.is_stunned(unblockable),
		"THE UNSTUNNABLE SKILL IS STILL USABLE THROUGH THE STUN — astolfo4 / yugi2 / orihime4 / cooler4 ship this")
	for e in hero.effects.get_effects_by_type(EffectType.Type.STUN):
		e.end_effect()

	# --- the Invisible class, and the raw engine flags ------------------------
	_check(hero.moveset.base_abilities[2].invisible == true and chaser.invisible == false,
		"the Invisible CLASS wrote through to the `invisible` FLAG match_event_recorder reads")
	var flagged = hero.moveset.base_abilities[7]
	_check(flagged.selfless and flagged.accurate and flagged.invisible,
		"the ability FLAGS are authorable directly (selfless/accurate/invisible)")
	_check(chaser.selfless == false and chaser.accurate == false,
		"...and they default off rather than leaking onto every skill")

	# --- `everyone` -> TargetType.ALL ----------------------------------------
	var wipe = hero.moveset.base_abilities[3]
	_check(int(wipe.target_type()) == int(TargetType.Type.ALL),
		"target mode 'everyone' resolved to TargetType.ALL (%d), the mode 147 shipped abilities use" % int(wipe.target_type()))
	_check(int(wipe.cooldown) == 12, "...on a skill with cooldown 12, past the old 0-10 bound")
	for c in m3.all_characters():
		c.targeted = false
	wipe.target(hero, m3)
	var hit_enemy := false
	var hit_ally := false
	for c in m3.all_characters():
		if c.targeted:
			if hero.is_hostile(c):
				hit_enemy = true
			else:
				hit_ally = true
	_check(hit_enemy and hit_ally,
		"...and it really flags BOTH sides of the board (enemy %s, ally %s)" % [str(hit_enemy), str(hit_ally)])
	for c in m3.all_characters():
		c.targeted = false

	# --- cooler1 / cooler5: the SELF-REFRESHING SWAP CHAIN --------------------
	var before := _wire_board(m3, "auth_palette_bounds")
	_check(before == ["Death Chaser", "Unblockable Blow", "Ghost Step", "Board Wipe"],
		"(baseline) the client's board shows the four visible skills (%s)" % str(before))
	hero.used_ability = chaser
	hero.targeter.targets = [villain]
	hero.targeter.main_target = villain
	chaser.execute(hero, m3)
	_check(_wire_board(m3, "auth_palette_bounds")[0] == "Sadistic Tread",
		"cooler1: slot 0 now shows 'Sadistic Tread' (%s)" % str(_wire_board(m3, "auth_palette_bounds")))
	var first = hero.has_effect("Death Chaser", EffectType.Type.ABILITY_SWAP, hero)
	_check(first != null and first.duration == 3,
		"...held by a swap at cooler's own raw duration 3 (got %d)" % (first.duration if first != null else -99))

	# The swapped-in skill applies the IDENTICAL swap — a CHAIN, and a SELF-chain.
	var tread = hero.moveset.base_abilities[6]
	hero.used_ability = tread
	hero.targeter.targets = [villain]
	hero.targeter.main_target = villain
	tread.execute(hero, m3)
	var second = hero.has_effect("Sadistic Tread", EffectType.Type.ABILITY_SWAP, hero)
	_check(second != null,
		"cooler5: THE SWAPPED-IN SKILL APPLIED ITS OWN SWAP — a chain the old validator refused at any depth")
	_check(_wire_board(m3, "auth_palette_bounds")[0] == "Sadistic Tread",
		"...and the board still shows the form (%s)" % str(_wire_board(m3, "auth_palette_bounds")))
	# The point of the chain: the form outlives the swap that started it.
	if first != null:
		first.end_effect()
	_check(hero.has_effect("Death Chaser", EffectType.Type.ABILITY_SWAP, hero) == null,
		"(setup) the ORIGINAL swap is gone")
	var chained := _wire_board(m3, "auth_palette_bounds")
	_check(chained[0] == "Sadistic Tread",
		"THE FORM SURVIVED ITS OWN SOURCE — extend-your-own-form works end to end (%s)" % str(chained))
	if second != null:
		second.end_effect()
	var restored := _wire_board(m3, "auth_palette_bounds")
	_check(restored[0] == "Death Chaser", "...and ending the chain hands slot 0 back (%s)" % str(restored))
	_check(restored.slice(1) == ["Unblockable Blow", "Ghost Step", "Board Wipe"],
		"...with the other three slots untouched throughout (%s)" % str(restored))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://authored/auth_palette_bounds.json"))
	AuthoredRegistry.load_all(true)
