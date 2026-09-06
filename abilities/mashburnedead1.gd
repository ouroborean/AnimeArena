extends Ability

# Big Bang Dash (display slot 0). For 1 turn, ENHANCES Ballista Knuckle + Hell Fall Knuckle (a self
# MARK named after this skill that those two read) and makes Mash ignore negative non-damage effects.

func describe(user):
	return ""

func split_desc():
	return [
		"For 1 turn, Ballista Knuckle and Hell Fall Knuckle are enhanced",
		["Mash also ignores negative non-damage effects for the turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# dur 3 so the enhancement survives the enemy's turn and is still active on Mash's NEXT actionable turn
	# (dur 2 would expire first). The Knuckles look up has_effect("Big Bang Dash", MARK).
	var mark = Effect.mark(3, "Ballista Knuckle and Hell Fall Knuckle are enhanced.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

	var ignore = Effect.ignore_non_damage_effect(2)
	ignore.set_source(self)
	Character.add_allied_effect(context, user, user, ignore)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 25)

func target(user, battle):
	default_self_target_function(user, battle)
