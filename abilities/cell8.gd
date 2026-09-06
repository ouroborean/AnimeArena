extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 25 Piercing damage to target enemy and Isolates them for 1 turn (Bypasses)."

func split_desc():
	return [
		"Deals 25 Piercing damage to target enemy (Bypasses)",
		"Isolates the target for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 25, DamageType.Type.PIERCING)
		var iso = Effect.isolate(2)
		iso.set_source(self)
		# bypassing=true: this skill bypasses invuln to target (see target()) and its description says the
		# Isolate "(Bypasses)" too — without the flag the Isolate drops on an invuln target.
		Character.add_hostile_effect(context, user, target, iso, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 50, 1.0, true)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, true)
