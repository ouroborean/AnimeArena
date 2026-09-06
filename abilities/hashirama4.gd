extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For one turn, the first Harmful skill that targets Hashirama or one ally will be delayed for 2 turns. Invisible until triggered."

func split_desc():
	return [
		"The first Harmful skill to target Hashirama or the chosen ally is delayed for 2 turns",
		["Lasts 1 turn, invisible until triggered", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var delay_receive = Effect.delay_receive_eff(2, 2, 1, ["Harmful"])
		delay_receive.set_source(self)
		delay_receive.invisible = true
		delay_receive.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, delay_receive)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
