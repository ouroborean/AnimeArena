extends Ability
var base_damage = 25
var splash_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 damage to one enemy, and 10 damage to the others."

func split_desc():
	return [
		"Deals 25 damage to one enemy, and 10 damage to all other enemies"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target == user.targeter.main_target:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		else:
			Character.resolve_damage(context, target, splash_damage, DamageType.Type.NORMAL)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_splash_aoe(context, 45)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
