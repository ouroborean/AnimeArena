extends Ability

var base_damage = 30

func describe(user):
	return "Deals 30 Piercing damage to all enemies. After use, Broly loses all stacks of Legendary Super Saiyan."

func split_desc():
	return [
		"Deals 30 Piercing damage to all enemies",
		["After use, Broly loses all stacks of Legendary Super Saiyan", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	user.effects.remove_effect("Legendary Super Saiyan", EffectType.Type.DAMAGE_MOD, user)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 60)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
