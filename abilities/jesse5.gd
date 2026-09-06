extends Ability

func describe(user):
	return "Deals 75 Piercing damage to target enemy (Bypasses)"

func split_desc():
	return [
		"Deals 75 Piercing damage to target enemy (Bypasses)",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 75, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 75, 1.0, true)

func target(user, battle):
	default_hostile_target_function(user, battle, true)
