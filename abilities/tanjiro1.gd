extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tanjiro deals 20 piercing damage to an enemy. Swaps with 'Tenth Form: Constant Flux'."

func split_desc():
	return [
		"Deals 20 Piercing damage to one enemy",
		["Swaps with Tenth Form: Constant Flux", Color.AQUA]
	]

func execute(user, battle):
	var context = make_context(battle)
	deal_damage_to_targets(context, base_damage, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context)

func target(user, battle):
	default_hostile_target_function(user, battle)
