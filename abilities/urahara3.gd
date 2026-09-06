extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Fully stuns an enemy for 1 turn then removes 1 random energy and their helpful effects from them. If their health is at 50 or less, this stuns for 2 turns and removes 2 random energies instead."

func split_desc():
	return [
		["Fully stuns an enemy for 1 turn, removes 1 random energy and their helpful effects", Color.ORANGE_RED],
		["If their health is 50 or less, stuns for 2 turns and removes 2 random energies instead", Color.ORANGE_RED]
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
