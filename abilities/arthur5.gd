extends Ability

var base_damage = 45
var execute_threshold = 20

func describe(user):
	return "Deals 45 Affliction damage to target enemy and executes them if their HP falls below 20. After using this skill, Arthur dies."

func split_desc():
	return [
		"Deals 45 Affliction damage to target enemy",
		"Executes them if their HP is below 20",
		["After using this skill, Arthur dies", Color.INDIAN_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		target.execute_attempt(execute_threshold, user, self)
	user.instant_kill(user, self)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 60, 1.5)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
