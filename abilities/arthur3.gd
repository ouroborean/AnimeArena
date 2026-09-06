extends Ability

func describe(user):
	return "Marks target enemy for 1 turn (Invisible). If that enemy would deal new damage, they instead gain Nullify equal to the damage they would have dealt for 1 turn."

func split_desc():
	return [
		"Marks target enemy for 1 turn (Invisible)",
		["If they would deal new damage, they gain Nullify equal to it instead, for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mark = Effect.mark(2, "Outgoing damage is converted into Nullify instead.")
		mark.set_source(self)
		mark.invisible = true
		Character.add_hostile_effect(context, user, target, mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
