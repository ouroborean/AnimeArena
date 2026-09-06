extends Ability

# Tumble. Stark gets out of the way for a turn. On a long cooldown by itself, but To The Rescue
# hands it straight back every time he catches a skill for someone — so the defensive turns chain.

func describe(user):
	return "Stark becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Stark becomes invulnerable for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	apply_allied(context, user, Effect.invuln_effect(2))

func extra_usable(user):
	return true

func custom_behavior(context):
	# behavior_self_panic_button is -30 + base_mod + (100 - hp); 40 keeps it mildly positive at full
	# health and climbing as he drops.
	return behavior_self_panic_button(context, 40)

func target(user, battle):
	default_self_target_function(user, battle)
