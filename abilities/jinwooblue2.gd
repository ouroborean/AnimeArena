extends Ability

# Hand of the Monarch (Blue form). Silences target enemy for 2 turns.

func describe(user):
	return "Silences target enemy for 2 turns."

func split_desc():
	return [
		"Silences target enemy for 2 turns",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var silence = Effect.silence_effect(4)
		silence.set_source(self)
		Character.add_hostile_effect(context, user, target, silence)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
