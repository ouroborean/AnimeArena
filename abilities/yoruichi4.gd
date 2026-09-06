extends Ability

# Yoruichi Dodge. Flash-step out of the way for a turn. Plain self-Invulnerability on a long
# cooldown — its real job in the kit is buying the turn she needs to keep a full Gather battery
# alive until Raijin Senkei comes off cooldown.

func describe(user):
	return "Yoruichi becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Yoruichi becomes invulnerable for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	apply_allied(context, user, Effect.invuln_effect(2))

func extra_usable(user):
	return true

func custom_behavior(context):
	# behavior_self_panic_button scores -30 + base_mod + (100 - hp); 40 keeps it mildly positive at
	# full health and climbing as she drops.
	return behavior_self_panic_button(context, 40)

func target(user, battle):
	default_self_target_function(user, battle)
