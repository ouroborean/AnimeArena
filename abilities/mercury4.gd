extends Ability

var base_damage = 0

func describe(user):
	return ""

func split_desc():
	return [
		"Mercury becomes Invulnerable for 1 turn",
		["While Empowered, this skill's cooldown is reduced by 3", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = make_context(battle)
	default_defend(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
