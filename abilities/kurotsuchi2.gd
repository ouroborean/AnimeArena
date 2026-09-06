extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "For 3 turns, all invisible skills and effects are revealed. During this time, Mayuri's Drug skills are empowered and he gains 1 Random energy each turn."

func split_desc():
	return [
		"For 3 turns, reveals invisible enemy effects",
		["Mayuri's Drug skills Empowered mode while active", Color.CADET_BLUE],
		["Mayuri gains 1 Random energy each turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# The mark itself is the source of truth for both the reveal hook in
	# effect_storage_component.get_effect_clusters and the Empowered check that
	# kurotsuchi3 / 7 / 8 perform via has_effect.
	var dc_mark = Effect.mark(5, "Invisible enemy effects are revealed; Drug skills are Empowered.")
	dc_mark.set_source(self)
	Character.add_allied_effect(context, user, user, dc_mark)
	user.gain_random_energy()
	var energy_trigger = Effect.trigger_effect(
		Trigger.always(energy_tick),
		EffectType.Type.TICKING_TRIGGER,
		5,
		"Mayuri gains 1 Random energy each turn."
	)
	energy_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, energy_trigger)

func energy_tick(context):
	user.gain_random_energy()

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([120, [user, self, [user]]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
