extends Ability

func describe(user):
	return "For 1 turn, the Thompson Sisters will ignore all harmful effects. At the end of this time, Patty will become the active Thompson Sister. If Transform: Demon Twin Guns is currently active, its target will begin wielding Liz instead."

func split_desc():
	return [
		"The Thompson Sisters become Invulnerable for 1 turn"
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
