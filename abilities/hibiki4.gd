extends Ability

# Berserk Mode stance. Permanent: ignore Stuns, ignore Counter/Reflect, +5 damage on all her skills.
# While active, Amalgam/Alchemic Gold apply their bonus to Hibiki herself on cast (handled in those
# skills). Mutually exclusive with Ex-Drive: using it strips Ex-Drive, and it can't be used while active.

func describe(user):
	return "For the rest of the game, Hibiki will ignore Stuns and Counter effects. During this time, her skills deal 5 more damage and automatically trigger their extra effects on her, but cannot affect allies. This skill cannot be used while active, and using it will remove Ex-Drive."

func split_desc():
	return [
		"For the rest of the game, Hibiki ignores Stuns and Counter effects",
		["Her skills deal 5 more damage and trigger their extra effects on herself, but can't aid allies", Color.CADET_BLUE],
		["Cannot be used while active; using it removes Ex-Drive", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# mutual exclusion — strip the opposite stance first
	user.effects.full_remove_effect_by_name("Ex-Drive", user)
	# permanent stance marker (Amalgam/Alchemic read has_effect("Berserk Mode", MARK) for the self-buff mode)
	var stance = Effect.mark(-1, "Berserk Mode is active.")
	stance.set_source(self)
	stance.cleansable = false
	stance.remove_on_death = false
	Character.add_allied_effect(context, user, user, stance)
	# permanent stun immunity
	var stun_ignore = Effect.ignore_effect_effect(-1, EffectType.Type.STUN)
	stun_ignore.set_source(self)
	stun_ignore.cleansable = false
	Character.add_allied_effect(context, user, user, stun_ignore)
	# permanent ignore Counter + Reflect (empty list = all her skills)
	var counter_ignore = Effect.ignore_counter_effect(-1, [])
	counter_ignore.set_source(self)
	counter_ignore.cleansable = false
	Character.add_allied_effect(context, user, user, counter_ignore)
	# permanent +5 damage on all her skills
	var boost = Effect.damage_mod_effect(5, -1)
	boost.set_source(self)
	boost.cleansable = false
	Character.add_allied_effect(context, user, user, boost)

func extra_usable(user):
	return user.has_effect("Berserk Mode", EffectType.Type.MARK, user) == null

func custom_behavior(context):
	return behavior_self_panic_button(context, 80)

func target(user, battle):
	default_self_target_function(user, battle)
