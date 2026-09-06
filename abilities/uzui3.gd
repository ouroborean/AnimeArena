extends Ability

func describe(user):
	return "Deals 10 Piercing damage to target enemy 3 times. For 1 turn, the first Harmful Physical skill used on Uzui will be countered."

func split_desc():
	return [
		"Deals 10 Piercing damage to target enemy 3 times",
		["For 1 turn, the first Harmful Physical skill used on Tengen will be countered", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		for i in range(3):
			Character.resolve_damage(context, target, 10, DamageType.Type.PIERCING)
	var counter_eff = Effect.counter_effect(Trigger.always(default_counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "The first Harmful Physical skill used on this character will be countered.", ["Physical"])
	counter_eff.set_source(self)
	counter_eff.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, counter_eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 25)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
