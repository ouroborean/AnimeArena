extends Ability

var base_damage = 15

func describe(user):
	return "Deals 15 damage to all enemies and Shatters them for 2 turns."

func split_desc():
	return [
		"Deals 15 damage to all enemies",
		"Shatters them for 2 turns"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var shatter = Effect.def_negate(4)
		shatter.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
