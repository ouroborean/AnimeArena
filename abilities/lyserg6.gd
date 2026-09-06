extends Ability

var base_damage = 15

func describe(user):
	return "Deals 15 damage to all enemies. Lyserg heals equal to the damage dealt to any targets with at least 1 Morphin Mark."

func split_desc():
	return [
		"Deals 15 damage to all enemies",
		"Lyserg heals equal to the damage dealt to any target with at least 1 Morphin Mark",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		health_drain = target.effects.has_effect("Homing Pendulum", EffectType.Type.MARK, user) != null
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
	health_drain = false

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 40, 1.1)

func target(user, battle):
	default_hostile_target_function(user, battle)
