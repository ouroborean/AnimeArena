extends Node

# Creator (block authoring) bug-fix probe.
#   godot --headless --path <repo> res://training/tests/creator_bugfix_probe.tscn
#
# 1. A damage block inside a REACTIVE payload was a silent no-op: Character.resolve_damage returns
#    immediately when owner.used_ability is null (scripts/character_component.gd:2112), and in a
#    reactive it always is. _op_heal borrowed used_ability to work around this; _op_damage did not.
# 2. _op_heal's restore LEAKED — when it borrowed (prev == null) it re-assigned the borrowed value
#    instead of clearing it, leaving a stale used_ability on the character.
# 3. Authored MARKs were not stackable, so `stacks_at_least` could never be satisfied.
# 4. ScriptedAbility had no `bot_tags`, so bot_policy.get_bot_tags() fell through and every authored
#    ability scored 0 on every semantic feature.

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

func _ready():
	print("=== creator bugfix probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("BotEnemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	var me = p1.team.characters[0]
	var foe = p2.team.characters[0]

	# =====================================================================================
	# 1 + 2. A damage block in a reactive payload must actually deal damage, and must not
	#        leave a stale used_ability behind.
	# =====================================================================================
	var runner = load("res://blocks/block_runner.gd").new(_fake_ability(), m, me)
	runner.set_explicit_targets([foe])
	me.used_ability = null                       # exactly the reactive situation
	var hp_before: int = foe.health.hp
	runner.run([{"op": "damage", "amount": 25, "to": "target"}])
	_check(foe.health.hp < hp_before,
		"a damage block with no used_ability DEALS DAMAGE (%d -> %d)" % [hp_before, foe.health.hp])
	_check(me.used_ability == null,
		"...and the borrowed used_ability was put back to null (got %s)" % str(me.used_ability))

	# The heal side of the same borrow must not leak either.
	me.used_ability = null
	me.health.hp = maxi(me.health.hp - 40, 1)
	var heal_before: int = me.health.hp
	runner.run([{"op": "heal", "amount": 20, "to": "user"}])
	_check(me.health.hp > heal_before, "a heal block with no used_ability HEALS (%d -> %d)" % [heal_before, me.health.hp])
	_check(me.used_ability == null, "...and heal restored used_ability to null too (this used to leak)")

	# A pre-existing used_ability must be left exactly as found, not clobbered.
	var real_ab = me.moveset.base_abilities[0]
	me.used_ability = real_ab
	runner.run([{"op": "damage", "amount": 5, "to": "target"}])
	_check(me.used_ability == real_ab, "an EXISTING used_ability is preserved, not overwritten")

	# =====================================================================================
	# 3. An authored mark must stack, or stacks_at_least is unreachable.
	#    A mark accumulates up to the ceiling it DECLARES. `max` did not exist when this
	#    probe was written, so it asserted the interim behaviour (every mark stacked
	#    without bound); an undeclared mark now refreshes at 1 instead, which is checked
	#    below. Both halves matter: unbounded accumulation on a mark nobody declared as a
	#    resource is a balance hole, and no accumulation at all is the original bug.
	# =====================================================================================
	var mark_block = {"op": "apply", "effect": {"kind": "mark", "turns": 5, "text": "Tally", "max": 4}, "to": "user"}
	runner.run([mark_block])
	runner.run([mark_block])
	runner.run([mark_block])
	var mk = me.has_effect("Authored Test", EffectType.Type.MARK, me)
	if mk == null:
		# effect_name() is the source ability's name; find it by type instead.
		var marks = me.effects.get_effects_by_type(EffectType.Type.MARK)
		mk = marks[0] if marks.size() > 0 else null
	_check(mk != null, "the authored mark applied")
	if mk != null:
		_check(mk.stackable, "the authored mark is STACKABLE (it is a counter by design)")
		_check(mk.stack_count() >= 3, "three applications stacked to >= 3 (got %d)" % mk.stack_count())
		_check(runner._check_condition({"cond": "stacks_at_least", "name": mk.effect_name(), "value": 3, "on": "user"}),
			"...so stacks_at_least(3) is now satisfiable — it never could be before")
		runner.run([mark_block])
		_check(mk.stack_count() == 4, "a fourth application stops at the declared max of 4 (got %d)" % mk.stack_count())

	# An UNDECLARED mark (no `max`) is not a resource: re-casting refreshes it at 1
	# rather than quietly banking stacks the author never asked for.
	var plain_ab = _fake_ability()
	plain_ab.ability_name = "Plain Tag"
	var plain_runner = load("res://blocks/block_runner.gd").new(plain_ab, m, me)
	var plain_block = {"op": "apply", "effect": {"kind": "mark", "turns": 5, "text": "Tag"}, "to": "user"}
	plain_runner.run([plain_block])
	plain_runner.run([plain_block])
	var plain_mk = me.has_effect("Plain Tag", EffectType.Type.MARK, me)
	_check(plain_mk != null and plain_mk.stack_count() == 1,
		"an undeclared mark stays at 1 stack across re-casts (got %s)" % (str(plain_mk.stack_count()) if plain_mk else "absent"))
	_check(plain_mk != null and not plain_mk.display_stacks,
		"...and does not show a pointless '1' pip counter")

	# =====================================================================================
	# 4. bot_tags must be derived from the blocks.
	# =====================================================================================
	var SA = load("res://blocks/scripted_ability.gd")
	var a = SA.new()
	a.blocks = [
		{"op": "heal", "amount": 10, "to": "user"},
		{"op": "apply", "effect": {"kind": "shield", "amount": 20, "turns": 2}, "to": "user"},
		{"op": "apply", "effect": {"kind": "mark", "turns": 3, "text": "x"}, "to": "target"},
		{"op": "apply", "effect": {"kind": "reactive", "trigger": "on_damage_received", "turns": 3,
			"then": [{"op": "apply", "effect": {"kind": "damage_boost", "amount": 5, "turns": 2}, "to": "user"}]}, "to": "user"},
	]
	var tags: int = a.bot_tags
	_check(tags != 0, "an authored ability reports a non-zero bot_tags mask (%d)" % tags)
	_check(tags & SA.TAG_HEAL != 0, "  HEAL bit set from the heal block")
	_check(tags & SA.TAG_MITIGATE != 0, "  MITIGATE bit set from the shield")
	_check(tags & SA.TAG_MARK != 0, "  MARK bit set from the mark")
	_check(tags & SA.TAG_REACTIVE != 0, "  REACTIVE bit set from the reactive")
	_check(tags & SA.TAG_AMPLIFY != 0, "  AMPLIFY bit set from the reactive's NESTED damage_boost payload")
	_check(tags & SA.TAG_CONTROL == 0, "  CONTROL stays clear — this tree has no action-denial block")
	var empty = SA.new()
	empty.blocks = []
	_check(int(empty.bot_tags) == 0, "an empty ability reports 0 (the safe fall-through)")
	a.free()
	empty.free()

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# A minimal stand-in for the ScriptedAbility that owns a run: block_runner only needs a name and a
# classes dictionary off it, plus identity as the effect source.
func _fake_ability():
	var SA = load("res://blocks/scripted_ability.gd")
	var a = SA.new()
	a.ability_name = "Authored Test"
	a.blocks = []
	add_child(a)
	return a
