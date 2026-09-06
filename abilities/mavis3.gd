extends Ability


func describe(user):
	return "Mavis's team ignores all damage for 1 turn, ignores negative non-damage effects for 2 turns, and gains 25 Shield for 3 turns."


func split_desc():
	return [
		"Mavis's team ignores all damage for 1 turn",
		"Mavis's team ignores negative non-damage effects for 2 turns",
		"Mavis's team gains 25 Shield for 3 turns",
	]


func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		apply_allied(context, target, Effect.ignore_damage_effect(2))
		apply_allied(context, target, Effect.ignore_non_damage_effect(4))
		apply_allied(context, target, Effect.shield_effect(25, 6))


func extra_usable(user):
	return not user.marked_by("Fairy Heart")


func custom_behavior(context):
	var variations = []
	var weight = 80
	for ally in context['ally_team'].characters:
		if ally.dead or ally.banished:
			continue
		weight += (100 - ally.health.hp) / 3
	variations.append([weight, [user, self, context['ally_team'].characters]])
	return variations


func target(user, battle):
	default_allied_target_function(user, battle)
