extends Ability

var base_damage = 15

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 piercing damage to one enemy ignoring invulnerability. For 2 turns this enemy is Shattered and ignores Shield effects."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy and Shatters them for 2 turns (Bypassing)",
		"Affected enemies ignore Shield effects"
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		apply_hostile(context, target, Effect.def_negate(3), true)
		apply_hostile(context, target, Effect.ignore_effect_effect(3, EffectType.Type.SHIELD), true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	var bakugo = context['owner']
	var stacks = 0
	if bakugo.has_effect("Nitroglycerin Storage", EffectType.Type.DAMAGE_MOD, bakugo):
		stacks = bakugo.has_effect("Nitroglycerin Storage", EffectType.Type.DAMAGE_MOD, bakugo).stacks
	for character in context['enemy_team'].characters:
		var mod = 0
		if len(character.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)) > 0:
			mod += 75
		if not (character.dead or character.banished):
			variations.append([150 + (stacks * 5) + mod, [bakugo, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
