extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, Xanxus can trigger Scars of Wrath as though it had not yet been triggered by any effects this game. Invisible."

func split_desc():
	return [
		["For 1 turn, Xanxus can trigger Scars of Wrath as though it had not yet been triggered this game", Color.CADET_BLUE],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(2, func (eff): return "Xanxus can trigger Scars of Wrath as though it hasn't been triggered by any effects this game.")
	mark.set_source(self)
	mark.invisible = true
	mark.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 85, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here

	default_self_target_function(user, battle)
