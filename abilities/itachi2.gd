extends Ability


func describe(user):
	return "Deals 20 damage to target enemy and stuns them for 1 turn. If that enemy was countered by Kotoamatsukami or damaged by Crow Clone last turn, they are instead banished for 1 turn."


func split_desc():
	return [
		"Deals 20 damage to target enemy and stuns them for 1 turn",
		["If they were damaged by Crow Clone or countered by Kotoamatsukami last turn, banishes them for 1 turn instead", Color.CADET_BLUE],
	]


func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		var crow_recent = target.has_effect("Crow Clone", EffectType.Type.MARK, user)
		var koto_recent = target.has_effect("Kotoamatsukami", EffectType.Type.MARK, user)
		var should_banish = (crow_recent or koto_recent) and not target.shrug_off_type(EffectType.Type.BANISH)
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		if should_banish:
			# Consume the breadcrumbs that enabled the banish so a single
			# Crow Clone / Kotoamatsukami trigger only powers one banish.
			if crow_recent:
				target.effects.remove_effect("Crow Clone", EffectType.Type.MARK, user)
			if koto_recent:
				target.effects.remove_effect("Kotoamatsukami", EffectType.Type.MARK, user)
			user.banish_character(context, target, self, 2)
		else:
			apply_hostile(context, target, Effect.stun_effect(2))


func extra_usable(user):
	return true


func custom_behavior(context):
	return behavior_single_target_stun(context, 30)


func target(user, battle):
	default_hostile_target_function(user, battle)
