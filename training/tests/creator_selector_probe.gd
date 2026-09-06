extends Node

# ============================================================================
# Creator PHASE F — THE SELECTOR SYSTEM. Two layers, one predicate vocabulary.
#
#   godot --headless --path <repo> res://training/tests/creator_selector_probe.tscn
#
# LAYER 1 — the ability-level ELIGIBILITY object at `target` (mode/shape/only/pick/measure/
#   bypass_invuln/exclude_self/include_dead). It FLAGS characters at target() time, so its filtered
#   set enters the whole interception pipeline — the payoff a block-level `to` filter can never reach.
# LAYER 2 — the block-level SELECTOR object at `to` (pool x where x pick x order x bypassing).
#
# WHAT EACH GROUP PROVES, and why it can fail:
#
# 1. REPRODUCTION — six shipped target() bodies (cooler5 / mars1 / alphonse2 / astolfo3 / hisoka6 /
#    jeanne4), each expressed as an eligibility object, must flag the EXACT SAME set the shipped
#    override flags on the same board. Both abilities share one `user`, so "by: mine" and the
#    override's `has_effect(..., user)` ask the same question. A mismatch is a set diff, printed.
# 2. THE PAYOFF — a FILTERED eligibility target lands in targeter.targets and is COUNTERABLE and
#    REFLECTABLE. The contrast is the pre-F hole on the SAME board: a block-level `to: any_enemy`
#    filter hitting a non-clicked enemy resolves AFTER interception, so that enemy's counter never
#    fires. Impossible-before-F is the whole point, so the hole is demonstrated, not just asserted.
# 3. LAYER 2 PICK/ORDER — pick:random returns DISTINCT characters (Fisher-Yates, no replacement);
#    pick:lowest includes TIES; order:clicked_first leads with main_target. Resolved directly through
#    BlockRunner so the assertion is on the LIST, not on damage aliasing.
# 4. GUARD BATTERY — rules 1-3, each rejection paired with the acceptance it is distinguished from.
# 5. PALETTE + BOT — the vocabularies the editor (stage 2) renders from, and the scorer that used to
#    drop an object-shaped target to single-target.
#
# The battle seed (4242) seeds battle.roll, so the random-pick assertion is reproducible.
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

# Direct execution, bypassing the turn machinery (used to apply setup effects).
func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _fire(caster, blocks: Array, targets: Array, m, nm := "Probe Skill", harmful := true) -> void:
	var ab := _mk({"name": nm, "target": "enemy", "blocks": blocks}, caster, harmful)
	_cast(caster, ab, targets, m)

# THE LIVE PATH — the only way an interception may fire. BattleManager.execute_ability runs
# countered() and reflect_check before ability.execute; calling execute() directly would skip both.
func _use(m, caster, ab, targets: Array) -> void:
	ab.user = caster
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	m.execute_ability(ab)
	caster.used_ability = null
	caster.acted = false

# Run target() on a fresh flag state and collect the characters it flagged. The `.targeted` snapshot/
# restore is exactly how _skill_pierces_invuln probes a target() body without side effects.
func _flagged(ability, user, battle) -> Array:
	var chars = battle.all_characters()
	for c in chars:
		c.targeted = false
	ability.user = user
	ability.target(user, battle)
	var out: Array = []
	for c in chars:
		if c.targeted:
			out.append(c)
	return out

func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not x in b:
			return false
	return true

func _names(list: Array) -> String:
	var out: Array = []
	for c in list:
		out.append(str(c.character_name) if "character_name" in c else str(c))
	return "[" + ", ".join(out) + "]"

func _shipped(path: String, user) -> Ability:
	var ab = load(path).new()
	ab.classes = Ability.default_classes()
	ab.ability_name = path.get_file().get_basename()
	ab.user = user
	user.moveset.add_ability(ab)
	return ab

func _mentions(errs: Array, needle: String) -> bool:
	for e in errs:
		if str(e).find(needle) != -1:
			return true
	return false

func _spec(blocks: Array, extra := {}) -> Dictionary:
	var s := {"name": "Probe", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Harmful"], "blocks": blocks, "requires": []}
	for k in extra:
		s[k] = extra[k]
	return s

# Apply a named MARK from `caster` onto `who`.
func _mark(caster, who, nm: String, m) -> void:
	_fire(caster, [{"op": "apply", "to": "target", "effect": {"kind": "mark", "turns": 9, "text": "",
		"name_override": nm}}], [who], m, "Mark " + nm, false)


func _ready():
	print("=== creator selector probe: layer 1 eligibility + layer 2 selector object ===")

	# =====================================================================================
	# GROUP 1 — REPRODUCTION. Each shipped target() body, re-expressed as an eligibility object,
	# must flag the identical set. All diffs are printed so a mismatch is legible.
	# =====================================================================================

	# --- cooler5: only Death-Chaser-marked ENEMIES ------------------------------------------------
	var g := _fresh()
	var mm = g["m"]
	var caster = g["allies"][0]
	_mark(caster, g["foes"][0], "Death Chaser", mm)
	_mark(caster, g["allies"][1], "Death Chaser", mm)   # a marked ALLY the hostile filter must ignore
	var cooler_obj := _mk({"name": "Death Chaser Obj", "target": {"mode": "enemy",
		"only": [{"cond": "has_effect", "name": "Death Chaser", "effect": "MARK", "by": "mine"}]},
		"blocks": [{"op": "damage", "amount": 5, "to": "target"}]}, caster)
	var cooler_ship := _shipped("res://abilities/cooler5.gd", caster)
	var a1 := _flagged(cooler_ship, caster, mm)
	var b1 := _flagged(cooler_obj, caster, mm)
	print("    cooler5 shipped=%s object=%s" % [_names(a1), _names(b1)])
	_check(_same_set(a1, b1) and a1.size() == 1 and a1[0] == g["foes"][0],
		"cooler5: eligibility object flags exactly the marked enemy, same as the shipped target()")

	# --- mars1: Ofuda-marked characters on EITHER side (mode everyone) ----------------------------
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	_mark(caster, g["foes"][1], "Ofuda", mm)
	_mark(caster, g["allies"][2], "Ofuda", mm)
	var mars_obj := _mk({"name": "Ofuda Obj", "target": {"mode": "everyone",
		"only": [{"cond": "has_effect", "name": "Ofuda", "effect": "MARK", "by": "mine"}]},
		"blocks": [{"op": "damage", "amount": 5, "to": "target"}]}, caster)
	var mars_ship := _shipped("res://abilities/mars1.gd", caster)
	var a2 := _flagged(mars_ship, caster, mm)
	var b2 := _flagged(mars_obj, caster, mm)
	print("    mars1 shipped=%s object=%s" % [_names(a2), _names(b2)])
	_check(_same_set(a2, b2) and a2.size() == 2,
		"mars1: mode:everyone flags the marked ally AND the marked enemy, same set")

	# --- alphonse2: allies WITHOUT a Weapon Alchemy DAMAGE_DEALT_TRIGGER --------------------------
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	_fire(caster, [{"op": "apply", "to": "target", "effect": {"kind": "trigger",
		"trigger": "on_damage_dealt", "turns": -1, "name_override": "Weapon Alchemy",
		"then": [{"op": "damage", "amount": 1, "to": "target"}]}}], [g["allies"][1]], mm, "Give WA", false)
	var alph_obj := _mk({"name": "Weapon Obj", "target": {"mode": "ally",
		"only": [{"cond": "not_has_effect", "name": "Weapon Alchemy", "effect": "DAMAGE_DEALT_TRIGGER", "by": "mine"}]},
		"blocks": [{"op": "heal", "amount": 5, "to": "target"}]}, caster, false)
	var alph_ship := _shipped("res://abilities/alphonse2.gd", caster)
	var a3 := _flagged(alph_ship, caster, mm)
	var b3 := _flagged(alph_obj, caster, mm)
	print("    alphonse2 shipped=%s object=%s" % [_names(a3), _names(b3)])
	_check(_same_set(a3, b3) and not (g["allies"][1] in b3),
		"alphonse2: not_has_effect flags every ally except the one already carrying Weapon Alchemy")

	# --- astolfo3: allies not already holding CASSEUR as IGNORE_SKILL -----------------------------
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	_fire(caster, [{"op": "apply", "to": "target", "effect": {"kind": "ignore_skill", "turns": -1,
		"name_override": "Casseur de Logistille"}}], [g["allies"][2]], mm, "Give Casseur", false)
	var ast_obj := _mk({"name": "Casseur Obj", "target": {"mode": "ally",
		"only": [{"cond": "not_has_effect", "name": "Casseur de Logistille", "effect": "IGNORE_SKILL", "by": "mine"}]},
		"blocks": [{"op": "heal", "amount": 5, "to": "target"}]}, caster, false)
	var ast_ship := _shipped("res://abilities/astolfo3.gd", caster)
	var a4 := _flagged(ast_ship, caster, mm)
	var b4 := _flagged(ast_obj, caster, mm)
	print("    astolfo3 shipped=%s object=%s" % [_names(a4), _names(b4)])
	_check(_same_set(a4, b4) and not (g["allies"][2] in b4),
		"astolfo3: the affected ally is excluded, same as the shipped 'already affected' skip")

	# --- hisoka6: pick:lowest over enemy HP, TIES INCLUDED ----------------------------------------
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	# Two enemies tied at the minimum, one healthier — the min-HP set must be BOTH tied enemies.
	g["foes"][0].health.hp = 20
	g["foes"][1].health.hp = 20
	g["foes"][2].health.hp = 80
	var his_obj := _mk({"name": "Execute Obj", "target": {"mode": "enemy", "shape": "one",
		"pick": "lowest", "measure": "hp"}, "blocks": [{"op": "damage", "amount": 5, "to": "target"}]}, caster)
	var his_ship := _shipped("res://abilities/hisoka6.gd", caster)
	var a5 := _flagged(his_ship, caster, mm)
	var b5 := _flagged(his_obj, caster, mm)
	print("    hisoka6 shipped=%s object=%s" % [_names(a5), _names(b5)])
	_check(_same_set(a5, b5) and a5.size() == 2,
		"hisoka6: pick:lowest flags BOTH tied-minimum enemies, same as the shipped scan (ties included)")
	_check(not (g["foes"][2] in b5), "…and NOT the healthier enemy (negative control)")

	# --- jeanne4: allies including the DEAD, excluding the BANISHED --------------------------------
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	g["allies"][1].dead = true              # a dead ally jeanne4 hand-flags with set_targeted
	g["allies"][2].banished = true          # a banished ally both must skip
	var jea_obj := _mk({"name": "Revive Obj", "target": {"mode": "ally", "include_dead": true},
		"blocks": [{"op": "heal", "amount": 5, "to": "target"}]}, caster, false)
	var jea_ship := _shipped("res://abilities/jeanne4.gd", caster)
	var a6 := _flagged(jea_ship, caster, mm)
	var b6 := _flagged(jea_obj, caster, mm)
	print("    jeanne4 shipped=%s object=%s" % [_names(a6), _names(b6)])
	_check(_same_set(a6, b6) and (g["allies"][1] in b6) and not (g["allies"][2] in b6),
		"jeanne4: include_dead flags the dead ally, skips the banished — same set as the shipped revive target()")
	# NEGATIVE CONTROL: without include_dead, the same object must NOT flag the dead ally.
	var jea_live := _mk({"name": "No Dead Obj", "target": {"mode": "ally"},
		"blocks": [{"op": "heal", "amount": 5, "to": "target"}]}, caster, false)
	var b6b := _flagged(jea_live, caster, mm)
	_check(not (g["allies"][1] in b6b),
		"…and include_dead is load-bearing: without it the dead ally is not eligible")

	# =====================================================================================
	# GROUP 2 — THE PAYOFF. A filtered eligibility target enters the interception pipeline and is
	# COUNTERABLE / REFLECTABLE. The contrast is the pre-F hole on the same board.
	# =====================================================================================

	# COUNTERABLE. An enemy carries a Fracture mark (the eligibility filter) AND an incoming counter.
	# The Layer-1 skill flags exactly that enemy, its target lands in targeter.targets, and the counter
	# fires through the live path.
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	var marked_foe = g["foes"][0]
	var plain_foe = g["foes"][1]
	_mark(caster, marked_foe, "Fracture", mm)
	_fire(marked_foe, [{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful",
		"turns": 9, "name_override": "Payoff Aegis",
		"then": [{"op": "damage", "amount": 3, "to": "target"}]}}], [marked_foe], mm, "Self Aegis", false)
	_check(marked_foe.has_effect("Payoff Aegis", EffectType.Type.COUNTER_RECEIVE) != null,
		"setup: the marked enemy carries an incoming counter")
	var strike := _mk({"name": "Filtered Strike", "target": {"mode": "enemy",
		"only": [{"cond": "has_effect", "name": "Fracture", "effect": "MARK", "by": "mine"}]},
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, caster)
	var flagged := _flagged(strike, caster, mm)
	_check(flagged.size() == 1 and flagged[0] == marked_foe,
		"the filtered eligibility flags exactly the marked enemy")
	var foe_hp: int = marked_foe.health.hp
	_use(mm, caster, strike, [marked_foe])
	_check(marked_foe.health.hp == foe_hp and caster.was_countered,
		"THE PAYOFF: the filtered eligibility target was COUNTERED — its target entered the pipeline (hp %d, countered %s)" % [marked_foe.health.hp, str(caster.was_countered)])
	# POSITIVE CONTROL: the same skill on a marked-but-uncountered enemy DOES land.
	_mark(caster, plain_foe, "Fracture", mm)
	var strike2 := _mk({"name": "Filtered Strike Two", "target": {"mode": "enemy",
		"only": [{"cond": "has_effect", "name": "Fracture", "effect": "MARK", "by": "mine"}]},
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, caster)
	var plain_before: int = plain_foe.health.hp
	_use(mm, caster, strike2, [plain_foe])
	_check(plain_foe.health.hp == plain_before - 20,
		"POSITIVE CONTROL: an uncountered marked enemy took the hit (%d -> %d)" % [plain_before, plain_foe.health.hp])

	# REFLECTABLE. The marked enemy carries a reflect; the filtered skill bounces back at the caster.
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	var mirror_foe = g["foes"][0]
	_mark(caster, mirror_foe, "Fracture", mm)
	_fire(mirror_foe, [{"op": "apply", "to": "user", "effect": {"kind": "reflect", "scope": "harmful",
		"destination": "attacker", "charges": -1, "turns": 9, "name_override": "Payoff Mirror"}}],
		[mirror_foe], mm, "Self Mirror", false)
	var refl := _mk({"name": "Filtered Bounce", "target": {"mode": "enemy",
		"only": [{"cond": "has_effect", "name": "Fracture", "effect": "MARK", "by": "mine"}]},
		"blocks": [{"op": "damage", "amount": 15, "to": "target"}]}, caster)
	var caster_before: int = caster.health.hp
	var mfoe_before: int = mirror_foe.health.hp
	_use(mm, caster, refl, [mirror_foe])
	_check(mirror_foe.health.hp == mfoe_before and caster.health.hp == caster_before - 15,
		"THE PAYOFF: the filtered target REFLECTED the skill back at the caster (foe %d, caster %d->%d)" % [mirror_foe.health.hp, caster_before, caster.health.hp])

	# THE PRE-F HOLE, on the same shape: a block-level `to: any_enemy` filter hitting a NON-CLICKED
	# enemy resolves AFTER interception, so that enemy's counter never fires. This is exactly what
	# Layer 1 fixes and what a block-level filter cannot.
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	var hidden_foe = g["foes"][0]     # carries the counter, but is NOT the clicked target
	var clicked_foe = g["foes"][1]
	_mark(caster, hidden_foe, "Fracture", mm)
	_fire(hidden_foe, [{"op": "apply", "to": "user", "effect": {"kind": "counter", "scope": "harmful",
		"turns": 9, "name_override": "Hole Aegis",
		"then": [{"op": "damage", "amount": 3, "to": "target"}]}}], [hidden_foe], mm, "Hole Self Aegis", false)
	var hole_ab := _mk({"name": "Block Filter", "target": "enemy", "blocks": [
		{"op": "damage", "amount": 12, "to": "any_enemy",
			"when": {"cond": "has_effect", "name": "Fracture", "effect": "MARK", "by": "mine"}}]}, caster)
	var hidden_before: int = hidden_foe.health.hp
	_use(mm, caster, hole_ab, [clicked_foe])   # clicked the OTHER enemy; the block hits the marked one
	_check(hidden_foe.health.hp == hidden_before - 12 and not caster.was_countered,
		"THE HOLE (pre-F): a block-level `to: any_enemy` hit the countering enemy WITHOUT firing its counter — its target never entered the pipeline (%d -> %d)" % [hidden_before, hidden_foe.health.hp])

	# =====================================================================================
	# GROUP 3 — LAYER 2 pick/order, resolved directly through BlockRunner so the assertion is on the
	# resolved LIST (no damage aliasing).
	# =====================================================================================
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	var runner := BlockRunner.new(_mk({"name": "Runner Host", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 1, "to": "target"}]}, caster), mm, caster)

	# pick:random, count 2 over 3 enemies — DISTINCT (Fisher-Yates, no replacement).
	var rnd: Array = runner._resolve_selector_object({"pool": "enemies", "pick": "random", "count": 2})
	_check(rnd.size() == 2 and rnd[0] != rnd[1],
		"pick:random count 2 returns TWO DISTINCT enemies (a single-roll picker could repeat) %s" % _names(rnd))
	# count above the pool size clamps to the whole pool, still distinct.
	var rnd_all: Array = runner._resolve_selector_object({"pool": "enemies", "pick": "random", "count": 9})
	var seen := {}
	for c in rnd_all: seen[c] = true
	_check(rnd_all.size() == 3 and seen.size() == 3,
		"pick:random count > pool draws the whole pool with no duplicate %s" % _names(rnd_all))

	# pick:lowest ties-included (direct resolution).
	g["foes"][0].health.hp = 15
	g["foes"][1].health.hp = 15
	g["foes"][2].health.hp = 90
	var low: Array = runner._resolve_selector_object({"pool": "enemies", "pick": "lowest", "measure": "hp"})
	_check(low.size() == 2 and (g["foes"][0] in low) and (g["foes"][1] in low) and not (g["foes"][2] in low),
		"pick:lowest includes BOTH tied-minimum members and excludes the healthier one %s" % _names(low))
	var high: Array = runner._resolve_selector_object({"pool": "enemies", "pick": "highest", "measure": "hp"})
	_check(high.size() == 1 and high[0] == g["foes"][2],
		"pick:highest picks the single healthiest %s" % _names(high))

	# order:clicked_first leads with main_target (the ONLY order that agrees with add_target).
	caster.targeter.main_target = g["foes"][2]
	var ordered: Array = runner._resolve_selector_object({"pool": "enemies", "order": "clicked_first", "pick": "all"})
	_check(ordered.size() == 3 and ordered[0] == g["foes"][2],
		"order:clicked_first leads the list with main_target (the clicked character) %s" % _names(ordered))
	# `where` filters per candidate; combined with `when` (whole-block guard) both are honoured.
	_mark(caster, g["foes"][0], "Slag", mm)
	var whered: Array = runner._resolve_selector_object({"pool": "enemies",
		"where": [{"cond": "has_effect", "name": "Slag", "effect": "MARK", "by": "mine"}], "pick": "all"})
	_check(whered.size() == 1 and whered[0] == g["foes"][0],
		"`where` keeps only the marked enemy — the same per-candidate filter `only` uses %s" % _names(whered))

	# A2 composition: an object `enemies` pool re-runs can_hostile_target, so an invulnerable enemy
	# is dropped unless the object bypasses.
	g = _fresh(); mm = g["m"]; caster = g["allies"][0]
	var host2 := _mk({"name": "Runner Host2", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 1, "to": "target"}]}, caster)
	var runner2 := BlockRunner.new(host2, mm, caster)
	_fire(caster, [{"op": "apply", "to": "target", "effect": {"kind": "invulnerable", "turns": 5}}],
		[g["foes"][0]], mm, "A2 Ward", false)
	var gated: Array = runner2._resolve_selector_object({"pool": "enemies", "pick": "all"})
	_check(not (g["foes"][0] in gated),
		"A2: an object `enemies` pool drops the invulnerable enemy (can_hostile_target is re-run) %s" % _names(gated))
	var bypassed: Array = runner2._resolve_selector_object({"pool": "enemies", "pick": "all", "bypassing": true})
	_check(g["foes"][0] in bypassed,
		"…and `bypassing: true` is the single opt-out that reaches it %s" % _names(bypassed))

	# =====================================================================================
	# GROUP 4 — GUARD BATTERY (rules 1-3). Every rejection paired with the acceptance it distinguishes.
	# =====================================================================================

	# Layer-1 object acceptance controls.
	_check(BlockValidator.validate_ability(_target_spec({"mode": "enemy",
		"only": [{"cond": "has_effect", "name": "X", "effect": "MARK", "by": "mine"}]})).is_empty(),
		"accepts a Layer-1 eligibility object with an `only` predicate")
	_check(BlockValidator.validate_ability(_target_spec({"mode": "enemy", "shape": "one",
		"pick": "lowest", "measure": "hp"})).is_empty(),
		"accepts pick:lowest + measure on an eligibility object (hisoka6)")

	# GUARD 1 — chance rejected in `only` and `where`, accepted in `when`.
	_check(_mentions(BlockValidator.validate_ability(_target_spec({"mode": "enemy",
		"only": [{"cond": "chance", "percent": 50}]})), "cannot decide eligibility"),
		"GUARD 1: rejects `chance` inside `only`")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5,
		"to": {"pool": "enemies", "where": [{"cond": "chance", "percent": 50}]}}])), "cannot pick targets"),
		"GUARD 1: rejects `chance` inside a selector `where`")
	_check(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "chance", "percent": 50}}])).is_empty(),
		"POSITIVE CONTROL: `chance` stays legal on a block `when` (evaluated once)")

	# GUARD 2 — a `to`-relative selector rejected in an eligibility `only`, accepted in a `where`.
	_check(_mentions(BlockValidator.validate_ability(_target_spec({"mode": "enemy",
		"only": [{"cond": "hp_below", "value": 40, "on": "target"}]})), "unstable while eligibility"),
		"GUARD 2: rejects `on: target` inside `only` (targeter.targets is half-built during target())")
	_check(_mentions(BlockValidator.validate_ability(_target_spec({"mode": "enemy",
		"only": [{"cond": "hp_below", "value": 40, "on": "random_enemy"}]})), "spends a roll"),
		"GUARD 2: rejects `on: random_enemy` inside `only` (a seeded roll on every re-run)")
	_check(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5,
		"to": {"pool": "enemies", "where": [{"cond": "hp_below", "value": 40, "on": "target"}]}}])).is_empty(),
		"POSITIVE CONTROL: `on: target` is fine in a `where` (it runs at execute, targeter.targets is built)")
	_check(BlockValidator.validate_ability(_target_spec({"mode": "enemy",
		"only": [{"cond": "hp_below", "value": 40, "on": "all_allies"}]})).is_empty(),
		"POSITIVE CONTROL: a FIXED pool (`on: all_allies`) is fine in `only` — deterministic during target()")

	# GUARD 3 — a selector OBJECT nested in a condition slot is rejected everywhere.
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5, "to": "target",
		"when": {"cond": "hp_below", "value": 40, "on": {"pool": "enemies"}}}])), "infinite regress"),
		"GUARD 3: a selector object inside a condition slot is rejected (infinite regress)")

	# Layer-2 object structural rejections.
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5,
		"to": {"pool": "nowhere"}}])), "pool: must be one of"),
		"rejects an unknown pool")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5,
		"to": {"pool": "enemies", "pick": "sideways"}}])), "pick: must be one of"),
		"rejects an unknown pick")
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5,
		"to": {"pool": "enemies", "pick": "all", "count": 2}}])), "only pick:random uses a count"),
		"rejects a count on pick:all (a control that would render and do nothing)")
	_check(_mentions(BlockValidator.validate_ability(_target_spec({"mode": "enemy", "pick": "random"})),
		"cannot be shown to the player"),
		"rejects pick:random on a Layer-1 eligibility object (a random highlight is unstable)")
	_check(_mentions(BlockValidator.validate_ability(_target_spec({"mode": "sideways"})), "mode: must be one of"),
		"rejects an unknown eligibility mode")

	# REMOVED CAP (owner ruling): there is no AoE product bound. Widening a skill to a whole faction
	# multiplies its damage across the enemy team — "a 100-damage AoE should be designable, it just would
	# not be approved." That total is an approver's balance call, not a cap the engine enforces, so a
	# widened heavy combo now VALIDATES. A modest AoE and an ally-side widening validate too (they always did).
	_check(BlockValidator.validate_ability(_target_spec({"mode": "enemy", "shape": "all"},
		[{"op": "damage", "amount": 30, "to": "target"}])).is_empty(),
		"a modest hostile AoE (30 × faction) validates")
	_check(BlockValidator.validate_ability(_target_spec({"mode": "enemy", "shape": "all"},
		[{"op": "damage", "amount": 9000, "to": "target"}, {"op": "damage", "amount": 9000, "to": "target"}])).is_empty(),
		"REMOVED CAP: a heavy hostile combo WIDENED to a faction now VALIDATES (balance is an approver's call)")
	_check(BlockValidator.validate_ability(_target_spec({"mode": "ally", "shape": "all"},
		[{"op": "heal", "amount": 9000, "to": "target"}])).is_empty(),
		"POSITIVE CONTROL: ally-side widening validates")

	# banish with a multi selector object is refused; a single one is accepted.
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "banish", "turns": 1,
		"to": {"pool": "enemies", "pick": "all"}}])), "banish must resolve to ONE"),
		"rejects a banish aimed at a whole-team selector object (instant win)")
	_check(BlockValidator.validate_ability(_spec([{"op": "banish", "turns": 1,
		"to": {"pool": "enemies", "pick": "random", "count": 1}}])).is_empty(),
		"POSITIVE CONTROL: banish accepts a selector object that resolves to ONE (random count 1)")

	# The legacy string filtered selector still MUST carry a `when`; the object form must NOT be forced.
	_check(_mentions(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5, "to": "any_enemy"}])),
		"needs an 'only if'"),
		"the legacy string `any_enemy` still requires a `when` (sugar, unchanged)")
	_check(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 5,
		"to": {"pool": "enemies", "where": [{"cond": "hp_above", "value": 10}]},
		"when": {"cond": "hp_below", "value": 40, "on": "user"}}])).is_empty(),
		"THE DESUGARING: an object `to` carries `where` AND a whole-block `when` — the defect Phase F closes")

	# =====================================================================================
	# GROUP 5 — the on-disk authored file still validates (KIND_ALIASES reason: re-validated on load),
	# and the palette exports every vocabulary stage 2's selector card needs.
	# =====================================================================================
	var disk := _read_text("res://authored/auth_testchar.json")
	if disk != "":
		var parsed = JSON.parse_string(disk)
		if parsed is Dictionary:
			var derrs := AuthoredRegistry.validate_character(parsed)
			_check(derrs.is_empty(), "authored/auth_testchar.json still validates after Phase F (%s)" % str(derrs))
	_check(BlockSchema.self_check().is_empty(), "BlockSchema.self_check() is still green")

	for c in ["target_object_modes", "target_shapes", "pools", "pool_gated", "pool_single",
			"picks", "orders", "measures"]:
		pass
	_check(BlockSchema.TARGET_OBJECT_MODES.size() == 4 and BlockSchema.TARGET_SHAPES == ["one", "all"],
		"TARGET_OBJECT_MODES + TARGET_SHAPES are exported vocabularies")
	_check(BlockSchema.POOLS.has("enemies") and BlockSchema.POOLS.has("dead_allies"),
		"POOLS exports the Layer-2 pool vocabulary")
	_check(BlockSchema.PICKS == ["all", "random", "lowest", "highest"] and BlockSchema.ORDERS == ["clicked_first", "pool"],
		"PICKS + ORDERS are exported")
	_check("hp" in BlockSchema.MEASURES and "missing_hp" in BlockSchema.MEASURES,
		"MEASURES is the per-character rank vocabulary")

	# =====================================================================================
	# GROUP 6 — the BOT SCORER. An object-shaped target used to fall through to single-target; the
	# ONE update reads the SIDE and whether it widened.
	# =====================================================================================
	# The fix: an object-shaped target no longer FALLS THROUGH to the single-target arm. Proven by
	# scoring IDENTICALLY to the equivalent string mode — shape:all matches all_enemies (the AoE arm),
	# and a single-target object matches "enemy" (the single arm). Before the fix both objects hit the
	# `_` branch and scored as single-target, so the shape:all count would have matched "enemy", not
	# "all_enemies".
	g = _fresh(); mm = g["m"]; var host = g["allies"][0]
	var ctx = {"owner": host, "enemy_team": g["m"].enemy.team, "ally_team": g["m"].player.team}
	var blk := [{"op": "damage", "amount": 20, "to": "target"}]
	var aoe_obj = _mk({"name": "AoE Obj", "target": {"mode": "enemy", "shape": "all"}, "blocks": blk}, host).custom_behavior(ctx)
	var aoe_str = _mk({"name": "AoE Str", "target": "all_enemies", "blocks": blk}, host).custom_behavior(ctx)
	var one_obj = _mk({"name": "One Obj", "target": {"mode": "enemy"}, "blocks": blk}, host).custom_behavior(ctx)
	var one_str = _mk({"name": "One Str", "target": "enemy", "blocks": blk}, host).custom_behavior(ctx)
	_check(aoe_obj.size() == aoe_str.size() and aoe_obj.size() != one_str.size(),
		"BOT: shape:all scores as the AoE arm — same as string all_enemies (%d), NOT single-target (%d)" % [aoe_obj.size(), one_str.size()])
	_check(one_obj.size() == one_str.size() and one_obj.size() >= 1,
		"BOT: a single-target eligibility object scores as string 'enemy' (%d), not dropped to zero" % one_obj.size())

	# =====================================================================================
	# GROUP 7 — STAGE-2 CARD OUTPUT PARITY. The selector card (webclient/app/app.js
	# creatorSelectorCard) is the only thing that authors these two objects, so the objects it
	# EMITS must be exactly the objects the validator accepts — otherwise the editor saves specs the
	# server rejects. These are the literal shapes captured from a browser render + toggle round-trip
	# of the card (both mounts), pinned here so a drift in either side is caught headlessly. The card
	# is UI; this asserts its DATA output, not its rendering.
	# The two toggle-ON seed defaults (targetStringToObject / toStringToPoolObject):
	_check(BlockValidator.validate_ability(_target_spec({"mode": "enemy", "shape": "one", "only": []})).is_empty(),
		"CARD: the ability-target 'Advanced' seed {mode:enemy,shape:one,only:[]} validates")
	_check(BlockValidator.validate_ability(_spec([{"op": "damage", "amount": 20, "damage_type": "NORMAL",
		"to": {"pool": "enemies", "where": []}}])).is_empty(),
		"CARD: the block-`to` 'Advanced' seed {pool:enemies,where:[]} validates")
	# The fully-authored card, both mounts populated (the shape the browser round-trip produced):
	_check(BlockValidator.validate_ability({"name": "Card", "cooldown": 0, "cost": {}, "classes": ["Harmful", "Damaging"],
		"requires": [],
		"target": {"mode": "enemy", "shape": "one",
			"only": [{"cond": "has_effect", "name": "Fracture", "effect": "MARK", "by": "mine"}],
			"pick": "lowest", "measure": "hp", "bypass_invuln": true},
		"blocks": [{"op": "damage", "amount": 20, "damage_type": "NORMAL",
			"to": {"pool": "enemies", "where": [{"cond": "hp_above", "value": 20}], "pick": "all", "order": "clicked_first"}}]
	}).is_empty(),
		"CARD: a fully-authored spec (eligibility object target + selector object `to`) validates end-to-end")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# A minimal ability spec whose `target` is a Layer-1 object.
func _target_spec(target_obj: Dictionary, blocks := []) -> Dictionary:
	var b = blocks if not blocks.is_empty() else [{"op": "damage", "amount": 5, "to": "target"}]
	return {"name": "TObj", "target": target_obj, "cooldown": 0, "cost": {},
		"classes": ["Harmful"], "blocks": b, "requires": []}

func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s
