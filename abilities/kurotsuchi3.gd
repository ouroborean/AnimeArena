extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Target ally gains 10 Damage Reduction for 3 turns. During this time, they heal 10 HP each turn. While Empowered, this healing happens instantly. Will swap to a random Drug skill each turn."

func split_desc():
	return [
		"Target ally gains 10 Damage Reduction for 3 turns",
		"Heals 10 HP per turn for 3 turns",
		["While Empowered (Data Collection active): the entire 30 HP heals instantly", Color.AQUAMARINE],
		["Drug — slot rotates to a random other Drug at the end of each turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.has_effect("Data Collection", EffectType.Type.MARK, user) != null

	for target in user.targeter.targets:
		var dr = Effect.damage_reduction_effect(10, 6)
		dr.set_source(self)
		Character.add_allied_effect(context, user, target, dr)

		if empowered:
			# Front-load the full 3-turn heal (3 × 10) as a single resolution.
			Character.resolve_healing(context, target, 30)
		else:
			Character.resolve_healing(context, target, 10)
			var heal_dot = Effect.healing_effect(10, 5)
			heal_dot.set_source(self)
			Character.add_allied_effect(context, user, target, heal_dot)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_helpful(context, 40)
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
