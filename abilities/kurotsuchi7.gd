extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "For 1 turn, target enemy's skills are Delayed by 1 turn. While Empowered, the duration and delay amount are increased to 2 turns. Will swap to a random Drug skill each turn."

func split_desc():
	return [
		"For 1 turn, target enemy's next skill is delayed by 1 turn",
		["While Empowered (Data Collection active): delay amount and duration both become 2", Color.AQUAMARINE],
		["Drug — slot rotates to a random other Drug at the end of each turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.has_effect("Data Collection", EffectType.Type.MARK, user) != null
	var delay_amount = 2 if empowered else 1
	var delay_dur = 4 if empowered else 2

	for target in user.targeter.targets:
		var delay = Effect.delay_eff(delay_amount, delay_dur, 1, [])
		delay.set_source(self)
		Character.add_hostile_effect(context, user, target, delay)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
