extends Ability

# Vital Strike (Green form). 20 Piercing; +10 (consuming the marker) if used the turn after Vanish.

func describe(user):
	return "Deals 20 Piercing damage to target enemy. Deals +10 damage if used the turn after Vanish."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy",
		["+10 damage if used the turn after Vanish", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dmg = 20
	if user.has_effect("Vanish", EffectType.Type.MARK, user):
		dmg = 30
		user.effects.remove_effect("Vanish", EffectType.Type.MARK, user)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, dmg, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
