extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"Touka ignores all damage for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var nukiashi = user.marked_by("Nukiashi")
	
	var ignore = Effect.ignore_damage_effect(2)
	ignore.set_source(self)
	if nukiashi:
		ignore.invisible = true
		ignore.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, ignore)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 30, 1.2)

func target(user, battle):
	default_self_target_function(user, battle)
