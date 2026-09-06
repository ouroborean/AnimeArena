extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Target enemy is Stunned and Shattered for 1 turn."

func split_desc():
	return [
		"Stuns and Shatters target enemy for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(2)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

		var shatter = Effect.def_negate(2)
		shatter.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context, 50)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
