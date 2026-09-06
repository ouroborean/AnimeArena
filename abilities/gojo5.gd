extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Gojo's skills cost 1 less Blue energy for 1 turn after he takes damage",
		["This effect can only trigger once per turn", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(six_eyes_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "After taking damage, Gojo's skills cost 1 less Blue energy for 1 turn.")
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func six_eyes_trigger(context):
	var gojo = user
	if not gojo.has_effect("Six Eyes", EffectType.Type.COST_MOD):
		var cost_mod = Effect.cost_mod_effect(-1, 2, Energy.Type.BLUE)
		cost_mod.set_source(self)
		Character.add_allied_effect(context, gojo, gojo, cost_mod)

func extra_usable(user):
	return false

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	pass
