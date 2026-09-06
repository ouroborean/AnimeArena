extends Node

# Regression probe for three crashes reported from the deployed server.
#   godot --headless --path <repo> res://training/tests/server_crash_regress_probe.tscn
#
# 1. ryohei4.extreme_trigger dereferenced a null MARK. Effect.mark leaves cleansable at its default
#    true, while trigger_effect sets cleansable = (dur >= 0) — so a permanent trigger is cleanse-proof
#    and outlives its own accumulator. inuyasha3 buff-strips and then damages on the very next line.
# 2. cancel_effects held Effect Nodes that were queue_free()d because their application was rejected
#    or merged, so reading `.removed` off them raised "previously freed".
# 3. ryohei4.extra_usable keyed on the MARK, so a strip (or Vongola Headgear creating the same mark)
#    either allowed a SECOND permanent trigger or locked the skill out for the match.

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
	for c in p.team.characters:
		c.bot_character = true
	return p

func _cast(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.used_ability = ab
	ab.execute(caster, m)
	return ab

func _ready():
	print("=== server crash regression probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["ryohei", "kitara", "gray"], false)
	var p2 = _build_player("BotEnemy", ["inuyasha", "naruto", "sasuke"], true)
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false

	var ryohei = p1.team.characters[0]
	var kitara = p1.team.characters[1]
	var inuyasha = p2.team.characters[0]

	# =====================================================================================
	# 1 + 3. Ryohei: buff-strip splits the mark from the permanent trigger.
	# =====================================================================================
	_cast(m, ryohei, 3, [ryohei])                      # To the Extreme!!
	var mark0 = ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei)
	var trig0 = ryohei.has_effect("To the Extreme!!", EffectType.Type.DAMAGE_RECEIVE_TRIGGER, ryohei)
	_check(mark0 != null and trig0 != null, "S4 installs both the accumulator MARK and the permanent trigger")
	_check(mark0.cleansable and not trig0.cleansable,
		"the pair really is split by cleansable (mark %s / trigger %s) — this is the whole bug"
			% [str(mark0.cleansable), str(trig0.cleansable)])

	# The exact deployed sequence: inuyasha3 cleanses the target, then damages it on the next line.
	ryohei.effects.cleanse_all_ally_effects(ryohei, inuyasha)
	_check(ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei) == null,
		"the buff-strip takes the MARK...")
	_check(ryohei.has_effect("To the Extreme!!", EffectType.Type.DAMAGE_RECEIVE_TRIGGER, ryohei) != null,
		"...and leaves the cleanse-proof TRIGGER behind")

	# Before the fix this raised "Invalid access to property or key 'mag' on a base object of type 'Nil'".
	var ctx = QueryContext.from_game_state(inuyasha, m)
	inuyasha.used_ability = inuyasha.moveset.base_abilities[0]
	var hp_before = ryohei.health.hp
	Character.resolve_damage(ctx, ryohei, 10, DamageType.Type.NORMAL)
	_check(ryohei.health.hp < hp_before, "taking damage after the strip does not crash")
	var rebuilt = ryohei.has_effect("To the Extreme!!", EffectType.Type.MARK, ryohei)
	_check(rebuilt != null, "the trigger rebuilt its accumulator instead of dying")
	_check(int(rebuilt.stacks) == 0,
		"...at ZERO stacks — the strip legitimately took the earned progress (got %d)" % int(rebuilt.stacks))
	_check(int(rebuilt.mag) == 10, "...and it counted the rebuilding hit (%d/20)" % int(rebuilt.mag))
	# ...and the 20-damage threshold still banks a stack afterwards.
	Character.resolve_damage(ctx, ryohei, 15, DamageType.Type.NORMAL)
	_check(int(rebuilt.stacks) == 1 and int(rebuilt.mag) == 5,
		"crossing 20 still banks a stack after the rebuild (%d stacks, %d/20)" % [int(rebuilt.stacks), int(rebuilt.mag)])

	# extra_usable must key on the TRIGGER: recasting would otherwise stack a second permanent one.
	_check(not ryohei.moveset.base_abilities[3].extra_usable(ryohei),
		"S4 stays UNUSABLE while the trigger lives, so a strip cannot buy a second one")
	var trig_count := 0
	for e in ryohei.effects.get_effects_by_type(EffectType.Type.DAMAGE_RECEIVE_TRIGGER):
		if String(e.effect_name()) == "To the Extreme!!":
			trig_count += 1
	_check(trig_count == 1, "exactly one permanent trigger is installed (got %d)" % trig_count)

	# =====================================================================================
	# 2. A cancel list holding an effect whose application was rejected / merged.
	# =====================================================================================
	# Kitara's channel appends each DoT to `cancels` BEFORE applying it. Make the target Invulnerable
	# so add_hostile_effect REFUSES the DoT: _free_unapplied_effect queue_free()s the node while the
	# cancel list still points at it. (The merge path frees a node the same way, but kitara1's DoT is
	# not stackable, so a recast stores a duplicate instead — rejection is the reachable one here.)
	var inv = Effect.invuln_effect(4)
	inv.set_source(inuyasha.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(inuyasha, m), inuyasha, inuyasha, inv)
	_check(inuyasha.is_invuln(kitara.moveset.base_abilities[0]), "the channel target is Invulnerable")
	_cast(m, kitara, 0, [inuyasha])
	# LET THE FRAME END. queue_free is DEFERRED, so within the casting frame the rejected node is
	# still readable and `.removed` would not fault — which is exactly why the deployed crash only
	# shows up on a LATER turn. Without this await the test passes even with the guard removed.
	await get_tree().process_frame
	await get_tree().process_frame
	var freed := 0
	var dangling := 0
	for cancel in kitara.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL):
		for eff in cancel.cancel_effects:
			dangling += 1
			if not is_instance_valid(eff):
				freed += 1
	_check(dangling > 0, "the cancel list holds an entry for the refused DoT (%d)" % dangling)
	_check(freed > 0, "...and after the frame ends that entry is REALLY freed (%d)" % freed)
	# Before the fix this raised "'removed' on a base object of type 'previously freed'".
	#
	# MEASURED, not assumed: a GDScript runtime error of this kind does NOT abort the function — the
	# bad read yields null and execution continues, so the teardown below still completes and the
	# damage is log spam rather than broken state. The assertions here therefore lock the PRECONDITION
	# (a really-freed entry does reach the cancel list) and that the teardown finishes; the error line
	# itself is only visible in stderr, so the regression signal for this one is:
	#     godot --headless --path . res://training/tests/server_crash_regress_probe.tscn 2>&1 	#       | grep "previously freed"
	# which must print NOTHING. Removing the is_instance_valid guard makes it print twice.
	var before_cc: int = kitara.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size()
	_check(before_cc > 0, "a channel cancel is installed before the teardown (%d)" % before_cc)
	kitara.cancel_channels()
	_check(kitara.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 0,
		"cancel_channels ran to completion despite the freed entry (%d cancels left)"
			% kitara.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size())
	# check_cancels walks the same lists and must survive the same way.
	_cast(m, kitara, 0, [inuyasha])
	await get_tree().process_frame
	await get_tree().process_frame
	kitara.check_cancels(true)
	_check(kitara.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 0,
		"check_cancels ran to completion too (%d cancels left)"
			% kitara.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size())

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
