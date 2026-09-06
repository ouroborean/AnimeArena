extends Ability

# Hand of the Monarch (White form). Stuns the target's non-Strategic skills for 1 turn.

func describe(user):
	return "Stuns target enemy's non-Strategic skills for 1 turn."

func split_desc():
	return [
		"Stuns target enemy's non-Strategic skills for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(2, [], ["Strategic"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
