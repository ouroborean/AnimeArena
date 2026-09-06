extends Ability
var base_damage = 60
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 60 piercing damage to one enemy and stuns them for 1 turn. Each time Goku uses the reduced cost version of Kamehameha, this skill costs 1 less Blue energy until the next time it's used. Bypassing."

func split_desc():
	return [
		"Deals 60 Piercing damage to target enemy and Stuns them for 1 turn (Bypassing)",
		"Costs -1 Blue until next use whenever Goku uses Kamehameha with its cost reduced"
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		apply_hostile(context, target, Effect.stun_effect(2), true)
	if user.has_effect("Kamehameha", EffectType.Type.COST_MOD, user):
		for mod in user.effects.get_effects_by_type(EffectType.Type.COST_MOD):
			if mod.source.ability_name == "Kamehameha":
				user.effects.erase_effect(mod)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_stun(context, 120, true)

func target(user, battle):
	default_hostile_target_function(user, battle, true)
