extends Node

# ============================================================================
# Creator Phase B, stage 2 — THE NEW OPS: `repeat`, `adjust`, `banish`.
#
#   godot --headless --path <repo> res://training/tests/creator_cheap_tier_probe.tscn
#
# WHAT IS UNDER TEST, and why each case is the one that can fail
#
# 1. `repeat` — a group with a count. The claim the op exists to make is that REPEATING A HIT IS
#    NOT ONE BIGGER HIT, so the load-bearing assertion is a comparison, not a number: the same
#    total damage delivered as 3x10 and as 1x30, on two identically defended characters, on the
#    same board. Damage reduction is the axis that separates them (it is re-tested per instance and
#    is not depleted), and a shield sits in front of both so the roadmap's "through a shield" case
#    is exercised — see the note in GROUP 1 about why a shield ALONE cannot separate them.
#    Its guards: `times` has its own limit, and _count_blocks MULTIPLIES the body so the 40-block
#    ceiling bounds executed work rather than typed work.
#
# 2. `adjust` — the read/write sibling of `remove`. The load-bearing case is the 2N convention:
#    `turns: +1` must move an effect's duration by TWO engine ticks, because durations tick on
#    every side's turn. A 1x conversion is the revert that this probe has to catch, and it would
#    look right in the editor and be wrong in play.
#
# 3. `banish` — an OPS row funnelling into Character.banish_character, the only writer of the
#    `character.banished` bool. Its guard is not a magnitude: check_win_condition counts a banished
#    character as eliminated and check_match_over runs mid-turn, so a banish aimed at a POOL ends
#    the match on the spot. Forbidden in the validator (two ways a block can aim at a pool) and
#    refused again in the runner, because a hand-edited file never met the validator.
#    A6 (a refused banish must not set the flag) is already shipped; GROUP 7 confirms this op
#    inherits it rather than re-introducing the desync.
#
# Every negative below is paired with a positive control on the SAME board.
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

# One battle per assertion group. Effects persist and HP does not reset, so sharing a board
# between groups would let one case decide another's answer.
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

# Build + cast in one step, for the many one-shot specs below.
func _fire(caster, blocks: Array, targets: Array, m, nm := "Probe Skill", harmful := true) -> void:
	var ab := _mk({"name": nm, "target": "enemy", "blocks": blocks}, caster, harmful)
	_cast(caster, ab, targets, m)

func _mentions(errs: Array, needle: String) -> bool:
	for e in errs:
		if str(e).find(needle) != -1:
			return true
	return false

# A defended character: a Shield in front of a non-depleting Damage Reduction. Both are ordinary
# authored effect kinds, applied by the authored path, so nothing here is a test fixture the live
# engine would not also produce.
func _defend(applier, who, m, shield: int, dr: int) -> void:
	_fire(applier, [
		{"op": "apply", "to": "target", "effect": {"kind": "shield", "amount": shield, "turns": 9,
			"name_override": "Probe Shield"}},
		{"op": "apply", "to": "target", "effect": {"kind": "damage_reduction", "amount": dr, "turns": 9,
			"name_override": "Probe DR"}}], [who], m, "Probe Wards", false)


func _ready():
	print("=== creator cheap-tier probe: repeat / adjust / banish ===")

	# =====================================================================================
	# GROUP 1 — `repeat` resolves PER INSTANCE, and that differs from one N-fold hit.
	#
	# Two enemies, identically warded (6 Shield, 5 damage reduction). One takes 3 repeats of 10;
	# the other takes a single 30. If a repeat were merely a bigger amount the two would be equal.
	#
	# WHY DAMAGE REDUCTION IS THE AXIS AND A SHIELD ALONE IS NOT: a Shield is a POOL —
	# check_damage_against_shielding subtracts from `mag` and carries the remainder onward, so
	# N hits and one N-fold hit drain exactly the same total and arrive at the same number. It is
	# in the board anyway (it is what the roadmap's case names, and it makes the break happen on a
	# specific instance) but it cannot carry the assertion. Damage reduction can: it is re-applied
	# in full to every instance and never depletes, so 3 instances pay it 3 times.
	# =====================================================================================
	var g1 := _fresh()
	var m1 = g1["m"]
	var a1 = g1["allies"][0]
	var v_many = g1["foes"][0]
	var v_once = g1["foes"][1]
	_defend(a1, v_many, m1, 6, 5)
	_defend(a1, v_once, m1, 6, 5)

	var many_hp: int = v_many.health.hp
	var once_hp: int = v_once.health.hp
	_fire(a1, [{"op": "repeat", "times": 3, "blocks": [{"op": "damage", "amount": 10}]}],
		[v_many], m1, "Probe Flurry")
	_fire(a1, [{"op": "damage", "amount": 30}], [v_once], m1, "Probe Haymaker")
	var many_lost: int = many_hp - v_many.health.hp
	var once_lost: int = once_hp - v_once.health.hp

	_check(many_lost > 0 and once_lost > 0,
		"both wards let SOMETHING through (3x10 -> %d, 1x30 -> %d)" % [many_lost, once_lost])
	_check(many_lost != once_lost,
		"THE CLAIM: 3x10 and 1x30 are not the same skill (%d vs %d lost)" % [many_lost, once_lost])
	# Pinned exactly, so a change in either direction is caught rather than merely "still unequal":
	#   3x10: inst1 10 - 6 Shield = 4, then -5 DR = 0 (shield now spent); inst2 and inst3 10 - 5 = 5.
	#   1x30: 30 - 6 Shield = 24, then -5 DR = 19.
	_check(many_lost == 10, "3x10 through 6 Shield + 5 DR costs 10 HP (got %d)" % many_lost)
	_check(once_lost == 19, "1x30 through the same wards costs 19 HP (got %d)" % once_lost)

	# The whole body repeats, not just the first block: a two-block repeat runs both, N times.
	var v_two = g1["foes"][2]
	var two_hp: int = v_two.health.hp
	_fire(a1, [{"op": "repeat", "times": 3, "blocks": [
		{"op": "damage", "amount": 2}, {"op": "damage", "amount": 3}]}], [v_two], m1, "Probe Two Step")
	_check(two_hp - v_two.health.hp == 15,
		"a two-block repeat runs BOTH blocks each time (3 x (2+3) = %d)" % [two_hp - v_two.health.hp])

	# =====================================================================================
	# GROUP 2 — receive-triggers fire PER INSTANCE. This is the half of "not one bigger hit" that
	# damage arithmetic cannot show, and the half that matters most for authored content: every
	# repetition re-enters whatever the target is carrying.
	# =====================================================================================
	var g2 := _fresh()
	var m2 = g2["m"]
	var a2 = g2["allies"][0]
	var t_many = g2["foes"][0]
	var t_once = g2["foes"][1]

	var counter_payload := [{"op": "apply", "to": "holder", "effect": {
		"kind": "mark", "turns": 20, "max": 9, "name_override": "Tick Count"}}]
	for who in [t_many, t_once]:
		_fire(a2, [{"op": "apply", "to": "target", "effect": {
			"kind": "trigger", "trigger": "on_damage_received", "turns": 20,
			"then": counter_payload}}], [who], m2, "Probe Watcher")

	_fire(a2, [{"op": "repeat", "times": 3, "blocks": [{"op": "damage", "amount": 4}]}],
		[t_many], m2, "Probe Flurry Two")
	_fire(a2, [{"op": "damage", "amount": 12}], [t_once], m2, "Probe Haymaker Two")

	var many_mark = t_many.has_effect("Tick Count", EffectType.Type.MARK)
	var once_mark = t_once.has_effect("Tick Count", EffectType.Type.MARK)
	_check(many_mark != null and int(many_mark.stacks) == 3,
		"a 3x repeat fires the victim's damage-received trigger 3 times (stacks=%s)" % [str(many_mark.stacks) if many_mark != null else "none"])
	_check(once_mark != null and int(once_mark.stacks) == 1,
		"control: the same total as ONE hit fires it once (stacks=%s)" % [str(once_mark.stacks) if once_mark != null else "none"])

	# =====================================================================================
	# GROUP 3 — `adjust`, the 2N case. THE revert-fails assertion of this stage.
	#
	# An authored "3 turns" DoT is duration 6. `turns: +1` must make it 8, not 7: durations tick on
	# EVERY side's turn, so one player-facing turn is two ticks. A 1x conversion reads correctly in
	# the editor, prints correctly in the description, and silently gives half the extension.
	# =====================================================================================
	var g3 := _fresh()
	var m3 = g3["m"]
	var a3 = g3["allies"][0]
	var d1 = g3["foes"][0]
	var d2 = g3["foes"][1]
	var d3 = g3["foes"][2]

	var burn := {"kind": "damage_over_time", "amount": 5, "turns": 3, "name_override": "Probe Burn"}
	for who in [d1, d2, d3]:
		_fire(a3, [{"op": "apply", "to": "target", "effect": burn}], [who], m3, "Probe Ignite")

	var b1 = d1.has_effect("Probe Burn", EffectType.Type.DAMAGE)
	_check(b1 != null and int(b1.duration) == 6,
		"setup: an authored 3-turn DoT is 6 engine ticks (got %s)" % [str(b1.duration) if b1 != null else "none"])

	_fire(a3, [{"op": "adjust", "to": "target", "name": "Probe Burn", "turns": 1}], [d1], m3, "Probe Stoke")
	_check(int(b1.duration) == 8,
		"adjust turns:+1 extends by exactly ONE GAME TURN = 2 ticks (6 -> %d; a 1x conversion gives 7)" % int(b1.duration))
	_check(int(b1.duration) - 6 == BlockSchema.turns_to_duration(1),
		"...and that delta IS what one authored turn is worth everywhere else in the palette (%d)" % BlockSchema.turns_to_duration(1))

	# The negative direction, same board: -1 turn is -2 ticks, not "permanent".
	var b2 = d2.has_effect("Probe Burn", EffectType.Type.DAMAGE)
	_fire(a3, [{"op": "adjust", "to": "target", "name": "Probe Burn", "turns": -1}], [d2], m3, "Probe Damp")
	_check(int(b2.duration) == 4,
		"adjust turns:-1 shortens by 2 ticks (6 -> %d) and does NOT read as -1 = permanent" % int(b2.duration))

	# Shortening past zero ENDS the effect rather than wrapping into the negative, where -1 would
	# mean permanent again — the worst possible outcome of a typo.
	_fire(a3, [{"op": "adjust", "to": "target", "name": "Probe Burn", "turns": -9}], [d3], m3, "Probe Douse")
	_check(not d3.has_any_effect("Probe Burn"),
		"shortening past 0 ends the effect instead of making it permanent")
	_check(d1.has_any_effect("Probe Burn"),
		"control: the other two DoTs on this board are untouched by that")

	# A PERMANENT effect is left alone. -1 + 2 = 1, so an unguarded extension would convert
	# "forever" into "one tick" — silently, and in the direction the author did not ask for.
	var perm_target = g3["foes"][0]
	_fire(a3, [{"op": "apply", "to": "target", "effect": {
		"kind": "mark", "turns": -1, "name_override": "Probe Forever"}}], [perm_target], m3, "Probe Brand")
	var pm = perm_target.has_effect("Probe Forever", EffectType.Type.MARK)
	_check(pm != null and int(pm.duration) == -1, "setup: a permanent mark is duration -1")
	_fire(a3, [{"op": "adjust", "to": "target", "name": "Probe Forever", "turns": 2}], [perm_target], m3, "Probe Brand Plus")
	_check(int(pm.duration) == -1,
		"adjusting a PERMANENT effect's duration leaves it permanent (got %d)" % int(pm.duration))

	# =====================================================================================
	# GROUP 4 — `adjust`'s other two axes, and the ONE-INSTANCE rule it inherits from `remove`.
	# =====================================================================================
	var g4 := _fresh()
	var m4 = g4["m"]
	var a4 = g4["allies"][0]
	var a4b = g4["allies"][1]
	var s1 = g4["foes"][0]
	var s2 = g4["foes"][1]

	_fire(a4, [{"op": "apply", "to": "target", "effect": {
		"kind": "mark", "turns": 9, "stacks": 2, "max": 9, "name_override": "Probe Tally"}}],
		[s1], m4, "Probe Tally Up")
	var tally = s1.has_effect("Probe Tally", EffectType.Type.MARK)
	_check(tally != null and int(tally.stacks) == 2, "setup: a mark starts at 2 stacks")
	_fire(a4, [{"op": "adjust", "to": "target", "name": "Probe Tally", "stacks": 3}], [s1], m4, "Probe Tally Add")
	_check(int(tally.stacks) == 5, "adjust stacks:+3 raises 2 -> %d" % int(tally.stacks))
	_fire(a4, [{"op": "adjust", "to": "target", "name": "Probe Tally", "stacks": 90}], [s1], m4, "Probe Tally Flood")
	_check(int(tally.stacks) == 9,
		"...and stops at the mark's OWN authored ceiling of 9, not the palette's 99 (got %d)" % int(tally.stacks))
	_fire(a4, [{"op": "adjust", "to": "target", "name": "Probe Tally", "stacks": -20}], [s1], m4, "Probe Tally Burn")
	_check(s1.has_effect("Probe Tally", EffectType.Type.MARK) == null,
		"spending more stacks than remain ends the effect — the same reading `remove` gives")

	# `mag` — the raw magnitude. A Shield's mag IS its remaining points, so this is checkable
	# behaviourally rather than only as a number.
	_fire(a4, [{"op": "apply", "to": "target", "effect": {
		"kind": "shield", "amount": 10, "turns": 9, "name_override": "Probe Plate"}}],
		[s2], m4, "Probe Plating", false)
	var plate = s2.has_effect("Probe Plate", EffectType.Type.SHIELD)
	_check(plate != null and int(plate.mag) == 10, "setup: a 10-point Shield")
	_fire(a4, [{"op": "adjust", "to": "target", "name": "Probe Plate", "mag": 5}], [s2], m4, "Probe Reinforce")
	_check(int(plate.mag) == 15, "adjust mag:+5 takes the Shield to %d points" % int(plate.mag))
	var s2_hp: int = s2.health.hp
	_fire(a4, [{"op": "damage", "amount": 15}], [s2], m4, "Probe Test Hit")
	_check(s2.health.hp == s2_hp,
		"...and the strengthened Shield actually absorbs 15 (HP %d unchanged)" % s2.health.hp)

	# ONE INSTANCE. Two different casters put a same-named effect on the same character; add_effect
	# dedups on (name, type, user), so these are two separate Effects. An adjust must move exactly
	# one of them — charging the author's delta against every match would apply it twice.
	var s3 = g4["foes"][2]
	_fire(a4, [{"op": "apply", "to": "target", "effect": burn}], [s3], m4, "Probe Ignite A")
	_fire(a4b, [{"op": "apply", "to": "target", "effect": burn}], [s3], m4, "Probe Ignite B")
	var twins: Array = []
	for eff in s3.effects._effects:
		if str(eff.effect_name()) == "Probe Burn":
			twins.append(eff)
	_check(twins.size() == 2, "setup: two separate 'Probe Burn' effects from two casters (%d)" % twins.size())
	_fire(a4, [{"op": "adjust", "to": "target", "name": "Probe Burn", "turns": 1}], [s3], m4, "Probe Stoke Twin")
	var moved := 0
	for eff in twins:
		if int(eff.duration) == 8:
			moved += 1
	_check(moved == 1,
		"adjust moves exactly ONE instance, not every match (%d of 2 moved)" % moved)

	# `adjust` is in REVALIDATED_OPS for the same reason `remove` is: writing eff.duration consults
	# no targeting predicate at all, so a pool-built `to` would otherwise reach inside an effect on
	# an INVULNERABLE defender — something no hand-written kit can do. Both halves on one board.
	var g4b := _fresh()
	var m4b = g4b["m"]
	var a4c = g4b["allies"][0]
	var hidden = g4b["foes"][0]
	var open = g4b["foes"][1]
	for who in [hidden, open]:
		_fire(a4c, [{"op": "apply", "to": "target", "effect": burn}], [who], m4b, "Probe Ignite C")
	_fire(a4c, [{"op": "apply", "to": "target", "effect": {"kind": "invulnerable", "turns": 4}}],
		[hidden], m4b, "Probe Aegis", false)
	_check(hidden.is_invuln(null), "setup: one of the two burning enemies is Invulnerable")
	_fire(a4c, [{"op": "adjust", "to": "all_enemies", "name": "Probe Burn", "turns": 1}],
		[hidden], m4b, "Probe Mass Stoke")
	var hidden_burn = hidden.has_effect("Probe Burn", EffectType.Type.DAMAGE)
	var open_burn = open.has_effect("Probe Burn", EffectType.Type.DAMAGE)
	_check(hidden_burn != null and int(hidden_burn.duration) == 6,
		"an `all_enemies` adjust does NOT reach an invulnerable defender (%d, unmoved)" % int(hidden_burn.duration))
	_check(open_burn != null and int(open_burn.duration) == 8,
		"control: the same block still adjusts the enemy who is not (%d)" % int(open_burn.duration))
	_fire(a4c, [{"op": "adjust", "to": "all_enemies", "name": "Probe Burn", "turns": 1, "bypassing": true}],
		[hidden], m4b, "Probe Mass Stoke Two")
	_check(int(hidden_burn.duration) == 8,
		"...and `bypassing: true` is the author's opt-out, exactly as on `remove` (%d)" % int(hidden_burn.duration))

	# =====================================================================================
	# GROUP 5 — `banish` does what the verb says, and inherits A6.
	# =====================================================================================
	var g5 := _fresh()
	var m5 = g5["m"]
	var a5 = g5["allies"][0]
	var gone = g5["foes"][0]
	var warded = g5["foes"][1]

	_fire(a5, [{"op": "banish", "to": "target", "turns": 1}], [gone], m5, "Probe Exile")
	_check(gone.banished, "banish sets the `banished` flag the win check and every selector read")
	_check(gone.is_banished(), "...and the BANISH effect is actually on them")
	var bef = gone.effects.get_effects_by_type(EffectType.Type.BANISH)
	_check(bef.size() == 1 and int(bef[0].duration) == 2,
		"'1 turn' is 2 engine ticks, the same 2N every other duration uses (got %s)" % [str(bef[0].duration) if bef.size() > 0 else "none"])

	# A6: a REFUSED banish must not leave the flag set. Invulnerability refuses the application,
	# and check_win_condition counts the flag — so the desync was a mid-turn false victory.
	_fire(a5, [{"op": "apply", "to": "target", "effect": {"kind": "invulnerable", "turns": 4}}],
		[warded], m5, "Probe Aegis", false)
	_check(warded.is_invuln(null), "setup: the second enemy is Invulnerable")
	_fire(a5, [{"op": "banish", "to": "target", "turns": 1}], [warded], m5, "Probe Exile Two")
	_check(not warded.banished,
		"A6 HOLDS FOR THIS OP: a refused banish does not set the flag (so it cannot read as an elimination)")
	_check(not warded.is_banished(), "...and no BANISH effect landed either")

	# A self-banish, the shipped Semiramis shape, on the same board — so "not banished" above is
	# about the refusal and not about the op being inert.
	_fire(a5, [{"op": "banish", "to": "user", "turns": 2}], [gone], m5, "Probe Withdraw")
	_check(a5.banished, "control: `to: \"user\"` banishes the caster (the self-banish shape)")

	# =====================================================================================
	# GROUP 6 — the RUNNER's own >1 refusal. A hand-edited file never met the validator, and
	# `target` inside a payload falls back to the applier's stale targeter, which on an AoE cast
	# is a whole team. Executed directly, bypassing validation, exactly as such a file would.
	# =====================================================================================
	var g6 := _fresh()
	var m6 = g6["m"]
	var a6 = g6["allies"][0]
	var foes6: Array = g6["foes"]
	_fire(a6, [{"op": "banish", "to": "all_enemies", "turns": 1}], [foes6[0]], m6, "Probe Mass Exile")
	var banished6 := 0
	for c in foes6:
		if c.banished:
			banished6 += 1
	_check(banished6 == 0,
		"a pool-aimed banish that slipped past the validator banishes NOBODY (%d of 3)" % banished6)
	_check(not m6.check_win_condition(), "...so it cannot end the match on the spot")

	# Positive control on the same board: a single-character selector still works, so the refusal
	# above is about the pool and not about the op failing outright.
	_fire(a6, [{"op": "banish", "to": "random_enemy", "turns": 1}], [foes6[0]], m6, "Probe Single Exile")
	var banished6b := 0
	for c in foes6:
		if c.banished:
			banished6b += 1
	_check(banished6b == 1,
		"control: `random_enemy` resolves to one character and banishes exactly them (%d of 3)" % banished6b)

	# =====================================================================================
	# GROUP 7 — VALIDATOR. Every rejection paired with the spec that must pass.
	# =====================================================================================
	# --- banish: the two ways a block can aim at a pool ---------------------------------
	var ok_banish := {"name": "Exile", "target": "enemy", "classes": ["Physical", "Harmful"],
		"blocks": [{"op": "banish", "to": "target", "turns": 1}]}
	_check(BlockValidator.validate_ability(ok_banish).is_empty(),
		"a single-target banish validates clean")

	var pool_banish := ok_banish.duplicate(true)
	pool_banish["blocks"][0]["to"] = "all_enemies"
	_check(_mentions(BlockValidator.validate_ability(pool_banish), "banish cannot aim at"),
		"banish `to: all_enemies` is REJECTED — a whole-team banish ends the match on the spot")

	var filtered_banish := ok_banish.duplicate(true)
	filtered_banish["blocks"][0]["to"] = "any_enemy"
	filtered_banish["blocks"][0]["when"] = {"cond": "hp_below", "value": 50}
	_check(_mentions(BlockValidator.validate_ability(filtered_banish), "banish cannot aim at"),
		"...and so is a condition-FILTERED selector, which is a pool too")

	var self_pool_banish := ok_banish.duplicate(true)
	self_pool_banish["blocks"][0]["to"] = "all_allies"
	_check(_mentions(BlockValidator.validate_ability(self_pool_banish), "banish cannot aim at"),
		"...and the mirror, `all_allies`, which would be an instant DEFEAT")

	# The subtler one: the selector name is innocent and the ABILITY makes it a pool.
	var aoe_banish := ok_banish.duplicate(true)
	aoe_banish["target"] = "all_enemies"
	_check(_mentions(BlockValidator.validate_ability(aoe_banish), "targets a whole team"),
		"`to: target` on an AoE-targeted skill is rejected — 'target' there IS the whole team")
	var aoe_banish_bare := {"name": "Exile", "target": "all_enemies", "classes": ["Physical", "Harmful"],
		"blocks": [{"op": "banish", "turns": 1}]}
	_check(_mentions(BlockValidator.validate_ability(aoe_banish_bare), "targets a whole team"),
		"...including with no `to` at all, which defaults to it")
	var aoe_banish_ok := {"name": "Exile", "target": "all_enemies", "classes": ["Physical", "Harmful"],
		"blocks": [{"op": "banish", "to": "random_enemy", "turns": 1}]}
	_check(BlockValidator.validate_ability(aoe_banish_ok).is_empty(),
		"control: the same AoE skill with a single-character `to` validates")

	# Inside a payload, `target` is rebound to the one character who tripped the hook, so the AoE
	# rule does not apply there — but the pool rule still does.
	var payload_banish := {"name": "Exile Trap", "target": "all_enemies",
		"classes": ["Physical", "Harmful"],
		"blocks": [{"op": "apply", "to": "target", "effect": {
			"kind": "trigger", "trigger": "on_harmful_received", "turns": 3,
			"then": [{"op": "banish", "to": "target", "turns": 1}]}}]}
	_check(BlockValidator.validate_ability(payload_banish).is_empty(),
		"control: `to: target` inside a PAYLOAD is one character, so an AoE skill may carry it")
	var payload_pool_banish := payload_banish.duplicate(true)
	payload_pool_banish["blocks"][0]["effect"]["then"][0]["to"] = "all_enemies"
	_check(_mentions(BlockValidator.validate_ability(payload_pool_banish), "banish cannot aim at"),
		"...but the pool rule still bites inside a payload")
	var payload_holder_banish := payload_banish.duplicate(true)
	payload_holder_banish["blocks"][0]["effect"]["then"][0]["to"] = "holder"
	_check(BlockValidator.validate_ability(payload_holder_banish).is_empty(),
		"control: `holder` is one character, so it is a legal banish aim inside a payload")

	# --- repeat --------------------------------------------------------------------------
	var ok_repeat := {"name": "Flurry", "target": "enemy", "classes": ["Physical", "Harmful"],
		"blocks": [{"op": "repeat", "times": 3, "blocks": [{"op": "damage", "amount": 10}]}]}
	_check(BlockValidator.validate_ability(ok_repeat).is_empty(), "a 3x repeat validates clean")

	var zero_repeat := ok_repeat.duplicate(true)
	zero_repeat["blocks"][0]["times"] = 0
	_check(_mentions(BlockValidator.validate_ability(zero_repeat), "never run at all"),
		"times:0 is rejected as a branch that never runs, not as 'too few'")

	var big_repeat := ok_repeat.duplicate(true)
	big_repeat["blocks"][0]["times"] = BlockSchema.LIMITS["max_repeat_times"] + 1
	_check(_mentions(BlockValidator.validate_ability(big_repeat), "times"),
		"times above max_repeat_times (%d) is rejected" % BlockSchema.LIMITS["max_repeat_times"])
	var max_repeat := ok_repeat.duplicate(true)
	max_repeat["blocks"][0]["times"] = BlockSchema.LIMITS["max_repeat_times"]
	_check(BlockValidator.validate_ability(max_repeat).is_empty(),
		"control: exactly max_repeat_times validates — the bound is inclusive")

	var empty_repeat := ok_repeat.duplicate(true)
	empty_repeat["blocks"][0]["blocks"] = []
	_check(_mentions(BlockValidator.validate_ability(empty_repeat), "non-empty"),
		"an empty repeat body is rejected")

	# HAZARD 4: the block ceiling must bound EXECUTED work. 12 x a 4-block body is 48 executions
	# from a tree that a plain recursion would count as 5.
	var body4: Array = []
	for i in range(4):
		body4.append({"op": "damage", "amount": 1})
	var fat_repeat := {"name": "Fat Flurry", "target": "enemy", "classes": ["Physical", "Harmful"],
		"blocks": [{"op": "repeat", "times": 12, "blocks": body4}]}
	_check(_count(fat_repeat) > BlockSchema.LIMITS["max_blocks_per_ability"],
		"_count_blocks MULTIPLIES a repeat's body: 12 x 4 counts as %d, not 5" % _count(fat_repeat))
	_check(_mentions(BlockValidator.validate_ability(fat_repeat), "too many blocks"),
		"...so the 40-block ceiling actually refuses it")
	var lean_repeat := {"name": "Lean Flurry", "target": "enemy", "classes": ["Physical", "Harmful"],
		"blocks": [{"op": "repeat", "times": 3, "blocks": body4}]}
	_check(BlockValidator.validate_ability(lean_repeat).is_empty(),
		"control: 3 x 4 is 13 counted blocks and validates — the ceiling bounds work, not ambition")

	# Nesting is where the multiplication has to compose, or two small repeats hide a big one.
	var nested_repeat := {"name": "Nested", "target": "enemy", "classes": ["Physical", "Harmful"],
		"blocks": [{"op": "repeat", "times": 8, "blocks": [
			{"op": "repeat", "times": 8, "blocks": [{"op": "damage", "amount": 1}]}]}]}
	_check(_mentions(BlockValidator.validate_ability(nested_repeat), "too many blocks"),
		"a repeat inside a repeat multiplies (8 x 8) and is refused")

	# The in-payload flag has to ride down through a repeat exactly as it does through a group,
	# or `holder` becomes illegal the moment an author wraps a payload block in one.
	var payload_repeat := {"name": "Payload Flurry", "target": "self",
		"classes": ["Strategic", "Instant"],
		"blocks": [{"op": "apply", "to": "user", "effect": {
			"kind": "trigger", "trigger": "on_turn_end", "turns": 3, "then": [
				{"op": "repeat", "times": 2, "blocks": [{"op": "damage", "amount": 5, "to": "holder"}]}]}}]}
	_check(BlockValidator.validate_ability(payload_repeat).is_empty(),
		"`holder` inside a REPEAT inside a payload validates — the in-payload flag rides down")
	var top_repeat_holder := ok_repeat.duplicate(true)
	top_repeat_holder["blocks"][0]["blocks"][0]["to"] = "holder"
	_check(_mentions(BlockValidator.validate_ability(top_repeat_holder), "holder"),
		"...and is still rejected inside a TOP-LEVEL repeat, where there is no event to address")

	# --- adjust ---------------------------------------------------------------------------
	var ok_adjust := {"name": "Stoke", "target": "enemy", "classes": ["Strategic", "Harmful"],
		"blocks": [{"op": "adjust", "to": "target", "name": "Burn", "turns": 1}]}
	_check(BlockValidator.validate_ability(ok_adjust).is_empty(), "a turns-delta adjust validates clean")

	var noname_adjust := ok_adjust.duplicate(true)
	noname_adjust["blocks"][0].erase("name")
	_check(_mentions(BlockValidator.validate_ability(noname_adjust), "name the effect to adjust"),
		"adjust with no effect name is rejected — the name is the whole match key")

	var noaxis_adjust := ok_adjust.duplicate(true)
	noaxis_adjust["blocks"][0].erase("turns")
	_check(_mentions(BlockValidator.validate_ability(noaxis_adjust), "at least one"),
		"adjust with no axis at all is rejected rather than silently doing nothing")

	var zero_adjust := ok_adjust.duplicate(true)
	zero_adjust["blocks"][0]["turns"] = 0
	_check(_mentions(BlockValidator.validate_ability(zero_adjust), "must not be 0"),
		"a 0 delta is rejected — the author meant one direction or the other")

	# THE DELTA-FORM RULE, enforced by construction: there is no `set` field, so the palette's
	# unknown-field rejection is what refuses one. That is the guard against unbounded ramps.
	var set_adjust := ok_adjust.duplicate(true)
	set_adjust["blocks"][0]["set"] = 5
	_check(_mentions(BlockValidator.validate_ability(set_adjust), "unexpected field 'set'"),
		"a `set` form is refused: there is no set axis, only deltas")

	var bad_type_adjust := ok_adjust.duplicate(true)
	bad_type_adjust["blocks"][0]["effect"] = "NOT_A_TYPE"
	_check(_mentions(BlockValidator.validate_ability(bad_type_adjust), "is not an effect type"),
		"an unknown `effect` type on adjust is rejected, same list `remove` checks against")
	var typed_adjust := ok_adjust.duplicate(true)
	typed_adjust["blocks"][0]["effect"] = "DAMAGE"
	_check(BlockValidator.validate_ability(typed_adjust).is_empty(),
		"control: a real EffectType name as the disambiguator validates")

	var multi_adjust := ok_adjust.duplicate(true)
	multi_adjust["blocks"][0]["stacks"] = -2
	multi_adjust["blocks"][0]["mag"] = 3
	_check(BlockValidator.validate_ability(multi_adjust).is_empty(),
		"control: all three axes at once validate")

	# A Passive still cannot aim a new op at the empty targeter it has at battle start.
	var passive_banish := {"name": "Exile Passive", "target": "self", "classes": ["Passive"],
		"blocks": [{"op": "banish", "to": "target", "turns": 1}]}
	_check(_mentions(BlockValidator.validate_ability(passive_banish), "battle start"),
		"a Passive banish aimed at 'target' is rejected — the passive-targets rule covers new ops")

	# =====================================================================================
	# GROUP 8 — GENERATED PROSE. `describe()` is never hand-written, so the generated sentence IS
	# the contract a player reads off the card. A new op that produces no sentence is invisible.
	# =====================================================================================
	var prose_ab := ScriptedAbility.new()
	prose_ab.configure({"target": "enemy", "blocks": [
		{"op": "repeat", "times": 3, "blocks": [{"op": "damage", "amount": 10}]},
		{"op": "adjust", "to": "target", "name": "Burn", "turns": 1},
		{"op": "banish", "to": "random_enemy", "turns": 2}]})
	prose_ab.ability_name = "Prose Probe"
	prose_ab.classes = {"Passive": false}
	var prose: String = prose_ab.describe(null)
	print("    prose: " + prose)
	_check(prose.find("3 times: Deals 10 damage to the target") != -1,
		"repeat prints its COUNT first, so a reader knows it is three separate hits")
	_check(prose.find("Extends Burn on the target by 1 turn") != -1,
		"adjust prints the effect, the direction and the amount in author turns")
	_check(prose.find("Banishes a random enemy for 2 turns") != -1,
		"banish prints its duration")

	var prose2 := ScriptedAbility.new()
	prose2.configure({"target": "ally", "blocks": [
		{"op": "adjust", "to": "user", "name": "Ward", "turns": -1, "stacks": 2, "mag": -5},
		{"op": "banish", "to": "user", "turns": -1}]})
	prose2.ability_name = "Prose Probe Two"
	prose2.classes = {"Passive": false}
	var prose_b: String = prose2.describe(null)
	print("    prose: " + prose_b)
	for phrase in ["Shortens Ward on the user by 1 turn", "Adds 2 stacks to Ward on the user",
			"Weakens Ward on the user by 5", "Banishes the user permanently"]:
		_check(prose_b.find(phrase) != -1, "prose contains '%s'" % phrase)

	# =====================================================================================
	# GROUP 9 — the BOT hints. An authored skill the policy cannot see is a skill the bot never
	# plays, which makes the character unpractisable.
	# =====================================================================================
	var hint_ab := ScriptedAbility.new()
	hint_ab.configure({"target": "enemy",
		"blocks": [{"op": "repeat", "times": 3, "blocks": [{"op": "damage", "amount": 10}]}]})
	hint_ab.ability_name = "Hint Probe"
	hint_ab.classes = {"Passive": false}
	_check(int(hint_ab.bot_damage_hint()) == 30,
		"a 3x10 repeat scores 30 to the bot, not 10 (got %d)" % int(hint_ab.bot_damage_hint()))

	var tag_ab := ScriptedAbility.new()
	tag_ab.configure({"target": "enemy", "blocks": [{"op": "banish", "to": "target", "turns": 1}]})
	tag_ab.ability_name = "Tag Probe"
	tag_ab.classes = {"Passive": false}
	_check(int(tag_ab.bot_tags) & ScriptedAbility.TAG_CONTROL != 0,
		"banish carries the CONTROL bit, which is where bake_bot_tags.py files banish_effect")

	var tag_ab2 := ScriptedAbility.new()
	tag_ab2.configure({"target": "ally", "blocks": [
		{"op": "repeat", "times": 2, "blocks": [{"op": "heal", "amount": 5}]}]})
	tag_ab2.ability_name = "Tag Probe Two"
	tag_ab2.classes = {"Passive": false}
	_check(int(tag_ab2.bot_tags) & ScriptedAbility.TAG_HEAL != 0,
		"a repeat's BODY still contributes its bits (HEAL through a repeat)")

	# The palette the editor builds from has to carry the new rows, or stage 3 renders nothing.
	for op in ["repeat", "adjust", "banish"]:
		_check(BlockSchema.OPS.has(op), "OPS exports '%s'" % op)
	_check(BlockSchema.LIMITS.has("max_repeat_times"), "LIMITS exports max_repeat_times")
	_check(BlockSchema.is_pool_selector("all_enemies") and not BlockSchema.is_pool_selector("random_enemy"),
		"is_pool_selector separates the pools from the singular selectors")
	_check(BlockSchema.turns_to_delta(-1) == -2 and BlockSchema.turns_to_delta(1) == 2,
		"turns_to_delta is 2N in BOTH directions (unlike turns_to_duration, where -1 is permanent)")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# Count what an ability would EXECUTE, through the validator's own counter.
func _count(spec: Dictionary) -> int:
	var big := spec.duplicate(true)
	# One extra block over the ceiling is what the error reports on; call the counter directly so
	# the assertion is about the number rather than about the message.
	return _count_via_validator(big.get("blocks", []))

func _count_via_validator(blocks: Array) -> int:
	# BlockValidator._count_blocks is private-by-convention (GDScript has no access control) and is
	# the exact function under test, so it is called directly rather than re-implemented here.
	return BlockValidator._count_blocks(blocks)
