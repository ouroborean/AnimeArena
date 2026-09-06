extends Ability


func describe(user):
	return "Deals 40 True damage to target enemy."


func split_desc():
	return [
		"Deals 40 True damage to target enemy",
	]


func execute(user, battle):
	var context = make_context(battle)
	deal_damage_to_targets(context, 40, DamageType.Type.TRUE)


func extra_usable(user):
	return not user.marked_by("Fairy Heart")


func custom_behavior(context):
	return behavior_single_target_damage(context, 200, 1.0, true)


func target(user, battle):
	default_hostile_target_function(user, battle, true)
