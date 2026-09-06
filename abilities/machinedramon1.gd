extends Ability
var base_damage = 35
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 35 damage to one enemy, removes 1 random energy from them, and Taunts them for 1 turn."

func split_desc():
	return [
		"Deals 35 damage to target enemy",
		"Removes 1 random energy from them",
		"Taunts them for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var taunt = Effect.taunt_effect(2, user)
		taunt.set_source(self)
		Character.add_hostile_effect(context, user, target, taunt, true)
		target.lose_energy(user, 1)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 40, 0.9)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
