extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Adam becomes Invulnerable for 1 turn and gains 1 stack of Eye Strain."

func split_desc():
	return [
		"Adam becomes Invulnerable for 1 turn",
		["Adam gains 1 stack of Eye Strain", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	user.moveset.base_abilities[4].grant_eye_strain(user)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 40)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
