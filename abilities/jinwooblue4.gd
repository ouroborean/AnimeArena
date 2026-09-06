extends Ability

# Vanish (Blue form). Stuns the target enemy's Strategic skills for 1 turn and Jin-woo becomes
# Invulnerable for 1 turn.

func describe(user):
	return "Stuns target enemy's Strategic skills for 1 turn and Jin-woo becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Stuns target enemy's Strategic skills for 1 turn",
		["Jin-woo becomes Invulnerable for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(2, ["Strategic"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
	default_defend(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
