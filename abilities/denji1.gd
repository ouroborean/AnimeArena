extends Ability

func describe(user):
	return "Deals 15 damage and 15 Piercing damage to target enemy. That enemy takes 10 Bleed damage on the following turn."

func split_desc():
	return [
		"Deals 10 damage and 10 Piercing damage to target enemy",
		["The target takes 10 Bleed damage next turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		Character.resolve_damage(context, target, 10, DamageType.Type.PIERCING)
		#Bleed rider unchanged: dur 3 + last_turn_only == a single tick next turn.
		var bleed = Effect.damage_effect(10, DamageType.Type.BLEED, 3)
		bleed.set_source(self)
		bleed.last_turn_only = true
		Character.add_hostile_effect(context, user, target, bleed)

func extra_usable(user):
	return user.has_effect("Devil Transformation", EffectType.Type.MARK, user) != null

func custom_behavior(context):
	var variations = []
	#Follows the immediate damage total down from 30 (15+15) to 20 (10+10).
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
