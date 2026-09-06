extends Ability
var base_damage = 20

func describe(user):
	return "Deals 20 Affliction damage to target enemy for 2 turns."

func split_desc():
	return [
		"Deals 20 Affliction damage to target enemy for 2 turns"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		var dot = Effect.damage_effect(base_damage, DamageType.Type.AFFLICTION, 3)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
