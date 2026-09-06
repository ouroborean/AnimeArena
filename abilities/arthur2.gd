extends Ability

func describe(user):
	return "For 1 turn, if Arthur would be damaged by a Harmful skill, he instead gains Shield equal to the damage he would have taken (Invisible) for 2 turns."

func split_desc():
	return [
		"For 1 turn, incoming Harmful damage is converted into Shield instead of being taken (Invisible)",
		["The Shield is Invisible and lasts 2 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(2, "Incoming Harmful damage is converted into Shield instead.")
	mark.set_source(self)
	mark.invisible = true
	Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 30, 1.2)

func target(user, battle):
	default_self_target_function(user, battle)
