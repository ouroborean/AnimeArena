extends Ability

func describe(user):
	return "Deals 20 damage to target enemy for 2 turns. That enemy takes 10 Bleed damage on the following 2 turns."

func split_desc():
	return [
		"Deals 20 damage to target enemy for 2 turns",
		["The target takes 10 Bleed damage on the following 2 turns", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# 20 normal for 2 turns = immediate hit (T) + one DoT tick (T+1).
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		var normal_dot = Effect.damage_effect(20, DamageType.Type.NORMAL, 3)
		normal_dot.set_source(self)
		normal_dot.name_override = "Reckless Charge"
		Character.add_hostile_effect(context, user, target, normal_dot)
		# One continuous Bleed ticking on the target's next two turns (dur 5 =
		# two delayed ticks, no tick on the cast turn).
		var bleed = Effect.damage_effect(10, DamageType.Type.BLEED, 5)
		bleed.set_source(self)
		bleed.name_override = "Reckless Charge (Bleed)"
		Character.add_hostile_effect(context, user, target, bleed)

func extra_usable(user):
	return user.has_effect("Devil Transformation", EffectType.Type.MARK, user) != null

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
