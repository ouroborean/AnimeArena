extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 Affliction damage to target enemy and applies 1 stack of Ink Splatter to both that enemy and Ichibe. Ichibe gains 5 permanent Damage Reduction for the stack applied to him."

func split_desc():
	return [
		"Deals 20 Affliction damage to target enemy.",
		["Applies 1 stack of Ink Splatter to that enemy and to Ichibe.", Color.DIM_GRAY],
		["Ichibe gains 5 permanent Shield for each stack applied to him", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ink_splatter = user.moveset.base_abilities[1]
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		ink_splatter.apply_ink_stack(context, user, target, true)
		ink_splatter.apply_self_ink_with_dr(context, user)
	ink_splatter.check_futen_unlock(context, user)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 20, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
