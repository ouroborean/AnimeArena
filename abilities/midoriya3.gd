extends Ability

var base_damage = 30

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to one enemy and fully silences their skills for 1 turn."

func split_desc():
	return [
		"Deals 30 damage to target enemy",
		"Fully silences their skills for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var silence = Effect.silence_effect(2)
		silence.set_source(self)
		Character.add_hostile_effect(context, user, target, silence)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var bypassing = false
	if context['owner'].has_effect("Faux 100%", EffectType.Type.ACTION_USE_TRIGGER, user):
		bypassing = true
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypassing) and not (character.dead or character.banished):
			var mod = 0
			if character.ignoring_effect_type(EffectType.Type.SILENCE):
				mod -= -75
			if character.has_effect("Blackwhip", EffectType.Type.VULNERABILITY, context['owner']):
				mod += 75
			variations.append([100 + mod + (100 - context['owner'].health.hp), [context['owner'], self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	var faux = Condition.has_effect(user, "Faux 100%", EffectType.Type.ACTION_USE_TRIGGER, user)
	var bypassing = false
	if faux.satisfied(context):
		bypassing = true
	
	default_hostile_target_function(user, battle, bypassing)
