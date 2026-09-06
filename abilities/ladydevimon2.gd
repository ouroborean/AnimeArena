extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 damage to target enemy and Taunts them for 1 turn."

func split_desc():
	return [
		"Deals 20 damage to target enemy.",
		["Taunts the target for 1 turn.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var taunt = Effect.taunt_effect(2, user)
		taunt.set_source(self)
		Character.add_hostile_effect(context, user, target, taunt)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 25)

func target(user, battle):
	default_hostile_target_function(user, battle)
