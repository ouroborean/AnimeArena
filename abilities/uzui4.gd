extends Ability

func describe(user):
	return "Uzui becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Tengen becomes Invulnerable for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
