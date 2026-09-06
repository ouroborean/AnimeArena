extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"The first time each game that Neferpitou would die, they instead become Immortal until the end of their next turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Post-Mortem Nen install marker — permanent and MUST be uncleansable: a "helpful" cleanse /
	# buff-strip must not be able to negate the once-per-game death save by removing this mark before
	# Neferpitou dies. Effect.mark() defaults cleansable=true (unlike permanent trigger machinery,
	# which auto-protects), so gain_mark's mark is pinned uncleansable here instead.
	var mark = Effect.mark(-1, "The first time Neferpitou would die, they instead become Immortal until the end of their next turn.")
	mark.set_source(self)
	mark.cleansable = false
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
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
