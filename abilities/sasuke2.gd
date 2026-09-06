extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to all enemies",
		["Removes all Bleed and Affliction damage effects from Sasuke", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
	var to_remove = []
	for damage_eff in user.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if damage_eff.damage_type == DamageType.Type.BLEED or damage_eff.damage_type == DamageType.Type.AFFLICTION:
			to_remove.append(damage_eff)
	for eff in to_remove:
		user.effects.erase_effect(eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 50)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
