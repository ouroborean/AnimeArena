extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, Black Star gains 5 Damage Reduction and Taunts target enemy. This effect Bypasses, and swaps Speed Star and Black Star Big Wave to their alternates."

func split_desc():
	return [
		"Gives Black Star 5 Damage Reduction and Taunts target enemy for 3 turns (Bypasses)",
		["Swaps Speed Star to The Unexplored Path", Color.AQUAMARINE],
		["Swaps Black Star Big Wave to Shadow Star", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var taunt = Effect.taunt_effect(6, user)
		taunt.set_source(self)
		
		var vuln = Effect.vulnerability_effect(10, 7, ["The Unexplored Path"])
		vuln.set_source(self)
		
		Character.add_hostile_effect(context, user, target, taunt, true)
		Character.add_hostile_effect(context, user, target, vuln, true)
		
	
	var dr = Effect.damage_reduction_effect(5, 6)
	dr.set_source(self)
	var swap1 = Effect.ability_swap_effect(4, 0, user, 7)
	swap1.set_source(self)
	var swap2 = Effect.ability_swap_effect(5, 1, user, 7)
	swap2.set_source(self)
	Character.add_allied_effect(context, user, user, dr, true)
	Character.add_allied_effect(context, user, user, swap1, true)
	Character.add_allied_effect(context, user, user, swap2, true)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 50, true)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
