extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "All enemies take 5 Affliction damage for 4 turns. During this time, they ignore cleansing and healing effects."

func split_desc():
	return [
		"All enemies take 5 Affliction damage per turn for 4 turns",
		["Affected enemies ignore Healing effects while the gas is active", Color.CADET_BLUE],
		["Affected enemies cannot be Cleansed while the gas is active", Color.CADET_BLUE],
		["After use, this slot swaps back to Ashisogi Jizo", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Deadly Gas is a one-shot: using it removes the Bankai swap so slot 0 shows Ashisogi Jizo again.
	var swap = user.has_effect("Bankai - Konjiki Ashisogi Jizo", EffectType.Type.ABILITY_SWAP, user)
	if swap != null:
		user.effects.erase_effect(swap)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 5, DamageType.Type.AFFLICTION)
		var dot = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 9)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot, true)

		var ignore_heal = Effect.ignore_healing(9)
		ignore_heal.set_source(self)
		Character.add_hostile_effect(context, user, target, ignore_heal, true)

		var ignore_cleanse = Effect.ignore_cleanse_effect(9)
		ignore_cleanse.set_source(self)
		Character.add_hostile_effect(context, user, target, ignore_cleanse, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 80)
	return variations

func target(user, battle):
	# target_type ALL: the engine filters down to valid hostile targets via
	# can_hostile_target inside the default helper.
	default_hostile_target_function(user, battle, true)
