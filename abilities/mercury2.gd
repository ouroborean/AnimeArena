extends Ability

var base_damage = 0

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 20 damage to target enemy and Paralyzes them for 2 turns",
		["While Empowered, also increases target's cooldowns by 1", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		var paralyze = Effect.paralyze_effect(4)
		paralyze.set_source(self)
		Character.add_hostile_effect(context, user, target, paralyze)
		if user.marked_by("Shabon Spray"):
			var cooldown_mod = Effect.cooldown_mod(1, 4)
			cooldown_mod.set_source(self)
			Character.add_hostile_effect(context, user, target, cooldown_mod)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context)

func target(user, battle):
	default_hostile_target_function(user, battle)
