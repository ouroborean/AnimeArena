extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 30 damage to target enemy",
		["Also targets any Blinded, Stunned, or Taunted enemies", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if character in user.targeter.targets:
			continue
		if user.is_hostile(character) and not character.dead and not character.banished:
			if character.has_stuns() or character.has_taunts() or character.blind_check():
				user.targeter.targets.append(character)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.NORMAL)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func and_target(character):
	return character.has_stuns() or character.has_taunts() or character.blind_check()

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
