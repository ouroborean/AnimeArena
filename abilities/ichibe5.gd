extends Ability

var stack_requirement = 10

func describe(user):
	return "Removes all helpful effects from target enemy, then executes them. Cannot be countered. Ignores Immortality. Requires 10 stacks of Ink Splatter on Ichibe."

func split_desc():
	return [
		"Removes all allied effects from target enemy, then executes them.",
		["Cannot be countered. Ignores Immortality.", Color.DIM_GRAY],
		["Requires 10 stacks of Ink Splatter on Ichibe.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		target.effects.cleanse_all_ally_effects(target, user)
		target.effects.full_remove_effect_by_type(EffectType.Type.IMMORTALITY)
		target.die(user, self)

func extra_usable(user):
	var eff = user.has_effect("Ink Splatter", EffectType.Type.MARK, user)
	return eff != null and eff.stack_count() >= stack_requirement

func custom_behavior(context):
	return behavior_single_target_damage(context, 200, 0.8, true)

func target(user, battle):
	default_hostile_target_function(user, battle, true)
