extends Ability

# Tensaiga. A straightforward self-Invulnerability for 1 turn.

func describe(user):
	return "Sesshomaru becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Sesshomaru becomes Invulnerable for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var inv = Effect.invuln_effect(2)   # dur 2 = 1 turn
	inv.set_source(self)
	Character.add_allied_effect(context, user, user, inv)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 25)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
