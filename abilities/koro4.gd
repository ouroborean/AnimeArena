extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.
 
func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 4 turns, Impossible Speed Bypasses and will mark its target for the remainder of Pitch Black's duration. During this time, whenever Impossible Speed is used, Koro-Sensei will also use it on any marked target."

func split_desc():
	return [
		["For 4 turns, Impossible Speed Bypasses and marks its target for the rest of Pitch Black's duration", Color.CADET_BLUE],
		["While active, using Impossible Speed also hits any marked target", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(9, "Impossible Speed will Bypass and mark its target for the duration of Pitch Black. Whenever Koro-sensei uses Impossible Speed, it will also target all marked targets.")
	mark.set_source(self)
	Character.add_hostile_effect(context, user, user, mark)
		
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
	default_self_target_function(user, battle)
