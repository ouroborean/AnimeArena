extends Ability

# Block — the Vessel becomes Invulnerable for 1 turn.
# Cost/cooldown/classes/target_type come from abilities_data.json via Ability.from_database.

func describe(user):
	return ""

func split_desc():
	return [
		["Become Invulnerable for 1 turn", Color.SKY_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var eff = Effect.invuln_effect(2)   # 2 == 1 turn; full invuln (no class args)
	eff.set_source(self)
	Character.add_allied_effect(context, user, user, eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 0)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
