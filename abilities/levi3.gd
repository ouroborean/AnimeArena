extends Ability

# Humanity's Strongest — 40 Piercing damage to one enemy.

var base_damage = 40

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 40 Piercing damage to target enemy",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 75)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
