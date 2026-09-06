extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next three turns, Lucy's skills will stay active for one more turn. During this time, this ability is replaced by Urano Metria."

func split_desc():
	return [
		["For 3 turns, Lucy's skills stay active for 1 more turn", Color.CADET_BLUE],
		["Replaced by Urano Metria while active", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(7, "Lucy's skills will stay active for one more turn.")
	mark.set_source(self)
	var swap = Effect.ability_swap_effect(4, 1, user, 7)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 60)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
