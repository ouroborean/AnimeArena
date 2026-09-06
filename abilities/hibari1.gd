extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 damage to target enemy."

func split_desc():
	return ["Deals 20 damage to target enemy"]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
