extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 20 damage to target enemy and Taunts them for 1 turn"
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		var taunt = Effect.taunt_effect(2, user)
		taunt.set_source(self)
		Character.add_hostile_effect(context, user, target, taunt)
	var burning_love = user.has_effect("Venus Burning Love", EffectType.Type.DAMAGE_MOD)
	if burning_love:
		Character.resolve_healing(context, user, 10 + 5 * burning_love.stack_count())
		user.effects.erase_effect(burning_love)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 60)

func target(user, battle):
	default_hostile_target_function(user, battle)
