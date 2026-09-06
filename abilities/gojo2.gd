extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 35 damage to target enemy",
		["+10 damage if Lapse: Blue was used last turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var base_damage = 35
	if user.marked_by("Lapse: Blue"):
		base_damage += 10
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	var mod = 0
	if user.marked_by("Lapse: Blue"):
		mod = 10
	variations += behavior_single_target_damage(context, 50 + mod)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
