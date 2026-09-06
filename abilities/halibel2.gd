extends Ability

var base_damage = 30

func describe(user):
	return "Halibel pierces target enemy with her three-pronged blade, dealing 30 Piercing damage. If Halibel is below max HP, the target is also Shattered for 1 turn."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy.",
		["Also Shatters them for 1 turn while Halibel is below max HP.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var wounded = user.health.hp < user.health.max_hp
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		if wounded:
			var shatter = Effect.def_negate(2)
			shatter.set_source(self)
			Character.add_hostile_effect(context, user, target, shatter)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 5, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
