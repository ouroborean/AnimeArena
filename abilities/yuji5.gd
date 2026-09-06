extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever Yuji deals True damage, he has a 10% chance to deal 15 bonus True damage and stun his target's Harmful skills for 1 turn. This chance increases by 15% each time he deals True damage, and resets to 10% when it triggers successfully."

func split_desc():
	return [
		["When Yuji deals True damage, 15% chance to deal 15 bonus True damage and stun the target's Harmful skills for 1 turn", Color.DIM_GRAY],
		["Chance increases 20% each time he deals True damage, and resets to its minimum (15%, raised by Consume Finger) on a successful trigger", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(-1, "When this character deals True damage, he has a chance to deal 15 bonus True damage and stun his target's Harmful skills for 1 turn.")
	mark.set_source(self)
	mark.display_mag = true
	# The opening chance is the SAME number character/yuji.gd holds as black_flash_minimum — the
	# passive stamps it here, that file resets to it and re-seeds the mark with it after a cleanse.
	mark.mag = 15
	Character.add_allied_effect(context, user, user, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
