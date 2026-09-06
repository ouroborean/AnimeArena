extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 3 turns, Hammer Swing will stun a random class of skills for 1 turn, chosen randomly from Physical, Mental, Energy, and Affliction. The same class cannot be chosen twice. Swaps to Hairpin while active."

func split_desc():
	return [
		["For 3 turns, Hammer Swing stuns a random skill class for 1 turn (Physical, Mental, Energy, or Affliction)", Color.CADET_BLUE],
		["The same class cannot be chosen twice", Color.DIM_GRAY],
		["Swaps to Hairpin while active", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(7, "Hammer Swing will stun a random class of skill each turn.")
	mark.set_source(self)
	mark.ability_targets = ["Physical", "Energy", "Mental", "Affliction"]
	Character.add_allied_effect(context, user, user, mark)
	var swap = Effect.ability_swap_effect(4, 2, user, 7)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
		
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
