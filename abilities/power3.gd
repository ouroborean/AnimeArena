extends Ability

func describe(user):
	return "Deals 15 Bleed damage to target enemy, increased by an amount equal to all the Bleed damage effects on the enemy team."

func split_desc():
	return [
		"Deals 15 Bleed damage to target enemy",
		["Increased by the total per-turn Bleed damage on the enemy team", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var bonus = 0
	for enemy in context['enemy_team'].characters:
		if enemy.dead or enemy.banished:
			continue
		for e in enemy.effects.get_effects_by_type(EffectType.Type.DAMAGE):
			if e.damage_type == DamageType.Type.BLEED:
				bonus += e.mag
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15 + bonus, DamageType.Type.BLEED)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 15)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
