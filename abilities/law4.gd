extends Ability

# Takt. Law flips the whole enemy line and Blinds all of them for a turn. The Blind is flagged invisible
# (blind.invisible=true, hidden from the opponent's snapshot — the "(Invisible)" in the skill text). The
# skill USE itself is NOT hidden: the builder did not tag Takt Invisible, and the engine only hides a use
# via the ability `invisible` flag anyway, which the "Invisible" CLASS does not set.

func describe(user):
	return "All enemies are Blinded for 1 turn (Invisible)."

func split_desc():
	return [
		"All enemies are Blinded for 1 turn",
		["The Blind is Invisible", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var blind = Effect.blind_effect(2)
		blind.set_source(self)
		blind.invisible = true
		# Reveal on expiry (invisible_expiration), like other invisible effects, so the opponent learns
		# the Blind has ended rather than silently guessing.
		blind.wrapup_func = default_counter_timeout
		Character.add_hostile_effect(context, user, target, blind)

func extra_usable(user):
	return user.has_effect("ROOM", EffectType.Type.START_OF_TURN_TRIGGER, user)

func custom_behavior(context):
	return behavior_all_target(context, 45)

func target(user, battle):
	default_hostile_target_function(user, battle)
