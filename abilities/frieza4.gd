extends Ability

# Telekinesis. Plain self-Invulnerability — the long cooldown is what prices it. It also doubles as
# Frieza's answer to his own Death Ball tempo: the turn he spends untouchable is the turn a bomb he
# planted is ticking down.

func describe(user):
	return "Frieza becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Frieza becomes invulnerable for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	apply_allied(context, user, Effect.invuln_effect(2))

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 40)

func target(user, battle):
	default_self_target_function(user, battle)
