extends Ability

# Wall of Protection. Ainz -> self-Invulnerable 1 turn; another ally -> 50% Damage Reduction 1 turn.
# Its cost cannot be increased (abilities_data "cost_locked"), so the passive's +Random never touches it.

func describe(user):
	return ""

func split_desc():
	return [
		"Target Ainz to make him Invulnerable for 1 turn",
		"Or target another ally to give them 50% Damage Reduction for 1 turn",
		["This skill's cost cannot be increased", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target == user:
			var inv = Effect.invuln_effect(2)                 # 1 turn
			inv.set_source(self)
			Character.add_allied_effect(context, user, user, inv)
		else:
			var dr = Effect.percent_dr(50, 2)                 # 50% DR, 1 turn
			dr.set_source(self)
			Character.add_allied_effect(context, user, target, dr)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_allied_target_function(user, battle)
