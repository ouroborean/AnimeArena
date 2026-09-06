extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tatsumaki becomes invulnerable for 1 turn. Swaps with City-Wide Barrier for 4 turns."

func split_desc():
	return [
		["Tatsumaki becomes invulnerable for 1 turn", Color.CADET_BLUE],
		["Swaps with City-Wide Barrier for 4 turns", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	var ability_swap = Effect.ability_swap_effect(5, 3, user, 7)
	ability_swap.set_source(self)
	Character.add_allied_effect(context, user, user, ability_swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0, 2.0)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
