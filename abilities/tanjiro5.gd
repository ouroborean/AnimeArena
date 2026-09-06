extends Ability
var base_damage = 30
var per_dead = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tanjiro deals 30 damage to all enemies. This skill will deal 20 additional damage for each dead enemy."

func split_desc():
	return [
		"Deals 30 damage to all enemies, +20 per dead enemy"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var boost_count = 0
	for character in battle.all_characters():
		if character in user.team.characters:
			continue
		if character.dead:
			boost_count += 1
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + (boost_count * per_dead), DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
