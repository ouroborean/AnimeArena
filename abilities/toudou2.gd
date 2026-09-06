extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"For 2 turns, Touka becomes Stealthed and her skills become Invisible (Invisible)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var mark = Effect.mark(5, "Touka's effects are invisible.")
	mark.set_source(self)
	mark.invisible = true
	Character.add_allied_effect(context, user, user, mark)
	var stealth = Effect.stealth_effect(5)
	stealth.set_source(self)
	stealth.invisible = true
	stealth.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, stealth)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 30)

func target(user, battle):
	default_self_target_function(user, battle)
