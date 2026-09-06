extends Ability

func describe(user):
	return "Jesse consumes 1 stack of Crystal Beasts to become Invulnerable for 1 turn."

func split_desc():
	return [
		"Jesse consumes 1 stack of Crystal Beasts to become Invulnerable for 1 turn.",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Consume 1 stack
	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	if cb_eff:
		cb_eff.consume_stack(1)

	# Grant invulnerability for 1 turn
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

func extra_usable(user):
	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	return cb_eff != null and cb_eff.stacks >= 1

func custom_behavior(context):
	return behavior_self_panic_button(context, 5, 1.5)

func target(user, battle):
	default_self_target_function(user, battle)
