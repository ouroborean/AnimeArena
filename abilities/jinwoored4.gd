extends Ability

# Vanish (Red form). Invulnerable for 1 turn + a permanent, stacking +5 to all of Jin-woo's damage.

func describe(user):
	return "Jin-woo becomes Invulnerable for 1 turn and permanently deals +5 damage."

func split_desc():
	return [
		["Jin-woo becomes Invulnerable for 1 turn", Color.CADET_BLUE],
		["Jin-woo permanently deals +5 damage (stacks)", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	var buff = Effect.damage_mod_effect(5, -1)
	buff.set_source(self)
	buff.stackable = true
	buff.stack_mag = true
	buff.display_stacks = true
	Character.add_allied_effect(context, user, user, buff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 0)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
