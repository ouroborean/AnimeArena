extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mars marks one target and one random character for the rest of the game, allowing them to be targeted by her other abilities."

func split_desc():
	return [
		"Marks the target and one random character with Ofuda for the rest of the game",
		["Ofuda lets Mars target them with her other abilities", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mark = Effect.mark(-1, "This character is marked by Ofuda.")
		mark.set_source(self)
		if target in user.team.characters:
			Character.add_allied_effect(context, user, target, mark)
		else:
			Character.add_hostile_effect(context, user, target, mark)
	
	var unmarked_characters = []
	
	for character in context['enemy_team'].characters:
		if not character.marked_by("Ofuda", user) and not character.dead and not character.banished:
			unmarked_characters.append(character)
	for character in context['ally_team'].characters:
		if not character.marked_by("Ofuda", user) and not character.dead and not character.banished:
			unmarked_characters.append(character)
	if len(unmarked_characters) == 1:
		user.manually_advance_mission(6, 1)
	if len(unmarked_characters) > 0:
		var char_roll = battle.roll(0, len(unmarked_characters) - 1)
		var target = unmarked_characters[char_roll]
		var mark = Effect.mark(-1, "This character is marked by Ofuda.")
		mark.set_source(self)
		if target in user.team.characters:
			Character.add_allied_effect(context, user, target, mark)
		else:
			Character.add_hostile_effect(context, user, target, mark)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	for character in context['ally_team'].characters:
		#TODO: add isolation check
		if (not character.is_isolated()) and not (character.dead or character.banished) and not (character.marked_by("Ofuda", user)):
			variations.append([120, [user, self, [character]]])
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self)) and not (character.dead or character.banished) and not (character.marked_by("Ofuda", user)):
			variations.append([120, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations
	
	return variations
	
func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if not character.marked_by("Ofuda", user):
			if character not in user.team.characters:
				check_hostile_target(user, character, context)
			else:
				check_allied_target(user, character, context)
