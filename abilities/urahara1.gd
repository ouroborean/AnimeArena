extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Fully stuns one enemy, makes them unable to become invulnerable, and ignore healing effects for 1 turn. The following turn, this swaps to 'Fire-Play, Benihime'."

func split_desc():
	return [
		["Fully stuns one enemy for 1 turn", Color.ORANGE_RED],
		["Target cannot become invulnerable for 1 turn", Color.ORANGE_RED],
		["Target ignores healing effects for 1 turn", Color.ORANGE_RED],
		["The following turn, swaps to Fire-Play, Benihime", Color.AQUA]
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
