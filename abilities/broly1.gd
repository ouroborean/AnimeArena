extends Ability

var base_damage = 25

func describe(user):
	return "Deals 25 damage to target enemy and stuns their non-Strategic skills for 1 turn."

func split_desc():
	return [
		"Deals 25 damage to target enemy",
		"Stuns their non-Strategic skills for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var slam_stun = Effect.stun_effect(2, [], ["Strategic"])
		slam_stun.set_source(self)
		Character.add_hostile_effect(context, user, target, slam_stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context, 50)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
