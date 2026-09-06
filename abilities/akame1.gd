extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Marks one enemy for two turns. During this time, One-Cut Killing may be used on them."

func split_desc():
	return [
		"For 2 turns, Akame can use One-Cut Killing on target enemy"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mark = Effect.mark(5, "This character can be targeted by One-Cut Killing.")
		mark.set_source(self)
		Character.add_allied_effect(context, user, target, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true


func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
