extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "One enemy has their non-affliction damage lowered by 10 until they use a new non-strategic skill. The next time that enemy uses a new non-strategic skill, they will receive 20 damage. This effect stacks and is invisible."

func split_desc():
	return [
		["One enemy has their non-affliction damage lowered by 10 until they use a new non-strategic skill", Color.ORANGE_RED],
		["The next time that enemy uses a new non-strategic skill, they receive 20 damage", Color.ORANGE_RED],
		["This effect stacks and is invisible", Color.DIM_GRAY]
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
	default_self_target_function(user, battle)
	default_allied_target_function(user, battle)
