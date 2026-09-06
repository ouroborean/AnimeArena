extends Ability

func describe(user):
	return "BlackWarGreymon becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"BlackWarGreymon becomes Invulnerable for 1 turn"
	]

func execute(user, battle):
	default_defend(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 45, 1.0)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
