extends Ability

# Unmatched Agility — Levi becomes invulnerable for 1 turn (invuln_effect(2)).

func describe(user):
	return ""

func split_desc():
	return [
		["Levi becomes Invulnerable for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 40)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
