extends Ability

var base_healing = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sayaka heals an ally for 10 health for 5 turns."

func split_desc():
	return [
		"For 5 turns, target ally heals 10 HP"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_healing(context, target, base_healing)
		var heal_eff = Effect.healing_effect(base_healing, 9)
		heal_eff.set_source(self)
		Character.add_allied_effect(context, user, target, heal_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 30, 1.5)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
