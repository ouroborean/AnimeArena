extends Ability

# Hand of the Monarch (Green form). 10 damage + stun the target's non-Mental skills for 1 turn.

func describe(user):
	return "Deals 10 damage to target enemy and stuns their non-Mental skills for 1 turn."

func split_desc():
	return [
		"Deals 10 damage to target enemy and stuns their non-Mental skills for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var stun = Effect.stun_effect(2, [], ["Mental"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 10)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
