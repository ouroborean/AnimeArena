extends Node

# Creator `remove` op probe.
#   godot --headless --path <repo> res://training/tests/creator_remove_probe.tscn
#
# `remove` is the mirror of `apply`: it is how an authored kit SPENDS a stack (shiro5's Ganta
# Fever) or takes an effect away (naruto1/naruto2's Sage Chakra Gather). The thing worth
# testing is not that "the effect is gone" — a bare erase_effect would pass that — but that it
# goes away through the ENGINE'S OWN teardown, because that is what fires wrapup_func and the
# shield/barrier break contingencies. So every removal assertion below is paired with an
# assertion about the side effects of the path taken.
#
# It also pins the boundary with `cleanse`: cleanse is the cleanse MECHANIC (it honours
# `cleansable`), `remove` is the author's own bookkeeping (it must not).

var fails := 0

func _check(c, l):
	if c:
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

func _mk(name: String, owner):
	var a = load("res://blocks/scripted_ability.gd").new()
	a.ability_name = name
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
	print("=== creator remove probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("BotEnemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 7, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	var me = p1.team.characters[0]
	var foe = p2.team.characters[0]
	# "target" reads the caster's live targeter — an unaimed probe silently resolves to [].
	me.targeter.targets = [foe]
	me.targeter.main_target = foe

	_test_spend(m, me)
	_test_whole(m, me)
	_test_type_filter(m, me)
	_test_no_match(m, me, foe)
	_test_shield_path(m, me)
	_test_not_cleanse(m, me)
	_test_enemy_side(m, me, foe)
	_test_descriptions()
	_test_validator()

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# =========================================================================================
# 1. Spending stacks. The whole reason the op exists.
# =========================================================================================
func _test_spend(m, me):
	print("-- spend stacks --")
	var ab = _mk("Fever", me)
	var r = _runner(ab, m, me)
	var bank := {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 9, "text": "Fever", "stacks": 3, "max": 5, "show_stacks": true}}
	r.run([bank])
	var mk = me.has_effect("Fever", EffectType.Type.MARK, me)
	_check(mk != null and mk.stack_count() == 3, "banked 3 stacks to spend")
	if mk == null:
		return
	r.run([{"op": "remove", "name": "Fever", "stacks": 1, "to": "user"}])
	_check(mk.stack_count() == 2, "spending 1 leaves 2 (got %d)" % mk.stack_count())
	_check(me.has_effect("Fever", EffectType.Type.MARK, me) != null, "...and the effect SURVIVES a partial spend")
	r.run([{"op": "remove", "name": "Fever", "stacks": 2, "to": "user"}])
	_check(me.has_effect("Fever", EffectType.Type.MARK, me) == null,
		"spending the last stacks ENDS the effect, exactly as consume_stack's own zero branch does")

	# Over-spending is explicitly NOT an error: "spend 3" with 1 left means "and that finishes it".
	r.run([bank])
	var mk2 = me.has_effect("Fever", EffectType.Type.MARK, me)
	r.run([{"op": "remove", "name": "Fever", "stacks": 99, "to": "user"}])
	_check(me.has_effect("Fever", EffectType.Type.MARK, me) == null and mk2.removed,
		"spending MORE stacks than remain just ends it")

# =========================================================================================
# 2. Whole-effect removal, and the wrapup_func that a bare erase would skip.
# =========================================================================================
func _test_whole(m, me):
	print("-- remove all --")
	var ab = _mk("Brand", me)
	var r = _runner(ab, m, me)
	r.run([{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 9, "text": "Brand"}}])
	var mk = me.has_effect("Brand", EffectType.Type.MARK, me)
	_check(mk != null, "the mark applied")
	if mk == null:
		return
	# THE point of routing through dispel_with_teardown rather than erase_effect: an effect
	# carrying a wrapup_func must have it run. erase_effect never calls it.
	var fired := [false]
	mk.wrapup_func = func(_ctx): fired[0] = true
	r.run([{"op": "remove", "name": "Brand", "to": "user"}])
	_check(me.has_effect("Brand", EffectType.Type.MARK, me) == null, "an omitted `stacks` removes the whole effect")
	_check(fired[0], "...and its wrapup_func RAN — a bare erase_effect would have skipped it")

	# Omitted vs explicit "all" are the same thing.
	r.run([{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 9, "text": "Brand"}}])
	r.run([{"op": "remove", "name": "Brand", "stacks": "all", "to": "user"}])
	_check(me.has_effect("Brand", EffectType.Type.MARK, me) == null, "an explicit stacks:'all' does the same")

# =========================================================================================
# 3. The optional type filter. Omitted = any type carrying the name.
# =========================================================================================
func _test_type_filter(m, me):
	print("-- effect-type filter --")
	var ab = _mk("Twinned", me)
	var r = _runner(ab, m, me)
	# Two effects, one NAME (via name_override), two TYPES — the exact case the filter exists
	# for, and the case add_effect's (name, type, user) dedup deliberately keeps separate.
	var mk_block := {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 9, "text": "Echo", "name_override": "Echo"}}
	var dot_block := {"op": "apply", "to": "user",
		"effect": {"kind": "damage_over_time", "amount": 5, "turns": 9, "name_override": "Echo"}}
	r.run([mk_block, dot_block])
	_check(me.has_effect("Echo", EffectType.Type.MARK, me) != null
		and me.has_effect("Echo", EffectType.Type.DAMAGE, me) != null, "two same-named effects of different types")
	r.run([{"op": "remove", "name": "Echo", "effect": "MARK", "to": "user"}])
	_check(me.has_effect("Echo", EffectType.Type.MARK, me) == null, "naming the TYPE removes that one...")
	_check(me.has_effect("Echo", EffectType.Type.DAMAGE, me) != null, "...and leaves the other alone")
	r.run([mk_block])
	r.run([{"op": "remove", "name": "Echo", "to": "user"}])
	_check(me.has_effect("Echo", EffectType.Type.MARK, me) == null
		and me.has_effect("Echo", EffectType.Type.DAMAGE, me) == null, "omitting the type takes every type with that name")

	# A hand-edited file can carry a type name the enum does not have (the validator rejects it,
	# but a file on disk never met the validator). It must remove LESS than asked, not collapse
	# into the "any type" marker and remove everything.
	r.run([mk_block, dot_block])
	r.run([{"op": "remove", "name": "Echo", "effect": "NOT_A_TYPE", "to": "user"}])
	_check(me.has_effect("Echo", EffectType.Type.MARK, me) != null
		and me.has_effect("Echo", EffectType.Type.DAMAGE, me) != null,
		"an unreadable type filter removes NOTHING rather than widening to every type")
	r.run([{"op": "remove", "name": "Echo", "to": "user"}])

# =========================================================================================
# 4. Removing what is not there. A NO-OP, never an error — "spend a stack if I have one" is
#    a legitimate thing to author and the roster writes it constantly.
# =========================================================================================
func _test_no_match(m, me, foe):
	print("-- no match --")
	var ab = _mk("Whiff", me)
	var r = _runner(ab, m, me)
	# A silent abort is the failure mode, so the block BEHIND the miss has to move something
	# observable. (This used to be `heal 0`, whose result is identical whether the block ran or
	# not, and a bare `_check(true, ...)` — neither could go red.) 6 damage can only land if
	# both no-op removes returned cleanly and the run carried on.
	me.used_ability = null
	var hp0: int = foe.health.hp
	r.run([{"op": "remove", "name": "Nothing At All", "to": "target"},
		{"op": "remove", "name": "Nothing At All", "stacks": 2, "to": "target"},
		{"op": "damage", "amount": 6, "to": "target"}])
	_check(hp0 - foe.health.hp == 6,
		"removing an absent effect (both forms) is a NO-OP: the run carried on and dealt 6 (dealt %d)" % (hp0 - foe.health.hp))

	# ...and "matched nothing" must mean nothing, not everything. A miss that widened into the
	# any-name marker would strip live effects off the target, so put one there and watch it live.
	r.run([{"op": "apply", "to": "target",
		"effect": {"kind": "mark", "turns": 9, "text": "Bystander", "name_override": "Bystander"}}])
	_check(foe.has_effect("Bystander", EffectType.Type.MARK, me) != null, "(setup) an unrelated mark is on the target")
	r.run([{"op": "remove", "name": "Nothing At All", "to": "target"}])
	_check(foe.has_effect("Bystander", EffectType.Type.MARK, me) != null,
		"...and a name that matches nothing removes NOTHING — the bystander effect survives")
	r.run([{"op": "remove", "name": "Bystander", "to": "target"}])
	foe.health.hp = foe.health.max_hp

# =========================================================================================
# 5. SHIELD: the documented trap. It must go through the BREAK path (check_effect_breaking +
#    consume), not a generic erase, or every "when my shield breaks" contingency is skipped
#    and paired state is stranded.
# =========================================================================================
func _test_shield_path(m, me):
	print("-- shield teardown --")
	var ab = _mk("Bulwark", me)
	var r = _runner(ab, m, me)
	r.run([{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 40, "turns": 9}}])
	var sh = me.has_effect("Bulwark", EffectType.Type.SHIELD, me)
	_check(sh != null and sh.mag == 40, "a 40-point shield is up")
	if sh == null:
		return
	var broke := [false]
	# check_effect_breaking calls wrapup_func — that is the hook every shipped shield
	# contingency (break_vow, gain_shield_break, break_hero, Metal Armor, Soul Gem) hangs off.
	sh.wrapup_func = func(_ctx): broke[0] = true
	r.run([{"op": "remove", "name": "Bulwark", "to": "user"}])
	_check(me.has_effect("Bulwark", EffectType.Type.SHIELD, me) == null, "`remove` took the shield down")
	_check(broke[0], "...through check_effect_breaking, so the break contingency fired")
	_check(sh.mag == 0, "...and its mag was zeroed like shatter_shields does (a raw erase leaves it at 40)")
	_check(sh.breaker == me, "...with the remover attributed as the breaker")

# =========================================================================================
# 6. remove IS NOT cleanse. `cleansable` gates the cleanse MECHANIC; it must not gate an
#    author's own bookkeeping, because the 59 shipped scripts that call remove_effect by hand
#    never consult it.
# =========================================================================================
func _test_not_cleanse(m, me):
	print("-- remove vs cleanse --")
	var ab = _mk("Anchor", me)
	var r = _runner(ab, m, me)
	var proof := {"op": "apply", "to": "user",
		"effect": {"kind": "mark", "turns": 9, "text": "Anchor", "cleansable": false}}
	r.run([proof])
	r.run([{"op": "cleanse", "to": "user", "scope": "any"}])
	_check(me.has_effect("Anchor", EffectType.Type.MARK, me) != null,
		"a cleanse-proof effect survives `cleanse` (that is what cleansable:false means)")
	r.run([{"op": "remove", "name": "Anchor", "to": "user"}])
	_check(me.has_effect("Anchor", EffectType.Type.MARK, me) == null,
		"...and `remove` takes it anyway — it is not the cleanse mechanic and must not borrow its gate")

# =========================================================================================
# 7. Enemy-side removal. remove_effect is called on ENEMY effects across the roster
#    (asta1 strips Demon-Slayer Sword off its target), so the op has to reach them.
# =========================================================================================
func _test_enemy_side(m, me, foe):
	print("-- enemy side --")
	var ab = _mk("Strip", me)
	var r = _runner(ab, m, me)
	r.run([{"op": "apply", "to": "target", "effect": {"kind": "mark", "turns": 9, "text": "Strip"}}])
	_check(foe.has_effect("Strip", EffectType.Type.MARK, me) != null, "a hostile mark landed on the target")
	r.run([{"op": "remove", "name": "Strip", "to": "target"}])
	_check(foe.has_effect("Strip", EffectType.Type.MARK, me) == null, "`remove` reaches the target's effects too")

# =========================================================================================
# 8. Generated prose. The two forms must read as two different acts.
# =========================================================================================
func _test_descriptions():
	print("-- descriptions --")
	var a = load("res://blocks/scripted_ability.gd").new()
	a.ability_name = "Bookkeeping"
	a.blocks = [{"op": "remove", "name": "Ganta Fever", "to": "user"}]
	var lines := []
	for l in a.split_desc():
		lines.append(l[0] if l is Array else str(l))
	_check("Removes Ganta Fever from the user" in lines, "whole-effect prose: %s" % str(lines))
	a.blocks = [{"op": "remove", "name": "Ganta Fever", "stacks": 1, "to": "user"}]
	lines = []
	for l in a.split_desc():
		lines.append(l[0] if l is Array else str(l))
	_check("Spends 1 stack of Ganta Fever from the user" in lines, "single-stack prose: %s" % str(lines))
	a.blocks = [{"op": "remove", "name": "Ganta Fever", "stacks": 3, "to": "all_enemies"}]
	lines = []
	for l in a.split_desc():
		lines.append(l[0] if l is Array else str(l))
	_check("Spends 3 stacks of Ganta Fever from all enemies" in lines, "plural-stack prose: %s" % str(lines))

# =========================================================================================
# 9. The safety envelope. The validator and the runtime arm must not drift.
# =========================================================================================
func _ability(blocks: Array) -> Dictionary:
	return {"name": "T", "target": "enemy", "cost": {}, "classes": ["Harmful"], "blocks": blocks}

func _test_validator():
	print("-- validator --")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "to": "user"}])).is_empty(),
		"the minimal form validates")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "effect": "MARK", "stacks": 2, "to": "user"}])).is_empty(),
		"the fully-specified form validates")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "stacks": 1, "to": "user"}])).size() > 0,
		"a missing `name` is rejected")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "   ", "to": "user"}])).size() > 0,
		"a blank `name` is rejected")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "effect": "NOT_A_TYPE"}])).size() > 0,
		"an unknown effect type is rejected")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "effect": "MISSION_TRIGGER_DAMAGE"}])).size() > 0,
		"the MISSION_TRIGGER_* family stays off the palette")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "stacks": 0}])).size() > 0,
		"stacks 0 is rejected (use the 'all' sentinel)")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "stacks": -1}])).size() > 0,
		"a negative stack count is rejected")
	var over: int = int(BlockSchema.LIMITS["max_stacks"]) + 1
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "stacks": over}])).size() > 0,
		"stacks above LIMITS.max_stacks is rejected (the mark ceiling, borrowed — not a new number)")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "stacks": "some"}])).size() > 0,
		"a bogus string sentinel is rejected")
	_check(BlockValidator.validate_ability(_ability([{"op": "remove", "name": "Fever", "count": 2}])).size() > 0,
		"an unknown field is still rejected (cleanse's `count` is not remove's `stacks`)")
	# The type vocabulary is DERIVED, not restated: the two consumers must be the same list.
	var types := BlockSchema.immunity_effects()
	_check("SHIELD" in types and "MARK" in types and "COUNTER_RECEIVE" in types,
		"the type list is the EffectType-derived one effect_immunity uses")
