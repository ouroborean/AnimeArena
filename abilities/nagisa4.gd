extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Nagisa becomes Invulnerable for 1 turn. Increases the duration of Killing Intent by 1 turn until the next time it is used (stacks)."

func split_desc():
	return [
		"Nagisa becomes invulnerable for 1 turn",
		["Killing Intent lasts 1 more turn until next used (stacks)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	var mark = Effect.mark(-1, "Killing Intent will last 1 more turn.")
	mark.set_source(self)
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 50, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
