extends Ability

# Vanish (White form). Makes a TARGET ALLY (Jin-woo or a teammate) Invulnerable for 1 turn.

func describe(user):
	return "Target ally becomes Invulnerable for 1 turn."

func split_desc():
	return [
		["Target ally becomes Invulnerable for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var inv = Effect.invuln_effect(2)
		inv.set_source(self)
		Character.add_allied_effect(context, user, target, inv)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_helpful(context)
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
