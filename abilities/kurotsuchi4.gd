extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Permanently, the next time Mayuri would be killed, he is instead Banished for 2 turns and returns at 30 HP. This effect can only trigger once, and after it has, this skill will make him Invulnerable for 1 turn instead."

func split_desc():
	return [
		"First use: Mayuri gains Immortality. The next hit that would kill him banishes him for 2 turns and returns him at 30 HP",
		["Once triggered, this skill makes Mayuri Invulnerable for 1 turn", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# After the death-trap has been consumed, Nikushibuki retools itself into a
	# straight 1-turn Invuln push. The consumed-state mark is system-tagged so
	# nothing else cleanses it off.
	if user.marked_by("Nikushibuki"):
		var invuln = Effect.invuln_effect(3)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, user, invuln)
		return

	# Pre-consumption re-casts are no-ops — the trap is already armed and the
	# duration is permanent. Returning early just wastes the cast (matches the
	# spirit of "permanently").
	if user.has_effect("Nikushibuki", EffectType.Type.IMMORTALITY, user) != null:
		return

	# First-use setup: immortality + a DAMAGE_RECEIVE_TRIGGER that watches for
	# lethal damage. Mirrors Ban's Undead Ban pattern almost verbatim, with
	# different HP-return value and a once-only consume.
	var immortality = Effect.immortality_effect(-1)
	immortality.set_source(self)
	immortality.invisible = true
	Character.add_allied_effect(context, user, user, immortality)

	var trap = Effect.trigger_effect(
		Trigger.always(death_trigger),
		EffectType.Type.DAMAGE_RECEIVE_TRIGGER,
		-1,
		"If Mayuri falls to 1 HP, he is Banished for 2 turns and returns at 30 HP."
	)
	trap.set_source(self)
	trap.invisible = true
	Character.add_allied_effect(context, user, user, trap)

func death_trigger(context):
	if user.health.hp > 1:
		return

	# Pick a banish duration that lands Mayuri's return on the desired turn.
	# Same shape as Ban6's pattern: depends on whose turn it currently is and
	# whether Mayuri has acted yet this round.
	var duration = 4
	if user in user.battle.player.team.characters:
		if user.battle.waiting_for_turn:
			duration = 5
		else:
			duration = 6
	else:
		if user.battle.waiting_for_turn:
			duration = 6
		else:
			duration = 5
	if user.waiting:
		duration = 6
	var qc = QueryContext.from_game_state(user, user.battle)
	
	var consumed = Effect.mark(-1, "Nikushibuki has been consumed.")
	consumed.set_source(self)
	consumed.unique_render_id = 15
	consumed.cleansable = false
	Character.add_allied_effect(qc, user, user, consumed)
	
	user.banish_character(qc, user, self, duration, return_trigger)

	# Mark the trap as consumed so future casts hit the Invuln branch instead
	# of re-arming. The mark stays on Mayuri permanently; system=true keeps it
	# off most cleanse paths.
	

	# Strip the now-redundant pre-consumption effects.
	user.effects.full_remove_effect_by_type(EffectType.Type.IMMORTALITY, user)
	user.effects.full_remove_effect_by_type(EffectType.Type.DAMAGE_RECEIVE_TRIGGER, user)

func return_trigger(context):
	user.set_health_capped(30)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 60)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
