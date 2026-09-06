extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "La Pucelle deals 55 piercing damage to one enemy. This ability ignores invulnerability, cannot be countered, and can only be used if La Pucelle is below 50 health."

func split_desc():
	return [
		"Deals 55 piercing damage to target enemy, Bypassing Invulnerability",
		["Cannot be countered", Color.DIM_GRAY],
		["Can only be used while La Pucelle is below 50 health", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		#Put execution per target here
		pass
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
