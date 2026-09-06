extends Ability

func describe(user):
	return "Shinoa becomes Invulnerable for 1 turn."

func split_desc():
	return [
		["Shinoa becomes invulnerable for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
