extends Node

# ============================================================================
# Block-DSL parity + safety probe.
#
# PARITY: express real, existing hand-coded abilities purely as block DATA and
# assert the authored version produces the same in-battle outcome as the
# GDScript original. If these pass, authored content is running through the same
# engine paths as shipped characters — the whole premise of the design.
#
# SAFETY: feed the validator hostile/malformed trees and assert it rejects them.
#
# Run: godot --headless --path <repo> res://training/tests/block_dsl_probe.tscn
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

var manager: BattleManager

func _fresh(team := ["naruto", "gon", "orihime"]) -> Array:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", team)
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 2024, BattleManager.MatchType.BOT)
	return [m, p1, p2]

# Build a ScriptedAbility straight from a spec (as from_database would).
func _mk(spec: Dictionary, owner) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Authored"))
	a.classes = {"Physical": false, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": false, "Harmful": true, "Helpful": false, "Instant": true, "Action": false,
		"Control": false, "Channeled": false, "Uncounterable": false, "Bypassing": false,
		"Stealthed": false, "Passive": false, "Preserves Channel": false, "Damaging": true}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)

func _ready():
	print("=== Block DSL: parity + safety ===")

	# ---------- PARITY 1: denji1 "Rip and Tear" -------------------------------
	# Hand-coded: 10 NORMAL + 10 PIERCING, then a delayed 10 BLEED next turn.
	# The two damage numbers moved 15 -> 10 in patch 2026-08-02; this replica has to track denji1
	# or the parity check stops comparing the DSL against the real ability and starts asserting a
	# stale constant. The point of the block is "authored == hand-coded", not "denji1 deals 30".
	var s1 = _fresh(); var m1 = s1[0]; var caster1 = s1[1].team.characters[0]; var victim1 = s1[2].team.characters[0]
	var authored_rip := {
		"name": "Rip and Tear (authored)", "target": "enemy", "cooldown": 1,
		"blocks": [
			{"op": "damage", "amount": 10, "damage_type": "NORMAL"},
			{"op": "damage", "amount": 10, "damage_type": "PIERCING"},
			{"op": "apply", "effect": {"kind": "damage_over_time", "amount": 10,
				"damage_type": "BLEED", "turns": 1, "delayed": true}}
		]
	}
	_check(BlockValidator.validate_ability(authored_rip).is_empty(), "authored Rip and Tear validates")
	var hp_before1 = victim1.health.hp
	_cast(caster1, _mk(authored_rip, caster1), [victim1], m1)
	_check(victim1.health.hp == hp_before1 - 20, "authored: 10+10 damage landed (%d -> %d)" % [hp_before1, victim1.health.hp])
	var bleeds := []
	for e in victim1.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if e.damage_type == DamageType.Type.BLEED: bleeds.append(e)
	_check(bleeds.size() == 1 and bleeds[0].mag == 10, "authored: 10 Bleed DoT applied")
	_check(bleeds.size() == 1 and bleeds[0].last_turn_only, "authored: Bleed is a single delayed tick (matches denji1)")

	# Same skill, hand-coded original, same battle state -> same numbers.
	var s2 = _fresh(["denji", "gon", "orihime"]); var m2 = s2[0]
	var denji = s2[1].team.characters[0]
	var victim2 = s2[2].team.characters[0]
	var real_rip = denji.moveset.base_abilities[0]
	var hp_before2 = victim2.health.hp
	_cast(denji, real_rip, [victim2], m2)
	var real_delta = hp_before2 - victim2.health.hp
	_check(real_delta == 20, "hand-coded denji1 deals the same 20 (%d)" % real_delta)
	var real_bleeds := []
	for e in victim2.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if e.damage_type == DamageType.Type.BLEED: real_bleeds.append(e)
	_check(real_bleeds.size() == 1 and real_bleeds[0].mag == 10 and real_bleeds[0].last_turn_only,
		"hand-coded denji1 Bleed matches the authored one (mag/last_turn_only)")

	# ---------- PARITY 2: conditional + self-buff ----------------------------
	var s3 = _fresh(); var m3 = s3[0]; var caster3 = s3[1].team.characters[0]; var foe3 = s3[2].team.characters[0]
	var conditional := {
		"name": "Finisher", "target": "enemy", "cooldown": 2,
		"blocks": [
			{"op": "damage", "amount": 10},
			{"op": "damage", "amount": 25, "when": {"cond": "hp_below", "value": 60, "on": "target"}},
			{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 20, "turns": 2}}
		]
	}
	_check(BlockValidator.validate_ability(conditional).is_empty(), "conditional ability validates")
	foe3.health.hp = 100
	_cast(caster3, _mk(conditional, caster3), [foe3], m3)
	_check(foe3.health.hp == 90, "condition FALSE at 100hp -> only 10 damage (got %d)" % foe3.health.hp)
	_check(caster3.get_shield_effects().size() == 1, "self-shield applied via 'to: user'")
	foe3.health.hp = 50
	_cast(caster3, caster3.moveset.abilities[caster3.moveset.abilities.size()-1], [foe3], m3)
	_check(foe3.health.hp == 15, "condition TRUE at 50hp -> 10+25 damage (got %d)" % foe3.health.hp)

	# ---------- PARITY 3: reactive (trigger payload is itself blocks) --------
	var s4 = _fresh(); var m4 = s4[0]; var caster4 = s4[1].team.characters[0]; var foe4 = s4[2].team.characters[0]
	var reactive := {
		"name": "Thorns", "target": "self", "cooldown": 3,
		"blocks": [
			{"op": "apply", "to": "user", "effect": {"kind": "reactive",
				"trigger": "on_harmful_received", "turns": 2, "text": "Retaliates.",
				"then": [ {"op": "damage", "amount": 12, "to": "target"} ]}}
		]
	}
	_check(BlockValidator.validate_ability(reactive).is_empty(), "reactive ability validates")
	_cast(caster4, _mk(reactive, caster4), [caster4], m4)
	var installed = caster4.effects.get_effects_by_type(EffectType.Type.HARMFUL_RECEIVE_TRIGGER)
	_check(installed.size() == 1, "reactive trigger installed on the user")
	# Trip it: the enemy hits the caster with a harmful skill.
	var foe_hp_before = foe4.health.hp
	foe4.used_ability = foe4.moveset.base_abilities[0]
	foe4.targeter.targets = [caster4]
	foe4.targeter.main_target = caster4
	caster4.check_harmful_receive_triggers(m4, foe4.used_ability)
	_check(foe4.health.hp == foe_hp_before - 12,
		"reactive payload ran and hit the attacker for 12 (%d -> %d)" % [foe_hp_before, foe4.health.hp])

	# ---------- generated description + bot hint ----------------------------
	var gen := _mk(authored_rip, s1[1].team.characters[1])
	var segs = gen.split_desc()
	_check(segs.size() >= 3, "split_desc auto-generated %d segments" % segs.size())
	print("        -> " + str(segs))
	_check(gen.bot_damage_hint() == 30, "bot_damage_hint derived from blocks = %d (10+10+10)" % gen.bot_damage_hint())
	_check(gen.custom_behavior(QueryContext.from_game_state(s1[1].team.characters[1], m1)).size() > 0,
		"custom_behavior produced bot variations (authored chars are visible to the AI)")

	# ---------- SAFETY: the validator is the security boundary ---------------
	var hostile := [
		[{"name":"X","blocks":[{"op":"exec_shell","cmd":"rm -rf /"}]}, "unknown op rejected"],
		[{"name":"X","blocks":[{"op":"damage","amount":999999}]}, "absurd damage rejected"],
		[{"name":"X","blocks":[{"op":"damage","amount":10,"to":"everyone_everywhere"}]}, "unknown selector rejected"],
		[{"name":"X","blocks":[{"op":"apply","effect":{"kind":"instant_win","turns":1}}]}, "unknown effect kind rejected"],
		[{"name":"X","blocks":[{"op":"damage","amount":10,"script":"payload"}]}, "unexpected field rejected"],
		[{"name":"","blocks":[{"op":"damage","amount":5}]}, "missing name rejected"],
		[{"name":"X","blocks":[]}, "empty ability rejected"],
		[{"name":"X","cost":{"0":99},"blocks":[{"op":"damage","amount":5}]}, "absurd cost rejected"],
	]
	for pair in hostile:
		_check(not BlockValidator.validate_ability(pair[0]).is_empty(), "SAFETY: " + str(pair[1]))
	# NO DURATION CEILING (owner Ruling 1 — durations are author-controlled, including permanent). A
	# large or -1 duration is NOT rejected: the game already ships infinite-duration ticking effects,
	# so the validator must not invent a cap. (This replaced the old "absurd duration rejected" case,
	# which asserted the opposite of the shipped ruling.)
	_check(BlockValidator.validate_ability({"name":"X","target":"enemy","classes":["Harmful"],"blocks":[{"op":"apply","to":"target","effect":{"kind":"mark","turns":9999}}]}).is_empty(),
		"SAFETY: a large duration VALIDATES (no invented duration ceiling — Ruling 1)")
	_check(BlockValidator.validate_ability({"name":"X","target":"enemy","classes":["Harmful"],"blocks":[{"op":"apply","to":"target","effect":{"kind":"mark","turns":-1}}]}).is_empty(),
		"SAFETY: a permanent (-1) duration VALIDATES")
	# A deeply self-nesting tree must be refused rather than run.
	var deep := {"name":"Deep","blocks":[]}
	var cur := {"op":"group","blocks":[]}
	deep["blocks"] = [cur]
	for i in range(10):
		var nxt := {"op":"group","blocks":[]}
		cur["blocks"] = [nxt]
		cur = nxt
	cur["blocks"] = [{"op":"damage","amount":5}]
	_check(not BlockValidator.validate_ability(deep).is_empty(), "SAFETY: over-nested tree rejected")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
