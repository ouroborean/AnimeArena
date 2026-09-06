extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Target enemy has a random skill's active cooldown increased by 1, and then is Paralyzed for 2 turns. While Empowered, the active cooldown increase occurs 3 times. Will swap to a random Drug skill each turn."

func split_desc():
	return [
		"Increases the active cooldown of one random skill on target enemy by 1",
		"Paralyzes the target for 2 turns (their cooldowns stop ticking)",
		["While Empowered (Data Collection active): the cooldown bump rolls 3 times — the same skill can be hit more than once", Color.AQUAMARINE],
		["Drug — slot rotates to a random other Drug at the end of each turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.has_effect("Data Collection", EffectType.Type.MARK, user) != null
	var bumps = 3 if empowered else 1

	for target in user.targeter.targets:
		# Pick a random skill from the target's currently-displayed moveset
		# (the row of buttons they have available, with any swaps already
		# applied). Mirrors the Frankenstein1 cooldown-bump pattern.
		var valid_skills = target.moveset.display_abilities()
		if not valid_skills.is_empty():
			for i in range(bumps):
				var roll = battle.roll(0, valid_skills.size() - 1)
				valid_skills[roll].cooldown_remaining += 1

		var paralyze = Effect.paralyze_effect(4)
		paralyze.set_source(self)
		Character.add_hostile_effect(context, user, target, paralyze, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
