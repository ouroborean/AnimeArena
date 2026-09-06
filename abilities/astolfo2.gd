extends Ability

func describe(user):
	return "Deals 15 damage to all enemies, Silencing and Isolating them for 1 turn."

func split_desc():
	return [
		"Deals 15 damage to all enemies",
		["Silences and Isolates them for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
		var silence = Effect.silence_effect(2)   # 1 turn
		silence.set_source(self)
		Character.add_hostile_effect(context, user, target, silence)
		var iso = Effect.isolate(2)   # 1 turn
		iso.set_source(self)
		Character.add_hostile_effect(context, user, target, iso)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 15, 1.0)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
