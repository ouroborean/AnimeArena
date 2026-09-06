extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ace gains 50% Damage Reduction for 1 turn, and 5 Damage Reduction permanently (stacks)."

func split_desc():
	return [
		"Ace gains 50% Damage Reduction for 1 turn and 5 permanent Damage Reduction (stacks)",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var percent = Effect.percent_dr(50, 2)
	percent.set_source(self)
	var flat = Effect.damage_reduction_effect(5, -1)
	flat.set_source(self)
	flat.stackable = true
	flat.display_stacks = true
	flat.stack_mag = true
	Character.add_allied_effect(context, user, user, flat)
	Character.add_allied_effect(context, user, user, percent)
	
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
