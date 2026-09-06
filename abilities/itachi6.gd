extends Ability


func describe(user):
	return "Target ally gains 30 Shield for 1 turn (Invisible). Each time they receive a Harmful skill during this time, Itachi gains 1 Red energy."


func split_desc():
	return [
		"Target ally gains 30 Shield for 1 turn (Invisible)",
		["Each Harmful skill they receive while shielded gives Itachi 1 Red energy", Color.CADET_BLUE],
	]


func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		var shield = Effect.shield_effect(30, 2)
		shield.invisible = true
		apply_allied(context, target, shield)

		var trig = Effect.trigger_effect(
			Trigger.always(yata_trigger),
			EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
			2,
			"Itachi gains 1 Red energy each time this character receives a Harmful skill.")
		trig.invisible = true
		apply_allied(context, target, trig)


func yata_trigger(context):
	var itachi = context['effect'].user
	if itachi.dead or itachi.banished:
		return
	itachi.gain_bonus_energy(Energy.Type.RED)


func extra_usable(user):
	return true


func custom_behavior(context):
	return behavior_single_target_helpful(context, 35)


func target(user, battle):
	default_allied_target_function(user, battle)
