extends Ability

var base_damage = 25

func describe(user):
	return "Deals 25 damage to target enemy, Stunning and Isolating them for 1 turn."

func split_desc():
	return [
		"Deals 25 damage to target enemy",
		"Stuns and Isolates them for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var cuffs_stun = Effect.stun_effect(2)
		cuffs_stun.set_source(self)
		Character.add_hostile_effect(context, user, target, cuffs_stun)
		var cuffs_isolate = Effect.isolate(2)
		cuffs_isolate.set_source(self)
		Character.add_hostile_effect(context, user, target, cuffs_isolate)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context, 55)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
