extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 Affliction damage to target enemy."

func split_desc():
	return [
		"Deals 20 Affliction damage to target enemy.",
	]

func execute(user, battle):
	var context = make_context(battle)
	deal_damage_to_targets(context, base_damage, DamageType.Type.AFFLICTION)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 10)

func target(user, battle):
	default_hostile_target_function(user, battle)
