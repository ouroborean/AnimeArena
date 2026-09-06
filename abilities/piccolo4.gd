extends Ability

# Energy Deflection (display slot 3). Piccolo becomes Invulnerable for 1 turn. Carries "Preserves
# Channel" so using it does NOT cancel an active channel (the one skill he may use mid-channel).

func describe(user):
	return ""

func split_desc():
	return [
		"Piccolo becomes Invulnerable for 1 turn",
		["Can be used while Channeling (does not end the channel)", Color.CADET_BLUE]
	]

func execute(user, battle):
	default_defend(user, battle)   # standard 1-turn self Invulnerability

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 50)

func target(user, battle):
	default_self_target_function(user, battle)
