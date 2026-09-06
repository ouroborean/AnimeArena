extends Ability

func describe(user):
	return "LadyDevimon becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"LadyDevimon becomes Invulnerable for 1 turn.",
	]

func execute(user, battle):
	var context = make_context(battle)
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 20, 1.3)

func target(user, battle):
	default_self_target_function(user, battle)
