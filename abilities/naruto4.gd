extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The next time Naruto's health is brought to 45 or below, this skill will activate. When triggered, all enemy skills are removed from him, he becomes invulnerable for 1 turn, Uzumaki Barrage and this skill swap to their alternate abilities, and Rasengan will deal its damage and non-damage effects instantly. This skill cannot be removed."

func split_desc():
	return [
		"Naruto becomes Invulnerable for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context)
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
