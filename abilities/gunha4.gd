extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"If Gunha has at least 1 stack of Guts, he becomes Invulnerable for 1 turn",
		["If he has no stacks of Guts, he gains 3 stacks and heals 35 HP", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var current_stacks = 0
	var guts = user.has_effect("Guts", EffectType.Type.MARK)
	if guts:
		current_stacks = guts.mag
	if current_stacks > 0:
		default_defend(user, battle)
	else:
		if not guts:
			return
		guts.mag += 3
		Character.resolve_healing(context, user, 35)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
