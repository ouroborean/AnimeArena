extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Adam copies a random non-Strategic skill from target enemy for 2 turns, replacing Divine Power Replication. The copied skill costs 1 random energy. Adam gains 1 stack of Eye Strain."

func split_desc():
	return [
		"Copies a random non-Strategic skill from target enemy for 2 turns, replacing this skill",
		["The copied skill costs 1 random energy", Color.CADET_BLUE],
		["Adam gains 1 stack of Eye Strain", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var candidates = []
		for abi in target.moveset.get_active_abilities(target):
			if abi == null:
				continue
			if abi.classes["Strategic"]:
				continue
			candidates.append(abi)
		if candidates.is_empty():
			continue
		var pick = candidates[battle.roll(0, len(candidates) - 1)]
		var slot = user.moveset.get_active_abilities(user).find(self)
		if slot == -1:
			slot = 0
		var copy = Effect.copy_effect(pick, slot, 5, user)
		copy.ability_targets._cost = {Energy.Type.GREEN: 0, Energy.Type.BLUE: 0, Energy.Type.WHITE: 0, Energy.Type.RED: 0, Energy.Type.RANDOM: 1}
		copy.unique_render_id = int(Time.get_ticks_msec())
		copy.set_source(self)
		Character.add_allied_effect(context, user, user, copy)
	user.moveset.base_abilities[4].grant_eye_strain(user)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
