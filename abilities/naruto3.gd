extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return ["Naruto gains 1 Green energy and heals 25 HP",
	["Cannot be used again until Naruto uses Toad Kumite or Rasenshuriken", Color.DIM_GRAY]]

func execute(user, battle):
	var context = make_context(battle)

	Character.resolve_healing(context, user, 25)
	user.gain_bonus_energy(Energy.Type.GREEN)

func custom_behavior(context):
	var variations = []

	variations += behavior_self_panic_button(context, 35, 1.5)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Sage Chakra Gather")
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
