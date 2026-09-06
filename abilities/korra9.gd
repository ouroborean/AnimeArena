extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Korra targets an ally or an enemy. If an ally, they will permanently ignore enemy non-damage effects and if an enemy they are permanently silenced. Cannot be used on an affected character and cannot be removed."

func split_desc():
	return [
		["If used on an ally, they permanently ignore negative non-damage effects", Color.CADET_BLUE],
		["If used on an enemy, they are permanently Silenced", Color.ORANGE_RED],
		["Cannot target an already-affected character; cannot be removed", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			var ignore = Effect.ignore_non_damage_effect(-1)
			ignore.set_source(self)
			ignore.cleansable = false
			Character.add_allied_effect(context, user, target, ignore)
		else:
			var silence = Effect.silence_effect(-1)
			silence.set_source(self)
			silence.cleansable = false
			Character.add_hostile_effect(context, user, target, silence)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	for character in context['ally_team'].characters:
		if not character.is_isolated() and not (character.dead or character.banished) and not character.has_effect("Energybending", EffectType.Type.IGNORE_NON_DAMAGE):
			variations.append([130, [user, self, [character]]])
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished) and not character.has_effect("Energybending", EffectType.Type.SILENCE):
			variations.append([130, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if character in user.team.characters:
			if character.effects.has_effect("Energybending", EffectType.Type.IGNORE_NON_DAMAGE, user):
				continue
			check_allied_target(user, character, context)
		else:
			if character.effects.has_effect("Energybending", EffectType.Type.SILENCE, user):
				continue
			check_hostile_target(user, character, context)
			
