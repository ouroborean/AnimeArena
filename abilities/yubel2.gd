extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Taunts the enemy team for 1 turn, increased by 1 turn on Invulnerable targets (Invisible)."

func split_desc():
	return [
		"Taunts the enemy team for 1 turn (Invisible)",
		["Lasts 1 additional turn on Invulnerable targets", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var duration = 2
		if target.is_invuln(self):
			duration = 4
		var taunt = Effect.taunt_effect(duration, user)
		taunt.set_source(self)
		taunt.invisible = true
		Character.add_hostile_effect(context, user, target, taunt, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_all_target(context, 80)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, true)
