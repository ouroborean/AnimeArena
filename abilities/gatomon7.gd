extends Ability
var base_power = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Target ally heals 10 HP and gains 10 Shield and 10 DR for 1 turn."

func split_desc():
	return [
		"Heals target ally 10 HP and gives them 10 Shield and 10 Damage Reduction for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_healing(context, target, base_power)
		var shield = Effect.shield_effect(10, 2)
		shield.set_source(self)
		var dr = Effect.damage_reduction_effect(10, 2)
		dr.set_source(self)
		Character.add_allied_effect(context, user, target, dr)
		Character.add_allied_effect(context, user, target, shield)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 65, 1.4)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
