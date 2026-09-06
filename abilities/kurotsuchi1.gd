extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Target enemy takes 15 Affliction damage, then 5 Affliction damage for 2 turns. This effect stacks and refreshes, and if it reaches 3 stacks, it becomes permanent."

func split_desc():
	return [
		"Deals 15 Affliction damage to target enemy, then 5 Affliction damage each turn for 2 turns",
		"Further uses refresh the DOT, but stacks do not increase damage",
		["At 3+ stacks the DOT becomes permanent", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Immediate hit always fires regardless of stack state.
		Character.resolve_damage(context, target, 15, DamageType.Type.AFFLICTION)

		# Stack semantics: per-turn damage stays at 5 forever — stacks are just
		# a counter that decides whether the DOT becomes permanent. On re-cast,
		# bump the stack count, refresh the duration back to 5 (= "2 turns"),
		# and pin duration to -1 once the counter reaches 3. We manage it
		# manually here because add_effect's stackable merge path doesn't
		# refresh duration or conditionally pin it to -1.
		var existing = target.has_effect("Ashisogi Jizo", EffectType.Type.DAMAGE, user)
		if existing:
			existing.stacks += 1
			existing.duration = -1 if existing.stacks >= 3 else 5
			existing.effect_updated.emit(existing)
		else:
			var dot = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 5)
			dot.set_source(self)
			dot.stackable = true
			dot.refresh = true
			dot.display_stacks = true
			Character.add_hostile_effect(context, user, target, dot)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
