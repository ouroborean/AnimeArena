extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 20 Piercing damage to target enemy (Bypassing). After damage, caps the target's HP at its current value."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy (Bypasses)",
		["After damage, permanently caps the target's max HP at their current HP", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.PIERCING)
		# Lock the cap to whatever HP the target was left with by the hit. -1
		# duration = permanent: no future healing can push them past that mark
		# even if the cap effect itself is never cleansed.
		var cap = Effect.health_cap_effect(target.health.hp, -1)
		cap.set_source(self)
		Character.add_hostile_effect(context, user, target, cap, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 80, 1.5, true)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, true)
