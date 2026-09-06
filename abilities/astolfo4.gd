extends Ability

# Akhilleus Kosmos. "Cannot be stunned or countered" is handled by the Unstunnable + Uncounterable
# classes + stunnable:false in abilities_data.json (checked by is_stunned / countered).

func describe(user):
	return "Astolfo becomes Invulnerable for 1 turn. This skill cannot be stunned or countered."

func split_desc():
	return [
		"Astolfo becomes Invulnerable for 1 turn",
		["Cannot be stunned or countered", Color.CADET_BLUE]
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
