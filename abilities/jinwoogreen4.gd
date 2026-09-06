extends Ability

# Vanish (Green form). Invulnerable for 1 turn and leaves a marker that empowers the next Vital Strike
# (jinwoogreen1 reads/consumes the "Vanish" MARK).

func describe(user):
	return "Jin-woo becomes Invulnerable for 1 turn."

func split_desc():
	return [
		["Jin-woo becomes Invulnerable for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	var mark = Effect.mark(3, "Vital Strike deals +10 damage this turn.")
	mark.set_source(self)
	mark.invisible = true
	Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 0)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
