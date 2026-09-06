extends Ability
var base_damage = 50
var damage_boost_inc = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Destroys the enemy team's Shield and deals 50 damage to them, increased by 25 for each of Saitama's allies that are dead. Uncounterable, Unreflectable."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var dead_allies = 0
	for character in user.team.characters:
		if character.dead and not character == user:
			dead_allies += 1
	
	for target in user.targeter.targets:
		target.shatter_shields(user)
		Character.resolve_damage(context, target, base_damage + (dead_allies * damage_boost_inc), DamageType.Type.NORMAL)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 50, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
