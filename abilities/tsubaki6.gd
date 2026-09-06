extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Removes all cleansable allied effects from target enemy then deals 40 damage to them",
		["Removes all cleansable enemy effects from the user", Color.AQUAMARINE],
		["Uncounterable", Color.DIM_GRAY]
	]

func execute(_user, battle):
	var context = QueryContext.from_game_state(_user, battle)
	_user.effects.cleanse_all_enemy_effects(_user)
	for target in _user.targeter.targets:
		target.effects.cleanse_all_ally_effects(target, _user)
		Character.resolve_damage(context, target, 40, DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 150)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
