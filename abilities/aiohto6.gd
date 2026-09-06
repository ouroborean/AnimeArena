extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Whenever Ai kills an enemy with Now I'm Mad!, she heals 10 HP, becomes Immortal for 1 turn, and the cooldown on Now I'm Mad! is reset."

func split_desc():
	return [
		["When Ai kills an enemy with Now I'm Mad!, she heals 10 HP and becomes Immortal for 1 turn", Color.CADET_BLUE],
		["Now I'm Mad!'s cooldown is also reset", Color.CADET_BLUE]
	]

func execute(user, battle):
	# The kill reward is applied inside Now I'm Mad! (ai2) the moment it lands a lethal blow, so this
	# passive slot has no setup of its own.
	pass

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
