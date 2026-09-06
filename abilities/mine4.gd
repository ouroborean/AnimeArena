extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"Mine becomes Invulnerable for 1 turn."
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 20)

func target(user, battle):
	default_self_target_function(user, battle)
