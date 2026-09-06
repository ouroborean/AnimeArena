extends Ability

var base_healing = 35

func describe(user):
	return "Heals target ally for 35 HP and cleanses all enemy Affliction effects from them."

func split_desc():
	return [
		"Heals target ally for 35 HP.",
		["Cleanses all enemy Affliction effects from them.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_healing(context, target, base_healing)
		target.effects.cleanse_hostile_afflictions(target)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_heal(context, 20, 1.0)

func target(user, battle):
	default_allied_target_function(user, battle)
