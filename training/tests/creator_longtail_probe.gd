extends Node

# ============================================================================
# Creator PHASE G — the long tail.
# STAGE 1: the exploit-carrying ops.
#   execute (instant kill) + its two immunities
#   revive + the dead_allies pool (targets that keep the dead)
#   direct cooldown control + the self-reset infinite-cast guard
#   drain_energy / steal + the energy_at_least condition
# STAGE 2: the cheaper rows.
#   else on group (ONE roll, exactly one branch; _count_blocks recurses into else)
#   max_uses charges (survive a cleanse AND a revive)
#   cost_color_at_least (reads ability.cost())
#   on_healing_given (rides `affected` = the healed)
#   seal (first-class skill_seal — class filter + name exclusion)
#
# Every negative assertion is PAIRED with a positive control. The load-bearing
# revert-fails cases (roadmap Verify) are called out in comments so a hand-reversal
# of the guard has a single line to point at:
#   * COOLDOWN SELF-RESET  — validator rejects it; the runner backstop keeps the
#                            cooldown even if the validator is bypassed.
#   * DRAIN TEAM-POOL       — all_enemies drains N, not 3N, and a steal grants only
#                            what was actually removed (empty-pool denial respected).
#   * EXECUTE IMMUNITIES    — Embrace Pain and a Sealed Nightmare IGNORE_DAMAGE refuse it.
#   * REVIVE / dead_ally    — revive reaches a dead ally; dead_allies is rejected in a `when`.
#
# Run: godot --headless --path <repo> res://training/tests/creator_longtail_probe.tscn
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

func _fresh(team := ["naruto", "gon", "orihime"], foes := ["eren", "misaka", "sakura"]) -> Array:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", team)
	var p2 := _build_player("BotEnemy", foes)
	m.start_battle(p1, p2, true, 2024, BattleManager.MatchType.BOT)
	return [m, p1, p2]

# Build a ScriptedAbility straight from a spec (as from_database would). `helpful` flips the class
# flags so a revive/cooldown skill routes ally-side.
func _mk(spec: Dictionary, owner, helpful := false) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Authored"))
	a.classes = {"Physical": false, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": false, "Harmful": not helpful, "Helpful": helpful, "Instant": true, "Action": false,
		"Control": false, "Channeled": false, "Uncounterable": false, "Bypassing": false,
		"Stealthed": false, "Passive": false, "Preserves Channel": false, "Damaging": not helpful}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)

func _v(spec: Dictionary) -> Array:
	return BlockValidator.validate_ability(spec)

# A bare-minimum valid spec with one block swapped in, so a validation check isolates the op.
func _spec(name: String, target: String, block: Dictionary) -> Dictionary:
	return {"name": name, "target": target, "cooldown": 0, "blocks": [block]}

func _team_cash(team) -> int:
	var n := 0
	for k in team.energy.pool:
		n += int(team.energy.pool[k])
	return n

func _ready():
	print("=== Creator Phase G Stage 1: exploit-carrying ops ===")

	# self_check() must stay green — a schema change must not break the reserves/trigger invariants.
	_check(BlockSchema.self_check().is_empty(), "BlockSchema.self_check() is green (errs=%s)" % str(BlockSchema.self_check()))

	_probe_execute()
	_probe_revive()
	_probe_cooldown()
	_probe_drain()
	# --- STAGE 2: the cheaper rows ---
	_probe_else()
	_probe_max_uses()
	_probe_cost_color()
	_probe_healing_given()
	_probe_seal()

	print("=== %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _desc_text(a: ScriptedAbility) -> String:
	var parts: Array = []
	for seg in a.split_desc():
		parts.append(seg[0] if seg is Array else str(seg))
	return " ".join(parts)

# ---------------------------------------------------------------------------
# 1) EXECUTE
# ---------------------------------------------------------------------------
func _probe_execute():
	print("--- execute ---")
	# VALIDATION: unconditional and thresholded both accept; a below-1 threshold is the silent-no-op
	# typo trap and is rejected (POSITIVE CONTROL: threshold 25 accepts).
	_check(_v(_spec("Erase", "enemy", {"op": "execute"})).is_empty(), "unconditional execute validates")
	_check(_v(_spec("Finish", "enemy", {"op": "execute", "hp_below": 25})).is_empty(), "thresholded execute (hp_below 25) validates")
	_check(not _v(_spec("Bad", "enemy", {"op": "execute", "hp_below": 0})).is_empty(), "execute hp_below 0 is rejected (can never fire)")
	_check(not _v(_spec("Bad", "enemy", {"op": "execute", "hp_below": -5})).is_empty(), "execute hp_below -5 is rejected")

	# RUNTIME: kills a normal target outright.
	var s = _fresh(); var m = s[0]; var caster = s[1].team.characters[0]; var victim = s[2].team.characters[0]
	var kill := _mk(_spec("Erase", "enemy", {"op": "execute"}), caster)
	_check(not victim.dead, "victim alive before execute")
	_cast(caster, kill, [victim], m)
	_check(victim.dead, "execute instant-kills a normal target")

	# IMMUNITY 1 — the Embrace Pain mark. instant_kill returns early. POSITIVE CONTROL: the un-marked
	# sibling on the same team dies from the same cast in the next assertion.
	var s2 = _fresh(); var m2 = s2[0]; var caster2 = s2[1].team.characters[0]
	var immune = s2[2].team.characters[0]
	var mortal = s2[2].team.characters[1]
	var mark = Effect.mark(-1); mark.name_override = "Embrace Pain"; mark.user = immune; mark.source = kill
	immune.effects.add_effect(mark)
	var kill2 := _mk(_spec("Erase", "enemy", {"op": "execute"}), caster2)
	_cast(caster2, kill2, [immune], m2)
	_check(not immune.dead, "REVERT-FAILS: execute refused by 'Embrace Pain'")
	_cast(caster2, kill2, [mortal], m2)
	_check(mortal.dead, "positive control: same execute kills the un-marked ally")

	# IMMUNITY 2 — a Sealed Nightmare IGNORE_DAMAGE effect. instant_kill returns early.
	var s3 = _fresh(); var m3 = s3[0]; var caster3 = s3[1].team.characters[0]
	var sealed = s3[2].team.characters[0]
	var sn = Effect.ignore_damage_effect(-1); sn.name_override = "Sealed Nightmare"; sn.user = sealed; sn.source = kill
	sealed.effects.add_effect(sn)
	var kill3 := _mk(_spec("Erase", "enemy", {"op": "execute"}), caster3)
	_cast(caster3, kill3, [sealed], m3)
	_check(not sealed.dead, "REVERT-FAILS: execute refused by 'Sealed Nightmare' IGNORE_DAMAGE")

	# THRESHOLD is per-target: kills the wounded, spares the healthy in the SAME cast.
	var s4 = _fresh(); var m4 = s4[0]; var caster4 = s4[1].team.characters[0]
	var low = s4[2].team.characters[0]
	var high = s4[2].team.characters[1]
	low.health.set_health(20)
	high.health.set_health(80)
	var fin := _mk(_spec("Finish", "enemy", {"op": "execute", "hp_below": 25}), caster4)
	_cast(caster4, fin, [low, high], m4)
	_check(low.dead, "thresholded execute kills a target below 25 HP")
	_check(not high.dead, "thresholded execute spares a target at 80 HP (per-target, not a block guard)")

# ---------------------------------------------------------------------------
# 2) REVIVE + dead_allies pool
# ---------------------------------------------------------------------------
func _probe_revive():
	print("--- revive ---")
	# VALIDATION: amount >= 1; 0 is the silent no-op (dies again immediately). dead_allies pool `to`
	# accepts. And dead_allies is REJECTED in a `when` / `requires` slot.
	_check(_v(_spec("Rise", "ally", {"op": "revive", "amount": 35})).is_empty(), "revive amount 35 validates")
	_check(not _v(_spec("Rise", "ally", {"op": "revive", "amount": 0})).is_empty(), "revive amount 0 is rejected (dies again)")
	_check(_v(_spec("Rise", "ally", {"op": "revive", "amount": 35, "to": {"pool": "dead_allies"}})).is_empty(), "revive to dead_allies pool validates")
	# REVERT-FAILS: dead_allies as a condition selector (no dead target exists during usability checks).
	var when_spec := {"name": "R", "target": "ally", "cooldown": 0,
		"blocks": [{"op": "heal", "amount": 5, "when": {"cond": "hp_below", "value": 50, "on": "dead_allies"}}]}
	_check(not _v(when_spec).is_empty(), "REVERT-FAILS: dead_allies rejected inside a `when` condition")
	var req_spec := {"name": "R", "target": "ally", "cooldown": 0,
		"requires": [{"cond": "hp_below", "value": 50, "on": "dead_allies"}],
		"blocks": [{"op": "heal", "amount": 5}]}
	_check(not _v(req_spec).is_empty(), "dead_allies rejected inside a `requires` usability condition")
	# POSITIVE CONTROL: a plain pool in a `when` slot still validates.
	var ok_when := {"name": "R", "target": "ally", "cooldown": 0,
		"blocks": [{"op": "heal", "amount": 5, "when": {"cond": "hp_below", "value": 50, "on": "all_allies"}}]}
	_check(_v(ok_when).is_empty(), "positive control: all_allies is fine inside a `when`")

	# RUNTIME: a dead ally is revived to N HP. The pool branch keeps the dead (target normally drops it).
	var s = _fresh(); var m = s[0]; var caster = s[1].team.characters[0]; var ally = s[1].team.characters[1]
	ally.health.set_health(0); ally.dead = true
	var revive := _mk(_spec("Rise", "ally", {"op": "revive", "amount": 35}), caster, true)
	_cast(caster, revive, [ally], m)
	_check(not ally.dead, "revive reaches a DEAD ally (targets keep the dead)")
	_check(ally.health.hp == 35, "revived ally is at 35 HP (%d)" % ally.health.hp)

	# The dead_allies POOL form finds the dead across the team without a click.
	var s2 = _fresh(); var m2 = s2[0]; var caster2 = s2[1].team.characters[0]; var a2 = s2[1].team.characters[2]
	a2.health.set_health(0); a2.dead = true
	var revive_pool := _mk(_spec("Rise", "ally", {"op": "revive", "amount": 40, "to": {"pool": "dead_allies"}}), caster2, true)
	_cast(caster2, revive_pool, [], m2)
	_check(not a2.dead and a2.health.hp == 40, "dead_allies pool revives the dead team member (hp=%d)" % a2.health.hp)

# ---------------------------------------------------------------------------
# 3) DIRECT COOLDOWN — the self-reset infinite-cast guard
# ---------------------------------------------------------------------------
func _probe_cooldown():
	print("--- cooldown ---")
	# VALIDATION. A negative op naming its OWN ability is refused; naming another is fine; an empty
	# skills list (= every skill, incl. self) with a negative amount is refused; a POSITIVE amount on
	# its own name is fine (lengthening is not the exploit).
	_check(not _v(_spec("Loop", "self", {"op": "cooldown", "amount": -1, "skills": ["Loop"]})).is_empty(),
		"REVERT-FAILS: negative cooldown naming its OWN ability is rejected")
	_check(not _v(_spec("Loop", "self", {"op": "cooldown", "amount": -99})).is_empty(),
		"negative cooldown with empty skills (= every skill, incl. self) is rejected")
	_check(_v(_spec("Loop", "self", {"op": "cooldown", "amount": -2, "skills": ["Some Other Skill"]})).is_empty(),
		"positive control: reducing ANOTHER skill's cooldown validates")
	_check(_v(_spec("Loop", "enemy", {"op": "cooldown", "amount": 2})).is_empty(),
		"positive control: LENGTHENING (positive amount) is fine, even unnamed")
	# The guard walks payloads: a self-reset buried in a trigger `then` is still refused.
	var buried := {"name": "Loop", "target": "self", "cooldown": 0, "blocks": [
		{"op": "apply", "effect": {"kind": "mark", "ticks": 2, "trigger": "on_turn_start",
			"then": [{"op": "cooldown", "amount": -5, "skills": ["Loop"]}]}}]}
	_check(not _v(buried).is_empty(), "self-reset buried in a trigger payload is rejected")

	# RUNTIME positive: reduce a DIFFERENT (real) base ability's cooldown.
	var s = _fresh(); var m = s[0]; var caster = s[1].team.characters[0]
	var other = caster.moveset.base_abilities[1]
	other.cooldown_remaining = 4
	var reducer := _mk(_spec("Speedup", "self", {"op": "cooldown", "amount": -2, "skills": [other.ability_name]}), caster, true)
	_cast(caster, reducer, [caster], m)
	_check(other.cooldown_remaining == 2, "cooldown op reduced another skill 4 -> %d" % other.cooldown_remaining)

	# RUNTIME backstop (defence in depth). Construct the exploit spec DIRECTLY (bypassing the validator)
	# and put the authored ability into base_abilities so it is its own copy. The runner must refuse to
	# reduce it — this is the assertion that FAILS if the runtime guard is hand-removed, proving the
	# skill would otherwise be infinitely repeatable.
	var s2 = _fresh(); var m2 = s2[0]; var caster2 = s2[1].team.characters[0]
	var loop := _mk({"name": "Loop", "target": "self", "cooldown": 0,
		"blocks": [{"op": "cooldown", "amount": -99, "skills": ["Loop"]}]}, caster2, true)
	caster2.moveset.base_abilities.append(loop)   # make it the caster's own copy, matched by name+identity
	loop.cooldown_remaining = 5                    # start_cooldown would have written this
	_cast(caster2, loop, [caster2], m2)
	_check(loop.cooldown_remaining == 5, "REVERT-FAILS: runner backstop refuses a skill's OWN-cooldown reset (still %d, not 0)" % loop.cooldown_remaining)
	# POSITIVE CONTROL: the same runner reduces a DIFFERENT owned ability with the same cast shape.
	var sibling = caster2.moveset.base_abilities[1]
	sibling.cooldown_remaining = 5
	var loop2 := _mk({"name": "LoopB", "target": "self", "cooldown": 0,
		"blocks": [{"op": "cooldown", "amount": -99, "skills": [sibling.ability_name]}]}, caster2, true)
	_cast(caster2, loop2, [caster2], m2)
	_check(sibling.cooldown_remaining == 0, "positive control: the runner DOES reset another owned skill (%d)" % sibling.cooldown_remaining)

# ---------------------------------------------------------------------------
# 4) DRAIN_ENERGY / STEAL + energy_at_least
# ---------------------------------------------------------------------------
func _probe_drain():
	print("--- drain_energy / steal / energy_at_least ---")
	# VALIDATION.
	_check(_v(_spec("Sap", "enemy", {"op": "drain_energy", "amount": 2})).is_empty(), "drain_energy amount 2 validates")
	_check(_v(_spec("Sap", "enemy", {"op": "drain_energy", "amount": 2, "steal": true})).is_empty(), "drain_energy steal validates")
	_check(not _v(_spec("Sap", "enemy", {"op": "drain_energy", "amount": 0})).is_empty(), "drain_energy amount 0 is rejected")
	_check(not _v(_spec("Sap", "enemy", {"op": "drain_energy", "amount": 99})).is_empty(), "drain_energy amount 99 (> loop guard) is rejected")
	_check(_v(_spec("Gate", "enemy", {"op": "damage", "amount": 5, "when": {"cond": "energy_at_least", "value": 2, "of": "all_enemies"}})).is_empty(),
		"energy_at_least validates in a `when`")
	_check(_v({"name": "Gate", "target": "enemy", "cooldown": 0,
		"requires": [{"cond": "energy_at_least", "value": 1}], "blocks": [{"op": "damage", "amount": 5}]}).is_empty(),
		"energy_at_least validates as a `requires` usability gate")

	# RUNTIME — TEAM-POOL DEDUPE. all_enemies drains ONE pool once per point, not once per enemy.
	# Give the enemy team 9 cash; a drain of 3 against all THREE enemies must remove 3, not 9.
	var s = _fresh(); var m = s[0]; var caster = s[1].team.characters[0]
	var foe_team = s[2].team
	foe_team.energy.change_energy(Energy.Type.GREEN, 9)
	var before := _team_cash(foe_team)
	var drain := _mk(_spec("Sap", "enemy", {"op": "drain_energy", "amount": 3, "to": "all_enemies"}), caster)
	_cast(caster, drain, foe_team.characters.duplicate(), m)
	var removed := before - _team_cash(foe_team)
	_check(removed == 3, "REVERT-FAILS: all_enemies drain removed N=3 (team-pool dedupe), not 3N=9 (removed=%d)" % removed)

	# RUNTIME — STEAL RESPECTS THE EMPTY-POOL DENIAL. Drain 5 from a pool holding only 2: the steal
	# grants exactly the 2 actually removed, never the nominal 5.
	var s2 = _fresh(); var m2 = s2[0]; var caster2 = s2[1].team.characters[0]
	var foe2 = s2[2].team
	var self2 = s2[1].team
	self2.energy.reset_pool()
	foe2.energy.reset_pool()
	foe2.energy.change_energy(Energy.Type.BLUE, 2)
	var my_before := _team_cash(self2)
	var steal := _mk(_spec("Rob", "enemy", {"op": "drain_energy", "amount": 5, "to": "target", "steal": true}), caster2)
	_cast(caster2, steal, [foe2.characters[0]], m2)
	var gained := _team_cash(self2) - my_before
	_check(_team_cash(foe2) == 0, "drain emptied the 2-energy pool")
	_check(gained == 2, "REVERT-FAILS: steal granted only the 2 ACTUALLY removed, not the nominal 5 (gained=%d)" % gained)

	# RUNTIME — energy_at_least gates on the live pool.
	var s3 = _fresh(); var m3 = s3[0]; var caster3 = s3[1].team.characters[0]; var foe3 = s3[2].team
	foe3.energy.reset_pool()
	foe3.energy.change_energy(Energy.Type.RED, 2)
	var runner := ScriptedAbilityRunnerFor(caster3, m3)
	_check(runner.check_condition_public({"cond": "energy_at_least", "value": 2, "of": "all_enemies"}), "energy_at_least true when pool == threshold")
	_check(not runner.check_condition_public({"cond": "energy_at_least", "value": 3, "of": "all_enemies"}), "energy_at_least false when pool < threshold")

# A BlockRunner bound to a caster, so a condition can be evaluated in isolation.
func ScriptedAbilityRunnerFor(caster, m) -> BlockRunner:
	var a := ScriptedAbility.new()
	a.ability_name = "Probe"
	a.user = caster
	return BlockRunner.new(a, m, caster)

# ---------------------------------------------------------------------------
# 5) else on group — ONE roll, exactly one branch
# ---------------------------------------------------------------------------
func _probe_else():
	print("--- else on group ---")
	# VALIDATION. else needs a `when` (else the branch is dead) and a non-empty list; _count_blocks
	# recurses into else (an oversized else trips the work ceiling).
	var ok := {"name": "Fork", "target": "ally", "cooldown": 0, "blocks": [
		{"op": "group", "when": {"cond": "chance", "percent": 50},
			"blocks": [{"op": "heal", "amount": 5}], "else": [{"op": "heal", "amount": 9}]}]}
	_check(_v(ok).is_empty(), "group with when + else validates")
	var no_when := {"name": "Fork", "target": "ally", "cooldown": 0, "blocks": [
		{"op": "group", "blocks": [{"op": "heal", "amount": 5}], "else": [{"op": "heal", "amount": 9}]}]}
	_check(not _v(no_when).is_empty(), "group with else but NO when is rejected (else would be dead)")
	var empty_else := {"name": "Fork", "target": "ally", "cooldown": 0, "blocks": [
		{"op": "group", "when": {"cond": "chance", "percent": 50}, "blocks": [{"op": "heal", "amount": 5}], "else": []}]}
	_check(not _v(empty_else).is_empty(), "group with an empty else is rejected")
	# _count_blocks RECURSES into else: a 45-block else pushes the whole tree over the 40 ceiling.
	var big_else: Array = []
	for _i in range(45): big_else.append({"op": "heal", "amount": 1})
	var overflow := {"name": "Fork", "target": "ally", "cooldown": 0, "blocks": [
		{"op": "group", "when": {"cond": "chance", "percent": 50}, "blocks": [{"op": "heal", "amount": 5}], "else": big_else}]}
	_check(not _v(overflow).is_empty(), "REVERT-FAILS: _count_blocks counts else — a 45-block else trips the 40-block ceiling")

	# RUNTIME — 100 SEEDED rolls, exactly one branch each. blocks -> +1 Green, else -> +1 Blue; each
	# cast adds to EXACTLY one colour, so green + blue == 100 (a double-fire would exceed 100, a
	# no-fire fall short) and both > 0 proves it is a real roll, not a constant branch.
	var s = _fresh(); var m = s[0]; var caster = s[1].team.characters[0]
	caster.team.energy.reset_pool()
	var fork := _mk({"name": "Fork", "target": "self", "cooldown": 0, "blocks": [
		{"op": "group", "when": {"cond": "chance", "percent": 50},
			"blocks": [{"op": "gain_energy", "amount": 1, "colour": "green"}],
			"else": [{"op": "gain_energy", "amount": 1, "colour": "blue"}]}]}, caster, true)
	for _i in range(100):
		_cast(caster, fork, [caster], m)
	var g := int(caster.team.energy.pool[Energy.Type.GREEN])
	var bl := int(caster.team.energy.pool[Energy.Type.BLUE])
	_check(g + bl == 100, "else fires EXACTLY one branch per roll across 100 casts (green %d + blue %d == 100)" % [g, bl])
	_check(g > 0 and bl > 0, "both branches fired across the 100 seeded rolls (green %d, blue %d)" % [g, bl])

# ---------------------------------------------------------------------------
# 6) max_uses — charges survive cleanse AND revive
# ---------------------------------------------------------------------------
func _probe_max_uses():
	print("--- max_uses ---")
	# VALIDATION.
	_check(_v({"name": "Ult", "target": "enemy", "cooldown": 0, "max_uses": 2, "blocks": [{"op": "damage", "amount": 5}]}).is_empty(),
		"max_uses 2 validates")
	_check(not _v({"name": "Ult", "target": "enemy", "cooldown": 0, "max_uses": 0, "blocks": [{"op": "damage", "amount": 5}]}).is_empty(),
		"max_uses 0 is rejected (permanently unusable)")
	_check(not _v({"name": "Ult", "target": "enemy", "cooldown": 0, "max_uses": 200, "blocks": [{"op": "damage", "amount": 5}]}).is_empty(),
		"max_uses 200 (> max_stacks) is rejected")

	# RUNTIME. Two uses, then the skill refuses. The counter mark survives a cleanse and a revive.
	var s = _fresh(); var m = s[0]; var caster = s[1].team.characters[0]; var victim = s[2].team.characters[0]
	var ult := _mk({"name": "Ult", "target": "enemy", "cooldown": 0, "max_uses": 2, "blocks": [{"op": "damage", "amount": 5}]}, caster)
	_check(_desc_text(ult).contains("Can be used 2 times per match"), "prose prints the per-match budget")
	_check(ult.extra_usable(caster), "usable before any cast (0/2)")
	_cast(caster, ult, [victim], m)
	_check(ult.extra_usable(caster), "still usable after 1 cast (1/2)")
	_cast(caster, ult, [victim], m)
	_check(not ult.extra_usable(caster), "refused after 2 casts (2/2)")

	# The counter mark is present, system + display_system, non-cleansable, remove_on_death:false.
	var counter = caster.has_effect("Uses — Ult", EffectType.Type.MARK, caster)
	_check(counter != null, "charge counter mark is present on the user")
	if counter != null:
		_check(counter.stack_count() == 2 and counter.system and counter.display_system and not counter.cleansable and not counter.remove_on_death,
			"charge mark: stacks=%d system=%s display_system=%s cleansable=%s remove_on_death=%s" % [counter.stack_count(), str(counter.system), str(counter.display_system), str(counter.cleansable), str(counter.remove_on_death)])

	# CLEANSE the user's own effects — the charge must NOT be refunded (cleansable:false).
	var cleanser := _mk({"name": "Wipe", "target": "ally", "cooldown": 0, "blocks": [{"op": "cleanse", "to": "user", "scope": "any"}]}, caster, true)
	_cast(caster, cleanser, [caster], m)
	_check(not ult.extra_usable(caster), "REVERT-FAILS: a cleanse does NOT refund the charge (still refused)")

	# KILL and REVIVE the user — the charge must NOT reset (system survives the death-cleanse,
	# remove_on_death:false survives the death itself).
	caster.instant_kill(victim, ult)
	_check(caster.dead, "user is dead before revive")
	caster.dead = false
	caster.health.set_health(50)
	_check(not ult.extra_usable(caster), "REVERT-FAILS: a revive does NOT reset the charge (still refused)")
	# POSITIVE CONTROL: a fresh caster with the same skill has full charges.
	var s2 = _fresh(); var m2 = s2[0]; var c2 = s2[1].team.characters[0]
	var ult2 := _mk({"name": "Ult", "target": "enemy", "cooldown": 0, "max_uses": 2, "blocks": [{"op": "damage", "amount": 5}]}, c2)
	_check(ult2.extra_usable(c2), "positive control: a fresh caster's copy is usable (0/2)")

# ---------------------------------------------------------------------------
# 7) cost_color_at_least — reads ability.cost()
# ---------------------------------------------------------------------------
func _probe_cost_color():
	print("--- cost_color_at_least ---")
	# VALIDATION.
	_check(_v({"name": "Gate", "target": "enemy", "cooldown": 0,
		"blocks": [{"op": "damage", "amount": 5, "when": {"cond": "cost_color_at_least", "colour": "random", "value": 1}}]}).is_empty(),
		"cost_color_at_least random 1 validates")
	_check(not _v({"name": "Gate", "target": "enemy", "cooldown": 0,
		"blocks": [{"op": "damage", "amount": 5, "when": {"cond": "cost_color_at_least", "colour": "purple", "value": 1}}]}).is_empty(),
		"cost_color_at_least with a bad colour is rejected")
	_check(not _v({"name": "Gate", "target": "enemy", "cooldown": 0,
		"blocks": [{"op": "damage", "amount": 5, "when": {"cond": "cost_color_at_least", "colour": "random", "value": 0}}]}).is_empty(),
		"cost_color_at_least value 0 is rejected (always true)")

	# RUNTIME — reads the ability's OWN resolved cost. Build a runner bound to an ability with a known
	# cost and evaluate the condition against it.
	var s = _fresh(); var m = s[0]; var caster = s[1].team.characters[0]
	var costed := ScriptedAbility.new()
	costed.ability_name = "Costed"
	costed.user = caster
	costed._cost = {0: 2, 1: 0, 2: 0, 3: 0, 4: 1}   # 2 Green, 1 Random
	var r := BlockRunner.new(costed, m, caster)
	_check(r.check_condition_public({"cond": "cost_color_at_least", "colour": "random", "value": 1}), "reads 1 Random cost as >= 1 (the Cost-Random idiom)")
	_check(r.check_condition_public({"cond": "cost_color_at_least", "colour": "green", "value": 2}), "reads 2 Green cost as >= 2")
	_check(not r.check_condition_public({"cond": "cost_color_at_least", "colour": "green", "value": 3}), "2 Green is NOT >= 3")
	# A free skill costs no Random.
	var freebie := ScriptedAbility.new(); freebie.ability_name = "Free"; freebie.user = caster
	freebie._cost = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	var r2 := BlockRunner.new(freebie, m, caster)
	_check(not r2.check_condition_public({"cond": "cost_color_at_least", "colour": "random", "value": 1}), "a costless skill reads Random < 1")

# ---------------------------------------------------------------------------
# 8) on_healing_given — rides `affected` = the healed
# ---------------------------------------------------------------------------
func _probe_healing_given():
	print("--- on_healing_given ---")
	# VALIDATION. The row exists; scope is LEGAL on it (it fires from a skill — positive control), while
	# a scope on an inert hook (on_turn_start) is still rejected.
	_check(_v({"name": "Mend", "target": "ally", "cooldown": 0, "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "trigger", "trigger": "on_healing_given", "ticks": -1,
			"then": [{"op": "damage", "amount": 3, "to": "affected"}]}}]}).is_empty(),
		"on_healing_given trigger validates")
	_check(_v({"name": "Mend", "target": "ally", "cooldown": 0, "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "trigger", "trigger": "on_healing_given", "scope": "damaging", "ticks": -1,
			"then": [{"op": "damage", "amount": 3, "to": "affected"}]}}]}).is_empty(),
		"scope IS legal on on_healing_given (it fires from a skill)")
	_check(not _v({"name": "Bad", "target": "ally", "cooldown": 0, "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "trigger", "trigger": "on_turn_start", "scope": "damaging", "ticks": -1,
			"then": [{"op": "heal", "amount": 3, "to": "holder"}]}}]}).is_empty(),
		"positive control: scope on an inert hook (on_turn_start) is still rejected")

	# RUNTIME — the healed character is `affected`. Plant the trigger on a healer, then heal an ally:
	# the payload hits the HEALED ally (context.target), not the caster.
	var s = _fresh(); var m = s[0]; var healer = s[1].team.characters[0]; var ally = s[1].team.characters[1]
	var plant := _mk({"name": "Bless", "target": "self", "cooldown": 0, "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "trigger", "trigger": "on_healing_given", "ticks": -1,
			"then": [{"op": "damage", "amount": 7, "to": "affected"}]}}]}, healer, true)
	_cast(healer, plant, [healer], m)
	ally.health.set_health(50)
	var heal := _mk({"name": "Mend", "target": "ally", "cooldown": 0, "blocks": [{"op": "heal", "amount": 10}]}, healer, true)
	_cast(healer, heal, [ally], m)
	# Net on ally: +10 heal then -7 payload damage to `affected` = 53. If `affected` mis-addressed the
	# caster (the old backwards bug) the ally would sit at 60 and the healer would be hurt instead.
	_check(ally.health.hp == 53, "on_healing_given payload hit the HEALED ally via `affected` (hp=%d, expected 53)" % ally.health.hp)
	_check(healer.health.hp == healer.health.max_hp, "the healer (the bearer) was NOT the one hit")

# ---------------------------------------------------------------------------
# 9) seal — locks out the sealed class, exempts the named skills
# ---------------------------------------------------------------------------
func _probe_seal():
	print("--- seal ---")
	# VALIDATION.
	_check(_v(_spec("Silence", "enemy", {"op": "seal", "turns": 2})).is_empty(), "bare seal (everything) validates")
	_check(_v(_spec("Silence", "enemy", {"op": "seal", "turns": 2, "classes": ["Harmful"]})).is_empty(), "seal by class validates")
	_check(_v(_spec("Silence", "enemy", {"op": "seal", "turns": 2, "skills": ["Bolt"], "exclude_skills": ["Zap"]})).is_empty(), "seal by name + exclusion validates")
	_check(not _v(_spec("Silence", "enemy", {"op": "seal", "turns": 2, "classes": ["Nonsense"]})).is_empty(), "seal with an unknown class is rejected")
	_check(not _v(_spec("Silence", "enemy", {"op": "seal", "turns": 2, "skills": [""]})).is_empty(), "seal with a blank skill name is rejected")

	# RUNTIME — class filter. Seal the enemy's Harmful skills; a Helpful skill stays usable.
	var s = _fresh(); var m = s[0]; var caster = s[1].team.characters[0]; var foe = s[2].team.characters[0]
	var foe_harm := _mk(_spec("Strike", "enemy", {"op": "damage", "amount": 5}), foe, false)     # Harmful
	var foe_help := _mk(_spec("Guard", "ally", {"op": "heal", "amount": 5}), foe, true)          # Helpful
	var sealer := _mk(_spec("Silence", "enemy", {"op": "seal", "turns": 2, "classes": ["Harmful"]}), caster)
	_cast(caster, sealer, [foe], m)
	_check(foe_harm.is_sealed_out(foe), "seal locks out the enemy's Harmful skill")
	_check(not foe_help.is_sealed_out(foe), "positive control: the Helpful skill is NOT sealed by a class:[Harmful] seal")

	# RUNTIME — name exclusion. Seal everything EXCEPT a named skill.
	var s2 = _fresh(); var m2 = s2[0]; var caster2 = s2[1].team.characters[0]; var foe2 = s2[2].team.characters[0]
	var bolt := _mk(_spec("Bolt", "enemy", {"op": "damage", "amount": 5}), foe2, false)
	var zap := _mk(_spec("Zap", "enemy", {"op": "damage", "amount": 5}), foe2, false)
	var sealer2 := _mk(_spec("Mahapadma", "enemy", {"op": "seal", "turns": 2, "exclude_skills": ["Bolt"]}), caster2)
	_cast(caster2, sealer2, [foe2], m2)
	_check(not bolt.is_sealed_out(foe2), "REVERT-FAILS: the excluded skill (Bolt) is exempt from the seal")
	_check(zap.is_sealed_out(foe2), "a non-excluded skill (Zap) is sealed by the seal-everything form")
