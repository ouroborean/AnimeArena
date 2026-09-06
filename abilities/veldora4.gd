extends Ability

func describe(user):
	return "Veldora becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Veldora becomes Invulnerable for 1 turn.",
	]

func execute(user, battle):
	default_defend(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 30, 1.5)

func target(user, battle):
	default_self_target_function(user, battle)
