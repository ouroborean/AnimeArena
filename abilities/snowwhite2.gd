extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Snow White targets an ally or an enemy for 1 turn. If used on an ally, that ally will gain 25 points of damage reduction and will gain one random energy if a new harmful ability is used on them. If used on an enemy, that enemy will have their first new harmful ability countered, and they will lose one random energy. This skill is invisible until triggered and ignores invulnerability and isolation."

func split_desc():
	return [
		["Targets an ally or enemy for 1 turn", Color.DIM_GRAY],
		["Ally: gains 25 damage reduction, and gains one random energy if a new harmful ability is used on them", Color.CADET_BLUE],
		["Enemy: their first new harmful ability is countered, and they lose one random energy", Color.ORANGE_RED],
		["Invisible until triggered, ignores invulnerability and isolation", Color.DIM_GRAY]
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
