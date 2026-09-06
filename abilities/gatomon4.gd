extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Gatomon becomes Invulnerable for 1 turn and gains one stack of Digivolution. This skill shares a cooldown with Angel Wings and Holy Light."

func split_desc():
	return [
		"Gatomon becomes Invulnerable for 1 turn",
		["Shares a cooldown with Angel Wings and Holy Light", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	user.moveset.base_abilities[7].start_cooldown()
	user.moveset.base_abilities[12].start_cooldown()
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here

	default_self_target_function(user, battle)
