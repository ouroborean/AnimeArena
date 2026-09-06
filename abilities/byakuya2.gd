extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Target enemy is Shattered and Stunned for 2 turns. During this time, this skill is replaced by Hado #4: Pale Lightning."

func split_desc():
	return [
		"Shatters and Stuns target enemy for 2 turns",
		["Swaps to Hado #4: Pale Lightning while active", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun_eff = Effect.stun_effect(4, [], [])
		stun_eff.set_source(self)
		var shatter_eff = Effect.def_negate(4)
		shatter_eff.set_source(self)
		stun_eff.remove_on_death = true
		Character.add_hostile_effect(context, user, target, shatter_eff)
		Character.add_hostile_effect(context, user, target, stun_eff)
	var move_swap = Effect.ability_swap_effect(5, 1, user, 5)
	move_swap.set_source(self)
	Character.add_allied_effect(context, user, user, move_swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
