extends Ability

# Ixa Parry. A normal skill — casting it cancels any active channel. It only INTERACTS with its partner:
# if the channel it just interrupted was Ixa Shield, Arima also ignores all harmful skills and effects
# for 1 turn (read from last_cancelled_channels). Always grants 1-turn Invulnerability and plants an
# "Ixa Parry" mark so Ixa Shield can read "used last turn".

func describe(user):
	return "Arima becomes Invulnerable for 1 turn. If this skill cancels an active Ixa Shield, Arima also ignores all harmful skills and effects for 1 turn."

func split_desc():
	return [
		"Arima becomes Invulnerable for 1 turn",
		["If it cancels an active Ixa Shield, Arima also ignores all harmful skills and effects for 1 turn", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var inv = Effect.invuln_effect(2)
	inv.set_source(self)
	Character.add_allied_effect(context, user, user, inv)
	# Let Ixa Shield detect "used the turn after Ixa Parry" (dur 3 survives to Arima's next turn).
	var mark = Effect.mark(3, "Arima's next Ixa Shield instead grants his team 75% Damage Reduction for 2 turns.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	# If casting this skill just interrupted an active Ixa Shield channel -> ignore ALL harmful skills and effects 1 turn.
	if "Ixa Shield" in user.last_cancelled_channels:
		var ig_dmg = Effect.ignore_damage_effect(2)
		ig_dmg.set_source(self)
		Character.add_allied_effect(context, user, user, ig_dmg)
		var ig_nd = Effect.ignore_non_damage_effect(2)
		ig_nd.set_source(self)
		Character.add_allied_effect(context, user, user, ig_nd)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 30)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
