extends Ability

func describe(user):
	return "Deals 20 Bleed damage to target enemy and prevents them from receiving healing for 1 turn."

func split_desc():
	return [
		"Deals 20 Bleed damage to target enemy",
		["Prevents the target from receiving healing for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.BLEED)
		var no_heal = Effect.ignore_healing(2)   # 1 turn
		no_heal.set_source(self)
		Character.add_hostile_effect(context, user, target, no_heal)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
