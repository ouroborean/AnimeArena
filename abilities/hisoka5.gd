extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Each skill that Hisoka ignored with Bungee Gum - Catch is used on target enemy",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var gum = user.has_effect("Bungee Gum - Catch", EffectType.Type.MARK)
	if not gum:
		return
	for target in user.targeter.targets:
		for skill in gum.class_targets:
			var path = skill.get_script().get_path()
			var mod_path = path.substr(16, len(path) - 3 - 16)
			var ability = Ability.from_database(mod_path)
			ability.user = user
			ability.execute(user, user.battle)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
