extends Ability


func describe(user):
	return "Deals 50 Piercing damage to target enemy. If that enemy's skills are currently sealed by Totsuka Blade, this skill deals 20 more damage."


func split_desc():
	return [
		"Deals 40 Piercing damage to target enemy",
		["+20 damage if the target is sealed by Totsuka Blade", Color.CADET_BLUE],
	]


func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		var dmg = 40
		var seal = target.has_effect("Totsuka Blade", EffectType.Type.MARK, user)
		if seal and seal.skill_seal:
			dmg += 20
		Character.resolve_damage(context, target, dmg, DamageType.Type.PIERCING)


func extra_usable(user):
	return true


func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		if (character.dead or character.banished):
			continue
		var weight = 100 + (100 - character.health.hp)
		var seal = character.has_effect("Totsuka Blade", EffectType.Type.MARK, context['owner'])
		if seal and seal.skill_seal:
			weight += 60
		variations.append([weight, [user, self, [character]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations


func target(user, battle):
	default_hostile_target_function(user, battle, true)
