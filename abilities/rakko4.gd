extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Rakko becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Rakko becomes Invulnerable for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# No class filter = invuln to everything for the duration, matching the
	# engine's default_defend pattern (dur=2 for "1 turn").
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 50)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
