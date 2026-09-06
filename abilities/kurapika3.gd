extends Ability
var base_healing = 35
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Removes all enemy harmful effects from target ally and heals them 35HP."

func split_desc():
	return [
		"Removes all enemy effects from target ally",
		"Heals them 35 HP"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		target.effects.cleanse_all_enemy_effects(target)
		Character.resolve_healing(context, target, base_healing)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 40)
	
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
