extends Ability

func describe(user):
	return "Impmon becomes Invulnerable for 1 turn and the target enemy is Blinded for 1 turn."

func split_desc():
	return [
		"Impmon becomes Invulnerable for 1 turn",
		["The target enemy is Blinded for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	for target in user.targeter.targets:
		var blind = Effect.blind_effect(2)
		blind.set_source(self)
		Character.add_hostile_effect(context, user, target, blind)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 50)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
