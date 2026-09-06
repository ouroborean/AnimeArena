extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to target enemy",
		["+15 damage if targeting an enemy whose allies don't have the same HP remaining as each other", Color.CADET_BLUE],
		["+15 damage if targeting an enemy with different HP than their only living ally", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var base_damage = 10
	for target in user.targeter.targets:
		var allies = []
		for character in target.team.characters:
			if not character.dead and character != target:
				allies.append(character)
		if len(allies) == 1:
			if allies[0].health.hp != target.health.hp:
				base_damage += 15
				user.manually_advance_mission(6, 1)
		elif len(allies) == 2:
			if allies[0].health.hp != allies[1].health.hp:
				base_damage += 15
				user.manually_advance_mission(6, 1)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
