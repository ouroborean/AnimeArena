extends Ability

var base_damage = 35

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 35 damage to one enemy. For 1 turn, this skill costs 1 blue energy and deals 15 less damage, then resets back to its original cost and damage."

func split_desc():
	return [
		"Deals 35 damage to target enemy",
		"Costs 1 less Blue and gets -15 damage for 1 turn"
	]

func execute(user, battle):
	var context = make_context(battle)
	var damage_type = DamageType.Type.NORMAL

	if user.marked_by("Kaioken x20", user):
		damage_type = DamageType.Type.PIERCING
		Character.resolve_effect_damage(context, user.has_effect("Kaioken x20", EffectType.Type.MARK, user), user, 5, DamageType.Type.AFFLICTION)

	deal_damage_to_targets(context, base_damage, damage_type)
	if user.has_effect("Kamehameha", EffectType.Type.DAMAGE_MOD, user):
		apply_allied(context, user, Effect.cost_mod_effect(-1, -1, Energy.Type.BLUE, ["Spirit Bomb"]))
	else:
		apply_allied(context, user, Effect.cost_change_effect({Energy.Type.BLUE: 1}, 3, ["Kamehameha"]))
		apply_allied(context, user, Effect.damage_mod_effect(-15, 3, ["Kamehameha"]))

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 65, 0.9)

func target(user, battle):
	default_hostile_target_function(user, battle)
