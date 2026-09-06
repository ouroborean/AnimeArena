extends Node

# ============================================================================
# ADVERSARIAL REVIEW of Creator Phase B. Written from the schema, not from the
# shipped probes. Every case here is one I suspected was NOT covered.
#
#   godot --headless --path <repo> res://training/tests/advreview_phaseb_probe.tscn
# ============================================================================

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
	var p1 := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _mk(spec: Dictionary, owner, harmful := true) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Authored Probe"))
	a.classes = {"Physical": harmful, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": not harmful, "Harmful": harmful, "Helpful": not harmful, "Instant": true,
		"Action": false, "Control": false, "Channeled": false, "Uncounterable": false,
		"Bypassing": false, "Stealthed": false, "Passive": false, "Preserves Channel": false,
		"Damaging": harmful}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _fire(caster, blocks: Array, targets: Array, m, nm := "Probe Skill", harmful := true) -> ScriptedAbility:
	var ab := _mk({"name": nm, "target": "enemy", "blocks": blocks}, caster, harmful)
	_cast(caster, ab, targets, m)
	return ab

func _use(m, caster, ab, targets: Array) -> void:
	ab.user = caster
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	m.execute_ability(ab)
	caster.used_ability = null
	caster.acted = false

func _spec(blocks: Array, extra := {}) -> Dictionary:
	var s := {"name": "Probe", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Harmful"], "blocks": blocks, "requires": []}
	for k in extra:
		s[k] = extra[k]
	return s

func _ready():
	print("=== ADVERSARIAL REVIEW: Creator Phase B ===")

	# ==================================================================================
	# A. THE UNIVERSAL `mag` FIELD vs `reflect`.destination
	#
	# _validate_reflect rejected a universal `stacks` on a reflect, with the reasoning
	# "charges and stacks are the same register to the engine". `destination` and the
	# universal `mag` are the SAME REGISTER by exactly the same argument:
	# Effect.reflect_effect writes `effect.mag = reflect_target` (effect_component.gd:312)
	# and Ability.reflect_trigger reads `context['effect'].mag` (:378, :386).
	# _apply_universal_fields wrote `mag` after the factory for every kind that did not
	# declare it in its own `fields` — and `reflect`'s fields are
	# ["scope","destination","charges","turns"].
	#
	# FIXED as a GENERAL rule, not a third special case: BlockSchema.EFFECT_KINDS now carries a
	# `reserves` column per kind (which universal registers that kind's factory already owns, and
	# which authored field owns each), BlockValidator._validate_reserved_fields refuses them for
	# every kind, and BlockRunner._apply_universal_fields skips them for a hand-edited file that
	# never met the validator. The `stacks` case below is now that same rule, not its own code.
	# Section K enumerates the whole table against the factories.
	# ==================================================================================
	print("\n-- A: universal `mag` on a reflect --")
	var refl_mag := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "reflect", "destination": "applier", "turns": 3, "mag": 0}}])
	var e_mag := BlockValidator.validate_ability(refl_mag)
	_check(not e_mag.is_empty(), "a reflect carrying a universal `mag` is REJECTED (errs=%s)" % str(e_mag))
	# The message has to point at the control that DOES own the register, or the author is left
	# knowing only that something is wrong.
	_check(str(e_mag).find("destination") != -1,
		"the rejection names 'destination', the authored field that owns the register")
	# The SIGN is not a special case: -1 is the bounce sentinel and was the silent-corruption
	# shape (a guardian quietly became a bounce), so it must be refused exactly as 0 is.
	_check(not BlockValidator.validate_ability(_spec([{"op": "apply", "to": "user", "effect": {
			"kind": "reflect", "destination": "applier", "turns": 3, "mag": -1}}])).is_empty(),
		"`mag: -1` on a reflect is rejected too — the sentinel value is not an exemption")

	var refl_stacks := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "reflect", "destination": "applier", "turns": 3, "stacks": 5}}])
	_check(not BlockValidator.validate_ability(refl_stacks).is_empty(),
		"POSITIVE CONTROL: the twin register `stacks` is still rejected — now by the SAME general rule")
	# NEGATIVE CONTROL, so none of the above is passing because reflects stopped validating.
	_check(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "user", "effect": {
			"kind": "reflect", "destination": "applier", "turns": 3}}])).is_empty(),
		"NEGATIVE CONTROL: the same reflect without either register still validates clean")

	# Now show it actually overwrites the destination on a live board.
	var gA := _fresh()
	var mA = gA["m"]
	var casterA = gA["allies"][0]
	var wardedA = gA["allies"][1]
	_fire(casterA, [{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "destination": "applier", "turns": 5,
		"name_override": "Probe Guard"}}], [wardedA], mA, "Probe Guard", false)
	var guard_eff = wardedA.has_effect("Probe Guard", EffectType.Type.REFLECT_RECEIVE)
	_check(guard_eff != null and guard_eff.mag is Character,
		"CONTROL: without `mag`, destination 'applier' stores the caster Character in eff.mag")

	var gA2 := _fresh()
	var mA2 = gA2["m"]
	var casterA2 = gA2["allies"][0]
	var wardedA2 = gA2["allies"][1]
	_fire(casterA2, [{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "destination": "applier", "turns": 5,
		"name_override": "Probe Guard", "mag": 0}}], [wardedA2], mA2, "Probe Guard 2", false)
	# NOTE: _fire builds the ScriptedAbility DIRECTLY and never calls the validator, so this is the
	# HAND-EDITED-FILE half — a spec the validator would now refuse, run anyway. That is exactly the
	# case BlockRunner's own skip exists for, and it is the one the review could not have reached
	# through the editor.
	var guard_eff2 = wardedA2.has_effect("Probe Guard", EffectType.Type.REFLECT_RECEIVE)
	_check(guard_eff2 != null, "the mag-carrying reflect (never validated) still landed")
	if guard_eff2 != null:
		_check(guard_eff2.mag is Character,
			"RUNTIME GUARD: the universal pass REFUSED to overwrite the destination register (mag is %s)" % str(guard_eff2.mag))

	# ...and what reflect_trigger USED TO DO with an int-that-is-not--1 on a SINGLE-target skill:
	# append that raw int into the attacker's targeter, then call
	# check_ability_receive_triggers on it. Nothing but a Character may reach that list.
	var attackerA = gA2["foes"][0]
	var swingA := _mk({"name": "Probe Swing A", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, attackerA)
	_use(mA2, attackerA, swingA, [wardedA2])
	var bad_targets := 0
	for t in attackerA.targeter.targets:
		if not (t is Character):
			bad_targets += 1
	_check(bad_targets == 0,
		"the attacker's targeter holds %d non-Character entr(y/ies) — no raw int reached reflect_trigger" % bad_targets)

	# ==================================================================================
	# B. `-1` as a universal mag SILENTLY converted a GUARDIAN reflect into a BOUNCE — the
	#    worst shape of the collision, because it raised no error at all. The validator now
	#    refuses the spec (section A); this is the runtime half, on a hand-edited file.
	# ==================================================================================
	print("\n-- B: `mag: -1` no longer flips a guardian into a bounce --")
	var gB := _fresh()
	var mB = gB["m"]
	var casterB = gB["allies"][0]
	var wardedB = gB["allies"][1]
	var attackerB = gB["foes"][0]
	_fire(casterB, [{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "destination": "applier", "turns": 5,
		"name_override": "Probe Flip", "mag": -1}}], [wardedB], mB, "Probe Flip", false)
	var caster_hp_b: int = casterB.health.hp
	var atk_hp_b: int = attackerB.health.hp
	var swingB := _mk({"name": "Probe Swing B", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, attackerB)
	_use(mB, attackerB, swingB, [wardedB])
	_check(casterB.health.hp < caster_hp_b and attackerB.health.hp == atk_hp_b,
		"the authored 'applier' guardian ATE the skill as written — it did not become a bounce (attacker %d->%d, caster %d->%d)"
			% [atk_hp_b, attackerB.health.hp, caster_hp_b, casterB.health.hp])

	# ==================================================================================
	# C. GENERATED PROSE — the scoped trigger stutter.
	#    _scope_phrase("harmful") -> "Harmful " and the on_harmful_received sentence already
	#    contains the word "harmful".
	# ==================================================================================
	print("\n-- C: scoped-trigger prose --")
	var gC := _fresh()
	var proseC = gC["allies"][0]
	var abC := _mk({"name": "Prose Probe", "target": "enemy", "blocks": [
		{"op": "apply", "to": "user", "effect": {
			"kind": "trigger", "trigger": "on_harmful_received", "scope": "harmful", "turns": 3,
			"then": [{"op": "damage", "amount": 5, "to": "holder"}]}}]}, proseC)
	var lines: Array = []
	for seg in abC.split_desc():
		lines.append(seg[0] if seg is Array else str(seg))
	var joined := " | ".join(lines)
	print("     PROSE: %s" % joined)
	# CASE-INSENSITIVE, deliberately. The review's own spelling of this bug was the capitalised
	# "Harmful harmful", because the two renderers disagreed on casing as well as on the join word.
	# Now that there is one renderer the stutter would come back LOWERCASE, and a literal search for
	# the capitalised form would sail straight past it — a guard that only catches the exact
	# yesterday of a bug. Verified: reverting the suppression alone makes this line fail.
	_check(joined.to_lower().find("harmful harmful") == -1,
		"scoped on_harmful_received does not stutter (any casing of 'harmful harmful skill')")
	# ...and it says the RIGHT thing rather than merely not stuttering: on this hook a scope naming
	# Harmful filters nothing (the hook only fires for Harmful skills and the class list is an OR),
	# so the unscoped sentence is the accurate one.
	_check(joined.find("when a harmful skill is used on them") != -1,
		"...it reads as the plain hook sentence, which is what that scope actually means")

	# NO OVER-SUPPRESSION. A scope naming a class the hook does NOT already guarantee still prints,
	# or the suppression would have swallowed a real filter.
	var abC1b := _mk({"name": "Prose Probe 1b", "target": "enemy", "blocks": [
		{"op": "apply", "to": "user", "effect": {
			"kind": "trigger", "trigger": "on_harmful_received", "scope": ["Physical"], "turns": 3,
			"then": [{"op": "damage", "amount": 5, "to": "holder"}]}}]}, proseC)
	var lines1b: Array = []
	for seg in abC1b.split_desc():
		lines1b.append(seg[0] if seg is Array else str(seg))
	var joined1b := " | ".join(lines1b)
	print("     PROSE: %s" % joined1b)
	_check(joined1b.find("Physical harmful skill") != -1,
		"a scope naming a class the hook does NOT imply still prints ('Physical harmful skill')")

	# ONE RENDERER, ONE WORDING. The same authored scope has to read the same way through the
	# TRIGGER's adjective phrase and through the COUNTER/REFLECT's noun. It did not: _scope_noun
	# joined a raw class list with " and " (which is the opposite of what _scope_matches does — it
	# returns true on the FIRST match) while _scope_phrase joined with " or ".
	var multi := ["Physical", "Energy"]
	var abC1c := _mk({"name": "Prose Probe 1c", "target": "enemy", "blocks": [
		{"op": "apply", "to": "user", "effect": {
			"kind": "trigger", "trigger": "on_skill_used", "scope": multi, "turns": 3,
			"then": [{"op": "damage", "amount": 5, "to": "holder"}]}},
		{"op": "apply", "to": "user", "effect": {
			"kind": "counter", "scope": multi, "turns": 3,
			"then": [{"op": "damage", "amount": 5, "to": "target"}]}},
		{"op": "apply", "to": "user", "effect": {
			"kind": "reflect", "scope": multi, "turns": 3}}]}, proseC)
	var lines1c: Array = []
	for seg in abC1c.split_desc():
		lines1c.append(seg[0] if seg is Array else str(seg))
	var joined1c := " | ".join(lines1c)
	print("     PROSE: %s" % joined1c)
	var or_count := joined1c.count("Physical or Energy")
	_check(or_count == 3 and joined1c.find("Physical and Energy") == -1,
		"trigger, counter and reflect all word one scope identically ('Physical or Energy' x%d, no 'and' form)" % or_count)
	# The in-battle TOOLTIP is a fourth reader of the same value (BlockRunner._scope_text), and it
	# used to print the literal word "any" for a scope that filters nothing.
	var gC2 := _fresh()
	var tipC = gC2["allies"][0]
	_fire(tipC, [{"op": "apply", "to": "user", "effect": {
		"kind": "counter", "scope": "any", "turns": 3, "name_override": "Tip Counter",
		"then": [{"op": "damage", "amount": 1, "to": "target"}]}}], [tipC], gC2["m"], "Tip Counter", false)
	var tip_eff = tipC.has_effect("Tip Counter", EffectType.Type.COUNTER_RECEIVE)
	var tip_txt := str(tip_eff.description.call(tip_eff)) if tip_eff != null else "<none>"
	print("     TOOLTIP: %s" % tip_txt)
	_check(tip_txt.find("The next skill used on this character") != -1,
		"the counter tooltip drops the empty 'any' adjective instead of printing it")

	var abC2 := _mk({"name": "Prose Probe 2", "target": "enemy", "blocks": [
		{"op": "apply", "to": "user", "effect": {
			"kind": "trigger", "trigger": "on_skill_used", "scope": "damaging", "turns": 3,
			"then": [{"op": "heal", "amount": 5, "to": "holder"}]}}]}, proseC)
	var lines2: Array = []
	for seg in abC2.split_desc():
		lines2.append(seg[0] if seg is Array else str(seg))
	print("     PROSE: %s" % " | ".join(lines2))

	# reflect prose with destination applier — does it name the right character?
	var abC3 := _mk({"name": "Prose Probe 3", "target": "ally", "blocks": [
		{"op": "apply", "to": "target", "effect": {
			"kind": "reflect", "destination": "applier", "charges": 1, "turns": 2}}]}, proseC, false)
	var lines3: Array = []
	for seg in abC3.split_desc():
		lines3.append(seg[0] if seg is Array else str(seg))
	print("     PROSE: %s" % " | ".join(lines3))

	# adjust / repeat / banish prose
	var abC4 := _mk({"name": "Prose Probe 4", "target": "enemy", "blocks": [
		{"op": "repeat", "times": 3, "blocks": [{"op": "damage", "amount": 10, "to": "target"}]},
		{"op": "adjust", "name": "Ward", "to": "user", "turns": 1, "stacks": 2, "mag": -5},
		{"op": "banish", "to": "random_enemy", "turns": 2}]}, proseC)
	var lines4: Array = []
	for seg in abC4.split_desc():
		lines4.append(seg[0] if seg is Array else str(seg))
	print("     PROSE: %s" % " | ".join(lines4))

	# ==================================================================================
	# D. CROSS-EFFECT trigger recursion. The re-entrancy latch is PER EFFECT INSTANCE.
	#    Two authored on_hp_changed triggers, one on each of two characters, each payload
	#    damaging the OTHER one, is a ping-pong neither latch sees as re-entry.
	# ==================================================================================
	print("\n-- D: cross-effect trigger ping-pong (latch is per instance) --")
	var gD := _fresh()
	var mD = gD["m"]
	var casterD = gD["allies"][0]
	var aD = gD["foes"][0]
	var bD = gD["foes"][1]
	# Trigger on A: when A's health changes, damage all enemies (of the applier) = the foe team,
	# which includes B. Trigger on B: same. Each is a distinct Effect instance with its own latch.
	_fire(casterD, [{"op": "apply", "to": "target", "effect": {
		"kind": "trigger", "trigger": "on_hp_changed", "turns": 9, "name_override": "PingA",
		"then": [{"op": "damage", "amount": 1, "to": "all_enemies"}]}}], [aD], mD, "PingA", true)
	_fire(casterD, [{"op": "apply", "to": "target", "effect": {
		"kind": "trigger", "trigger": "on_hp_changed", "turns": 9, "name_override": "PingB",
		"then": [{"op": "damage", "amount": 1, "to": "all_enemies"}]}}], [bD], mD, "PingB", true)
	var a_before: int = aD.health.hp
	var b_before: int = bD.health.hp
	_fire(casterD, [{"op": "damage", "amount": 1, "to": "target"}], [aD], mD, "PokeD", true)
	print("     A %d -> %d,  B %d -> %d (1 authored damage)" % [a_before, aD.health.hp, b_before, bD.health.hp])
	_check(a_before - aD.health.hp <= 12 and b_before - bD.health.hp <= 12,
		"a 1-damage poke did not cascade unboundedly through two paired triggers")

	# ==================================================================================
	# E. `_op_adjust` reaching an effect whose `mag` is not an int (a guardian reflect).
	# ==================================================================================
	print("\n-- E: adjust `mag` on an effect whose mag is a Character --")
	var gE := _fresh()
	var mE = gE["m"]
	var casterE = gE["allies"][0]
	var wardedE = gE["allies"][1]
	_fire(casterE, [{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "destination": "applier", "turns": 5, "name_override": "Probe Guard E"}}],
		[wardedE], mE, "Probe Guard E", false)
	# STILL VALIDATES CLEAN, and deliberately so: `adjust` addresses an effect BY NAME, so the
	# validator cannot know what kind of effect will be standing there at cast time (a different
	# character's skill may have put it there). The guard therefore has to be at runtime, on the
	# TYPE of what it found — which is where the error was.
	var adj_spec := _spec([{"op": "adjust", "name": "Probe Guard E", "to": "target", "mag": 1}])
	_check(BlockValidator.validate_ability(adj_spec).is_empty(),
		"an `adjust ... mag` aimed at a reflect still validates clean (the name is all it can see)")
	# TWO axes in one block, so a skipped `mag` must not take `turns` down with it.
	var gE_eff_pre = wardedE.has_effect("Probe Guard E", EffectType.Type.REFLECT_RECEIVE)
	var dur_pre: int = int(gE_eff_pre.duration) if gE_eff_pre != null else 0
	print("     (executing it — there must be NO cast error above/below)")
	_fire(casterE, [{"op": "adjust", "name": "Probe Guard E", "to": "target", "mag": 1, "turns": 1}],
		[wardedE], mE, "Probe Adjust E", false)
	var gE_eff = wardedE.has_effect("Probe Guard E", EffectType.Type.REFLECT_RECEIVE)
	print("     eff.mag is now: %s" % str(gE_eff.mag if gE_eff != null else "<gone>"))
	_check(gE_eff != null and gE_eff.mag is Character,
		"the reflect's destination register SURVIVED the adjust (no 'Nonexistent int constructor')")
	_check(gE_eff != null and int(gE_eff.duration) == dur_pre + BlockSchema.turns_to_delta(1),
		"the SAME block's `turns` axis still applied (%d -> %d) — the axis is skipped, not the block"
			% [dur_pre, int(gE_eff.duration) if gE_eff != null else -999])
	# CONTROL: an `adjust ... mag` on an effect whose mag IS a magnitude still does its job, so
	# the type guard cannot be passing by disabling the axis everywhere.
	_fire(casterE, [{"op": "apply", "to": "user", "effect": {
		"kind": "shield", "amount": 20, "turns": 5, "name_override": "Probe Shield E"}}],
		[casterE], mE, "Probe Shield E", false)
	_fire(casterE, [{"op": "adjust", "name": "Probe Shield E", "to": "user", "mag": 5}],
		[casterE], mE, "Probe Adjust Shield", false)
	var shE = casterE.has_effect("Probe Shield E", EffectType.Type.SHIELD)
	_check(shE != null and int(shE.mag) == 25,
		"CONTROL: `adjust mag` on a numeric register still works (shield 20 -> %s)" % str(shE.mag if shE != null else "<gone>"))

	# ==================================================================================
	# F. Does the `repeat` runtime budget bound a repeat INSIDE a trigger payload?
	#    Each payload builds a NEW BlockRunner with a fresh 40-block budget.
	# ==================================================================================
	print("\n-- F: budget scope --")
	# 12 reps x a 4-block body = 48 executed blocks, above the 40 ceiling. If _count_blocks
	# multiplied only at the top level this would count as 6 and sail through.
	var fat_body := [{"op": "damage", "amount": 1, "to": "all_enemies"},
		{"op": "damage", "amount": 1, "to": "all_enemies"},
		{"op": "damage", "amount": 1, "to": "all_enemies"},
		{"op": "damage", "amount": 1, "to": "all_enemies"}]
	var payload_repeat := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "trigger", "trigger": "on_turn_start", "turns": 5,
		"then": [{"op": "repeat", "times": 12, "blocks": fat_body}]}}])
	var e_f := BlockValidator.validate_ability(payload_repeat)
	_check(not e_f.is_empty(),
		"_count_blocks multiplies a repeat that lives INSIDE a `then` payload (errs=%s)" % str(e_f))
	var payload_small := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "trigger", "trigger": "on_turn_start", "turns": 5,
		"then": [{"op": "repeat", "times": 12,
			"blocks": [{"op": "damage", "amount": 1, "to": "all_enemies"}]}]}}])
	_check(BlockValidator.validate_ability(payload_small).is_empty(),
		"POSITIVE CONTROL: 12 x 1 block inside a payload (14 total) is still legal")

	# ==================================================================================
	# G. banish pool ban — is it enforced when the banish hides under `repeat`?
	# ==================================================================================
	print("\n-- G: banish placement --")
	var b_in_repeat := _spec([{"op": "repeat", "times": 2,
		"blocks": [{"op": "banish", "to": "all_enemies", "turns": 1}]}])
	_check(not BlockValidator.validate_ability(b_in_repeat).is_empty(),
		"banish with a pool selector inside a `repeat` is rejected")
	var b_in_group_in_then := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "trigger", "trigger": "on_turn_start", "turns": 3,
		"then": [{"op": "group", "blocks": [{"op": "banish", "to": "all_enemies", "turns": 1}]}]}}])
	_check(not BlockValidator.validate_ability(b_in_group_in_then).is_empty(),
		"banish with a pool selector inside a group inside a payload is rejected")
	var b_ok := _spec([{"op": "banish", "to": "random_enemy", "turns": 1}])
	_check(BlockValidator.validate_ability(b_ok).is_empty(),
		"POSITIVE CONTROL: a single-aimed banish still validates")

	# A `repeat` of a banish aimed at a single target — 2 banishes of the same character.
	var b_rep_ok := _spec([{"op": "repeat", "times": 2,
		"blocks": [{"op": "banish", "to": "random_enemy", "turns": 1}]}])
	print("     repeat-of-single-banish errs: %s" % str(BlockValidator.validate_ability(b_rep_ok)))

	# ==================================================================================
	# H. `channel` + `banish`. The accumulator only ever collected _op_apply's effects, so a
	#    channelled skill whose ONLY block is a banish handed _close_channel an empty list, it
	#    returned early, and NO HOLDER WAS PLANTED — while the card said "Channeled — everything
	#    this skill applies ends if the user is stunned". COLLECTED rather than rejected:
	#    Character.banish_character now returns the effect it landed and _op_banish appends it.
	# ==================================================================================
	print("\n-- H: channelled banish --")
	var gH := _fresh()
	var mH = gH["m"]
	var casterH = gH["allies"][0]
	var foeH = gH["foes"][0]
	var abH := _mk({"name": "Chan Banish", "target": "enemy", "channel": "control",
		"blocks": [{"op": "banish", "to": "target", "turns": 3}]}, casterH)
	_cast(casterH, abH, [foeH], mH)
	_check(foeH.banished, "the channelled banish landed")
	var holderH = casterH.has_effect("Chan Banish", EffectType.Type.CONTROL_CANCEL)
	_check(holderH != null,
		"a channel holder WAS planted over the banish — the card's promise has machinery behind it")
	_check(holderH != null and holderH.cancel_effects.size() == 1,
		"...and it is holding the BANISH effect itself (%d entr(y/ies))" % (holderH.cancel_effects.size() if holderH != null else -1))
	# Break it the way a stun does — check_cancels is the single entry point for stun/death/banish/seal.
	casterH.check_cancels(true)
	_check(foeH.effects.get_effects_by_type(EffectType.Type.BANISH).is_empty(),
		"breaking the channel ENDED the banish effect")
	# The `banished` BOOL clears on the next tick_durations pass, when no BANISH effect is left —
	# the same route an ordinary banish EXPIRY takes, which is why ending the effect is coherent
	# rather than novel. Asserted so a future change to that pass cannot silently strand the flag.
	mH.tick_durations()
	_check(not foeH.banished, "...and the next duration tick returned them to the board")

	# NEGATIVE CONTROL: a channelled skill that applies NOTHING must still plant no holder — a pip
	# promising a channel with no channel behind it is the defect in reverse.
	var gH2 := _fresh()
	var casterH2 = gH2["allies"][0]
	var abH2 := _mk({"name": "Chan Nothing", "target": "enemy", "channel": "control",
		"blocks": [{"op": "damage", "amount": 5, "to": "target"}]}, casterH2)
	_cast(casterH2, abH2, [gH2["foes"][0]], gH2["m"])
	_check(casterH2.has_effect("Chan Nothing", EffectType.Type.CONTROL_CANCEL) == null,
		"NEGATIVE CONTROL: a channelled skill that applies nothing still plants no holder")

	# ==================================================================================
	# I. `trigger.scope` on a hook whose source is an EFFECT with no `source` Ability.
	#    _scope_matches returns false — a filtered trigger stays silent. Confirm the
	#    positive control fires so the negative is not vacuous.
	# ==================================================================================
	print("\n-- I: scope filter matching --")
	var gI := _fresh()
	var mI = gI["m"]
	var casterI = gI["allies"][0]
	var bearerI = gI["allies"][1]
	_fire(casterI, [{"op": "apply", "to": "target", "effect": {
		"kind": "trigger", "trigger": "on_skill_received", "scope": ["Mental"], "turns": 9,
		"name_override": "ScopeI",
		"then": [{"op": "damage", "amount": 5, "to": "holder"}]}}], [bearerI], mI, "ScopeI", false)
	var foeI = gI["foes"][0]
	var physI := _mk({"name": "Phys Poke", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 3, "to": "target"}]}, foeI)
	var hpI: int = bearerI.health.hp
	_use(mI, foeI, physI, [bearerI])
	_check(hpI - bearerI.health.hp == 3,
		"a Physical skill does NOT fire a Mental-scoped trigger (%d -> %d)" % [hpI, bearerI.health.hp])
	var mentalI := _mk({"name": "Mental Poke", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 3, "to": "target"}]}, foeI)
	mentalI.classes["Mental"] = true
	var hpI2: int = bearerI.health.hp
	_use(mI, foeI, mentalI, [bearerI])
	_check(hpI2 - bearerI.health.hp == 8,
		"POSITIVE CONTROL: a Mental skill DOES fire it (3 + 5 payload) (%d -> %d)" % [hpI2, bearerI.health.hp])

	# ==================================================================================
	# J. IS THE `mag` COLLISION SYSTEMIC? Three shipped kinds use Effect.mag as something
	#    other than a magnitude, and the universal pass writes over all three.
	#      reflect          -> mag = the destination Character   (Phase B, new)
	#      effect_immunity  -> mag = the EffectType ignored      (effect_component.gd:637)
	#      swap             -> mag = Vector2(into, slot), read as swap.mag[0]
	#                          (moveset_component.gd:98)
	# ==================================================================================
	print("\n-- J: the same collision on two Phase A kinds --")
	var imm_spec := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "effect_immunity", "effect": "STUN", "turns": 3, "mag": 0}}])
	_check(not BlockValidator.validate_ability(imm_spec).is_empty(),
		"effect_immunity + universal `mag` is rejected too — one rule, every kind")
	var gJ := _fresh()
	var mJ = gJ["m"]
	var casterJ = gJ["allies"][0]
	_fire(casterJ, [{"op": "apply", "to": "user", "effect": {
		"kind": "effect_immunity", "effect": "STUN", "turns": 3,
		"name_override": "Probe Imm", "mag": 0}}], [casterJ], mJ, "Probe Imm", false)
	_check(casterJ.ignoring_effect_type(EffectType.Type.STUN),
		"RUNTIME GUARD: the authored STUN immunity ignores stuns even with a hand-edited `mag` present")
	var gJ2 := _fresh()
	var casterJ2 = gJ2["allies"][0]
	_fire(casterJ2, [{"op": "apply", "to": "user", "effect": {
		"kind": "effect_immunity", "effect": "STUN", "turns": 3,
		"name_override": "Probe Imm2"}}], [casterJ2], gJ2["m"], "Probe Imm2", false)
	_check(casterJ2.ignoring_effect_type(EffectType.Type.STUN),
		"POSITIVE CONTROL: without `mag` the same immunity works")

	var swap_spec := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "swap", "slot": 0, "into": 1, "turns": 2, "mag": 0}}])
	_check(not BlockValidator.validate_ability(swap_spec).is_empty(),
		"swap + universal `mag` is rejected too (moveset reads swap.mag[0], a Vector2)")

	_probe_k_reserved_registers()
	_probe_l_trigger_table()
	_probe_m_messages()

	print("\n=== adversarial review probe: %d failure(s) ===" % fails)
	get_tree().quit(0)

# ======================================================================================
# K. THE GENERAL RULE, ENUMERATED FROM THE FACTORIES.
#
# Sections A/B/J are the three kinds a human found by hand. This section is the part that
# has to still be true after Phase C adds ~20 more: it READS scripts/effect_component.gd and
# blocks/block_runner.gd, collects every universal-effect-field register each kind's factory
# actually writes, and requires each one to be either DECLARED in that kind's `reserves` or
# classified below as an overridable factory DEFAULT. A kind added with a factory that writes
# a register and no `reserves` entry fails here, which is the only thing that makes "they
# cannot forget" true rather than aspirational.
# ======================================================================================

# A factory write that is a DEFAULT, not a reservation — the factory sets the register but the
# author has no OTHER control for it, so the universal field is the only writer and overriding it
# is the entire purpose of the universal set. Each needs a reason, or this list becomes the
# escape hatch that empties the rule. Keyed "<kind>.<field>".
const ACKNOWLEDGED_DEFAULTS := {
	"stun.remove_on_death": "stun_effect pins it false; an author who wants a stun to die with its victim has no other switch",
	"trigger.cleansable": "trigger_effect derives it from the duration; the universal field is the only way to say otherwise",
	"shield.stackable": "shield_effect sets it from `display_shield`, which is not an authored field",
	"shield.stack_mag": "same call, same reason",
	"shield.display_mag": "same call, same reason",
	"swap.cleansable": "ability_swap_effect pins it false (identity state); overriding is a deliberate author choice",
	"cost_change.cleansable": "color_change_effect pins it false for the same reason",
	"mark.stackable": "BlockRunner's mark branch turns it on so re-casting stacks; no competing authored field",
	"portrait_change.cleansable": "portrait_change_effect pins it false (a transform must survive a cleanse); the universal field is the only override",
	"portrait_change.system": "portrait_change_effect pins it true (the snapshot filters PORTRAIT_CHANGE off the wire by `system`); no competing authored field",
}

func _universal_keys() -> Array:
	var out: Array = []
	for k in BlockSchema.UNIVERSAL_EFFECT_FIELDS.keys():
		out.append(str(k))
	return out

# Read a .gd file and answer {function name: [universal field written, ...]}, matching any
# `<something>.<universal field> =` assignment inside each top-level function.
func _scan_writes(path: String) -> Dictionary:
	var out: Dictionary = {}
	var uni := _universal_keys()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var cur := ""
	while not f.eof_reached():
		var raw := f.get_line()
		var t := raw.strip_edges()
		if t.begins_with("func ") or t.begins_with("static func "):
			var head := t.substr(t.find("func ") + 5)
			var paren := head.find("(")
			cur = head.substr(0, paren) if paren > 0 else head
			out[cur] = []
			continue
		if cur == "":
			continue
		var dot := t.find(".")
		if dot <= 0:
			continue
		var rest := t.substr(dot + 1)
		for u in uni:
			if rest.begins_with(u + " =") or rest.begins_with(u + "="):
				# "=" but not "==": an assignment, not a comparison.
				var after := rest.substr(u.length()).strip_edges()
				if after.begins_with("==") or after.begins_with("!="):
					continue
				if not u in (out[cur] as Array):
					(out[cur] as Array).append(u)
	f.close()
	return out

# Which of BlockRunner._build_effect's `match kind:` arms writes a universal register. Tracked by
# case label, because those writes belong to the KIND rather than to a factory — mark's
# `display_stacks` (written from the authored `show_stacks`) and damage_over_time's
# `last_turn_only` (written from the authored `delayed`) are BOTH collisions and NEITHER is
# visible in effect_component.gd.
func _scan_build_effect_arms() -> Dictionary:
	var out: Dictionary = {}
	var uni := _universal_keys()
	var f := FileAccess.open("res://blocks/block_runner.gd", FileAccess.READ)
	if f == null:
		return out
	var inside := false
	var arm := ""
	while not f.eof_reached():
		var raw := f.get_line()
		var t := raw.strip_edges()
		if t.begins_with("func _build_effect"):
			inside = true
			continue
		if not inside:
			continue
		if t.begins_with("func ") or t.begins_with("static func "):
			break                            # next function: _build_effect is over
		# A case label: `"mark":` at the match's indent, nothing after the colon.
		if t.begins_with("\"") and t.ends_with("\":"):
			arm = t.substr(1, t.length() - 3)
			if not out.has(arm):
				out[arm] = []
			continue
		if arm == "":
			continue
		var dot := t.find(".")
		if dot <= 0:
			continue
		var rest := t.substr(dot + 1)
		for u in uni:
			if rest.begins_with(u + " =") and not rest.substr(u.length()).strip_edges().begins_with("=="):
				if not u in (out[arm] as Array):
					(out[arm] as Array).append(u)
	f.close()
	return out

# The factories a kind reaches that its `factory` column does not name: `trigger`'s column is the
# "__trigger__" sentinel, and `cost_change` is three mechanics behind one kind.
const EXTRA_FACTORIES := {
	"trigger": ["trigger_effect"],
	"cost_change": ["cost_change_effect", "color_change_effect"],
}

func _probe_k_reserved_registers() -> void:
	print("\n-- K: the reserved-register rule, enumerated from the factories --")
	_check(BlockSchema.self_check().is_empty(),
		"BlockSchema.self_check() is clean (errs=%s)" % str(BlockSchema.self_check()))

	var fac := _scan_writes("res://scripts/effect_component.gd")
	_check(fac.has("reflect_effect") and "mag" in (fac["reflect_effect"] as Array),
		"the factory scan works at all (it sees reflect_effect writing `mag`)")

	var arms := _scan_build_effect_arms()
	_check(arms.has("mark") and "display_stacks" in (arms["mark"] as Array),
		"the runner scan works at all (it sees the mark arm writing `display_stacks`)")

	# THE HOLE THE FIRST VERSION OF THIS SECTION HAD, found by reversal: the two scans above see
	# only effect_component.gd's factories and _build_effect's INLINE match arms. Five kinds
	# (trigger, counter, reflect, swap, cost_change) are built by their own `_build_<kind>` helper
	# in block_runner.gd, and a universal register written in there was invisible to both — an
	# `rfx.invisible = true` planted inside _build_reflect left this section reporting
	# "undeclared: []". Phase C adds ~20 kinds and more helpers, so scan the runner by helper name
	# too and fold each helper's writes into its kind.
	var helpers := _scan_writes("res://blocks/block_runner.gd")
	var helper_hits := 0
	for fn in helpers.keys():
		var name := str(fn)
		if not name.begins_with("_build_"):
			continue
		var kind_of_helper := name.substr(7)
		if not BlockSchema.EFFECT_KINDS.has(kind_of_helper):
			continue
		helper_hits += 1
		if not arms.has(kind_of_helper):
			arms[kind_of_helper] = []
		for u in (helpers[name] as Array):
			if not u in (arms[kind_of_helper] as Array):
				(arms[kind_of_helper] as Array).append(u)
	_check(helper_hits > 0,
		"the helper scan resolves at least one _build_<kind> helper to its kind (%d)" % helper_hits)

	var undeclared: Array = []
	var owned_total := 0
	for kind in BlockSchema.EFFECT_KINDS.keys():
		var k := str(kind)
		var row: Dictionary = BlockSchema.EFFECT_KINDS[k]
		var writes: Array = []
		var facs: Array = [str(row.get("factory", ""))]
		if EXTRA_FACTORIES.has(k):
			facs.append_array(EXTRA_FACTORIES[k] as Array)
		for fn in facs:
			if fac.has(str(fn)):
				for u in (fac[str(fn)] as Array):
					if not u in writes:
						writes.append(u)
		if arms.has(k):
			for u in (arms[k] as Array):
				if not u in writes:
					writes.append(u)
		var reserved := BlockSchema.reserved_fields(k)
		var own: Array = row.get("fields", []) as Array
		for u in writes:
			# `description` is a Callable in every factory and a String here — the universal field is
			# the author's deliberate tooltip override, on every kind, and always has been.
			if str(u) == "description":
				continue
			if str(u) in own:
				continue                     # the author's OWN control under that name
			if reserved.has(str(u)):
				owned_total += 1
				continue
			if ACKNOWLEDGED_DEFAULTS.has("%s.%s" % [k, str(u)]):
				continue
			undeclared.append("%s.%s" % [k, str(u)])
	_check(undeclared.is_empty(),
		"every register a kind's factory writes is either RESERVED or a classified default (undeclared: %s)" % str(undeclared))
	_check(owned_total >= 12,
		"...and the table actually claims registers rather than being empty (%d reserved entries matched a real factory write)" % owned_total)

	# Now the RULE ITSELF, on every reserved field of every kind: build a minimal legal spec of that
	# kind, assert it validates; add the reserved field, assert it does not. That is the half the
	# review did by hand for three of them.
	var checked := 0
	for kind in BlockSchema.EFFECT_KINDS.keys():
		var k := str(kind)
		var reserved := BlockSchema.reserved_fields(k)
		if reserved.is_empty():
			continue
		var base := _minimal_effect(k)
		if base.is_empty():
			_check(false, "K: no minimal spec written for kind '%s' — the enumeration has a hole" % k)
			continue
		var clean := BlockValidator.validate_ability(_spec([{"op": "apply", "to": "user", "effect": base}]))
		_check(clean.is_empty(), "K/%s: the minimal spec validates clean (errs=%s)" % [k, str(clean)])
		for f in reserved.keys():
			var dirty: Dictionary = base.duplicate(true)
			# A value of the field's declared type, so the rejection cannot be a type error.
			dirty[str(f)] = 1 if str(BlockSchema.UNIVERSAL_EFFECT_FIELDS[str(f)]) == "int" else true
			var errs := BlockValidator.validate_ability(_spec([{"op": "apply", "to": "user", "effect": dirty}]))
			_check(not errs.is_empty(), "K/%s: '%s' is rejected" % [k, str(f)])
			_check(str(errs).find(str(reserved[f])) != -1,
				"K/%s: the message for '%s' names '%s'" % [k, str(f), str(reserved[f])])
			checked += 1
	print("     %d reserved field(s) checked across the whole table" % checked)

	# THE OTHER HALF OF THE ANSWER, and the reason `mag` is not banned outright: on a kind whose
	# factory never touches that register, an authored `mag` is the ONLY writer and is a real
	# authoring shape — a `mark` carrying a magnitude is the corpus's tracker idiom (uzui5's
	# `tracker.mag += 1`), and it is what `adjust`'s mag axis was written against.
	var tracker := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "mark", "turns": 5, "mag": 3, "display_mag": true, "name_override": "Tally"}}])
	_check(BlockValidator.validate_ability(tracker).is_empty(),
		"a `mark` carrying an authored `mag` still validates — the rule is per-kind, not a blanket ban")
	var gK := _fresh()
	var casterK = gK["allies"][0]
	_fire(casterK, [{"op": "apply", "to": "user", "effect": {
		"kind": "mark", "turns": 5, "mag": 3, "display_mag": true, "name_override": "Tally"}}],
		[casterK], gK["m"], "Tally Up", false)
	var tally = casterK.has_effect("Tally", EffectType.Type.MARK)
	_check(tally != null and int(tally.mag) == 3, "...and it lands, carrying the authored magnitude (%s)" % str(tally.mag if tally != null else "<gone>"))
	_fire(casterK, [{"op": "adjust", "name": "Tally", "to": "user", "mag": 2}], [casterK], gK["m"], "Tally Bump", false)
	_check(tally != null and int(tally.mag) == 5, "...and `adjust` can ramp it (3 -> %s)" % str(tally.mag if tally != null else "<gone>"))

	# And the two collisions this table found that nobody had reported.
	_check(not BlockValidator.validate_ability(_spec([{"op": "apply", "to": "user", "effect": {
			"kind": "mark", "turns": 3, "max": 5, "show_stacks": false, "display_stacks": true}}])).is_empty(),
		"NEW: `mark`.show_stacks and universal `display_stacks` are one register, and the pair is refused")
	_check(not BlockValidator.validate_ability(_spec([{"op": "apply", "to": "user", "effect": {
			"kind": "damage_over_time", "amount": 5, "turns": 3, "delayed": true, "last_turn_only": false}}])).is_empty(),
		"NEW: `damage_over_time`.delayed and universal `last_turn_only` are one register, and the pair is refused")

	# THE EDITOR HALF. A field that validates-as-rejected but still renders is the same lie in
	# reverse, so the palette has to carry the table the editor filters its control list with.
	var pal := _palette()
	_check(pal.has("effect_reserved") and (pal["effect_reserved"] as Dictionary).size() == BlockSchema.EFFECT_KINDS.size(),
		"the palette exports `effect_reserved` for every kind, so the editor can stop drawing the control")
	_check(pal.has("effect_reserved") and (pal["effect_reserved"] as Dictionary).get("reflect", {}).has("mag"),
		"...and reflect's entry names `mag`")

# The smallest spec that is VALID for a kind, so adding one reserved field is the only difference
# between the two validations above. Empty for a kind nobody has written one for, which is itself
# a failure — a kind that reserves a register must be reachable by this enumeration.
func _minimal_effect(kind: String) -> Dictionary:
	match kind:
		"mark":              return {"kind": "mark", "turns": 3, "max": 3}
		"damage_over_time":  return {"kind": "damage_over_time", "amount": 5, "turns": 3}
		"heal_over_time":    return {"kind": "heal_over_time", "amount": 5, "turns": 3}
		"shield":            return {"kind": "shield", "amount": 20, "turns": 3}
		"damage_reduction":  return {"kind": "damage_reduction", "amount": 5, "turns": 3}
		"vulnerability":     return {"kind": "vulnerability", "amount": 5, "turns": 3}
		"damage_boost":      return {"kind": "damage_boost", "amount": 5, "turns": 3}
		"swap":              return {"kind": "swap", "slot": 0, "into": 1, "turns": 3}
		"reflect":           return {"kind": "reflect", "destination": "applier", "turns": 3}
		"redirect":          return {"kind": "redirect", "amount": 50, "destination": {"pool": "other_allies", "pick": "random", "count": 1}, "turns": 3}
		"cost_change":       return {"kind": "cost_change", "amount": 1, "colour": "blue", "turns": 3}
		"cooldown_change":   return {"kind": "cooldown_change", "amount": 1, "turns": 3}
		"effect_immunity":   return {"kind": "effect_immunity", "effect": "STUN", "turns": 3}
		# PHASE C Simple Effect rows that reserve `mag` (the build arm writes it from `amount`). Every
		# one is reachable here so section K can prove `mag` is rejected on it with a message naming
		# `amount`. Percentage rows stay within their amount_max (100) so the minimal spec validates.
		"percent_dr":         return {"kind": "percent_dr", "amount": 50, "turns": 3}
		"heal_cut":           return {"kind": "heal_cut", "amount": 50, "turns": 3}
		"health_cap":         return {"kind": "health_cap", "amount": 50, "turns": 3}
		"damage_cap":         return {"kind": "damage_cap", "amount": 20, "turns": 3}
		"damage_cap_receive": return {"kind": "damage_cap_receive", "amount": 20, "turns": 3}
		"dodge_chance":       return {"kind": "dodge_chance", "amount": 50, "turns": 3}
		"healing_received_mod": return {"kind": "healing_received_mod", "amount": 10, "turns": 3}
		"barrier":            return {"kind": "barrier", "amount": 20, "turns": 3}
		"delay":              return {"kind": "delay", "amount": 1, "turns": 3}
		"delay_receive":      return {"kind": "delay_receive", "amount": 1, "turns": 3}
		# NAMED kind that reserves `mag` from its `index` field (the alt-portrait slot). Index 0 is the
		# first uploaded alt slot, always in bounds, so this minimal spec validates and section K can prove
		# `mag` is rejected on it with a message naming `index`.
		"portrait_change":    return {"kind": "portrait_change", "index": 0, "turns": 3}
	return {}

# The palette the editor renders from, built the same way ServerConnection._authored_palette does.
# Kept to the two keys this section asserts on rather than calling that method, which needs a live
# ServerConnection node.
func _palette() -> Dictionary:
	return {
		"effect_kinds": BlockSchema.EFFECT_KINDS,
		"effect_universal": BlockSchema.UNIVERSAL_EFFECT_FIELDS,
		"effect_reserved": BlockSchema.reserved_by_kind(),
	}

# ======================================================================================
# L. BlockSchema.TRIGGERS was a DEAD TABLE — the live mapping was a duplicated `match` in
# trigger_hook_id, and nothing asserted the two agreed. A hook row could validate, render,
# export to the palette and listen on the WRONG engine hook with the whole suite green.
# trigger_hook_id now DERIVES from the table; these are the assertions that the derivation
# lands on the same ten enum members the old match hard-coded.
# ======================================================================================
func _probe_l_trigger_table() -> void:
	print("\n-- L: the trigger table is the single source of truth --")
	# The enum values the retired `match` returned, restated by hand so the derivation is checked
	# against something INDEPENDENT of the table it derives from.
	var expected := {
		"on_harmful_received": EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
		"on_damage_received": EffectType.Type.DAMAGE_RECEIVE_TRIGGER,
		"on_damage_dealt": EffectType.Type.DAMAGE_DEALT_TRIGGER,
		"on_turn_start": EffectType.Type.START_OF_TURN_TRIGGER,
		"on_turn_end": EffectType.Type.END_OF_TURN_TRIGGER,
		"on_death": EffectType.Type.ON_DEATH_TRIGGER,
		"on_skill_used": EffectType.Type.ACTION_USE_TRIGGER,
		"on_hp_changed": EffectType.Type.HEALTH_CHANGE_TRIGGER,
		"on_stunned": EffectType.Type.STUN_RECEIVED_TRIGGER,
		"on_skill_received": EffectType.Type.ACTION_RECEIVE_TRIGGER,
		# Phase G long tail — the healer-side hook, addressing the healed via `affected`.
		"on_healing_given": EffectType.Type.HEALING_GIVEN_TRIGGER,
	}
	_check(expected.size() == BlockSchema.TRIGGERS.size(),
		"every hook in the palette is covered here (%d vs %d)" % [BlockSchema.TRIGGERS.size(), expected.size()])
	var wrong: Array = []
	for k in BlockSchema.TRIGGERS.keys():
		var got := BlockSchema.trigger_hook_id(str(k))
		if not expected.has(str(k)) or got != int(expected[str(k)]):
			wrong.append("%s -> %d" % [str(k), got])
	_check(wrong.is_empty(), "trigger_hook_id derives the SAME hook the retired match returned (wrong: %s)" % str(wrong))
	_check(BlockSchema.trigger_hook_id("on_nothing_at_all") == -1,
		"an unknown hook name still answers -1")

# ======================================================================================
# M. The two message fixes. Both are cases where the validator knew the right answer and
# said something that sent the author hunting a typo instead.
# ======================================================================================
func _probe_m_messages() -> void:
	print("\n-- M: error messages that say WHERE, not 'unknown' --")
	# A payload selector in a CONDITION slot. `holder` is legal two lines away as the payload
	# block's `to`, so "unknown selector 'holder'" is the worst possible answer.
	var cond_holder := _spec([{"op": "apply", "to": "user", "effect": {
		"kind": "trigger", "trigger": "on_turn_start", "turns": 3,
		"then": [{"op": "damage", "amount": 5, "to": "holder",
			"when": {"cond": "hp_below", "value": 50, "on": "holder"}}]}}])
	var errs := BlockValidator.validate_ability(cond_holder)
	print("     %s" % str(errs))
	_check(not errs.is_empty(), "a payload selector in a condition slot is still rejected")
	_check(str(errs).find("unknown selector") == -1,
		"...and NOT as 'unknown selector' — the name is real and spelled correctly")
	_check(str(errs).find("the character carrying this effect") != -1,
		"...the message says what 'holder' means and where it belongs")
	# The filtered-selector message it is now matching, unchanged.
	var cond_filtered := _spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "hp_below", "value": 50, "on": "any_enemy"}}])
	_check(str(BlockValidator.validate_ability(cond_filtered)).find("cannot be used inside one") != -1,
		"POSITIVE CONTROL: the filtered-selector slot message is untouched")
	# A genuinely unknown name must STILL say "unknown selector" — the placement message must not
	# have swallowed the typo case it exists to be distinguished from.
	var cond_typo := _spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "hp_below", "value": 50, "on": "holdr"}}])
	# Two separate finds, not one quoted phrase: str() on an Array escapes the single quotes.
	var typo_txt := str(BlockValidator.validate_ability(cond_typo))
	_check(typo_txt.find("unknown selector") != -1 and typo_txt.find("holdr") != -1,
		"NEGATIVE CONTROL: a real typo still reads as 'unknown selector' (%s)" % typo_txt)
