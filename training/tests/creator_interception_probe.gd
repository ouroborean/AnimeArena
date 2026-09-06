extends Node

# ============================================================================
# Creator Phase B, stage 3 — INTERCEPTION AND IDENTITY:
#   `counter`.on  ·  `reflect` kind  ·  `cost_change`.mode  ·  presence `.effect`/`.by`  ·
#   the ability-level `channel` flag.
#
#   godot --headless --path <repo> res://training/tests/creator_interception_probe.tscn
#
# WHAT IS UNDER TEST, and why each case is the one that can fail
#
# 1. `counter`.on: "outgoing" — THE HAZARD. check_counter_use_effects /
#    check_counter_receive_effects (scripts/character_component.gd:1515, :1521) look exactly like
#    the wiring for this and have ZERO CALLERS repo-wide; an implementation bound to them passes
#    any smoke test that only inspects the effect. So every counter assertion here goes through
#    BattleManager.execute_ability, which is the live path: it calls Character.countered() and
#    cancels the skill at :1204. The assertion is on the VICTIM'S HP, never on the effect.
#
# 2. `reflect` — same live pass, one step later (reflect_check, :385). Two destinations, and they
#    are asserted by WHO ENDED UP HURT: a bounce must damage the attacker, a guardian pull must
#    damage the reflect's caster rather than the ally it was planted on. `charges` is asserted by
#    firing twice.
#
# 3. `cost_change`.mode — the three modes are three different EFFECT TYPES read by Ability.cost()
#    in a fixed order, so the assertion is on the resolved cost dictionary, not on the effect.
#
# 4. presence `.effect` + `.by` — they SHIP TOGETHER because the engine has one entry point
#    (has_effect(name, type, user) matches all three at once) and no name+user-without-type call.
#    The load-bearing case is two same-named marks from two different casters on one character:
#    `by: "mine"` must tell them apart and the default must not.
#
# 5. `channel` — the accumulator. The load-bearing case is that the guard is on the ACCUMULATOR:
#    a channelled skill whose applications are partly REFUSED (invulnerable target) leaves freed
#    Effect nodes in the list, and reading `.removed` off one of those aborts a live match.
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

# Direct execution, bypassing the turn machinery. Used where the block tree itself is what is
# under test and the interception pass is not.
func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _fire(caster, blocks: Array, targets: Array, m, nm := "Probe Skill", harmful := true) -> void:
	var ab := _mk({"name": nm, "target": "enemy", "blocks": blocks}, caster, harmful)
	_cast(caster, ab, targets, m)

# THE LIVE PATH, and the only way the counter/reflect groups may fire a skill.
# BattleManager.execute_ability is what a real turn calls: it runs cancel_channels, then
# `if not char.countered(self, ability)`, then reflect_check, and only then ability.execute.
# Calling ab.execute() directly would skip all three and every interception assertion below
# would pass without the feature existing.
func _use(m, caster, ab, targets: Array) -> void:
	ab.user = caster
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	m.execute_ability(ab)
	caster.used_ability = null
	caster.acted = false

func _mentions(errs: Array, needle: String) -> bool:
	for e in errs:
		if str(e).find(needle) != -1:
			return true
	return false

# A minimal valid ability spec to hang one block or one effect off.
func _spec(blocks: Array, extra := {}) -> Dictionary:
	var s := {"name": "Probe", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Harmful"], "blocks": blocks, "requires": []}
	for k in extra:
		s[k] = extra[k]
	return s


func _ready():
	print("=== creator interception probe: counter.on / reflect / cost mode / presence / channel ===")

	# =====================================================================================
	# GROUP 1 — `counter`.on: "outgoing" cancels the BEARER'S OWN next skill, through the live
	# path. Two enemies on one board: one carries an outgoing counter, the other does not. Both
	# then attack the same ally with the same skill. The assertion is the ally's HP.
	#
	# The positive control is not decoration here: it is the only thing that distinguishes "the
	# counter worked" from "the probe never managed to deal damage at all".
	# =====================================================================================
	var g1 := _fresh()
	var m1 = g1["m"]
	var planter = g1["allies"][0]
	var victim = g1["allies"][1]
	var muzzled = g1["foes"][0]
	var free_foe = g1["foes"][1]

	_fire(planter, [{"op": "apply", "to": "target", "effect": {
		"kind": "counter", "on": "outgoing", "scope": "harmful", "turns": 5,
		"name_override": "Probe Muzzle",
		"then": [{"op": "damage", "amount": 7, "to": "target"}]}}], [muzzled], m1, "Probe Muzzle")

	_check(muzzled.effects.has_any_effect("Probe Muzzle"), "the outgoing counter landed on the enemy")
	var muzzle_eff = muzzled.has_effect("Probe Muzzle", EffectType.Type.COUNTER_USE)
	_check(muzzle_eff != null, "...as a COUNTER_USE effect, not COUNTER_RECEIVE")

	var muzzled_swing := _mk({"name": "Muzzled Swing", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, muzzled)
	var free_swing := _mk({"name": "Free Swing", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, free_foe)

	var hp_before: int = victim.health.hp
	_use(m1, muzzled, muzzled_swing, [victim])
	var after_muzzled: int = victim.health.hp
	_check(after_muzzled == hp_before,
		"THE CLAIM: the muzzled enemy's attack never landed (%d -> %d)" % [hp_before, after_muzzled])
	_check(muzzled.was_countered, "...and the engine recorded it as countered")

	_use(m1, free_foe, free_swing, [victim])
	_check(victim.health.hp < after_muzzled,
		"POSITIVE CONTROL: the same skill from an unmuzzled enemy DID land (%d -> %d)" % [after_muzzled, victim.health.hp])

	# The payload runs, and `target` inside it is the character who was countered — who, on the
	# outgoing side, is the bearer themselves.
	_check(muzzled.health.hp < 100, "the counter's payload fired on the countered character (hp %d)" % muzzled.health.hp)
	_check(muzzled.has_effect("Probe Muzzle", EffectType.Type.COUNTER_USE) == null,
		"the counter was SPENT when it fired (default_counter_trigger consumed it)")

	# =====================================================================================
	# GROUP 2 — the INCOMING side is untouched, on its own board. A regression here would be
	# invisible in group 1: every counter written before this field existed omits `on`.
	# =====================================================================================
	var g2 := _fresh()
	var m2 = g2["m"]
	var guard = g2["allies"][0]
	var shielded = g2["allies"][1]
	var attacker2 = g2["foes"][0]

	_fire(guard, [{"op": "apply", "to": "target", "effect": {
		"kind": "counter", "scope": "harmful", "turns": 5, "name_override": "Probe Aegis",
		"then": [{"op": "damage", "amount": 5, "to": "target"}]}}], [shielded], m2, "Probe Aegis", false)
	_check(shielded.has_effect("Probe Aegis", EffectType.Type.COUNTER_RECEIVE) != null,
		"an `on`-less counter is still COUNTER_RECEIVE (no saved character changes meaning)")

	var swing2 := _mk({"name": "Swing Two", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, attacker2)
	var sh_before: int = shielded.health.hp
	var at_before: int = attacker2.health.hp
	_use(m2, attacker2, swing2, [shielded])
	_check(shielded.health.hp == sh_before, "the incoming counter cancelled the attack (%d)" % shielded.health.hp)
	_check(attacker2.health.hp == at_before - 5,
		"...and its payload hit the ATTACKER, who is `target` on this side (%d -> %d)" % [at_before, attacker2.health.hp])

	# =====================================================================================
	# GROUP 3 — HOSTILITY IS DATA, and `on` is what flips it. An outgoing counter is a muzzle
	# fitted to somebody, so it must go through add_hostile_effect and be refused by
	# invulnerability. An incoming one is a shield handed to somebody and must not be.
	#
	# Both halves are asserted on the SAME invulnerable character on the SAME board, which is
	# what makes the pair a test rather than two independent facts.
	# =====================================================================================
	var g3 := _fresh()
	var m3 = g3["m"]
	var caster3 = g3["allies"][0]
	var ward_mate = g3["allies"][1]
	var ward_foe = g3["foes"][0]

	_fire(caster3, [{"op": "apply", "to": "target", "effect": {"kind": "invulnerable", "turns": 5}}],
		[ward_foe], m3, "Probe Ward Foe", false)
	_fire(caster3, [{"op": "apply", "to": "target", "effect": {"kind": "invulnerable", "turns": 5}}],
		[ward_mate], m3, "Probe Ward Mate", false)
	_check(ward_foe.is_invuln(null) and ward_mate.is_invuln(null), "both wards are up")

	_fire(caster3, [{"op": "apply", "to": "target", "effect": {
		"kind": "counter", "on": "outgoing", "scope": "harmful", "turns": 5,
		"name_override": "Probe Gag", "then": [{"op": "damage", "amount": 1, "to": "target"}]}}],
		[ward_foe], m3, "Probe Gag")
	_check(not ward_foe.effects.has_any_effect("Probe Gag"),
		"THE CLAIM: an outgoing counter is refused by invulnerability (it is a hostile application)")

	_fire(caster3, [{"op": "apply", "to": "target", "effect": {
		"kind": "counter", "scope": "harmful", "turns": 5,
		"name_override": "Probe Boon", "then": [{"op": "damage", "amount": 1, "to": "target"}]}}],
		[ward_mate], m3, "Probe Boon", false)
	_check(ward_mate.effects.has_any_effect("Probe Boon"),
		"POSITIVE CONTROL: an incoming counter still lands on an invulnerable ALLY")

	# =====================================================================================
	# GROUP 4 — `reflect`, both destinations, through the live path.
	#
	# BOUNCE: the defender carries a reflect aimed at the attacker. The attacker's own skill must
	# damage the attacker and leave the defender untouched.
	# GUARDIAN: an ally carries a reflect whose destination is the applier, so a skill aimed at
	# that ally lands on whoever CAST the reflect instead. That is the shape mash4/saber3/tamaki4
	# ship, and it is the one where the two destinations give visibly different answers.
	# =====================================================================================
	var g4 := _fresh()
	var m4 = g4["m"]
	var mirror_caster = g4["allies"][0]
	var mirror_holder = g4["allies"][1]
	var puncher = g4["foes"][0]

	_fire(mirror_caster, [{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "scope": "harmful", "destination": "attacker", "charges": -1, "turns": 5,
		"name_override": "Probe Mirror"}}], [mirror_holder], m4, "Probe Mirror", false)
	_check(mirror_holder.has_effect("Probe Mirror", EffectType.Type.REFLECT_RECEIVE) != null,
		"the reflect landed as a REFLECT_RECEIVE effect")

	var punch := _mk({"name": "Probe Punch", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 18, "to": "target"}]}, puncher)
	var holder_before: int = mirror_holder.health.hp
	var puncher_before: int = puncher.health.hp
	_use(m4, puncher, punch, [mirror_holder])
	_check(mirror_holder.health.hp == holder_before,
		"THE CLAIM: the reflected skill did not hurt its original target (%d)" % mirror_holder.health.hp)
	_check(puncher.health.hp == puncher_before - 18,
		"...it hurt the ATTACKER instead (%d -> %d)" % [puncher_before, puncher.health.hp])

	# charges -1 means it stays. Fire the same skill again with a fresh cooldown state.
	var punch2 := _mk({"name": "Probe Punch Two", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 6, "to": "target"}]}, puncher)
	var puncher_mid: int = puncher.health.hp
	_use(m4, puncher, punch2, [mirror_holder])
	_check(puncher.health.hp == puncher_mid - 6,
		"charges -1: the reflect is still there on the SECOND skill (%d -> %d)" % [puncher_mid, puncher.health.hp])

	# =====================================================================================
	# GROUP 5 — reflect: `destination: "applier"` (the guardian pull) and `charges: 1`.
	# =====================================================================================
	var g5 := _fresh()
	var m5 = g5["m"]
	var guardian = g5["allies"][0]
	var protege = g5["allies"][1]
	var puncher5 = g5["foes"][0]

	_fire(guardian, [{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "scope": "harmful", "destination": "applier", "charges": 1, "turns": 5,
		"name_override": "Probe Guard"}}], [protege], m5, "Probe Guard", false)

	var protege_before: int = protege.health.hp
	var guardian_before: int = guardian.health.hp
	var jab := _mk({"name": "Probe Jab", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 14, "to": "target"}]}, puncher5)
	_use(m5, puncher5, jab, [protege])
	_check(protege.health.hp == protege_before,
		"THE CLAIM: the guarded ally took nothing (%d)" % protege.health.hp)
	_check(guardian.health.hp == guardian_before - 14,
		"...the reflect's CASTER ate it instead (%d -> %d)" % [guardian_before, guardian.health.hp])
	_check(puncher5.health.hp == 100, "...and the attacker was NOT the destination this time (%d)" % puncher5.health.hp)

	# charges 1 is consumed. The second skill must land normally.
	var jab2 := _mk({"name": "Probe Jab Two", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 9, "to": "target"}]}, puncher5)
	var protege_mid: int = protege.health.hp
	_use(m5, puncher5, jab2, [protege])
	_check(protege.health.hp == protege_mid - 9,
		"POSITIVE CONTROL: charges 1 was spent, so the next skill landed normally (%d -> %d)" % [protege_mid, protege.health.hp])

	# =====================================================================================
	# GROUP 6 — `cost_change`.mode. Three engine effects behind one kind, asserted on the
	# RESOLVED COST (Ability.cost()), which is the only place the difference is observable.
	# =====================================================================================
	var g6 := _fresh()
	var m6 = g6["m"]
	var taxman = g6["allies"][0]
	var payer = g6["allies"][1]

	var priced := _mk({"name": "Priced Skill", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 5, "to": "target"}]}, payer)
	priced._cost = {Energy.Type.GREEN: 2, Energy.Type.BLUE: 1, Energy.Type.WHITE: 0,
		Energy.Type.RED: 0, Energy.Type.RANDOM: 0}
	var base_cost: Dictionary = priced.cost()
	_check(int(base_cost[Energy.Type.GREEN]) == 2 and int(base_cost[Energy.Type.BLUE]) == 1,
		"baseline: the probe skill costs 2 Green + 1 Blue")

	# add — the historical shape, and the control the other two are measured against.
	_fire(taxman, [{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "add", "amount": 1, "colour": "green", "turns": 5,
		"skills": ["Priced Skill"], "name_override": "Probe Tax"}}], [payer], m6, "Probe Tax", false)
	_check(int(priced.cost()[Energy.Type.GREEN]) == 3,
		"mode add: +1 Green makes it 3 (got %d)" % int(priced.cost()[Energy.Type.GREEN]))
	_fire(taxman, [{"op": "remove", "to": "target", "name": "Probe Tax"}], [payer], m6, "Probe Untax", false)
	_check(int(priced.cost()[Energy.Type.GREEN]) == 2, "…and removing it puts the cost back")

	# set — OVERRIDES the whole cost. Blue must vanish, which is what distinguishes it from add.
	_fire(taxman, [{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "set", "amount": 4, "colour": "red", "turns": 5,
		"skills": ["Priced Skill"], "name_override": "Probe Reprice"}}], [payer], m6, "Probe Reprice", false)
	var set_cost: Dictionary = priced.cost()
	_check(int(set_cost[Energy.Type.RED]) == 4,
		"mode set: the new price is 4 Red (got %d)" % int(set_cost[Energy.Type.RED]))
	_check(int(set_cost[Energy.Type.GREEN]) == 0 and int(set_cost[Energy.Type.BLUE]) == 0,
		"THE CLAIM: `set` REPLACED the old cost rather than adding to it (green %d, blue %d)" % [int(set_cost[Energy.Type.GREEN]), int(set_cost[Energy.Type.BLUE])])
	_fire(taxman, [{"op": "remove", "to": "target", "name": "Probe Reprice"}], [payer], m6, "Probe Unprice", false)

	# set with amount 0 — the "free skill" shape, and the reason `set`'s amount is unsigned with a
	# legal 0 while `add`'s is signed and rejects it.
	_fire(taxman, [{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "set", "amount": 0, "colour": "red", "turns": 5,
		"skills": ["Priced Skill"], "name_override": "Probe Free"}}], [payer], m6, "Probe Free", false)
	var free_cost: Dictionary = priced.cost()
	var free_total := 0
	for k in free_cost:
		free_total += int(free_cost[k])
	_check(free_total == 0, "mode set with amount 0 makes the skill free (total %d)" % free_total)
	_fire(taxman, [{"op": "remove", "to": "target", "name": "Probe Free"}], [payer], m6, "Probe Unfree", false)

	# swap — recolours, TOTAL UNCHANGED. That invariant is the assertion, not the two numbers.
	_fire(taxman, [{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "swap", "colour": "white", "from": "green", "turns": 5,
		"skills": ["Priced Skill"], "name_override": "Probe Recolour"}}], [payer], m6, "Probe Recolour", false)
	var sw: Dictionary = priced.cost()
	var sw_total := 0
	for k in sw:
		sw_total += int(sw[k])
	_check(int(sw[Energy.Type.WHITE]) == 2 and int(sw[Energy.Type.GREEN]) == 0,
		"mode swap: the 2 Green became 2 White (white %d, green %d)" % [int(sw[Energy.Type.WHITE]), int(sw[Energy.Type.GREEN])])
	_check(sw_total == 3, "…and the TOTAL is unchanged, which is what makes it a swap (got %d)" % sw_total)

	# =====================================================================================
	# GROUP 7 — presence `.effect` + `.by`.
	#
	# THE LOAD-BEARING BOARD: one character carrying TWO marks with the SAME NAME from TWO
	# different casters. Nothing else separates `by: "mine"` from the default — with one mark on
	# the board both readings agree, and the assertion could not fail.
	# =====================================================================================
	var g7 := _fresh()
	var m7 = g7["m"]
	var mine_caster = g7["allies"][0]
	var other_caster = g7["allies"][1]
	var bearer = g7["allies"][2]
	var probe_foe = g7["foes"][0]

	# Two same-named marks, deliberately given different unique_render_ids so storage keeps them
	# apart rather than merging (add_effect dedups on name+type+USER, so two users is already
	# enough — the id is belt and braces against a future merge rule).
	_fire(other_caster, [{"op": "apply", "to": "target", "effect": {
		"kind": "mark", "turns": 9, "text": "", "name_override": "Shared Sigil",
		"unique_render_id": 2}}], [bearer], m7, "Other Sigil", false)
	_check(bearer.effects.has_any_effect("Shared Sigil"), "the OTHER caster's mark is on the bearer")

	# A condition is evaluated with the runner's own `user` as "mine", so it is asked through an
	# ability owned by each caster in turn.
	var ask_mine := {"cond": "has_effect", "name": "Shared Sigil", "effect": "MARK", "by": "mine", "on": "all_allies"}
	var ask_any := {"cond": "has_effect", "name": "Shared Sigil", "on": "all_allies"}

	var hp0: int = probe_foe.health.hp
	_fire(mine_caster, [{"op": "damage", "amount": 11, "to": "target", "when": ask_mine}],
		[probe_foe], m7, "Ask Mine A")
	_check(probe_foe.health.hp == hp0,
		"THE CLAIM: `by: mine` does not see somebody ELSE's same-named mark (%d)" % probe_foe.health.hp)

	_fire(mine_caster, [{"op": "damage", "amount": 11, "to": "target", "when": ask_any}],
		[probe_foe], m7, "Ask Any A")
	_check(probe_foe.health.hp == hp0 - 11,
		"POSITIVE CONTROL: the default reading DOES see it, on the same board (%d)" % probe_foe.health.hp)

	# Now give the first caster their own copy. `mine` must flip to true without anything else
	# on the board changing.
	_fire(mine_caster, [{"op": "apply", "to": "target", "effect": {
		"kind": "mark", "turns": 9, "text": "", "name_override": "Shared Sigil",
		"unique_render_id": 3}}], [bearer], m7, "Mine Sigil", false)
	var hp1: int = probe_foe.health.hp
	_fire(mine_caster, [{"op": "damage", "amount": 11, "to": "target", "when": ask_mine}],
		[probe_foe], m7, "Ask Mine B")
	_check(probe_foe.health.hp == hp1 - 11,
		"…and once the asker has their OWN copy, `by: mine` reads true (%d -> %d)" % [hp1, probe_foe.health.hp])

	# `.effect` narrows by TYPE. A SHIELD-typed query must not match a MARK of that name; the
	# untyped query on the same board still does.
	var ask_wrong_type := {"cond": "has_effect", "name": "Shared Sigil", "effect": "SHIELD", "on": "all_allies"}
	var hp2: int = probe_foe.health.hp
	_fire(mine_caster, [{"op": "damage", "amount": 7, "to": "target", "when": ask_wrong_type}],
		[probe_foe], m7, "Ask Type Wrong")
	_check(probe_foe.health.hp == hp2, "`effect: SHIELD` does not match a MARK of the same name")
	_fire(mine_caster, [{"op": "damage", "amount": 7, "to": "target",
		"when": {"cond": "has_effect", "name": "Shared Sigil", "effect": "MARK", "on": "all_allies"}}],
		[probe_foe], m7, "Ask Type Right")
	_check(probe_foe.health.hp == hp2 - 7, "POSITIVE CONTROL: `effect: MARK` matches it (%d)" % probe_foe.health.hp)

	# stacks_at_least: the hardcoded MARK is now a DEFAULT. A stacking non-mark effect was
	# uncountable before; the default must still count marks.
	var g7b := _fresh()
	var m7b = g7b["m"]
	var stacker = g7b["allies"][0]
	var holder7 = g7b["allies"][1]
	var foe7 = g7b["foes"][0]
	_fire(stacker, [{"op": "apply", "to": "target", "effect": {
		"kind": "shield", "amount": 4, "turns": 9, "name_override": "Probe Layer",
		"stackable": true, "stacks": 3}}], [holder7], m7b, "Probe Layer", false)
	var layer = holder7.has_effect("Probe Layer", EffectType.Type.SHIELD, stacker)
	_check(layer != null and int(layer.stack_count()) == 3, "the board is a SHIELD carrying 3 stacks")
	var hp7b: int = foe7.health.hp
	_fire(stacker, [{"op": "damage", "amount": 8, "to": "target", "when":
		{"cond": "stacks_at_least", "name": "Probe Layer", "effect": "SHIELD", "value": 3, "on": "all_allies"}}],
		[foe7], m7b, "Count Shield")
	_check(foe7.health.hp == hp7b - 8,
		"THE CLAIM: a stacking SHIELD is now countable — the MARK was a default, not the rule (%d)" % foe7.health.hp)
	var hp7bb: int = foe7.health.hp
	_fire(stacker, [{"op": "damage", "amount": 8, "to": "target", "when":
		{"cond": "stacks_at_least", "name": "Probe Layer", "effect": "SHIELD", "value": 4, "on": "all_allies"}}],
		[foe7], m7b, "Count Shield High")
	_check(foe7.health.hp == hp7bb,
		"NEGATIVE CONTROL: asking for 4 stacks of the same shield reads false (%d)" % foe7.health.hp)
	var mark_default := {"cond": "stacks_at_least", "name": "Probe Counter", "value": 2, "on": "user"}
	_fire(stacker, [{"op": "apply", "to": "user", "effect": {
		"kind": "mark", "turns": 9, "text": "", "max": 5, "stacks": 2, "name_override": "Probe Counter"}}],
		[stacker], m7b, "Probe Counter", false)
	var hp7c: int = foe7.health.hp
	_fire(stacker, [{"op": "damage", "amount": 6, "to": "target", "when": mark_default}], [foe7], m7b, "Count Mark")
	_check(foe7.health.hp == hp7c - 6,
		"POSITIVE CONTROL: with no `effect`, stacks_at_least still defaults to MARK (%d)" % foe7.health.hp)

	# =====================================================================================
	# GROUP 8 — the `channel` flag.
	#
	# A channelled skill plants a CHANNEL_CANCEL over everything it applied. Stunning the user
	# must end the lot. The positive control is the identical spec WITHOUT the flag, on the same
	# board, stunned the same way — otherwise the assertion cannot tell "the channel broke" from
	# "the effects expired".
	# =====================================================================================
	var g8 := _fresh()
	var m8 = g8["m"]
	var singer = g8["allies"][0]
	var plain = g8["allies"][1]
	var foe8 = g8["foes"][0]

	var chant := _mk({"name": "Probe Chant", "target": "enemy", "channel": "channel", "blocks": [
		{"op": "apply", "to": "target", "effect": {"kind": "damage_over_time", "amount": 5, "turns": 9,
			"name_override": "Chant Burn"}}]}, singer)
	_cast(singer, chant, [foe8], m8)
	_check(foe8.effects.has_any_effect("Chant Burn"), "the channelled skill's effect landed")
	_check(singer.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 1,
		"…and a CHANNEL_CANCEL holder was planted on the user")

	var plain_ab := _mk({"name": "Probe Plain", "target": "enemy", "blocks": [
		{"op": "apply", "to": "target", "effect": {"kind": "damage_over_time", "amount": 5, "turns": 9,
			"name_override": "Plain Burn"}}]}, plain)
	_cast(plain, plain_ab, [foe8], m8)
	_check(foe8.effects.has_any_effect("Plain Burn"), "POSITIVE CONTROL: the unflagged skill's effect landed too")
	_check(plain.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).is_empty(),
		"…and planted NO holder (the flag is what makes one)")

	# Stun both casters. check_cancels ends what a channel is holding and leaves the rest alone.
	_fire(foe8, [{"op": "apply", "to": "target", "effect": {"kind": "stun", "turns": 3}}], [singer], m8, "Probe Hush")
	_fire(foe8, [{"op": "apply", "to": "target", "effect": {"kind": "stun", "turns": 3}}], [plain], m8, "Probe Hush Two")
	singer.check_cancels()
	plain.check_cancels()
	_check(not foe8.effects.has_any_effect("Chant Burn"),
		"THE CLAIM: stunning the user ended everything the channel was holding")
	_check(foe8.effects.has_any_effect("Plain Burn"),
		"POSITIVE CONTROL: the unflagged skill's effect survived the same stun on the same board")

	# =====================================================================================
	# GROUP 9 — `control` vs `channel`: only a channel breaks when the user acts again.
	# Driven through BattleManager.execute_ability, because cancel_channels() is called from
	# there (:1202) and nowhere a probe could fake.
	# =====================================================================================
	var g9 := _fresh()
	var m9 = g9["m"]
	var ctrl_user = g9["allies"][0]
	var chan_user = g9["allies"][1]
	var foe9 = g9["foes"][0]

	var ctrl_ab := _mk({"name": "Probe Hold", "target": "enemy", "channel": "control", "blocks": [
		{"op": "apply", "to": "target", "effect": {"kind": "damage_over_time", "amount": 5, "turns": 9,
			"name_override": "Hold Burn"}}]}, ctrl_user)
	_use(m9, ctrl_user, ctrl_ab, [foe9])
	var chan_ab := _mk({"name": "Probe Sing", "target": "enemy", "channel": "channel", "blocks": [
		{"op": "apply", "to": "target", "effect": {"kind": "damage_over_time", "amount": 5, "turns": 9,
			"name_override": "Sing Burn"}}]}, chan_user)
	_use(m9, chan_user, chan_ab, [foe9])
	_check(foe9.effects.has_any_effect("Hold Burn") and foe9.effects.has_any_effect("Sing Burn"),
		"both holders' effects are on the board")

	var idle_a := _mk({"name": "Probe Idle A", "target": "enemy",
		"blocks": [{"op": "gain_energy", "amount": 1}]}, ctrl_user)
	var idle_b := _mk({"name": "Probe Idle B", "target": "enemy",
		"blocks": [{"op": "gain_energy", "amount": 1}]}, chan_user)
	_use(m9, ctrl_user, idle_a, [foe9])
	_use(m9, chan_user, idle_b, [foe9])
	_check(not foe9.effects.has_any_effect("Sing Burn"),
		"THE CLAIM: acting again broke the CHANNEL")
	_check(foe9.effects.has_any_effect("Hold Burn"),
		"POSITIVE CONTROL: it did NOT break the CONTROL, which only ends on a stun/death/banish")

	# =====================================================================================
	# GROUP 10 — HAZARD 5: the accumulator holds Effect NODES, and two ordinary outcomes free
	# one between building it and closing the channel. A skill that applies to an invulnerable
	# target AND to a legal one must not carry a corpse into the holder.
	# =====================================================================================
	var g10 := _fresh()
	var m10 = g10["m"]
	var caster10 = g10["allies"][0]
	var live_foe = g10["foes"][0]
	var ward10 = g10["foes"][1]
	_fire(caster10, [{"op": "apply", "to": "target", "effect": {"kind": "invulnerable", "turns": 5}}],
		[ward10], m10, "Probe Ward Ten", false)

	var mixed := _mk({"name": "Probe Mixed", "target": "all_enemies", "channel": "channel", "blocks": [
		{"op": "apply", "to": "target", "effect": {"kind": "damage_over_time", "amount": 4, "turns": 9,
			"name_override": "Mixed Burn"}}]}, caster10)
	_cast(caster10, mixed, [live_foe, ward10], m10)
	_check(live_foe.effects.has_any_effect("Mixed Burn"), "the legal half of the cast landed")
	_check(not ward10.effects.has_any_effect("Mixed Burn"), "the invulnerable half was refused (and its node freed)")
	var holders: Array = caster10.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL)
	_check(holders.size() == 1, "one holder was planted (got %d)" % holders.size())
	if holders.size() == 1:
		_check(holders[0].cancel_effects.size() == 1,
			"THE CLAIM: only the LIVE effect is in the holder — the freed one was filtered out (got %d)" % holders[0].cancel_effects.size())
	# And ending it must not raise. _end_cancel_effects reading `.removed` off a freed node is the
	# crash this filter exists to prevent, so run the real teardown rather than inspecting it.
	caster10.cancel_channels()
	_check(not live_foe.effects.has_any_effect("Mixed Burn"),
		"…and cancelling the channel ended it without touching a freed node")

	# A channelled skill that lands NOTHING plants no holder: a pip promising a channel with no
	# channel behind it is the same lie as an invisible required field.
	var g10b := _fresh()
	var m10b = g10b["m"]
	var caster10b = g10b["allies"][0]
	var ward10b = g10b["foes"][0]
	_fire(caster10b, [{"op": "apply", "to": "target", "effect": {"kind": "invulnerable", "turns": 5}}],
		[ward10b], m10b, "Probe Ward Ten B", false)
	var futile := _mk({"name": "Probe Futile", "target": "enemy", "channel": "channel", "blocks": [
		{"op": "apply", "to": "target", "effect": {"kind": "damage_over_time", "amount": 4, "turns": 9,
			"name_override": "Futile Burn"}}]}, caster10b)
	_cast(caster10b, futile, [ward10b], m10b)
	_check(caster10b.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).is_empty(),
		"a channelled cast that landed nothing plants no holder")

	# The payload of a channelled skill's own trigger must NOT re-plant the holder: the payload
	# runs turns later and is not part of the cast.
	var g10c := _fresh()
	var m10c = g10c["m"]
	var caster10c = g10c["allies"][0]
	var foe10c = g10c["foes"][0]
	var reactive := _mk({"name": "Probe Echo", "target": "enemy", "channel": "channel", "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "trigger", "trigger": "on_turn_start", "turns": 9,
			"name_override": "Echo Watch",
			"then": [{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 3, "text": "",
				"name_override": "Echo Mark"}}]}}]}, caster10c)
	_cast(caster10c, reactive, [foe10c], m10c)
	var before_holders: int = caster10c.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size()
	var watch = caster10c.has_effect("Echo Watch", EffectType.Type.START_OF_TURN_TRIGGER, caster10c)
	if watch != null:
		watch.trigger.check(QueryContext.from_effect_end(watch))
	_check(caster10c.effects.has_any_effect("Echo Mark"), "the trigger payload ran")
	_check(caster10c.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == before_holders,
		"THE CLAIM: the payload did NOT plant a second channel holder (%d)" % before_holders)

	# =====================================================================================
	# GROUP 11 — VALIDATOR. Every rejection paired with the acceptance it is distinguished from.
	# =====================================================================================
	# counter.on
	_check(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "counter", "on": "outgoing", "scope": "harmful", "turns": 2,
		"then": [{"op": "damage", "amount": 5}]}}])).is_empty(),
		"accepts counter on: outgoing")
	var bad_side := BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "counter", "on": "sideways", "scope": "harmful", "turns": 2,
		"then": [{"op": "damage", "amount": 5}]}}]))
	_check(_mentions(bad_side, "must be 'incoming'"), "rejects an unknown counter side")

	# reflect
	_check(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "scope": "harmful", "destination": "applier", "charges": 1, "turns": 2}}])).is_empty(),
		"accepts a fully specified reflect")
	_check(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "turns": 2}}])).is_empty(),
		"POSITIVE CONTROL: every reflect field is optional (all three have engine defaults)")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "destination": "somebody_else", "turns": 2}}])), "destination"),
		"rejects an unknown reflect destination")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "charges": 3, "turns": 2}}])), "charges"),
		"rejects charges: 3 — the engine consumes the whole reflect on its first fire")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "charges": -1, "stacks": 5, "turns": 2}}])), "stacks"),
		"rejects a universal `stacks` on a reflect — it IS the charge register")

	# cost_change modes
	_check(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "set", "amount": 0, "colour": "red", "turns": 2}}])).is_empty(),
		"accepts `set` with amount 0 (the free-skill shape)")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "add", "amount": 0, "colour": "red", "turns": 2}}])), "must not be 0"),
		"POSITIVE CONTROL: `add` still rejects amount 0 — 0 means opposite things on the two modes")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "set", "amount": -2, "colour": "red", "turns": 2}}])), "cannot be negative"),
		"rejects a negative `set` price")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "swap", "amount": 1, "colour": "red", "from": "green", "turns": 2}}])), "no amount to set"),
		"rejects an `amount` on a swap — a field that would render and do nothing")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "swap", "colour": "red", "turns": 2}}])), "colour it replaces"),
		"rejects a swap with no `from`")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "swap", "colour": "red", "from": "red", "turns": 2}}])), "for itself"),
		"rejects a swap from a colour to itself")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "mode": "add", "amount": 1, "colour": "red", "from": "green", "turns": 2}}])), "colour swap"),
		"rejects `from` on a non-swap")
	_check(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "target", "effect": {
		"kind": "cost_change", "amount": 1, "colour": "red", "turns": 2}}])).is_empty(),
		"POSITIVE CONTROL: a mode-less cost_change (every character saved before this) still validates")

	# presence pair
	_check(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "has_effect", "name": "X", "effect": "MARK", "by": "mine", "on": "user"}}])).is_empty(),
		"accepts .effect + .by together")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "has_effect", "name": "X", "by": "mine", "on": "user"}}])), "also needs an effect type"),
		"rejects `by: mine` on its own — the engine has no name+user-without-type call")
	_check(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "stacks_at_least", "name": "X", "value": 2, "by": "mine", "on": "user"}}])).is_empty(),
		"POSITIVE CONTROL: stacks_at_least takes `by` alone — its type defaults to MARK")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "has_effect", "name": "X", "effect": "NOT_A_TYPE", "on": "user"}}])), "not an effect type"),
		"rejects an effect type the enum does not have")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "has_effect", "name": "X", "effect": "MARK", "by": "everyone", "on": "user"}}])), "must be 'any'"),
		"rejects an unknown `by`")

	# channel
	_check(BlockValidator.validate_ability(_spec([{"op": "heal", "amount": 5, "to": "user"}],
		{"channel": "channel"})).is_empty(), "accepts channel: channel on an ordinary skill")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "heal", "amount": 5, "to": "user"}],
		{"channel": "sing"})), "must be 'control'"), "rejects an unknown channel mode")
	var passive_channel := _spec([{"op": "heal", "amount": 5, "to": "user"}],
		{"channel": "channel", "classes": ["Passive"], "cooldown": 0})
	_check(_mentions(BlockValidator.validate_ability(passive_channel), "a Passive cannot be 'channel'"),
		"rejects a channelled Passive — its user's first turn would cancel everything it set up")
	var passive_control := _spec([{"op": "heal", "amount": 5, "to": "user"}],
		{"channel": "control", "classes": ["Passive"], "cooldown": 0})
	_check(BlockValidator.validate_ability(passive_control).is_empty(),
		"POSITIVE CONTROL: a Passive may be 'control' — that ends only on a stun/death/banish")

	# =====================================================================================
	# GROUP 12 — PROSE. Generated prose is the contract; a block with no sentence is a tooltip
	# that lies.
	# =====================================================================================
	var pr1 := ScriptedAbility.new()
	pr1.configure({"target": "enemy", "channel": "channel", "blocks": [
		{"op": "apply", "to": "target", "effect": {"kind": "counter", "on": "outgoing",
			"scope": "harmful", "turns": 2, "then": [{"op": "damage", "amount": 5, "to": "target"}]}},
		{"op": "apply", "to": "user", "effect": {"kind": "reflect", "scope": "harmful",
			"destination": "applier", "charges": 1, "turns": 3}}]})
	pr1.ability_name = "Prose One"
	pr1.classes = {"Passive": false}
	var p1txt: String = pr1.describe(null)
	print("    prose 1: " + p1txt)
	for phrase in ["the next harmful skill the target uses is countered",
			"the next harmful skill used on the user is reflected onto the user",
			"Channeled — everything this skill applies ends if the user is stunned"]:
		_check(p1txt.find(phrase) != -1, "prose contains '%s'" % phrase)

	var pr2 := ScriptedAbility.new()
	pr2.configure({"target": "ally", "channel": "control", "blocks": [
		{"op": "apply", "to": "target", "effect": {"kind": "reflect", "scope": "harmful", "turns": 2}},
		{"op": "apply", "to": "target", "effect": {"kind": "cost_change", "mode": "set",
			"amount": 0, "colour": "red", "turns": 2}},
		{"op": "apply", "to": "target", "effect": {"kind": "cost_change", "mode": "swap",
			"colour": "white", "from": "green", "turns": 2}},
		{"op": "apply", "to": "target", "effect": {"kind": "cost_change", "mode": "set",
			"amount": 3, "colour": "blue", "turns": 2}},
		{"op": "heal", "amount": 5, "to": "target",
			"when": {"cond": "has_effect", "name": "Sigil", "effect": "MARK", "by": "mine", "on": "user"}}]})
	pr2.ability_name = "Prose Two"
	pr2.classes = {"Passive": false}
	var p2txt: String = pr2.describe(null)
	print("    prose 2: " + p2txt)
	for phrase in ["harmful skills used on the target are reflected back at whoever used it",
			"The target's skills cost no energy at all",
			"The target's skills cost White energy instead of Green",
			"The target's skills cost exactly 3 Blue energy",
			"If the user's own Sigil is present",
			"Controlled — everything this skill applies ends if the user is stunned"]:
		_check(p2txt.find(phrase) != -1, "prose contains '%s'" % phrase)

	# =====================================================================================
	# GROUP 13 — the BOT hint and the PALETTE EXPORT the editor renders from. A vocabulary that
	# does not leave the server is a control the editor cannot draw.
	# =====================================================================================
	var tag_ab := ScriptedAbility.new()
	tag_ab.configure({"target": "ally", "blocks": [{"op": "apply", "to": "target", "effect": {
		"kind": "reflect", "scope": "harmful", "turns": 2}}]})
	tag_ab.ability_name = "Tag Probe"
	tag_ab.classes = {"Passive": false}
	_check(int(tag_ab.bot_tags) & ScriptedAbility.TAG_REACTIVE != 0,
		"reflect carries the REACTIVE bit, where bake_bot_tags.py files reflect_effect")
	_check(int(tag_ab.bot_tags) & ScriptedAbility.TAG_CONTROL == 0,
		"…and NOT the CONTROL bit: a reflect re-aims the skill, it does not deny the action")

	_check(BlockSchema.EFFECT_KINDS.has("reflect"), "EFFECT_KINDS exports 'reflect'")
	_check("on" in (BlockSchema.EFFECT_KINDS["counter"]["fields"] as Array), "counter exports the `on` field")
	for f in ["mode", "from"]:
		_check(f in (BlockSchema.EFFECT_KINDS["cost_change"]["fields"] as Array), "cost_change exports `%s`" % f)
	for arg in ["effect", "by"]:
		_check(arg in (BlockSchema.CONDITIONS["has_effect"]["args"] as Array), "has_effect exports the `%s` arg" % arg)
		_check(arg in (BlockSchema.CONDITIONS["stacks_at_least"]["args"] as Array), "stacks_at_least exports the `%s` arg" % arg)
	_check(BlockSchema.COUNTER_SIDES.size() == 2 and BlockSchema.COST_MODES.size() == 3,
		"COUNTER_SIDES and COST_MODES are exported vocabularies")
	_check(BlockSchema.CHANNEL_MODES.size() == 2 and BlockSchema.CHANNEL_CLASSES.has("channel"),
		"CHANNEL_MODES + CHANNEL_CLASSES are exported")
	_check(BlockSchema.counter_side_id("outgoing") == EffectType.Type.COUNTER_USE
		and BlockSchema.counter_side_id("incoming") == EffectType.Type.COUNTER_RECEIVE,
		"counter_side_id maps both sides to the live effect types")

	# The channel CLASS is derived from the flag, so the card cannot promise a channel the skill
	# does not have. AuthoredCharacter does the deriving; assert the mapping it reads.
	_check(str(BlockSchema.CHANNEL_CLASSES["channel"]) == "Channeled"
		and str(BlockSchema.CHANNEL_CLASSES["control"]) == "Control",
		"the channel flag maps onto the engine's own class labels")

	# =====================================================================================
	# GROUP 13b — the CLASS is DERIVED from the flag, at build time. Nothing in the engine reads
	# classes["Channeled"] (battle_manager:1202 reads "Preserves Channel"), so the string is a pure
	# LABEL — which is exactly why it must be derived: a skill that prints the chip and channels
	# nothing is a card that lies. Asserted through AuthoredCharacter._build_moveset, which is the
	# function that actually writes it, rather than through the constant it reads.
	# =====================================================================================
	var built_ac := AuthoredCharacter.new()
	built_ac.spec = {"name": "Channel Probe", "id": "auth_chanprobe", "abilities": [
		{"name": "Sung", "target": "enemy", "channel": "channel",
			"blocks": [{"op": "damage", "amount": 5, "to": "target"}]},
		{"name": "Held", "target": "enemy", "channel": "control",
			"blocks": [{"op": "damage", "amount": 5, "to": "target"}]},
		{"name": "Plainly", "target": "enemy",
			"blocks": [{"op": "damage", "amount": 5, "to": "target"}]}]}
	var built: Array = built_ac._build_moveset()
	_check(built.size() == 3, "the authored moveset built (%d skills)" % built.size())
	if built.size() == 3:
		_check(bool(built[0].classes.get("Channeled", false)) and str(built[0].channel_mode) == "channel",
			"THE CLAIM: `channel: channel` derives the Channeled class AND reaches the runner")
		_check(bool(built[1].classes.get("Control", false)) and str(built[1].channel_mode) == "control",
			"…and `channel: control` derives Control")
		_check(not bool(built[2].classes.get("Channeled", false)) and not bool(built[2].classes.get("Control", false)),
			"POSITIVE CONTROL: an unflagged skill gets neither label")
		_check(str(built[2].channel_mode) == "",
			"…and no channel mode, so it plants no holder")
	built_ac.free()

	# =====================================================================================
	# GROUP 14 — THE EDITOR AUDIT. The palette drives enum CONTENTS and field LOOKUPS; it does
	# NOT drive control EXISTENCE. Per-op controls are hardcoded `else if (b.op === ...)`
	# branches and effect-kind fields render through a fixed chain of known field NAMES, so a new
	# op or a new field name renders NOTHING until somebody writes a line for it — and the field
	# is still REQUIRED by the server. The client documents that exact defect at app.js:5595
	# ("`break` was offered by the add-row but rendered no controls, so it was structurally
	# invalid the moment it was added").
	#
	# So this reads the shipped app.js and asserts a control exists for every palette entry. It is
	# a text search, not a render, and that is the honest limit of it: it proves the branch was
	# written, not that it draws the right widget. What it CANNOT do is silently pass when a
	# future field is added to the schema and forgotten in the editor, which is the failure this
	# whole phase kept warning about.
	# =====================================================================================
	var client_src := _read_text("res://webclient/app/app.js")
	_check(client_src.length() > 1000, "read the shipped client source (%d bytes)" % client_src.length())

	# Every op needs its own branch. `group` is the one that renders through a nesting block
	# rather than the else-if chain, so it is matched on either spelling.
	for op in BlockSchema.OPS.keys():
		var o := str(op)
		_check(client_src.find('b.op === "%s"' % o) != -1, "the editor has a control branch for op '%s'" % o)

	# Every FACTORY field of every effect kind needs a lookup in the field chain. `then` is the
	# exception and a real one: a payload is not a field control, it is the nested block editor,
	# keyed off the effect's KIND rather than off its field list.
	var seen := {}
	for kind in BlockSchema.EFFECT_KINDS.keys():
		for f in (BlockSchema.EFFECT_KINDS[kind]["fields"] as Array):
			seen[str(f)] = true
	for f in seen.keys():
		if str(f) == "then":
			continue
		_check(client_src.find('fields.includes("%s")' % str(f)) != -1,
			"the editor renders the effect field '%s'" % str(f))

	# The three ops whose own fields are new this phase. These do NOT go through `fields.includes`
	# — per-op controls are hand-written — so each is checked against the label it renders.
	for probe_pair in [["adjust", "turns ±"], ["adjust", "stacks ±"], ["adjust", "strength ±"],
			["repeat", "times"], ["banish", "turns"]]:
		_check(client_src.find('"%s"' % str(probe_pair[1])) != -1,
			"the editor renders %s's '%s' control" % [str(probe_pair[0]), str(probe_pair[1])])

	# The condition args. An unnamed arg falls through to a NUMBER field, which for a type name
	# and a two-value enum is simply the wrong widget — so each needs a named branch.
	for arg in ["effect", "by"]:
		_check(client_src.find('f === "%s"' % arg) != -1, "the condition editor has a branch for the '%s' arg" % arg)

	# The three palette lists the editor cannot work without, and the in-payload plumbing that
	# decides where two of them may appear.
	for key in ["payload_selectors", "pool_selectors", "scoped_triggers", "counter_sides",
			"reflect_destinations", "reflect_charges", "cost_modes", "channel_modes", "presence_by"]:
		_check(client_src.find("pal.%s" % key) != -1, "the editor consumes the '%s' palette key" % key)
	_check(client_src.find("ctx.inPayload") != -1 and client_src.find("inPayload: true") != -1,
		"the in-payload flag is threaded and set (holder/affected are offered ONLY inside a payload)")

	# THE DEPLOY MIRROR. webclient/app/app.js is the source and deploy/app.js is what is served;
	# a change that lands in one and not the other ships an editor that disagrees with the server.
	_check(client_src == _read_text("res://deploy/app.js"),
		"deploy/app.js is byte-identical to webclient/app/app.js")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s
