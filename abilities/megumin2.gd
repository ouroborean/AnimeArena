extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Reduces the cost of Explosion by 2 Random until the next time it is used (stacks)",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var cost_mod = Effect.cost_mod_effect(-2, -1, Energy.Type.RANDOM, ["Explosion"])
	cost_mod.set_source(self)
	cost_mod.stackable = true
	cost_mod.stack_mag = true
	cost_mod.display_stacks = true
	Character.add_allied_effect(context, user, user, cost_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Explosion")
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
