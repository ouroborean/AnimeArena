extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Alphonse gains 1 random energy, permanently swaps this skill to Ground Pillars, and enables the use of Weapon Alchemy and Destruction Alchemy Strike."

func split_desc():
	return [
		"Alphonse gains 1 Random energy",
		"Enables the use of Ground Pillars, Weapon Alchemy, and Destruction Alchemy Strike",
		["Swaps to Ground Pillars", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.gain_random_energy()
	var swap = Effect.ability_swap_effect(4, 0, user, -1)
	swap.set_source(self)
	
	var mark = Effect.mark(-1, func (eff): return "Alphonse can use Weapon Alchemy and Destruction Alchemy Strike.")
	mark.set_source(self)
	mark.cleansable = false

	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 150)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
