extends Ability

var base_damage = 0

func describe(user):
	return ""

func split_desc():
	return [""]

func execute(user, battle):
	var context = make_context(battle)
	deal_damage_to_targets(context, base_damage)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context)

func target(user, battle):
	default_hostile_target_function(user, battle)
