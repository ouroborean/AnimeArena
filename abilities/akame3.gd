extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 2 turns, Akame is invulnerable to Physical skills and she may use One Cut Killing on any target. "

func split_desc():
	return ["Akame becomes invulnerable to Physical skills for 2 turns",
		["Akame can use One Cut Killing on any target while active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(3, "Akame can use One Cut Killing on any target.")
	mark.set_source(self)
	var invuln = Effect.invuln_effect(4, ["Physical"])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, invuln)
	
		
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
