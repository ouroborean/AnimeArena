extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Removes all Nullify from Squalo, all Shield from target enemy, then deals 20 Piercing damage to them"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shattered = 0
	shattered += user.shatter_barrier(user)
	
	for target in user.targeter.targets:
		shattered += target.shatter_shields(user)
		Character.resolve_damage(context, target, 20, DamageType.Type.PIERCING)
	user.manually_advance_mission(6, shattered)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 10)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
