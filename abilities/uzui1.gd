extends Ability

func describe(user):
	return "Deals 20 Piercing damage to target enemy and removes one random energy from them."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy",
		["Removes one random energy from them", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.PIERCING)
		target.lose_energy(user, 1)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
