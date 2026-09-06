extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ophanimon becomes invulnerable for 1 turn and removes all harmful skills from her team. This skill shares a cooldown with Nekodamashi."

func split_desc():
	return [
		"Ophanimon becomes Invulnerable for 1 turn and removes all enemy effects from her team",
		"Shares a cooldown with Nekodamashi"
	]
	

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	for character in user.team.characters:
		character.effects.cleanse_all_enemy_effects(character)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25, 1.1)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	
	default_self_target_function(user, battle)
