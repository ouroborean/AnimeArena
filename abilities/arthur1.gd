extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 damage to target enemy. Consumes any Shield from Plasmantle on Arthur and any Nullify from Nirvana on the target to increase its damage by the same amount."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["Consumes Plasmantle Shield on Arthur and Nirvana Nullify on the target, adding their value to the damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var bonus = 0
		var plasma_shield = user.effects.has_effect("Plasmantle", EffectType.Type.SHIELD, user)
		if plasma_shield:
			bonus += plasma_shield.mag
			user.effects.erase_effect(plasma_shield)
		var nirvana_nullify = target.effects.has_effect("Nirvana", EffectType.Type.BARRIER, target)
		if nirvana_nullify:
			bonus += nirvana_nullify.mag
			target.effects.erase_effect(nirvana_nullify)
		Character.resolve_damage(context, target, base_damage + bonus, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
