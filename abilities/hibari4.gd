extends Ability

func describe(user):
	return "Hibari becomes Invulnerable for 1 turn."

func split_desc():
	return ["Hibari becomes Invulnerable for 1 turn"]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var block = Effect.invuln_effect(2)
	block.set_source(self)
	Character.add_allied_effect(context, user, user, block)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 25)

func target(user, battle):
	default_self_target_function(user, battle)
