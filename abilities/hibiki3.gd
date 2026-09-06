extends Ability

# Ex-Drive stance. Permanent +25 Shield and a stance marker that Amalgam/Alchemic Gold read to extend
# their reward window by 1 turn. Mutually exclusive with Berserk Mode: using it strips Berserk, and it
# cannot be used while already active.

func describe(user):
	return "Hibiki gains 25 Shield and, for the rest of the game, Amalgam and Alchemic Gold's bonus effects will last 1 extra turn. This skill cannot be used while active, and using it will remove Berserk Mode."

func split_desc():
	return [
		"Hibiki gains 25 Shield",
		["For the rest of the game, Amalgam and Alchemic Gold's bonus effects last 1 extra turn", Color.CADET_BLUE],
		["Cannot be used while active; using it removes Berserk Mode", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# mutual exclusion — strip the opposite stance first
	user.effects.full_remove_effect_by_name("Berserk Mode", user)
	# permanent stance marker (Amalgam/Alchemic read has_effect("Ex-Drive", MARK) for the +1 turn window)
	var stance = Effect.mark(-1, "Ex-Drive: Amalgam and Alchemic Gold bonuses last 1 extra turn.")
	stance.set_source(self)
	stance.cleansable = false
	stance.remove_on_death = false
	Character.add_allied_effect(context, user, user, stance)
	# permanent +25 Shield
	var shield = Effect.shield_effect(25, -1)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)

func extra_usable(user):
	return user.has_effect("Ex-Drive", EffectType.Type.MARK, user) == null

func custom_behavior(context):
	return behavior_self_panic_button(context, 80)

func target(user, battle):
	default_self_target_function(user, battle)
