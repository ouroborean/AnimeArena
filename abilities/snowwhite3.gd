extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Snow White targets an ally other than herself. For 1 turn, if that ally dies, they instead return to 50 health. This healing cannot be prevented. This effect will not trigger on abilities that kill the user."

func split_desc():
	return [
		["Targets an ally other than herself; for 1 turn, if that ally dies they instead return to 50 health", Color.CADET_BLUE],
		["Healing cannot be prevented", Color.CADET_BLUE],
		["Will not trigger on abilities that kill the user", Color.DIM_GRAY]
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
