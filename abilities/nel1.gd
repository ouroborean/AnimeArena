extends Ability

var base_damage = 35
var gamuza_bonus = 5

func describe(user):
	var bonus = gamuza_bonus if user.has_effect("Declare, Gamuza", EffectType.Type.MARK, user) else 0
	return "Deals " + str(base_damage + bonus) + " damage to target enemy."

func split_desc():
	return [
		"Deals 35 damage to target enemy.",
		["Deals 5 additional damage while Declare, Gamuza is active.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var bonus = gamuza_bonus if user.has_effect("Declare, Gamuza", EffectType.Type.MARK, user) else 0
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + bonus, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 0, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
