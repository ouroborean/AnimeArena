extends Ability

var base_damage = 40

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 65 damage to one enemy."

func split_desc():
	return [
		"Deals 40 damage to one enemy"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	#The 135 nuke premium was tuned to a 65 damage hit; scaled with the damage (135 * 40/65) so the
	#policy stops over-valuing Titan Bite. missing_ratio is unchanged - the finisher shape still holds.
	variations += behavior_single_target_damage(context, 80, 0.6)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
