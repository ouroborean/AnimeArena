extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 40 Piercing damage to target enemy (Bypasses)."

func split_desc():
	return [
		"Deals 40 Piercing damage to target enemy (Bypasses)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 40, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 70, 1.2, true)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, true)
