extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Gilgamesh becomes invulnerable for one turn. This skill requires 1 stack of Gate of Babylon to be used, and consumes that stack on use."

func split_desc():
	return [
		"Gilgamesh becomes Invulnerable for 1 turn",
		"Must consume 1 stack of Gate of Babylon to be used"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	# extra_usable() requires the mark, but a same-turn cleanse could strip it before this resolves —
	# guard the consume so the skill still grants its Invuln instead of null-derefing.
	var gates = user.has_effect("Gate of Babylon", EffectType.Type.MARK, user)
	if gates != null:
		gates.consume_stack(1)

	default_defend(user, battle)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Gate of Babylon", user)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
