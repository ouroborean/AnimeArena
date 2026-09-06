extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Madoka targets an ally. If that ally is dead, they are resurrected with 50 HP. If that ally is alive, they have all enemy effects removed from them, are healed 50 HP, and become invulnerable for one turn. If that ally is Madoka, all enemies are permanently silenced. This skill can only be used if Madoka has at least 7 stacks of her passive, and after using it Madoka dies."

func split_desc():
	return [
		["If the target ally is dead, they are resurrected with 50 HP", Color.CADET_BLUE],
		["If alive, all enemy effects are removed from them, they heal 50 HP, and become invulnerable for 1 turn", Color.CADET_BLUE],
		["If she targets herself, all enemies are permanently Silenced", Color.ORANGE_RED],
		["Requires at least 7 stacks of her passive; Madoka dies after using it", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hostile = Condition.is_hostile(user, target)
		if target == user:
			for character in battle.all_characters():
				var silence_hostile = Condition.is_hostile(character, user)
				if silence_hostile.satisfied(context):
					var silence = Effect.silence_effect(-1)
					silence.set_source(self)
					silence.remove_on_death = false
					Character.add_allied_effect(context, user, character, silence)
		elif target.dead:
			target.dead = false
			target.health.set_health(50)
			target.update.emit()
		else:
			target.effects.cleanse_all_enemy_effects(target)
			var invuln = Effect.invuln_effect(2)
			invuln.set_source(self)
			invuln.remove_on_death = false
			Character.add_allied_effect(context, user, target, invuln)
			Character.resolve_healing(context, target, 50)
	user.die(user, self)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	if user.effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK, user):
		return user.effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK, user).mag >= 7
	return false

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	for character in context['ally_team'].characters:
		if not character.is_isolated() and not character.banished:
			variations.append([50, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
	for character in user.team.characters:
		if character.dead and not character.banished:
			character.set_targeted()
