extends Ability

var base_damage = 40

func describe(user):
	return "Yoh deals 40 damage to target enemy, or executes them if they are at or below 40 HP."

func split_desc():
	return [
		"Deals 40 damage to target enemy",
		["Executes the target instead if they are at or below 40 HP", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		target.execute_attempt(40, user, self)
		if not target.dead:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 60, 1.4)

func target(user, battle):
	default_hostile_target_function(user, battle)
