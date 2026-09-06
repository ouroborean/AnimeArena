extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 5 damage to all enemies and Blinds them for 1 turn",
		["Enemies that are already Blinded are Taunted for 1 turn instead", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 5, DamageType.Type.NORMAL)
		if target.blind_check():
			var taunt = Effect.taunt_effect(3, user)
			taunt.set_source(self)
			Character.add_hostile_effect(context, user, target, taunt)
		else:
			var blind = Effect.blind_effect(3)
			blind.set_source(self)
			Character.add_hostile_effect(context, user, target, blind)
	var burning_love = user.has_effect("Venus Burning Love", EffectType.Type.DAMAGE_MOD)
	if burning_love:
		Character.resolve_healing(context, user, 10 + 5 * burning_love.stack_count())
		user.effects.erase_effect(burning_love)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 60)

func target(user, battle):
	default_hostile_target_function(user, battle)
